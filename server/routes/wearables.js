'use strict';

const express = require('express');
const { requireAuth } = require('../middleware/auth');
const { sanitizeError } = require('../utils/security');
const { getAgentIdFromRequest, resolveAgentId } = require('../services/agents/manager');
const { wearableDeviceAuth } = require('../services/wearables/device_auth');
const {
  buildIngestHttpResponse,
  readWearableAudioChunk,
  requireCharacteristicUuid,
  requireWearableManager,
  toWearableRouteError,
} = require('./_helpers/wearableAudioRoutes');

const router = express.Router();
router.use(requireAuth);

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

router.post('/pairing/code', (req, res) => {
  try {
    const agentId = resolveAgentId(req.session.userId, getAgentIdFromRequest(req));
    const pairing = wearableDeviceAuth.createPairingCode(req.session.userId, {
      agentId,
      ttlMinutes: req.body?.ttlMinutes,
      source: 'wearables_panel',
      deviceHint: req.body?.deviceHint,
    });
    res.status(201).json(pairing);
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
    const message = sanitizeError(err);
    const isClientError = /unsupported wearable protocol|required/i.test(message);
    res.status(isClientError ? 400 : 500).json({ error: message });
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

router.post('/:macAddress/stop-live', (req, res) => {
  try {
    const manager = req.app.locals.wearableManager;
    const ended = manager.stopLiveStream(req.session.userId, req.params.macAddress, 'wearable_stopped');
    res.json({ success: true, ended });
  } catch (err) {
    const mapped = toWearableRouteError(err);
    res.status(mapped.status).json({ error: mapped.message });
  }
});

router.post('/:macAddress/stream', async (req, res) => {
  try {
    const manager = requireWearableManager(req.app.locals);
    const rawBuffer = await readWearableAudioChunk(req);
    const characteristicUuid = requireCharacteristicUuid(
      req,
      'Missing characteristicUuid (x-characteristic-uuid header or query.characteristicUuid)'
    );
    const ingestResult = manager.handleLiveStreamChunk(
      req.session.userId,
      req.params.macAddress,
      rawBuffer,
      { characteristicUuid },
    );
    const response = buildIngestHttpResponse(ingestResult);
    return res.status(response.status).json(response.body);
  } catch (err) {
    const mapped = toWearableRouteError(err);
    res.status(mapped.status).json({ error: mapped.message });
  }
});

router.post('/:macAddress/sync', async (req, res) => {
  try {
    const manager = requireWearableManager(req.app.locals);
    const rawBuffer = await readWearableAudioChunk(req);

    const session = await manager.syncOfflineAudio(req.session.userId, req.params.macAddress, rawBuffer);
    res.status(200).json({ success: true, sessionId: session.id });
  } catch (err) {
    const mapped = toWearableRouteError(err);
    res.status(mapped.status).json({ error: mapped.message });
  }
});

module.exports = router;
