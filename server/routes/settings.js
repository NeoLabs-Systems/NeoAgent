const express = require('express');
const router = express.Router();
const rateLimit = require('express-rate-limit');
const db = require('../db/database');
const { requireAuth, requireAdmin } = require('../middleware/auth');
const { getVersionInfo } = require('../utils/version');
const { readUpdateStatus } = require('../utils/update_status');
const { getRuntimeValidation } = require('../services/runtime/validation');
const { startUpdate, setUpdateChannel } = require('../services/admin/updates');
const {
  AI_PROVIDER_DEFINITIONS,
  createDefaultAiSettings,
  ensureDefaultAiSettings,
  normalizeProviderConfigs,
  setProviderConfig,
  setProviderSecret,
} = require('../services/ai/settings');
const {
  ensureDefaultRuntimeSettings,
  getRuntimeSettings,
  redactRuntimeSettingValue,
} = require('../services/runtime/settings');
const {
  HIDDEN_SETTING_KEYS,
  RETIRED_SETTING_KEYS,
  SERVER_MANAGED_SETTING_KEYS,
  applySettingsSideEffects,
  applySettingsUpdate,
  isAgentScopedSettingKey,
  isProtectedSecretSettingKey,
  parseStoredValue,
  readSettingValue,
} = require('../services/settings/store');
const { getAgentIdFromRequest, isMainAgent, resolveAgentId } = require('../services/agents/manager');
const { getProviderHealthCatalog, getSupportedModels, PROVIDER_FACTORIES } = require('../services/ai/models');
const { getSystemOneModels } = require('../services/ai/system_one');
const { hasSignInMethod } = require('../services/ai/provider_sign_in');
const { validateCloudUrlWithDns } = require('../utils/cloud-security');

const updateTriggerLimiter = rateLimit({
  windowMs: 5 * 60 * 1000,
  max: 3,
  message: { success: false, error: 'Too many update requests, try again later' },
  standardHeaders: true,
  legacyHeaders: false,
});

router.get('/update/status', requireAuth, (req, res) => {
  try {
    const status = readUpdateStatus();
    const version = getVersionInfo();
    res.json({
      ...status,
      backendVersion: version.version,
      installedVersion: version.installedVersion,
      packageVersion: version.packageVersion,
      gitVersion: version.gitVersion,
      gitSha: version.gitSha,
      gitBranch: version.gitBranch,
      releaseChannel: version.releaseChannel,
      targetBranch: status.state === 'running' ? status.targetBranch || version.targetBranch : version.targetBranch,
      deploymentMode: version.deploymentMode,
      managedDeployment: version.managedDeployment,
      allowSelfUpdate: version.allowSelfUpdate,
      containerImage: version.containerImage,
      runtimeDefaults: version.runtimeDefaults,
      allowHostRuntime: version.allowHostRuntime,
      runtimeValidation: getRuntimeValidation(req.app?.locals?.runtimeManager),
    });
  } catch (error) {
    console.error('[Settings] Update status failed:', error.message);
    res.status(503).json({ error: 'Update status is temporarily unavailable.' });
  }
});

router.use(requireAuth);

// Get supported models metadata
router.get('/meta/models', async (req, res) => {
  const agentId = resolveAgentId(req.session.userId, getAgentIdFromRequest(req));
  const models = await getSupportedModels(req.session.userId, agentId, { signal: req.signal });
  res.json({ models });
});

// SystemOne decision models, kept apart from the chat models above.
router.get('/meta/system-one-models', async (req, res) => {
  const agentId = resolveAgentId(req.session.userId, getAgentIdFromRequest(req));
  const models = await getSystemOneModels(req.session.userId, agentId, { signal: req.signal });
  res.json({ models });
});

router.get('/meta/ai-providers', async (req, res) => {
  const agentId = resolveAgentId(req.session.userId, getAgentIdFromRequest(req));
  const providers = await getProviderHealthCatalog(req.session.userId, agentId, {
    signal: req.signal,
  });
  const models = await getSupportedModels(req.session.userId, agentId, {
    providerCatalog: providers,
    signal: req.signal,
  });

  const modelCounts = models.reduce((acc, model) => {
    acc[model.provider] = (acc[model.provider] || 0) + 1;
    if (model.available !== false) {
      acc[`${model.provider}:available`] = (acc[`${model.provider}:available`] || 0) + 1;
    }
    return acc;
  }, {});

  res.json({
    providers: providers.map((provider) => ({
      ...provider,
      modelCount: modelCounts[provider.id] || 0,
      availableModelCount: modelCounts[`${provider.id}:available`] || 0,
    })),
  });
});

