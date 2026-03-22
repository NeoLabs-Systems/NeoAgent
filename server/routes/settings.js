const express = require('express');
const fs = require('fs');
const path = require('path');
const router = express.Router();
const db = require('../db/database');
const { requireAuth } = require('../middleware/auth');
const { normalizeWhatsAppWhitelist } = require('../utils/whatsapp');
const { getVersionInfo } = require('../utils/version');
const { UPDATE_STATUS_FILE, APP_DIR } = require('../../runtime/paths');
const {
  createDefaultAiSettings,
  ensureDefaultAiSettings,
  normalizeProviderConfigs,
} = require('../services/ai/settings');

router.use(requireAuth);

function readUpdateStatus() {
  try {
    return JSON.parse(fs.readFileSync(UPDATE_STATUS_FILE, 'utf8'));
  } catch {
    return {
      state: 'idle',
      progress: 0,
      phase: 'idle',
      message: 'No update running',
      startedAt: null,
      completedAt: null,
      versionBefore: null,
      versionAfter: null,
      changelog: [],
      logs: []
    };
  }
}

function writeUpdateStatus(patch) {
  const next = {
    ...readUpdateStatus(),
    ...patch,
    updatedAt: new Date().toISOString()
  };
  fs.mkdirSync(path.dirname(UPDATE_STATUS_FILE), { recursive: true });
  fs.writeFileSync(UPDATE_STATUS_FILE, JSON.stringify(next, null, 2));
  return next;
}

function canApplyGlobalBrowserSetting(userId) {
  const users = db.prepare('SELECT id FROM users ORDER BY id ASC').all();
  return users.length <= 1 || users[0]?.id === userId;
}

// Get supported models metadata
router.get('/meta/models', async (req, res) => {
  const { getSupportedModels } = require('../services/ai/models');
  const models = await getSupportedModels(req.session.userId);
  res.json({ models });
});

router.get('/meta/ai-providers', async (req, res) => {
  const { getProviderCatalog, getSupportedModels } = require('../services/ai/models');
  const [providers, models] = await Promise.all([
    getProviderCatalog(req.session.userId),
    getSupportedModels(req.session.userId),
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
  ensureDefaultAiSettings(req.session.userId);
  const rows = db.prepare('SELECT key, value FROM user_settings WHERE user_id = ?').all(req.session.userId);
  const settings = createDefaultAiSettings();
  for (const row of rows) {
    try {
      settings[row.key] = JSON.parse(row.value);
    } catch (e) {
      if (typeof row.value === 'string' && (row.value.trim().startsWith('{') || row.value.trim().startsWith('['))) {
        console.warn(`[Settings] Failed to parse '${row.key}' as JSON, treating as raw string. Error:`, e.message);
      }
      settings[row.key] = row.value;
    }
  }
  settings.ai_provider_configs = normalizeProviderConfigs(settings.ai_provider_configs);
  res.json(settings);
});

// Update settings (batch)
router.put('/', (req, res) => {
  const userId = req.session.userId;
  const upsert = db.prepare('INSERT INTO user_settings (user_id, key, value) VALUES (?, ?, ?) ON CONFLICT(user_id, key) DO UPDATE SET value = excluded.value');
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

  const tx = db.transaction((entries) => {
    for (const [key, value] of entries) {
      const v = typeof value === 'string' ? value : JSON.stringify(value);
      upsert.run(userId, key, v);
    }
  });

  tx(Object.entries(normalizedBody));

  // Apply headless toggle immediately without restarting
  if ('headless_browser' in normalizedBody) {
    const bc = req.app.locals.browserController;
    if (bc && canApplyGlobalBrowserSetting(userId)) {
      bc.setHeadless(normalizedBody.headless_browser).catch(() => { });
    }
  }

  res.json({ success: true });
});

// Token usage summary for settings UI
router.get('/token-usage/summary', (req, res) => {
  const userId = req.session.userId;
  const totals = db.prepare(`
    SELECT
      COALESCE(SUM(total_tokens), 0) AS totalTokens,
      COUNT(*) AS totalRuns,
      COALESCE(AVG(CASE WHEN total_tokens > 0 THEN total_tokens END), 0) AS avgTokensPerRun
    FROM agent_runs
    WHERE user_id = ?
  `).get(userId);

  const recentRows = db.prepare(`
    SELECT
      date(created_at) AS day,
      COALESCE(SUM(total_tokens), 0) AS tokens,
      COUNT(*) AS runs
    FROM agent_runs
    WHERE user_id = ? AND created_at >= datetime('now', '-6 days')
    GROUP BY date(created_at)
    ORDER BY day ASC
  `).all(userId);

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
    WHERE user_id = ? AND prompt_metrics IS NOT NULL
    ORDER BY created_at DESC
    LIMIT 20
  `).all(userId);

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
  const row = db.prepare('SELECT value FROM user_settings WHERE user_id = ? AND key = ?').get(req.session.userId, req.params.key);
  if (!row) return res.json({ value: null });
  try {
    res.json({ value: JSON.parse(row.value) });
  } catch (e) {
    if (typeof row.value === 'string' && (row.value.trim().startsWith('{') || row.value.trim().startsWith('['))) {
      console.warn(`[Settings] Failed to parse '${req.params.key}' as JSON, returning as raw string. Error:`, e.message);
    }
    res.json({ value: row.value });
  }
});

// Set single setting
router.put('/:key', (req, res) => {
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
  }
  const v = typeof value === 'string' ? value : JSON.stringify(value);
  db.prepare('INSERT INTO user_settings (user_id, key, value) VALUES (?, ?, ?) ON CONFLICT(user_id, key) DO UPDATE SET value = excluded.value')
    .run(req.session.userId, req.params.key, v);
  if (req.params.key === 'headless_browser') {
    const bc = req.app.locals.browserController;
    if (bc && canApplyGlobalBrowserSetting(req.session.userId)) {
      bc.setHeadless(value).catch(() => { });
    }
  }
  res.json({ success: true });
});

// Delete setting
router.delete('/:key', (req, res) => {
  db.prepare('DELETE FROM user_settings WHERE user_id = ? AND key = ?').run(req.session.userId, req.params.key);
  res.json({ success: true });
});

// Trigger auto-update script
router.post('/update', (req, res) => {
  const { spawn } = require('child_process');
  const status = readUpdateStatus();
  if (status.state === 'running') {
    return res.status(409).json({ success: false, error: 'An update is already running' });
  }
  console.log('[Settings] Triggering update-runner...');
  writeUpdateStatus({
    state: 'running',
    progress: 1,
    phase: 'starting',
    message: 'Launching update job',
    startedAt: new Date().toISOString(),
    completedAt: null,
    versionBefore: null,
    versionAfter: null,
    changelog: [],
    logs: []
  });

  // Spawn detached runner so status survives server restarts.
  const child = spawn(process.execPath, ['scripts/update-runner.js'], {
    detached: true,
    stdio: 'ignore',
    cwd: APP_DIR
  });

  child.once('error', (error) => {
    writeUpdateStatus({
      state: 'failed',
      progress: 100,
      phase: 'failed',
      message: `Failed to launch update job: ${error.message}`,
      completedAt: new Date().toISOString()
    });
  });

  child.unref();
  res.json({ success: true, message: 'Update triggered', pid: child.pid });
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
    gitSha: version.gitSha
  });
});

module.exports = router;
