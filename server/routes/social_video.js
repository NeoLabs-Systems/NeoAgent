const express = require('express');
const { requireAuth } = require('../middleware/auth');
const { sanitizeError } = require('../utils/security');

const router = express.Router();

router.use(requireAuth);

router.get('/health', async (req, res) => {
  try {
    const service = req.app?.locals?.socialVideoService;
    if (!service || typeof service.getHealthStatus !== 'function') {
      return res.status(503).json({
        ready: false,
        error: 'Social video service is unavailable.',
      });
    }
    const health = await service.getHealthStatus({
      forceRefresh: req.query?.refresh === '1' || req.query?.refresh === 'true',
    });
    return res.json(health);
  } catch (error) {
    return res.status(500).json({ error: sanitizeError(error) });
  }
});

router.post('/extract', async (req, res) => {
  try {
    const service = req.app?.locals?.socialVideoService;
    if (!service || typeof service.extractFromUrl !== 'function') {
      return res.status(503).json({ error: 'Social video service is unavailable.' });
    }
    if (!req.session || !req.session.userId) {
      return res.status(401).json({ error: 'Authentication required.' });
    }

    const sourceUrl = String(req.body?.url || '').trim();
    if (!sourceUrl) {
      return res.status(400).json({ error: 'url is required.' });
    }

    const result = await service.extractFromUrl(req.session.userId, sourceUrl, {
      includeFrame: req.body?.include_frame !== false,
      forceStt: req.body?.force_stt === true,
    });

    if (result?.setup?.ready === false) {
      return res.status(503).json(result);
    }

    if (Array.isArray(result.errors) && result.errors.length > 0) {
      const failed = !result.title && !result.description && !result.transcript && !result.frameImage;
      return res.status(failed ? 422 : 200).json(result);
    }

    return res.json(result);
  } catch (error) {
    return res.status(500).json({ error: sanitizeError(error) });
  }
});

module.exports = router;
