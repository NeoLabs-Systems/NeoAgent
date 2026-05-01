'use strict';

const express = require('express');
const { requireAuth } = require('../middleware/auth');
const { sanitizeError } = require('../utils/security');

const router = express.Router();

function wearableService(req) {
  return req.app?.locals?.wearableService || null;
}

// Intentionally public so an already-provisioned wearable can sync local time
// before the user finishes session-based pairing on the device.
router.get('/timezone', (req, res) => {
  try {
    const service = wearableService(req);
    if (!service) {
      return res.status(500).json({ error: 'Wearable service unavailable.' });
    }
    res.json(service.buildTimeConfig(req));
  } catch (err) {
    res.status(400).json({ error: sanitizeError(err) });
  }
});

router.use(requireAuth);

router.get('/bootstrap', async (req, res) => {
  try {
    const service = wearableService(req);
    if (!service) {
      return res.status(500).json({ error: 'Wearable service unavailable.' });
    }
    res.json(await service.buildBootstrap(req));
  } catch (err) {
    res.status(400).json({ error: sanitizeError(err) });
  }
});

router.get('/firmware/manifest', async (req, res) => {
  try {
    const service = wearableService(req);
    if (!service) {
      return res.status(500).json({ error: 'Wearable service unavailable.' });
    }
    res.json(await service.buildFirmwareManifest(req));
  } catch (err) {
    res.status(400).json({ error: sanitizeError(err) });
  }
});

router.get('/connections', (req, res) => {
  try {
    const service = wearableService(req);
    if (!service) {
      return res.status(500).json({ error: 'Wearable service unavailable.' });
    }
    res.json({
      connections: service.listConnections(req.session.userId),
    });
  } catch (err) {
    res.status(400).json({ error: sanitizeError(err) });
  }
});

module.exports = router;
