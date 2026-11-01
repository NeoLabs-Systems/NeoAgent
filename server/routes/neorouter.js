'use strict';

const express = require('express');
const rateLimit = require('express-rate-limit');
const { requireAuth } = require('../middleware/auth');
const { isAdminUser } = require('../services/access/admin');
const { getAgentIdFromRequest, resolveAgentId } = require('../services/agents/manager');
const { ROLES, apiBaseFor, serverConnection, userConnection } = require('../services/ai/neorouter/connection');
const { describeOffer } = require('../services/ai/neorouter/offer');
const signIn = require('../services/ai/neorouter/sign_in');
const { validateCloudUrlWithDns } = require('../utils/cloud-security');
const { sanitizeError } = require('../utils/security');

// "Connect NeoRouter": the server's connection (admins) and each person's own.
const router = express.Router();
router.use(requireAuth);

const writeLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 20,
  message: { error: 'Too many requests, try again in a minute.' },
  standardHeaders: true,
  legacyHeaders: false,
});

function scopeOf(req, res) {
  const scope = req.body?.scope || req.params.scope;
  if (scope !== 'server' && scope !== 'user') {
    res.status(400).json({ error: 'scope must be "server" or "user".' });
    return null;
  }
  if (scope === 'server' && !isAdminUser(req.session.userId)) {
    res.status(403).json({ error: 'Only an admin can connect NeoRouter for the whole server.', code: 'ADMIN_REQUIRED' });
    return null;
  }
  return scope;
}

const agentOf = (req) => resolveAgentId(req.session.userId, getAgentIdFromRequest(req));

// The settings page always asks the router afresh: what a key may use is
// changed in NeoRouter, not here. Live voice follows newly available models.
async function describe(connection, context) {
  if (!connection) return { connected: false, address: null, roles: [], offer: null };
  const offer = await describeOffer(connection, { fresh: true }).catch(() => null);
  if (offer) await signIn.applyLiveChoice(connection, { ...context, onlyIfUnusable: true, offer }).catch(() => {});
  return { connected: true, address: connection.origin, roles: [...connection.roles], offer, reachable: Boolean(offer) };
}

router.get('/', async (req, res) => {
  const userId = req.session.userId;
  const isAdmin = isAdminUser(userId);
  const server = serverConnection();
  const [serverState, userState] = await Promise.all([
    // Only admins see where the server's NeoRouter lives and what it offers;
    // everyone else only learns that one is connected.
    isAdmin ? describe(server, { scope: 'server', userId, agentId: null }) : { connected: Boolean(server) },
    describe(userConnection(userId, agentOf(req)), { scope: 'user', userId, agentId: agentOf(req) }),
  ]);
  res.json({ roles: ROLES, isAdmin, server: serverState, user: userState });
});

router.post('/connect', writeLimiter, async (req, res) => {
  const scope = scopeOf(req, res);
  if (!scope) return;
  const address = String(req.body?.address || '').trim();
  const apiBase = apiBaseFor(address);
  // A person's own address is user input pointed at from the server: it may
  // not reach the server's network, unless it is the admin's own NeoRouter.
  if (scope === 'user' && apiBase && apiBase !== serverConnection()?.apiBase) {
    const check = await validateCloudUrlWithDns(apiBase);
    if (!check.allowed) return res.status(400).json({ error: check.reason });
  }
  try {
    res.json(await signIn.begin({ scope, userId: req.session.userId, agentId: scope === 'user' ? agentOf(req) : null, address }));
  } catch (error) {
    res.status(400).json({ error: sanitizeError(error) });
  }
});

router.get('/connect/:id', (req, res) => {
  const result = signIn.status(req.params.id, req.session.userId);
  if (!result) return res.status(404).json({ error: 'This sign-in expired. Start again.' });
  return res.json(result);
});

router.put('/:scope/roles', writeLimiter, async (req, res) => {
  const scope = scopeOf(req, res);
  if (!scope) return;
  if (!Array.isArray(req.body?.roles)) return res.status(400).json({ error: 'roles must be a list.' });
  try {
    const roles = await signIn.updateRoles({ scope, userId: req.session.userId, agentId: agentOf(req), roles: req.body.roles });
    return res.json({ roles });
  } catch (error) {
    return res.status(400).json({ error: sanitizeError(error) });
  }
});

router.delete('/:scope', writeLimiter, async (req, res) => {
  const scope = scopeOf(req, res);
  if (!scope) return;
  try {
    await signIn.disconnect({ scope, userId: req.session.userId, agentId: agentOf(req) });
    res.json({ success: true });
  } catch (error) {
    res.status(400).json({ error: sanitizeError(error) });
  }
});

module.exports = router;
