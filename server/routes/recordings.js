const express = require('express');

const { requireAuth } = require('../middleware/auth');
const { sanitizeError } = require('../utils/security');

const router = express.Router();

router.use(requireAuth);

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
    const manager = req.app.locals.recordingManager;
    const sessions = manager.listSessions(req.session.userId, {
      limit: Number(req.query.limit) || 24,
    });
    res.json(sessions);
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

router.get('/:sessionId', (req, res) => {
  try {
    const manager = req.app.locals.recordingManager;
    const session = manager.getSession(req.session.userId, req.params.sessionId);
    res.json({ session });
  } catch (err) {
    const message = sanitizeError(err);
    res.status(/not found/i.test(message) ? 404 : 500).json({ error: message });
  }
});

router.post('/', (req, res) => {
  try {
    const manager = req.app.locals.recordingManager;
    const session = manager.createSession(req.session.userId, req.body || {});
    res.status(201).json({ session });
  } catch (err) {
    const message = sanitizeError(err);
    res.status(/source|title|required|duplicate/i.test(message) ? 400 : 500).json({ error: message });
  }
});

router.post('/:sessionId/chunks', async (req, res) => {
  try {
    const manager = req.app.locals.recordingManager;
    const body = await readChunkBody(req);
    const result = manager.appendChunk(
      req.session.userId,
      req.params.sessionId,
      {
        sourceKey: req.get('x-recording-source-key') || req.query.sourceKey,
        sequenceIndex: req.get('x-recording-sequence') || req.query.sequenceIndex,
        startMs: req.get('x-recording-start-ms') || req.query.startMs,
        endMs: req.get('x-recording-end-ms') || req.query.endMs,
        mimeType: req.get('content-type') || req.query.mimeType,
      },
      body,
    );
    res.status(result.duplicate ? 200 : 201).json(result);
  } catch (err) {
    console.error('[Recordings] Chunk upload failed:', err);
    const message = sanitizeError(err);
    const status = /not found/i.test(message)
      ? 404
      : /empty|required|unknown|non-negative|accepting/i.test(message)
        ? 400
        : 500;
    res.status(status).json({ error: message });
  }
});

router.post('/:sessionId/finalize', (req, res) => {
  try {
    const manager = req.app.locals.recordingManager;
    const session = manager.finalizeSession(req.session.userId, req.params.sessionId, req.body || {});
    res.json({ session });
  } catch (err) {
    const message = sanitizeError(err);
    res.status(/not found/i.test(message) ? 404 : 500).json({ error: message });
  }
});

router.post('/:sessionId/retry', async (req, res) => {
  try {
    const manager = req.app.locals.recordingManager;
    const session = await manager.retrySession(req.session.userId, req.params.sessionId);
    res.json({ session });
  } catch (err) {
    const message = sanitizeError(err);
    res.status(/not found/i.test(message) ? 404 : /configured/i.test(message) ? 400 : 500).json({ error: message });
  }
});

router.delete('/:sessionId/segments/:segmentId', (req, res) => {
  try {
    const manager = req.app.locals.recordingManager;
    const session = manager.deleteTranscriptSegment(
      req.session.userId,
      req.params.sessionId,
      req.params.segmentId,
    );
    res.json({ session });
  } catch (err) {
    const message = sanitizeError(err);
    const status = /not found/i.test(message)
      ? 404
      : /positive integer/i.test(message)
        ? 400
        : 500;
    res.status(status).json({ error: message });
  }
});

module.exports = router;
