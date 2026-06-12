'use strict';

const express = require('express');

const router = express.Router();

router.get('/config', (req, res) => {
  res.json({
    analytics: {
      enabled: false,
      provider: null,
      requiresConsent: true,
    },
  });
});

module.exports = router;
