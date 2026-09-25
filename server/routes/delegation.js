'use strict';

const express = require('express');
const rateLimit = require('express-rate-limit');
const { requireAuth, requireAdmin } = require('../middleware/auth');
const { publicBaseUrlForRequest } = require('../utils/public_url');
const { jsonHandler, userIdParam } = require('./_helpers/http');
const { buildAccessSummary } = require('../services/access/summary');
const { listAccessEvents } = require('../services/access/audit');
const { leaveManager, releaseManaged, setManagedPermission } = require('../services/access/delegations');
const {
  buildInviteLink,
  createInvite,
  previewInvite,
  redeemInvite,
  revokeInvite,
} = require('../services/access/invites');

const router = express.Router();
router.use(requireAuth);

const inviteLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many invite link attempts, try again later', code: 'RATE_LIMITED' },
});

const changeLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 120,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many access changes, slow down', code: 'RATE_LIMITED' },
});

function summaryFor(req) {
  return buildAccessSummary(req.session.userId);
}

router.get('/', jsonHandler(summaryFor));

router.post('/invites/preview', inviteLimiter, jsonHandler((req) => (
  previewInvite(req.session.userId, req.body?.link)
)));

router.post('/invites/redeem', inviteLimiter, jsonHandler((req) => {
  redeemInvite(req.session.userId, req.body?.link);
  return summaryFor(req);
}));

router.post('/leave', changeLimiter, jsonHandler((req) => {
  leaveManager(req.session.userId);
  return summaryFor(req);
}));

router.post('/invites', changeLimiter, jsonHandler((req) => {
  const body = req.body || {};
  const { invite, token } = createInvite(req.session.userId, {
    label: body.label,
    permissions: body.permissions,
    expiresInHours: body.expiresInHours,
    maxUses: body.maxUses,
  });
  return { invite, link: buildInviteLink(publicBaseUrlForRequest(req), token) };
}, { status: 201 }));

router.delete('/invites/:id', changeLimiter, jsonHandler((req) => {
  revokeInvite(req.session.userId, String(req.params.id));
  return summaryFor(req);
}));

router.delete('/managing/:userId', changeLimiter, jsonHandler((req) => {
  releaseManaged(req.session.userId, userIdParam(req.params.userId));
  return summaryFor(req);
}));

router.put('/managing/:userId/permissions', changeLimiter, jsonHandler((req) => {
  setManagedPermission(
    req.session.userId,
    userIdParam(req.params.userId),
    req.body?.permission,
    req.body?.allowed,
  );
  return summaryFor(req);
}));

router.get('/audit', requireAdmin, jsonHandler((req) => (
  listAccessEvents({ limit: Math.min(Math.max(parseInt(req.query.limit, 10) || 100, 1), 500) })
)));

module.exports = router;
