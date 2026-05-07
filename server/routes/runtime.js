'use strict';

const express = require('express');
const { getAnalyticsConfig } = require('../config/analytics');

const router = express.Router();

router.get('/config', (req, res) => {
  res.json({
    analytics: getAnalyticsConfig(),
  });
});

module.exports = router;
