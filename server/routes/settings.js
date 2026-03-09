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
