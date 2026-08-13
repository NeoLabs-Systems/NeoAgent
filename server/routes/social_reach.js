'use strict';

const express = require('express');
const { requireAuth } = require('../middleware/auth');
const { sanitizeError } = require('../utils/security');

const router = express.Router();

router.use(requireAuth);

function serviceFromReq(req) {
  return req.app?.locals?.socialReachService || null;
}

function sendError(res, error) {
  const status = Number(error?.status || 500);
  return res.status(status >= 400 && status < 600 ? status : 500).json({
    error: sanitizeError(error),
  });
}

router.get('/status', async (req, res) => {
  try {
    const service = serviceFromReq(req);
    if (!service || typeof service.getStatus !== 'function') {
      return res.status(503).json({ error: 'Social reach service is unavailable.' });
    }
    return res.json(await service.getStatus(req.session.userId, { signal: req.signal }));
  } catch (error) {
    return sendError(res, error);
  }
});

router.post('/read', async (req, res) => {
  try {
    const service = serviceFromReq(req);
    if (!service || typeof service.read !== 'function') {
      return res.status(503).json({ error: 'Social reach service is unavailable.' });
    }
    return res.json(await service.read(
      req.session.userId,
      req.body || {},
      { signal: req.signal },
    ));
  } catch (error) {
    return sendError(res, error);
  }
});

router.post('/search', async (req, res) => {
  try {
    const service = serviceFromReq(req);
    if (!service || typeof service.search !== 'function') {
      return res.status(503).json({ error: 'Social reach service is unavailable.' });
    }
    return res.json(await service.search(
      req.session.userId,
      req.body || {},
      { signal: req.signal },
    ));
  } catch (error) {
    return sendError(res, error);
  }
});

router.post('/cookies/import', async (req, res) => {
  try {
    const service = serviceFromReq(req);
    if (!service || typeof service.importCookiesFromComputer !== 'function') {
      return res.status(503).json({ error: 'Social reach service is unavailable.' });
    }
    const platform = String(req.body?.platform || '').trim();
    if (!platform) {
      return res.status(400).json({ error: 'platform is required.' });
    }
    return res.json(await service.importCookiesFromComputer(req.session.userId, platform, {
      signal: req.signal,
    }));
  } catch (error) {
    return sendError(res, error);
  }
});

router.delete('/cookies/:platform', (req, res) => {
  try {
    const service = serviceFromReq(req);
    if (!service || typeof service.clearCookies !== 'function') {
      return res.status(503).json({ error: 'Social reach service is unavailable.' });
    }
    return res.json(service.clearCookies(req.session.userId, req.params.platform));
  } catch (error) {
    return sendError(res, error);
  }
});

module.exports = router;
