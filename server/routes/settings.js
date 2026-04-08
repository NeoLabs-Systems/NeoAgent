const express = require('express');
const router = express.Router();
const db = require('../db/database');
const { requireAuth } = require('../middleware/auth');
const { normalizeWhatsAppWhitelist } = require('../utils/whatsapp');
const { getVersionInfo } = require('../utils/version');
const { APP_DIR } = require('../../runtime/paths');
const {
  readUpdateStatus,
  writeUpdateStatusFile: writeUpdateStatus,
} = require('../utils/update_status');
const { getRuntimeValidation } = require('../services/runtime/validation');
const {
  parseReleaseChannel,
  writeReleaseChannelToEnvFile,
  getReleaseChannelBranchPolicy,
  getReleaseChannelNpmPolicy,
} = require('../../runtime/release_channel');
const {
  createDefaultAiSettings,
  ensureDefaultAiSettings,
  normalizeProviderConfigs,
} = require('../services/ai/settings');
const {
  ensureDefaultRuntimeSettings,
  getRuntimeSettings,
  redactRuntimeSettingValue,
  serializeRuntimeSettingValue,
  validateRuntimeSettings,
} = require('../services/runtime/settings');
const { isManagedDeployment } = require('../utils/deployment');
const { getAgentIdFromRequest, isMainAgent, resolveAgentId } = require('../services/agents/manager');

const AGENT_SETTING_KEYS = new Set([
  'cost_mode',
  'chat_history_window',
  'tool_replay_budget_chars',
  'subagent_max_iterations',
  'assistant_behavior_notes',
  'auto_skill_learning',
  'auto_recording_insights',
  'fallback_model_id',
  'smarter_model_selector',
  'ai_provider_configs',
  'default_chat_model',
  'default_subagent_model',
  'enabled_models',
  'last_platform',
  'last_chat_id',
]);

router.use(requireAuth);

function isAgentScopedSettingKey(key) {
  return AGENT_SETTING_KEYS.has(key)
    || key.startsWith('platform_whitelist_')
    || key === 'platform_voice_secret_telnyx';
}

function getBrowserController(req) {
  const runtimeManager = req.app?.locals?.runtimeManager;
  if (runtimeManager && typeof runtimeManager.getBrowserProviderForUser === 'function') {
    return runtimeManager.getBrowserProviderForUser(req.session?.userId);
  }
  const resolver = req.app?.locals?.getBrowserControllerForUser;
  if (typeof resolver === 'function') {
    return resolver(req.session?.userId);
  }
  return req.app?.locals?.browserController;
}

function applyHeadlessSetting(req, value) {
  Promise.resolve(getBrowserController(req))
    .then((controller) => {
      if (controller && typeof controller.setHeadless === 'function') {
        return controller.setHeadless(value);
      }
      return null;
    })
    .catch(() => { });
}

// Get supported models metadata
router.get('/meta/models', async (req, res) => {
  const { getSupportedModels } = require('../services/ai/models');
  const agentId = resolveAgentId(req.session.userId, getAgentIdFromRequest(req));
  const models = await getSupportedModels(req.session.userId, agentId);
  res.json({ models });
});

