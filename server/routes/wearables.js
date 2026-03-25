'use strict';

const express = require('express');
const { requireAuth } = require('../middleware/auth');
const { sanitizeError } = require('../utils/security');

const router = express.Router();
router.use(requireAuth);

async function readChunkBody(req, maxSize = 10 * 1024 * 1024, timeout = 30000) {
  if (Buffer.isBuffer(req.body) && req.body.length > 0) {
    if (req.body.length > maxSize) throw new Error('Payload too large');
    return req.body;
  }
  if (req.readableEnded) {
    return Buffer.alloc(0);
  }
  return new Promise((resolve, reject) => {
    const chunks = [];
    let totalSize = 0;

    const timer = setTimeout(() => {
      cleanup();
      reject(new Error('Request timeout'));
      req.destroy();
    }, timeout);

    const onData = (chunk) => {
      const b = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
      totalSize += b.length;
      if (totalSize > maxSize) {
        cleanup();
        reject(new Error('Payload too large'));
        req.destroy();
        return;
      }
      chunks.push(b);
    };

    const onEnd = () => {
      cleanup();
      resolve(Buffer.concat(chunks));
    };

    const onError = (err) => {
      cleanup();
      reject(err);
    };

    function cleanup() {
      clearTimeout(timer);
      req.removeListener('data', onData);
      req.removeListener('end', onEnd);
      req.removeListener('error', onError);
    }

    req.on('data', onData);
    req.on('end', onEnd);
    req.on('error', onError);
  });
}

router.get('/', (req, res) => {
  try {
    const manager = req.app.locals.wearableManager;
    res.json(manager.listDevices(req.session.userId));
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

router.get('/protocols', (req, res) => {
  try {
    const manager = req.app.locals.wearableManager;
    res.json(manager.getProtocols());
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

router.post('/', (req, res) => {
  try {
    const manager = req.app.locals.wearableManager;
    const { macAddress, protocol, name } = req.body;
    if (!macAddress || !protocol) return res.status(400).json({ error: 'macAddress and protocol required' });

    const device = manager.registerDevice(req.session.userId, macAddress, protocol, name);
    res.status(201).json(device);
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

router.post('/:macAddress/status', (req, res) => {
  try {
    const manager = req.app.locals.wearableManager;
    const { status, batteryLevel } = req.body;
    const device = manager.updateStatus(req.session.userId, req.params.macAddress, status, batteryLevel);
    if (!device) return res.status(404).json({ error: 'Device not found' });
    res.json(device);
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

router.post('/:macAddress/stream', async (req, res) => {
  try {
    const manager = req.app.locals.wearableManager;
    const rawBuffer = await readChunkBody(req);
    if (rawBuffer.length === 0) return res.status(400).json({ error: 'Empty payload' });

    const characteristicUuid = req.headers['x-characteristic-uuid'] || req.body.characteristicUuid;
    manager.handleLiveStreamChunk(req.session.userId, req.params.macAddress, rawBuffer, { characteristicUuid });
    res.status(200).json({ success: true });
  } catch (err) {
    const is404 = /not found/i.test(err.message);
    res.status(is404 ? 404 : 500).json({ error: sanitizeError(err) });
  }
});

router.post('/:macAddress/sync', async (req, res) => {
  try {
    const manager = req.app.locals.wearableManager;
    const rawBuffer = await readChunkBody(req);
    if (rawBuffer.length === 0) return res.status(400).json({ error: 'Empty payload' });

    const session = await manager.syncOfflineAudio(req.session.userId, req.params.macAddress, rawBuffer);
    res.status(200).json({ success: true, sessionId: session.id });
  } catch (err) {
    const is404 = /not found/i.test(err.message);
    res.status(is404 ? 404 : 500).json({ error: sanitizeError(err) });
  }
});

module.exports = router;
