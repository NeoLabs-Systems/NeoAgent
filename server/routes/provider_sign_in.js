'use strict';

const express = require('express');
const rateLimit = require('express-rate-limit');
const { requireAuth } = require('../middleware/auth');
const { getAgentIdFromRequest, resolveAgentId } = require('../services/agents/manager');
const { bindOAuthState } = require('../services/account/oauth_handoff');
const providerSignIn = require('../services/ai/provider_sign_in');
const { publicBaseUrlForRequest } = require('../utils/public_url');
const { sanitizeError } = require('../utils/security');

const router = express.Router();

router.use(requireAuth);

const signInWriteLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 20,
  message: { error: 'Too many requests, try again in a minute.' },
  standardHeaders: true,
  legacyHeaders: false,
});

router.post('/:providerId', signInWriteLimiter, (req, res) => {
  const userId = req.session.userId;
  try {
    const flow = providerSignIn.begin({
      providerId: String(req.params.providerId || '').trim(),
      userId,
      agentId: resolveAgentId(userId, getAgentIdFromRequest(req)),
      baseUrl: publicBaseUrlForRequest(req),
    });
    // Only a browser redirect returns through the shared OAuth callback.
    if (flow.mode === 'redirect') bindOAuthState(req.session, flow.state);
    res.json(flow);
  } catch (error) {
    res.status(400).json({ error: sanitizeError(error) });
  }
});

router.get('/:state', (req, res) => {
  const result = providerSignIn.status(req.params.state, req.session.userId);
  if (!result) {
    return res.status(404).json({ error: providerSignIn.EXPIRED_MESSAGE });
  }
  res.json(result);
});

router.post('/:state/code', signInWriteLimiter, async (req, res) => {
  const code = typeof req.body?.code === 'string' ? req.body.code.trim() : '';
  if (!code) {
    return res.status(400).json({ error: 'A sign-in code is required.' });
  }
  try {
    res.json(await providerSignIn.complete(req.params.state, code, { userId: req.session.userId }));
  } catch (error) {
    res.status(400).json({ error: sanitizeError(error) });
  }
});

module.exports = router;