// ── Bring-your-own-key (BYOK) provider credentials ──────────────────────
// Every route below is scoped strictly to req.session.userId (and the agent
// it resolves to, which is itself owned by that user) -- a user can only
// ever read the status of, set, clear, or test their own keys. Raw key
// values are never echoed back once saved.
const BYOK_RATE_LIMIT_WINDOW_MS = 60 * 1000;
const byokWriteLimiter = rateLimit({
  windowMs: BYOK_RATE_LIMIT_WINDOW_MS,
  max: 20,
  message: { success: false, error: 'Too many requests, try again in a minute.' },
  standardHeaders: true,
  legacyHeaders: false,
});

function isValidByokBaseUrl(value) {
  try {
    const url = new URL(value);
    return (url.protocol === 'http:' || url.protocol === 'https:')
      && Boolean(url.hostname)
      && !url.username
      && !url.password;
  } catch {
    return false;
  }
}

// A BYOK base URL is user-controlled input pointed at from the server, so it
// must never be allowed to resolve to the server's own loopback/LAN network
// (SSRF into internal services, cloud metadata, etc.). Checks both the
// literal host and, for a hostname, what it actually resolves to.
async function assertSafeByokBaseUrl(baseUrl, res, signal) {
  if (!isValidByokBaseUrl(baseUrl)) {
    res.status(400).json({ success: false, ok: false, error: 'Base URL must be a valid http(s) URL.' });
    return false;
  }
  const result = await validateCloudUrlWithDns(baseUrl, { signal });
  if (!result.allowed) {
    res.status(400).json({
      success: false,
      ok: false,
      error: result.reason,
    });
    return false;
  }
  return true;
}

// Providers a user can't actually self-serve through a pasted key: OAuth
// login flows (`neoagent login <provider>`) and MiniMax's account-bound
// coding-plan subscription. They have no place in a self-service BYOK UI.
const BYOK_EXCLUDED_PROVIDER_IDS = new Set(['minimax']);
function isByokEligible(definition) {
  return definition.authentication !== 'oauth' && !BYOK_EXCLUDED_PROVIDER_IDS.has(definition.id);
}

router.get('/byok', async (req, res) => {
  const userId = req.session.userId;
  const agentId = resolveAgentId(userId, getAgentIdFromRequest(req));
  const providers = await getProviderHealthCatalog(userId, agentId, { signal: req.signal });
  res.json({
    providers: providers
      .filter((provider) => (provider.supportsApiKey || provider.supportsBaseUrl) && isByokEligible(provider))
      .map((provider) => ({
        id: provider.id,
        label: provider.label,
        description: provider.description,
        supportsApiKey: provider.supportsApiKey,
        supportsBaseUrl: provider.supportsBaseUrl,
        requiresBaseUrl: provider.requiresBaseUrl,
        defaultBaseUrl: provider.defaultBaseUrl,
        isCustomEndpoint: provider.id === 'openai-compatible',
        configured: provider.isByok,
        signInAvailable: hasSignInMethod(provider.id),
        baseUrl: provider.isByok ? provider.baseUrl : '',
        customLabel: provider.isByok ? (provider.customLabel || '') : '',
      })),
  });
});

