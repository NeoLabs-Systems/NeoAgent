const express = require('express');

const { requireAuth } = require('../middleware/auth');
const { sanitizeError } = require('../utils/security');

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
  return {
    sourceKey: req.get('x-recording-source-key') || req.query.sourceKey,
    sequenceIndex: req.get('x-recording-sequence') || req.query.sequenceIndex,
    startMs: req.get('x-recording-start-ms') || req.query.startMs,
    endMs: req.get('x-recording-end-ms') || req.query.endMs,
    mimeType: req.get('content-type') || req.query.mimeType,
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

module.exports = router;
