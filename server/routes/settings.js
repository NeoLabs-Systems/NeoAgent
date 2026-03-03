const express = require('express');
const router = express.Router();
const db = require('../db/database');
const { requireAuth } = require('../middleware/auth');

router.use(requireAuth);

// Get all settings
router.get('/', (req, res) => {
  const rows = db.prepare('SELECT key, value FROM user_settings WHERE user_id = ?').all(req.session.userId);
  const settings = {};
  for (const row of rows) {
    try { settings[row.key] = JSON.parse(row.value); } catch { settings[row.key] = row.value; }
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
    if (bc) bc.setHeadless(req.body.headless_browser).catch(() => {});
  }

  res.json({ success: true });
});

// Get single setting
router.get('/:key', (req, res) => {
  const row = db.prepare('SELECT value FROM user_settings WHERE user_id = ? AND key = ?').get(req.session.userId, req.params.key);
  if (!row) return res.json({ value: null });
  try { res.json({ value: JSON.parse(row.value) }); } catch { res.json({ value: row.value }); }
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

module.exports = router;