router.put('/byok/:providerId', byokWriteLimiter, async (req, res) => {
  const userId = req.session.userId;
  const agentId = resolveAgentId(userId, getAgentIdFromRequest(req));
  const providerId = String(req.params.providerId || '').trim();
  const definition = AI_PROVIDER_DEFINITIONS[providerId];
  if (!definition || (!definition.supportsApiKey && !definition.supportsBaseUrl) || !isByokEligible(definition)) {
    return res.status(404).json({ success: false, error: 'Unknown or unsupported provider.' });
  }

  const apiKey = typeof req.body?.apiKey === 'string' ? req.body.apiKey.trim() : '';
  const baseUrl = typeof req.body?.baseUrl === 'string' ? req.body.baseUrl.trim() : undefined;
  const label = typeof req.body?.label === 'string' ? req.body.label.trim() : undefined;

  if (definition.supportsApiKey && !apiKey) {
    return res.status(400).json({ success: false, error: 'An API key is required.' });
  }
  // A provider with no API key concept (e.g. Ollama) is only ever "yours"
  // by pointing it at your own custom address, so that address is mandatory.
  const baseUrlRequired = definition.requiresBaseUrl || !definition.supportsApiKey;
  if (baseUrlRequired && !baseUrl) {
    return res.status(400).json({ success: false, error: 'A base URL is required for this provider.' });
  }
  if (baseUrl && !(await assertSafeByokBaseUrl(baseUrl, res, req.signal))) return;

  try {
    if (definition.supportsApiKey) {
      setProviderSecret(userId, providerId, apiKey, agentId);
    }
    if (definition.supportsBaseUrl && (baseUrl !== undefined || label !== undefined)) {
      setProviderConfig(userId, providerId, { baseUrl, label }, agentId);
    }
    res.json({ success: true, configured: true });
  } catch (error) {
    console.error('[Settings][BYOK] Failed to save provider credential:', error.message);
    res.status(500).json({ success: false, error: 'Could not save this credential.' });
  }
});

router.delete('/byok/:providerId', byokWriteLimiter, (req, res) => {
  const userId = req.session.userId;
  const agentId = resolveAgentId(userId, getAgentIdFromRequest(req));
  const providerId = String(req.params.providerId || '').trim();
  const definition = AI_PROVIDER_DEFINITIONS[providerId];
  if (!definition || !isByokEligible(definition)) {
    return res.status(404).json({ success: false, error: 'Unknown provider.' });
  }
  try {
    if (definition.supportsApiKey) {
      setProviderSecret(userId, providerId, '', agentId);
    }
    if (definition.supportsBaseUrl) {
      const updates = { baseUrl: '' };
      if (!definition.supportsApiKey) updates.label = '';
      setProviderConfig(userId, providerId, updates, agentId);
    }
    res.json({ success: true, configured: false });
  } catch (error) {
    console.error('[Settings][BYOK] Failed to clear provider credential:', error.message);
    res.status(500).json({ success: false, error: 'Could not clear this credential.' });
  }
});

// Tests a key/endpoint the user is about to save (or has already saved, when
// no body is sent) without persisting anything from this call.
router.post('/byok/:providerId/test', byokWriteLimiter, async (req, res) => {
  const userId = req.session.userId;
  const agentId = resolveAgentId(userId, getAgentIdFromRequest(req));
  const providerId = String(req.params.providerId || '').trim();
  const definition = AI_PROVIDER_DEFINITIONS[providerId];
  const factory = PROVIDER_FACTORIES[providerId];
  if (!definition || !factory || !isByokEligible(definition)) {
    return res.status(404).json({ success: false, error: 'Unknown provider.' });
  }

  const suppliedKey = typeof req.body?.apiKey === 'string' ? req.body.apiKey.trim() : '';
  const suppliedUrl = typeof req.body?.baseUrl === 'string' ? req.body.baseUrl.trim() : '';
  if (suppliedUrl && !suppliedKey && definition.supportsApiKey) {
    return res.status(400).json({
      success: false,
      ok: false,
      error: 'Testing a custom base URL requires the API key for that endpoint.',
    });
  }
  let apiKey = suppliedKey;
  let baseUrl = suppliedUrl;
  if (!apiKey && !suppliedUrl) {
    const { getProviderRuntimeConfig } = require('../services/ai/models');
    const runtime = getProviderRuntimeConfig(userId, providerId, agentId);
    apiKey = runtime.apiKey;
    baseUrl = runtime.baseUrl;
  }
  if (definition.supportsApiKey && !apiKey) {
    return res.status(400).json({ success: false, ok: false, error: 'No API key to test.' });
  }
  const baseUrlRequired = definition.requiresBaseUrl || !definition.supportsApiKey;
  if (baseUrlRequired && !baseUrl) {
    return res.status(400).json({ success: false, ok: false, error: 'A base URL is required.' });
  }
  if (baseUrl && !(await assertSafeByokBaseUrl(baseUrl, res, req.signal))) return;

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 8000);
  try {
    const config = {};
    if (factory.apiKey) config.apiKey = apiKey;
    if (factory.baseUrl) config.baseUrl = baseUrl;
    const provider = new factory.Provider(config);
    if (typeof provider.listModels !== 'function') {
      return res.json({ success: true, ok: true, message: 'Credential saved format looks valid; this provider does not support a live connection test.' });
    }
    let models = await provider.listModels(controller.signal);
    // A provider with only SystemOne models (TypeSafe) proves its key there.
    if (!models?.length && typeof provider.listDecisionModels === 'function') {
      models = await provider.listDecisionModels(controller.signal);
    }
    res.json({
      success: true,
      ok: true,
      message: Array.isArray(models) && models.length
        ? `Connected — found ${models.length} model(s).`
        : 'Connected, but no models were returned.',
    });
  } catch (error) {
    res.json({ success: true, ok: false, error: error?.message || 'Connection failed.' });
  } finally {
    clearTimeout(timeout);
  }
});