router.get('/meta/ai-providers', async (req, res) => {
  const { getProviderHealthCatalog, getSupportedModels } = require('../services/ai/models');
  const agentId = resolveAgentId(req.session.userId, getAgentIdFromRequest(req));
  const [providers, models] = await Promise.all([
    getProviderHealthCatalog(req.session.userId, agentId),
    getSupportedModels(req.session.userId, agentId),
  ]);

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

// Get all settings
router.get('/', (req, res) => {
  const agentId = resolveAgentId(req.session.userId, getAgentIdFromRequest(req));
  ensureDefaultAiSettings(req.session.userId, agentId);
  ensureDefaultRuntimeSettings(req.session.userId);
  const includeLegacyAgentSettings = isMainAgent(req.session.userId, agentId);
  const userRows = db.prepare('SELECT key, value FROM user_settings WHERE user_id = ?').all(req.session.userId)
    .filter((row) => includeLegacyAgentSettings || !isAgentScopedSettingKey(row.key));
  const rows = [
    ...userRows,
    ...db.prepare('SELECT key, value FROM agent_settings WHERE user_id = ? AND agent_id = ?').all(req.session.userId, agentId),
  ];
  const settings = createDefaultAiSettings();
  for (const row of rows) {
    try {
      settings[row.key] = redactRuntimeSettingValue(row.key, JSON.parse(row.value));
    } catch (e) {
      if (typeof row.value === 'string' && (row.value.trim().startsWith('{') || row.value.trim().startsWith('['))) {
        console.warn(`[Settings] Failed to parse '${row.key}' as JSON, treating as raw string. Error:`, e.message);
      }
      settings[row.key] = redactRuntimeSettingValue(row.key, row.value);
    }
  }
  settings.agentId = agentId;
  settings.ai_provider_configs = normalizeProviderConfigs(settings.ai_provider_configs);
  res.json(settings);
});

// Update settings (batch)
router.put('/', (req, res) => {
  const userId = req.session.userId;
  const agentId = resolveAgentId(userId, getAgentIdFromRequest(req));
  ensureDefaultAiSettings(userId, agentId);
  ensureDefaultRuntimeSettings(userId);
  const upsert = db.prepare('INSERT INTO user_settings (user_id, key, value) VALUES (?, ?, ?) ON CONFLICT(user_id, key) DO UPDATE SET value = excluded.value');
  const upsertAgent = db.prepare('INSERT INTO agent_settings (user_id, agent_id, key, value) VALUES (?, ?, ?, ?) ON CONFLICT(user_id, agent_id, key) DO UPDATE SET value = excluded.value');
  const normalizedBody = { ...req.body };

  if ('platform_whitelist_whatsapp' in normalizedBody) {
    let whitelist = normalizedBody.platform_whitelist_whatsapp;
    if (typeof whitelist === 'string') {
      try {
        whitelist = JSON.parse(whitelist);
      } catch {
        whitelist = [];
      }
    }
    normalizedBody.platform_whitelist_whatsapp = JSON.stringify(normalizeWhatsAppWhitelist(whitelist));
  }

  if ('ai_provider_configs' in normalizedBody) {
    normalizedBody.ai_provider_configs = normalizeProviderConfigs(normalizedBody.ai_provider_configs);
  }

  if (
    'runtime_profile' in normalizedBody
    || 'runtime_backend' in normalizedBody
    || 'browser_backend' in normalizedBody
    || 'android_backend' in normalizedBody
    || 'mcp_backend' in normalizedBody
    || 'remote_worker_base_url' in normalizedBody
    || 'remote_worker_token' in normalizedBody
  ) {
    const validation = validateRuntimeSettings({
      ...getRuntimeSettings(userId),
      ...normalizedBody,
    });
    if (!validation.valid) {
      return res.status(400).json({
        success: false,
        error: validation.issues[0],
        issues: validation.issues,
      });
    }
    Object.assign(normalizedBody, validation.settings);
  }

  const tx = db.transaction((entries) => {
    for (const [key, value] of entries) {
      const v = serializeRuntimeSettingValue(key, value);
      if (isAgentScopedSettingKey(key)) {
        upsertAgent.run(userId, agentId, key, v);
      } else if (key !== 'agentId' && key !== 'agent_id') {
        upsert.run(userId, key, v);
      }
    }
  });

  tx(Object.entries(normalizedBody));

  // Apply headless toggle immediately without restarting
  if ('headless_browser' in normalizedBody) {
    applyHeadlessSetting(req, normalizedBody.headless_browser);
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
    }
  });
});

// Get single setting
router.get('/:key', (req, res) => {
  const userId = req.session.userId;
  const agentId = resolveAgentId(userId, getAgentIdFromRequest(req));
  ensureDefaultRuntimeSettings(userId);
  const isAgentSetting = isAgentScopedSettingKey(req.params.key);
  const row = isAgentSetting
    ? (
      db.prepare('SELECT value FROM agent_settings WHERE user_id = ? AND agent_id = ? AND key = ?').get(userId, agentId, req.params.key)
      || (isMainAgent(userId, agentId)
        ? db.prepare('SELECT value FROM user_settings WHERE user_id = ? AND key = ?').get(userId, req.params.key)
        : null)
    )
    : db.prepare('SELECT value FROM user_settings WHERE user_id = ? AND key = ?').get(userId, req.params.key);
  if (!row) return res.json({ value: null });
  try {
    res.json({ value: redactRuntimeSettingValue(req.params.key, JSON.parse(row.value)) });
  } catch (e) {
    if (typeof row.value === 'string' && (row.value.trim().startsWith('{') || row.value.trim().startsWith('['))) {
      console.warn(`[Settings] Failed to parse '${req.params.key}' as JSON, returning as raw string. Error:`, e.message);
    }
    res.json({ value: redactRuntimeSettingValue(req.params.key, row.value) });
  }
});

