'use strict';

const { getAnalytics } = require('../services/admin/analytics');
const { listUsers, deleteUser, revokeUserSessions, resetUserPassword } = require('../services/admin/users');
const { getUserRateLimits, setUserRateLimits, getDefaultRateLimits, setDefaultRateLimits } = require('../services/admin/rate_limits');
const { getUserAllowedModels, setUserAllowedModels } = require('../services/admin/allowed_models');
const { getDisabledModelIds, setDisabledModelIds, getAutoEnableNewModels, setAutoEnableNewModels } = require('../services/ai/model_visibility');
const { getGeneralSettings, updateGeneralSettings } = require('../services/admin/general');
const { getVmSettings, updateVmSettings } = require('../services/admin/vm');
const { getIntegrationSettings, updateIntegrationSettings } = require('../services/admin/integrations');
const { getAdminEmailSettings, updateAdminEmailSettings } = require('../services/admin/email');
const { listProviders } = require('../services/ai/providers');
const { getSupportedModels } = require('../services/ai/models');
const { runReadOnlyQuery } = require('../services/admin/sql_console');

const express = require('express');
const router = express.Router();
const { jsonHandler } = require('./_helpers/http');
const { requireAdmin } = require('../middleware/auth');
const { settingsLimiter } = require('../middleware/rate_limit');
const { userIdParam } = require('../utils/params');

router.use(requireAdmin);

router.get('/users', jsonHandler((req) => listUsers(req.query.q ? String(req.query.q) : null)));

router.delete('/users/:id', jsonHandler((req) => deleteUser(userIdParam(req.params.id), { actorUserId: req.session?.userId ?? null })));

router.post('/users/:id/sessions/revoke', jsonHandler((req) => revokeUserSessions(userIdParam(req.params.id), { actorUserId: req.session?.userId ?? null })));

router.post('/users/:id/password', settingsLimiter, jsonHandler((req) => resetUserPassword(
  userIdParam(req.params.id),
  req.body?.password,
  { actorUserId: req.session?.userId ?? null }
)));

router.get('/users/:id/rate-limits', jsonHandler((req) => getUserRateLimits(userIdParam(req.params.id))));

router.put('/users/:id/rate-limits', jsonHandler((req) => setUserRateLimits(userIdParam(req.params.id), req.body)));

router.get('/users/:id/allowed-models', jsonHandler((req) => getUserAllowedModels(userIdParam(req.params.id))));

router.put('/users/:id/allowed-models', jsonHandler((req) => setUserAllowedModels(
  userIdParam(req.params.id),
  req.body,
  { actorUserId: req.session?.userId ?? null }
)));

router.get('/config/rate-limits', jsonHandler(() => getDefaultRateLimits()));

router.put('/config/rate-limits', settingsLimiter, jsonHandler((req) => setDefaultRateLimits(req.body)));

// --- Providers and models ---

router.get('/providers', jsonHandler(() => listProviders()));

router.put('/providers', jsonHandler((req) => setProviderEnabled(req.body?.providerId, req.body?.enabled)));

router.get('/models', jsonHandler((req) => getSupportedModels(req.session?.userId ?? null, null, { includeRuntimeHealth: true })));

router.put('/models/disabled', jsonHandler((req) => {
  const disabledModels = req.body?.disabledModels;
  if (!Array.isArray(disabledModels)) throw httpError(400, 'disabledModels must be an array');
  if (typeof req.body?.autoEnableNewModels === 'boolean') {
    setAutoEnableNewModels(req.body.autoEnableNewModels);
  }
  return {
    ok: true,
    disabledModels: setDisabledModelIds(disabledModels),
    autoEnableNewModels: getAutoEnableNewModels(),
  };
}));

router.get('/models/config', jsonHandler(() => ({
  disabledModels: getDisabledModelIds(),
  autoEnableNewModels: getAutoEnableNewModels(),
})));

router.put('/models/config', jsonHandler((req) => {
  const disabledModels = req.body?.disabledModels;
  if (!Array.isArray(disabledModels)) throw httpError(400, 'disabledModels must be an array');
  if (typeof req.body?.autoEnableNewModels === 'boolean') {
    setAutoEnableNewModels(req.body.autoEnableNewModels);
  }
  return {
    ok: true,
    disabledModels: setDisabledModelIds(disabledModels),
    autoEnableNewModels: getAutoEnableNewModels(),
  };
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
EOF
echo done