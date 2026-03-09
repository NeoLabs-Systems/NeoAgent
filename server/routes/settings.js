const express = require('express');
const fs = require('fs');
const path = require('path');
const router = express.Router();
const db = require('../db/database');
const { requireAuth } = require('../middleware/auth');

router.use(requireAuth);

const UPDATE_STATUS_FILE = path.join(process.cwd(), 'data', 'update-status.json');

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

// Get supported models metadata
router.get('/meta/models', (req, res) => {
  const { SUPPORTED_MODELS } = require('../services/ai/models');
  res.json({ models: SUPPORTED_MODELS });
});

// Get all settings
router.get('/', (req, res) => {
  const rows = db.prepare('SELECT key, value FROM user_settings WHERE user_id = ?').all(req.session.userId);
  const settings = {};
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
  res.json(settings);
});

// Update settings (batch)
router.put('/', (req, res) => {
  const userId = req.session.userId;
  const upsert = db.prepare('INSERT INTO user_settings (user_id, key, value) VALUES (?, ?, ?) ON CONFLICT(user_id, key) DO UPDATE SET value = excluded.value');

  const tx = db.transaction((entries) => {
    for (const [key, value] of entries) {
      const v = typeof value === 'string' ? value : JSON.stringify(value);
      upsert.run(userId, key, v);
    }
  });

  tx(Object.entries(req.body));

  // Apply headless toggle immediately without restarting
  if ('headless_browser' in req.body) {
    const bc = req.app.locals.browserController;
    if (bc) bc.setHeadless(req.body.headless_browser).catch(() => { });
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

  res.json({
    totals: {
      totalTokens: Number(totals?.totalTokens || 0),
      totalRuns: Number(totals?.totalRuns || 0),
      avgTokensPerRun: Math.round(Number(totals?.avgTokensPerRun || 0)),
      last7DaysTokens: last7Totals.tokens,
      last7DaysRuns: last7Totals.runs
    },
    last7Days
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
  const v = typeof req.body.value === 'string' ? req.body.value : JSON.stringify(req.body.value);
  db.prepare('INSERT INTO user_settings (user_id, key, value) VALUES (?, ?, ?) ON CONFLICT(user_id, key) DO UPDATE SET value = excluded.value')
    .run(req.session.userId, req.params.key, v);
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

  // Spawn detached runner so status survives server restarts.
  const child = spawn(process.execPath, ['scripts/update-runner.js'], {
    detached: true,
    stdio: 'ignore',
    cwd: process.cwd()
  });

  child.unref();
  res.json({ success: true, message: 'Update triggered', pid: child.pid });
});

router.get('/update/status', (req, res) => {
  res.json(readUpdateStatus());
});

module.exports = router;
