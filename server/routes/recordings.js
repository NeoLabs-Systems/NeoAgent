const express = require('express');
const fs = require('fs');

const { requireAuth } = require('../middleware/auth');
const { sanitizeError } = require('../utils/security');
const db = require('../db/database');

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

async function readChunkBody(req) {
  if (Buffer.isBuffer(req.body) && req.body.length > 0) {
    return req.body;
  }
  if (req.readableEnded) {
    return Buffer.alloc(0);
  }

  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', (chunk) => {
      chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
    });
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
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

router.get('/:sessionId/audio/:sourceKey', (req, res) => {
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

    res.setHeader('Content-Type', mimeType);
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('Content-Disposition', `inline; filename="${source.source_key}.audio"`);

    for (const chunk of chunks) {
      const filePath = chunk.file_path;
      if (!filePath || !fs.existsSync(filePath)) {
        continue;
      }
      const bytes = fs.readFileSync(filePath);
      if (bytes.length > 0) {
        res.write(bytes);
      }
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
