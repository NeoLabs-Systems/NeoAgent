const express = require('express');

const { requireAuth } = require('../middleware/auth');

const router = express.Router();

router.use(requireAuth);

router.post('/respond', (_req, res) => {
  return res.status(410).json({
    error:
      'The recording-based voice assistant flow is deprecated. Use the live call integration for mic/playback voice interaction.',
    deprecated: true,
    replacement: 'live_call_integration',
  });
});

module.exports = router;