// Get all settings
router.get('/', async (req, res) => {
  const agentId = resolveAgentId(req.session.userId, getAgentIdFromRequest(req));
  ensureDefaultAiSettings(req.session.userId, agentId);
  ensureDefaultRuntimeSettings(req.session.userId);
  const includeLegacyAgentSettings = isMainAgent(req.session.userId, agentId);
  const userRows = db.prepare('SELECT key, value FROM user_settings WHERE user_id = ?').all(req.session.userId)
    .filter((row) => !RETIRED_SETTING_KEYS.has(row.key) && !HIDDEN_SETTING_KEYS.has(row.key))
    .filter((row) => includeLegacyAgentSettings || !isAgentScopedSettingKey(row.key));
  const rows = [
    ...userRows,
    ...db.prepare('SELECT key, value FROM agent_settings WHERE user_id = ? AND agent_id = ?')
      .all(req.session.userId, agentId)
      .filter((row) => !RETIRED_SETTING_KEYS.has(row.key) && !HIDDEN_SETTING_KEYS.has(row.key)),
  ];
  const settings = createDefaultAiSettings();
  for (const row of rows) {
    settings[row.key] = redactRuntimeSettingValue(row.key, parseStoredValue(row.key, row.value));
  }
  settings.agentId = agentId;
  settings.ai_provider_configs = normalizeProviderConfigs(settings.ai_provider_configs);
  settings.voice_capabilities = await req.app?.locals?.voiceRuntimeManager?.getCapabilities?.({
    userId: req.session.userId,
    agentId,
  }) || null;
  
  // Normalize runtime settings for consistency across deployments
  const normalizedRuntime = getRuntimeSettings(req.session.userId);
  Object.assign(settings, normalizedRuntime);
  
  res.json(settings);
});

// Update settings (batch)
router.put('/', (req, res) => {
  const userId = req.session.userId;
  const result = applySettingsUpdate({
    userId,
    agentId: resolveAgentId(userId, getAgentIdFromRequest(req)),
    patch: req.body || {},
    taskRuntime: req.app?.locals?.taskRuntime || null,
    source: `client ${req.get('user-agent') || 'unknown'}`,
  });
  if (!result.ok) {
    return res.status(400).json({ success: false, error: result.error, issues: result.issues });
  }
  res.json({ success: true });
});

