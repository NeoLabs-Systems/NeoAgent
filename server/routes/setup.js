'use strict';

const express = require('express');
const rateLimit = require('express-rate-limit');
const { requireAuth } = require('../middleware/auth');

const {
  exchangeSetupClaim,
  getSetupHandshake,
  getSetupProgress,
} = require('../services/setup/onboarding');

const router = express.Router();
const setupClaimLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    type: 'https://neoagent.ai/problems/setup-rate-limited',
    title: 'Too many setup attempts',
    status: 429,
    code: 'SETUP_RATE_LIMITED',
    detail: 'Wait before trying the setup code again.',
    retryable: true,
  },
});

function sendProblem(res, error) {
  const status = Number(error?.statusCode || 400);
  return res.status(status).type('application/problem+json').json({
    type: `https://neoagent.ai/problems/${String(error?.code || 'setup-failed').toLowerCase().replace(/_/g, '-')}`,
    title: status === 401 ? 'Setup authorization failed' : 'Setup could not continue',
    status,
    code: error?.code || 'SETUP_FAILED',
    detail: error?.message || 'Setup could not continue.',
    retryable: status >= 500,
  });
}

router.get('/handshake', (_req, res) => {
  res.json(getSetupHandshake());
});

router.get('/status', requireAuth, (_req, res) => {
  res.json(getSetupProgress());
});

router.post('/claim', setupClaimLimiter, (req, res) => {
  try {
    const claim = exchangeSetupClaim(req.body?.token);
    req.session.setupClaimId = claim.id;
    req.session.save((error) => {
      if (error) {
        error.code = 'SETUP_SESSION_FAILED';
        error.statusCode = 500;
        return sendProblem(res, error);
      }
      return res.json({
        success: true,
        expiresAt: claim.expiresAt,
      });
    });
  } catch (error) {
    return sendProblem(res, error);
  }
});

module.exports = router;
