'use strict';

const express = require('express');

const router = express.Router();

router.get('/config', (req, res) => {
  res.json({});
});

module.exports = router;
