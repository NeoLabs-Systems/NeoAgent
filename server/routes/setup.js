'use strict';

const express = require('express');
const { requireAuth } = require('../middleware/auth');

const {
  getSetupHandshake,
  getSetupProgress,
} = require('../services/setup/onboarding');

const router = express.Router();

router.get('/handshake', (_req, res) => {
  res.json(getSetupHandshake());
});

router.get('/status', requireAuth, (_req, res) => {
  res.json(getSetupProgress());
});

module.exports = router;