// Token usage summary for settings UI
router.get('/token-usage/summary', (req, res) => {
  const userId = req.session.userId;
  const agentId = resolveAgentId(userId, getAgentIdFromRequest(req));
  const totals = db.prepare(`
    SELECT
      COALESCE(SUM(total_tokens), 0) AS totalTokens,
      COUNT(*) AS totalRuns,
      COALESCE(AVG(CASE WHEN total_tokens > 0 THEN total_tokens END), 0) AS avgTokensPerRun
    FROM agent_runs
    WHERE user_id = ? AND agent_id = ?
  `).get(userId, agentId);

  const recentRows = db.prepare(`
    SELECT
      date(created_at) AS day,
      COALESCE(SUM(total_tokens), 0) AS tokens,
      COUNT(*) AS runs
    FROM agent_runs
    WHERE user_id = ? AND agent_id = ? AND created_at >= datetime('now', '-6 days')
    GROUP BY date(created_at)
    ORDER BY day ASC
  `).all(userId, agentId);

  const byDay = new Map(recentRows.map(r => [r.day, { tokens: Number(r.tokens || 0), runs: Number(r.runs || 0) }]));
  const last7Days = [];
  for (let offset = 6; offset >= 0; offset--) {
    const day = db.prepare(`SELECT date('now', ?) AS day`).get(`-${offset} days`).day;
    const dayRow = byDay.get(day) || { tokens: 0, runs: 0 };
    last7Days.push({ date: day, tokens: dayRow.tokens, runs: dayRow.runs });
  }

  const last7Totals = last7Days.reduce((acc, d) => {
    acc.tokens += d.tokens;
    acc.runs += d.runs;
    return acc;
  }, { tokens: 0, runs: 0 });

  const promptMetricRows = db.prepare(`
    SELECT prompt_metrics
    FROM agent_runs
    WHERE user_id = ? AND agent_id = ? AND prompt_metrics IS NOT NULL
    ORDER BY created_at DESC
    LIMIT 20
  `).all(userId, agentId);

  const parsedMetrics = promptMetricRows
    .map((row) => {
      try { return JSON.parse(row.prompt_metrics); } catch { return null; }
    })
    .filter(Boolean);

  const metricTotals = parsedMetrics.reduce((acc, item) => {
    const last = item.lastEstimate || {};
    acc.count += 1;
    acc.system += Number(last.systemPromptTokens || 0);
    acc.tools += Number(last.toolSchemaTokens || 0);
    acc.history += Number(last.historyTokens || 0);
    acc.recall += Number(last.recalledMemoryTokens || 0);
    acc.replay += Number(last.toolReplayTokens || 0);
    return acc;
  }, { count: 0, system: 0, tools: 0, history: 0, recall: 0, replay: 0 });

  const normalizedUsage = db.prepare(`
    SELECT
      COALESCE(SUM(input_tokens), 0) AS inputTokens,
      COALESCE(SUM(output_tokens), 0) AS outputTokens,
      COALESCE(SUM(reasoning_tokens), 0) AS reasoningTokens,
      COALESCE(SUM(cached_read_tokens), 0) AS cachedReadTokens,
      COALESCE(SUM(cache_write_tokens), 0) AS cacheWriteTokens,
      COALESCE(SUM(total_tokens), 0) AS totalTokens,
      SUM(estimated_cost_usd) AS estimatedCostUsd,
      COUNT(estimated_cost_usd) AS pricedCallCount,
      COUNT(*) AS callCount
    FROM agent_model_usage
    WHERE user_id = ? AND agent_id = ?
  `).get(userId, agentId);
  const cacheEligibleTokens = Number(normalizedUsage?.inputTokens || 0)
    + Number(normalizedUsage?.cachedReadTokens || 0);

  res.json({
    totals: {
      totalTokens: Number(totals?.totalTokens || 0),
      totalRuns: Number(totals?.totalRuns || 0),
      avgTokensPerRun: Math.round(Number(totals?.avgTokensPerRun || 0)),
      last7DaysTokens: last7Totals.tokens,
      last7DaysRuns: last7Totals.runs
    },
    last7Days,
    promptMetrics: {
      sampleCount: metricTotals.count,
      average: metricTotals.count === 0 ? null : {
        systemPromptTokens: Math.round(metricTotals.system / metricTotals.count),
        toolSchemaTokens: Math.round(metricTotals.tools / metricTotals.count),
        historyTokens: Math.round(metricTotals.history / metricTotals.count),
        recalledMemoryTokens: Math.round(metricTotals.recall / metricTotals.count),
        toolReplayTokens: Math.round(metricTotals.replay / metricTotals.count)
      },
      latest: parsedMetrics[0] || null
    },
    modelUsage: {
      inputTokens: Number(normalizedUsage?.inputTokens || 0),
      outputTokens: Number(normalizedUsage?.outputTokens || 0),
      reasoningTokens: Number(normalizedUsage?.reasoningTokens || 0),
      cachedReadTokens: Number(normalizedUsage?.cachedReadTokens || 0),
      cacheWriteTokens: Number(normalizedUsage?.cacheWriteTokens || 0),
      totalTokens: Number(normalizedUsage?.totalTokens || 0),
      estimatedCostUsd: Number(normalizedUsage?.pricedCallCount || 0) > 0
        ? Number(normalizedUsage.estimatedCostUsd)
        : null,
      pricedCallCount: Number(normalizedUsage?.pricedCallCount || 0),
      callCount: Number(normalizedUsage?.callCount || 0),
      cacheHitRatio: cacheEligibleTokens > 0
        ? Number(normalizedUsage?.cachedReadTokens || 0) / cacheEligibleTokens
        : 0,
    },
  });
});

