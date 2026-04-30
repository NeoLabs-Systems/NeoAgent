'use strict';

const express = require('express');
const { requireAuth } = require('../middleware/auth');
const { sanitizeError } = require('../utils/security');

const router = express.Router();

router.use(requireAuth);

function wearableService(req) {
  return req.app?.locals?.wearableService || null;
}

router.get('/bootstrap', (req, res) => {
  try {
    const service = wearableService(req);
    if (!service) {
      return res.status(500).json({ error: 'Wearable service unavailable.' });
    }
    res.json(service.buildBootstrap(req));
  } catch (err) {
    res.status(400).json({ error: sanitizeError(err) });
  }
});

router.get('/firmware/manifest', (req, res) => {
  try {
    const service = wearableService(req);
    if (!service) {
      return res.status(500).json({ error: 'Wearable service unavailable.' });
    }
    res.json(service.buildFirmwareManifest(req));
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
