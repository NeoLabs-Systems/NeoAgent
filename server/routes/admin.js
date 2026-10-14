'use strict';

// Admin API. Every route needs a signed-in account whose users.is_admin flag is
// set; the flag is re-read on each request, so revoking admin applies at once.

const express = require('express');
const rateLimit = require('express-rate-limit');
const { requireAuth, requireAdmin } = require('../middleware/auth');
const { sendJsonError } = require('../http/errors');
const { getSupportedModels } = require('../services/ai/models');
const { getSystemOneModels } = require('../services/ai/system_one');
const { reconcileModelVisibility, setDisabledModelIds } = require('../services/ai/model_visibility');
const { getAdminEmailSettings, updateAdminEmailSettings } = require('../services/account/service_email_settings');
const { getServerVersion, runHealthChecks } = require('../services/admin/health');
const { getAnalytics } = require('../services/admin/analytics');
const { listUsers, deleteUser, revokeUserSessions, resetUserPassword } = require('../services/admin/users');
const {
  getUserRateLimits,
  setUserRateLimits,
  getDefaultRateLimits,
  setDefaultRateLimits,
} = require('../services/admin/rate_limits');
const { runReadOnlyQuery } = require('../services/admin/sql_console');
const { listProviders, updateProvider } = require('../services/admin/providers');
const {
  getGeneralSettings,
  updateGeneralSettings,
  getVmSettings,
  updateVmSettings,
  getAccessSettings,
  setSignupEnabled,
} = require('../services/admin/server_config');
const { getIntegrationSettings, updateIntegrationSettings } = require('../services/admin/integrations');
const { httpError } = require('../utils/http_error');
const { jsonHandler, userIdParam } = require('./_helpers/http');

const router = express.Router();
router.use(requireAuth, requireAdmin);

const settingsLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many settings changes, slow down' },
});

const sqlLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 60,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many SQL queries, slow down' },
});

// --- Server ---

router.get('/version', jsonHandler(() => getServerVersion()));

router.get('/health', jsonHandler((req) => runHealthChecks(req.app.locals.runtimeManager)));

router.get('/logs', jsonHandler((req) => ({ logs: req.app.locals.logHistory || [] })));

router.get('/analytics', jsonHandler((req) => getAnalytics(req.query.range)));

// --- Users ---

router.get('/users', jsonHandler((req) => listUsers(req.query.q ? String(req.query.q) : null)));

router.delete('/users/:id', jsonHandler((req) => deleteUser(userIdParam(req.params.id), {
  actorUserId: req.session.userId,
  runtimeManager: req.app.locals.runtimeManager,
})));

router.delete('/users/:id/sessions', jsonHandler((req) => revokeUserSessions(userIdParam(req.params.id))));

router.post('/users/:id/password', settingsLimiter, jsonHandler((req) => resetUserPassword(
  userIdParam(req.params.id),
  req.body?.password,
  { actorUserId: req.session.userId },
)));

router.get('/users/:id/rate-limits', jsonHandler((req) => getUserRateLimits(userIdParam(req.params.id))));

router.put('/users/:id/rate-limits', jsonHandler((req) => setUserRateLimits(userIdParam(req.params.id), req.body)));

router.get('/config/rate-limits', jsonHandler(() => getDefaultRateLimits()));

router.put('/config/rate-limits', jsonHandler((req) => setDefaultRateLimits(req.body)));

// --- SQL console (read-only) ---

router.post('/sql', sqlLimiter, jsonHandler((req) => runReadOnlyQuery(req.body?.query)));

// --- Access ---

router.get('/access', jsonHandler(() => getAccessSettings()));

router.put('/access/signup', settingsLimiter, jsonHandler((req) => setSignupEnabled(req.body?.enabled)));

// --- Providers and models ---

router.get('/providers', jsonHandler(() => listProviders()));

router.put('/providers', jsonHandler((req) => updateProvider(req.body?.key, req.body?.value)));

router.get('/models', async (req, res) => {
  try {
    const [models, systemOneModels] = await Promise.all([
      getSupportedModels(null, null, { signal: req.signal }),
      getSystemOneModels(null, null, { signal: req.signal }),
    ]);
    // Tracks newly discovered / retired models and applies the default
    // enable/disable policy to anything new. Chat and SystemOne models share
    // one disabled list but are tracked as separate catalogs.
    reconcileModelVisibility(models.map((model) => model.id), 'llm');
    const disabledModels = reconcileModelVisibility(
      systemOneModels.map((model) => model.id),
      'decisions',
    );
    res.json({ models, systemOneModels, disabledModels });
  } catch (err) {
    sendJsonError(res, err);
  }
});

router.put('/models/config', jsonHandler((req) => {
  const disabledModels = req.body?.disabledModels;
  if (!Array.isArray(disabledModels)) throw httpError(400, 'disabledModels must be an array');
  return { ok: true, disabledModels: setDisabledModelIds(disabledModels) };
}));

// --- Server configuration ---

router.get('/config/general', jsonHandler(() => getGeneralSettings()));

router.put('/config/general', settingsLimiter, jsonHandler((req) => updateGeneralSettings(req.body)));

router.get('/config/vm', jsonHandler(() => getVmSettings()));

router.put('/config/vm', settingsLimiter, jsonHandler((req) => updateVmSettings(req.body)));

router.get('/config/integrations', jsonHandler(() => getIntegrationSettings()));

router.put('/config/integrations', settingsLimiter, jsonHandler((req) => updateIntegrationSettings(req.body)));

router.get('/config/email', jsonHandler(() => getAdminEmailSettings()));

router.put('/config/email', settingsLimiter, jsonHandler((req) => ({ ok: true, ...updateAdminEmailSettings(req.body) })));

module.exports = router;
