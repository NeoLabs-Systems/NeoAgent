'use strict';

const express = require('express');
const { buildPublicStatus } = require('../services/public_status');

const { createStatusHistory } = require('../status_history');
const history = createStatusHistory();
const router = express.Router();

router.get('/status', (req, res) => {
  res.set('Cache-Control', 'no-store');
  res.json({ ...buildPublicStatus(req.app), history: history.history() });
});

module.exports = router;
module.exports.history = history;
