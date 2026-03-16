const express = require('express');
const router = express.Router();
const { requireAuth } = require('../middleware/auth');
const { sanitizeError } = require('../utils/security');
const { getHealthSyncStatus, ingestHealthSync } = require('../services/health/ingestion');

router.use(requireAuth);

router.get('/status', (req, res) => {
  try {
    res.json(getHealthSyncStatus(req.session.userId));
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

router.post('/sync', (req, res) => {
  try {
    const result = ingestHealthSync(req.session.userId, req.body);
    res.status(201).json({ success: true, ...result });
  } catch (err) {
    const message = sanitizeError(err);
    const status = /payload|Missing user/i.test(message) ? 400 : 500;
    res.status(status).json({ error: message });
  }
});

module.exports = router;
