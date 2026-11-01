'use strict';

const express = require('express');
const { requireAuth } = require('../middleware/auth');
const { sanitizeError } = require('../utils/security');
const { getAgentIdFromRequest, resolveAgentId } = require('../services/agents/manager');
const { forgetDevice, registerDevice, syncDevice } = require('../services/integrations/phone/store');

const router = express.Router();
router.use(requireAuth);

function scopeOf(req) {
  const userId = Number(req.session.userId);
  return { userId, agentId: resolveAgentId(userId, getAgentIdFromRequest(req)) };
}

router.post('/register', (req, res) => {
  try {
    res.json(registerDevice({
      ...scopeOf(req),
      device: { id: req.body?.deviceId, name: req.body?.deviceName, platform: req.body?.platform },
      kinds: req.body?.kinds,
    }));
  } catch (err) {
    res.status(400).json({ error: sanitizeError(err) });
  }
});

router.delete('/register', (req, res) => {
  try {
    const { userId, agentId } = scopeOf(req);
    forgetDevice(userId, agentId, String(req.query.deviceId || ''));
    res.json({ connected: false });
  } catch (err) {
    res.status(400).json({ error: sanitizeError(err) });
  }
});

router.post('/sync', (req, res) => {
  try {
    res.json(syncDevice({ ...scopeOf(req), body: req.body || {} }));
  } catch (err) {
    res.status(400).json({ error: sanitizeError(err) });
  }
});

module.exports = router;
