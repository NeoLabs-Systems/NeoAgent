const express = require('express');
const fs = require('fs');
const { finished } = require('stream/promises');

const { requireAuth } = require('../middleware/auth');
const { sanitizeError } = require('../utils/security');
const db = require('../db/database');
const { readChunkBody } = require('./_helpers/readChunkBody');

const router = express.Router();

router.use(requireAuth);

function getRecordingManager(req) {
  return req.app.locals.recordingManager;
}

function parsePositiveInt(value, fallback) {
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function getChunkMetadata(req) {
  const parseNonNegativeNumber = (value, fieldName) => {
    const parsed = Number(value);
    if (!Number.isFinite(parsed) || parsed < 0) {
      throw new Error(`${fieldName} must be a non-negative number`);
    }
    return parsed;
  };

  const sequenceIndexRaw = req.get('x-recording-sequence') || req.query.sequenceIndex;
  const startMsRaw = req.get('x-recording-start-ms') || req.query.startMs;
  const endMsRaw = req.get('x-recording-end-ms') || req.query.endMs;
  const mimeRaw = req.get('content-type') || req.query.mimeType || '';

  return {
    sourceKey: req.get('x-recording-source-key') || req.query.sourceKey,
    sequenceIndex: parseNonNegativeNumber(sequenceIndexRaw, 'sequenceIndex'),
    startMs: parseNonNegativeNumber(startMsRaw, 'startMs'),
    endMs: parseNonNegativeNumber(endMsRaw, 'endMs'),
    mimeType: String(mimeRaw).split(';')[0].trim(),
  };
}

const WAV_HEADER_BYTES = 44;

// Reads the canonical 44-byte WAV header our recorders emit. Returns the audio
// format fields, or null when the file is not a canonical WAV (in which case
// the caller streams the chunks unmodified instead of rebuilding a WAV).
async function readCanonicalWavHeader(filePath) {
  let handle;
  try {
    handle = await fs.promises.open(filePath, 'r');
    const { bytesRead, buffer } = await handle.read(
      Buffer.alloc(WAV_HEADER_BYTES),
      0,
      WAV_HEADER_BYTES,
      0,
    );
    if (
      bytesRead < WAV_HEADER_BYTES
      || buffer.toString('ascii', 0, 4) !== 'RIFF'
      || buffer.toString('ascii', 8, 12) !== 'WAVE'
      || buffer.toString('ascii', 36, 40) !== 'data'
    ) {
      return null;
    }
    return {
      audioFormat: buffer.readUInt16LE(20),
      channelCount: buffer.readUInt16LE(22),
      sampleRate: buffer.readUInt32LE(24),
      bitsPerSample: buffer.readUInt16LE(34),
    };
  } catch {
    return null;
  } finally {
    await handle?.close();
  }
}

function buildWavHeader({ audioFormat, channelCount, sampleRate, bitsPerSample }, dataLength) {
  const blockAlign = channelCount * (bitsPerSample / 8);
  const byteRate = sampleRate * blockAlign;
  const header = Buffer.alloc(WAV_HEADER_BYTES);
  header.write('RIFF', 0, 4, 'ascii');
  header.writeUInt32LE(36 + dataLength, 4);
  header.write('WAVE', 8, 4, 'ascii');
  header.write('fmt ', 12, 4, 'ascii');
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(audioFormat, 20);
  header.writeUInt16LE(channelCount, 22);
  header.writeUInt32LE(sampleRate, 24);
  header.writeUInt32LE(byteRate, 28);
  header.writeUInt16LE(blockAlign, 32);
  header.writeUInt16LE(bitsPerSample, 34);
  header.write('data', 36, 4, 'ascii');
  header.writeUInt32LE(dataLength, 40);
  return header;
}

function buildInlineFilename(sourceKey) {
  const original = `${String(sourceKey || 'recording').normalize('NFKC')}.audio`
    .replace(/[\r\n]+/g, ' ')
    .trim() || 'recording.audio';
  const safeAscii = original
    .replace(/["]/g, "'")
    .replace(/[^\x20-\x7E]+/g, '_')
    .trim() || 'recording.audio';
  return `inline; filename="${safeAscii}"; filename*=UTF-8''${encodeURIComponent(original)}`;
}

function statusFromMessage(message, rules, fallbackStatus = 500) {
  for (const rule of rules) {
    if (rule.pattern.test(message)) {
      return rule.status;
    }
  }
  return fallbackStatus;
}

function respondWithMappedError(res, err, rules, fallbackStatus = 500) {
  const message = sanitizeError(err);
  res.status(statusFromMessage(message, rules, fallbackStatus)).json({ error: message });
}

router.get('/', (req, res) => {
  try {
    const manager = getRecordingManager(req);
    const sessions = manager.listSessions(req.session.userId, {
      limit: parsePositiveInt(req.query.limit, 24),
    });
    res.json(sessions);
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

router.get('/:sessionId', (req, res) => {
  try {
    const manager = getRecordingManager(req);
    const session = manager.getSession(req.session.userId, req.params.sessionId);
    res.json({ session });
  } catch (err) {
    respondWithMappedError(res, err, [
      { pattern: /not found/i, status: 404 },
    ]);
  }
});

router.get('/:sessionId/audio/:sourceKey', async (req, res) => {
  try {
    const sessionId = req.params.sessionId;
    const sourceKey = String(req.params.sourceKey || '').trim();
    if (!sourceKey) {
      return res.status(400).json({ error: 'sourceKey is required.' });
    }

    const session = db.prepare(`
      SELECT id
      FROM recording_sessions
      WHERE id = ? AND user_id = ?
    `).get(sessionId, req.session.userId);
    if (!session) {
      return res.status(404).json({ error: 'Recording session not found.' });
    }

    const source = db.prepare(`
      SELECT id, source_key, mime_type
      FROM recording_sources
      WHERE session_id = ? AND LOWER(source_key) = LOWER(?)
      LIMIT 1
    `).get(sessionId, sourceKey);
    if (!source) {
      return res.status(404).json({ error: 'Recording source not found.' });
    }

    const chunks = db.prepare(`
      SELECT file_path, mime_type
      FROM recording_chunks
      WHERE source_id = ?
      ORDER BY sequence_index ASC
    `).all(source.id);
    if (!Array.isArray(chunks) || chunks.length == 0) {
      return res.status(404).json({ error: 'No audio chunks available.' });
    }

    const mimeType = String(source.mime_type || chunks[0]?.mime_type || 'application/octet-stream');
    if (!mimeType.startsWith('audio/')) {
      return res.status(415).json({
        error: `Playback unsupported for mime type: ${mimeType}`,
      });
    }

    const readableChunks = [];
    for (const chunk of chunks) {
      const filePath = chunk.file_path;
      if (!filePath) {
        continue;
      }
      try {
        await fs.promises.access(filePath, fs.constants.R_OK);
        readableChunks.push(chunk);
      } catch {
        // Skip chunk files that are missing or unreadable on disk.
      }
    }
    if (readableChunks.length === 0) {
      return res.status(404).json({ error: 'No audio chunks available.' });
    }

    res.setHeader('Content-Type', mimeType);
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('Content-Disposition', buildInlineFilename(source.source_key));

    // Each WAV chunk is a self-contained file with its own 44-byte RIFF header
    // whose declared length only covers that chunk. Streaming them back-to-back
    // produces a file most players stop reading after the first chunk. Rebuild
    // one continuous WAV: a single header sized for the combined PCM, followed
    // by the raw sample data from every chunk. Non-WAV containers (e.g. WebM)
    // concatenate into a valid stream as-is.
    const wavFormat = /wav/i.test(mimeType)
      ? await readCanonicalWavHeader(readableChunks[0].file_path)
      : null;

    if (wavFormat) {
      let totalPcmBytes = 0;
      for (const chunk of readableChunks) {
        const { size } = await fs.promises.stat(chunk.file_path);
        totalPcmBytes += Math.max(0, size - WAV_HEADER_BYTES);
      }
      res.write(buildWavHeader(wavFormat, totalPcmBytes));
      for (const chunk of readableChunks) {
        const stream = fs.createReadStream(chunk.file_path, { start: WAV_HEADER_BYTES });
        stream.pipe(res, { end: false });
        await finished(stream);
      }
      res.end();
      return;
    }

    for (const chunk of readableChunks) {
      const stream = fs.createReadStream(chunk.file_path);
      stream.pipe(res, { end: false });
      await finished(stream);
    }

    res.end();
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

router.post('/', (req, res) => {
  try {
    const manager = getRecordingManager(req);
    const session = manager.createSession(req.session.userId, req.body || {});
    res.status(201).json({ session });
  } catch (err) {
    respondWithMappedError(res, err, [
      { pattern: /source|title|required|duplicate/i, status: 400 },
    ]);
  }
});

router.post('/:sessionId/chunks', async (req, res) => {
  try {
    const manager = getRecordingManager(req);
    const body = await readChunkBody(req);
    const result = manager.appendChunk(req.session.userId, req.params.sessionId, getChunkMetadata(req), body);
    res.status(result.duplicate ? 200 : 201).json(result);
  } catch (err) {
    console.error('[Recordings] Chunk upload failed:', err);
    respondWithMappedError(res, err, [
      { pattern: /not found/i, status: 404 },
      { pattern: /empty|required|unknown|non-negative|accepting|sequence|contiguous/i, status: 400 },
    ]);
  }
});

router.post('/:sessionId/finalize', (req, res) => {
  try {
    const manager = getRecordingManager(req);
    const session = manager.finalizeSession(req.session.userId, req.params.sessionId, req.body || {});
    res.json({ session });
  } catch (err) {
    respondWithMappedError(res, err, [
      { pattern: /not found/i, status: 404 },
    ]);
  }
});

router.post('/:sessionId/retry', async (req, res) => {
  try {
    const manager = getRecordingManager(req);
    const session = await manager.retrySession(req.session.userId, req.params.sessionId);
    res.json({ session });
  } catch (err) {
    respondWithMappedError(res, err, [
      { pattern: /not found/i, status: 404 },
      { pattern: /configured/i, status: 400 },
    ]);
  }
});

router.delete('/:sessionId/segments/:segmentId', (req, res) => {
  try {
    const manager = getRecordingManager(req);
    const session = manager.deleteTranscriptSegment(
      req.session.userId,
      req.params.sessionId,
      req.params.segmentId,
    );
    res.json({ session });
  } catch (err) {
    respondWithMappedError(res, err, [
      { pattern: /not found/i, status: 404 },
      { pattern: /positive integer/i, status: 400 },
    ]);
  }
});

router.delete('/:sessionId', (req, res) => {
  try {
    const manager = getRecordingManager(req);
    manager.deleteSession(req.session.userId, req.params.sessionId);
    res.status(204).send();
  } catch (err) {
    respondWithMappedError(res, err, [
      { pattern: /not found/i, status: 404 },
    ]);
  }
});

module.exports = router;
