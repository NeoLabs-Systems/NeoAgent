'use strict';

const express = require('express');
const { buildPublicStatus } = require('../services/public_status');

const router = express.Router();

router.get('/status', (req, res) => {
  res.json(buildPublicStatus(req.app));
});

module.exports = router;