// Set single setting
router.put('/:key', (req, res) => {
  const userId = req.session.userId;
  const agentId = resolveAgentId(userId, getAgentIdFromRequest(req));
  ensureDefaultRuntimeSettings(userId);
  let value = req.body.value;
  if (req.params.key === 'platform_whitelist_whatsapp') {
    if (typeof value === 'string') {
      try {
        value = JSON.parse(value);
      } catch {
        value = [];
      }
    }
    value = normalizeWhatsAppWhitelist(value);
  } else if (req.params.key === 'ai_provider_configs') {
    value = normalizeProviderConfigs(value);
  } else if (
    ['runtime_profile', 'runtime_backend', 'browser_backend', 'android_backend', 'mcp_backend', 'remote_worker_base_url', 'remote_worker_token']
      .includes(req.params.key)
  ) {
    const validation = validateRuntimeSettings({
      ...getRuntimeSettings(req.session.userId),
      [req.params.key]: value,
    });
    if (!validation.valid) {
      return res.status(400).json({
        success: false,
        error: validation.issues[0],
        issues: validation.issues,
      });
    }
    value = validation.settings[req.params.key];
  }
  const v = serializeRuntimeSettingValue(req.params.key, value);
  if (
    isAgentScopedSettingKey(req.params.key)
  ) {
    db.prepare(
      `INSERT INTO agent_settings (user_id, agent_id, key, value)
       VALUES (?, ?, ?, ?)
       ON CONFLICT(user_id, agent_id, key) DO UPDATE SET value = excluded.value`
    ).run(userId, agentId, req.params.key, v);
  } else {
    db.prepare('INSERT INTO user_settings (user_id, key, value) VALUES (?, ?, ?) ON CONFLICT(user_id, key) DO UPDATE SET value = excluded.value')
      .run(userId, req.params.key, v);
  }
  if (req.params.key === 'headless_browser') {
    applyHeadlessSetting(req, value);
  }
  res.json({ success: true });
});

// Delete setting
router.delete('/:key', (req, res) => {
  const userId = req.session.userId;
  const agentId = resolveAgentId(userId, getAgentIdFromRequest(req));
  if (
    isAgentScopedSettingKey(req.params.key)
  ) {
    db.prepare('DELETE FROM agent_settings WHERE user_id = ? AND agent_id = ? AND key = ?')
      .run(userId, agentId, req.params.key);
  } else {
    db.prepare('DELETE FROM user_settings WHERE user_id = ? AND key = ?').run(userId, req.params.key);
  }
  res.json({ success: true });
});

// Trigger auto-update script
router.post('/update', (req, res) => {
  if (isManagedDeployment()) {
    return res.status(403).json({
      success: false,
      error: 'Updates are managed by this deployment.',
    });
  }
  const { spawn } = require('child_process');
  const status = readUpdateStatus();
  if (status.state === 'running') {
    return res.status(409).json({ success: false, error: 'An update is already running' });
  }
  console.log('[Settings] Triggering update-runner...');
  const child = spawn(process.execPath, ['scripts/update-runner.js'], {
    detached: true,
    stdio: 'ignore',
    cwd: APP_DIR
  });

  writeUpdateStatus({
    state: 'running',
    progress: 1,
    phase: 'starting',
    message: 'Launching update job',
    startedAt: new Date().toISOString(),
    completedAt: null,
    versionBefore: null,
    versionAfter: null,
    runnerPid: child.pid,
    changelog: [],
    logs: []
  });

  child.once('error', (error) => {
    writeUpdateStatus({
      state: 'failed',
      progress: 100,
      phase: 'failed',
      message: `Failed to launch update job: ${error.message}`,
      completedAt: new Date().toISOString(),
      runnerPid: null,
    });
  });

  child.unref();
  res.json({ success: true, message: 'Update triggered', pid: child.pid });
});

router.put('/update/channel', (req, res) => {
  if (isManagedDeployment()) {
    return res.status(403).json({
      success: false,
      error: 'Release channel changes are managed by this deployment.',
    });
  }
  const requested = req.body?.channel;
  const releaseChannel = parseReleaseChannel(requested);
  if (!releaseChannel) {
    return res.status(400).json({
      success: false,
      error: 'Release channel must be "stable" or "beta".',
    });
  }

  writeReleaseChannelToEnvFile(releaseChannel);
  process.env.NEOAGENT_RELEASE_CHANNEL = releaseChannel;

  res.json({
    success: true,
    releaseChannel,
    targetBranch: getReleaseChannelBranchPolicy(releaseChannel),
    npmDistTag: getReleaseChannelNpmPolicy(releaseChannel),
  });
});

router.get('/update/status', (req, res) => {
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
    releaseChannel: status.releaseChannel || version.releaseChannel,
    targetBranch: status.targetBranch || version.targetBranch,
    npmDistTag: status.npmDistTag || version.npmDistTag,
    deploymentMode: version.deploymentMode,
    deploymentProfile: version.deploymentProfile,
    managedDeployment: version.managedDeployment,
    allowSelfUpdate: version.allowSelfUpdate,
    runtimeDefaults: version.runtimeDefaults,
    allowHostRuntime: version.allowHostRuntime,
    runtimeValidation: getRuntimeValidation(req.app?.locals?.runtimeManager),
  });
});

module.exports = router;