// Get single setting
router.get('/:key', (req, res) => {
  const userId = req.session.userId;
  const agentId = resolveAgentId(userId, getAgentIdFromRequest(req));
  res.json({ value: readSettingValue(userId, agentId, req.params.key) });
});

// Set single setting
router.put('/:key', (req, res) => {
  const key = req.params.key;
  if (RETIRED_SETTING_KEYS.has(key)) {
    return res.status(410).json({ success: false, error: `${key} has been retired` });
  }
  if (SERVER_MANAGED_SETTING_KEYS.has(key)) {
    return res.status(403).json({
      success: false,
      error: 'This setting is managed by the server, not per account.',
    });
  }
  if (isProtectedSecretSettingKey(key)) {
    return res.status(403).json({
      success: false,
      error: `${key} is managed by Social Reach cookie setup`,
    });
  }
  const userId = req.session.userId;
  const result = applySettingsUpdate({
    userId,
    agentId: resolveAgentId(userId, getAgentIdFromRequest(req)),
    patch: { [key]: req.body.value },
    taskRuntime: req.app?.locals?.taskRuntime || null,
    source: `client ${req.get('user-agent') || 'unknown'}`,
  });
  if (!result.ok) {
    return res.status(400).json({ success: false, error: result.error, issues: result.issues });
  }
  res.json({ success: true });
});

// Delete setting
router.delete('/:key', (req, res) => {
  if (SERVER_MANAGED_SETTING_KEYS.has(req.params.key)) {
    return res.status(403).json({
      success: false,
      error: 'This setting is managed by the server, not per account.',
    });
  }
  const userId = req.session.userId;
  const agentId = resolveAgentId(userId, getAgentIdFromRequest(req));
  if (RETIRED_SETTING_KEYS.has(req.params.key)) {
    db.prepare('DELETE FROM agent_settings WHERE user_id = ? AND agent_id = ? AND key = ?')
      .run(userId, agentId, req.params.key);
    db.prepare('DELETE FROM user_settings WHERE user_id = ? AND key = ?')
      .run(userId, req.params.key);
    return res.json({ success: true });
  }
  if (
    isAgentScopedSettingKey(req.params.key)
  ) {
    db.prepare('DELETE FROM agent_settings WHERE user_id = ? AND agent_id = ? AND key = ?')
      .run(userId, agentId, req.params.key);
  } else {
    db.prepare('DELETE FROM user_settings WHERE user_id = ? AND key = ?').run(userId, req.params.key);
  }
  applySettingsSideEffects(userId, agentId, { [req.params.key]: null }, req.app?.locals?.taskRuntime || null);
  res.json({ success: true });
});

router.post('/update', requireAuth, requireAdmin, updateTriggerLimiter, async (req, res, next) => {
  try {
    res.status(202).json(await startUpdate());
  } catch (error) {
    if (error.status) return res.status(error.status).json({ success: false, error: error.message });
    next(error);
  }
});

router.put('/update/channel', requireAuth, requireAdmin, (req, res, next) => {
  try {
    res.json(setUpdateChannel(req.body?.channel));
  } catch (error) {
    if (error.status) return res.status(error.status).json({ success: false, error: error.message });
    next(error);
  }
});

module.exports = router;
