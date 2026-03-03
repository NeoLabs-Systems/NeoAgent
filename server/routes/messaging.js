const express = require('express');
const router = express.Router();
const db = require('../db/database');
const { requireAuth } = require('../middleware/auth');
const { sanitizeError } = require('../utils/security');

router.use(requireAuth);

// Get all platform statuses
router.get('/status', (req, res) => {
  const manager = req.app.locals.messagingManager;
  res.json(manager.getAllStatuses(req.session.userId));
});

// Connect to a platform
router.post('/connect', async (req, res) => {
  try {
    const { platform, config } = req.body;
    if (!platform) return res.status(400).json({ error: 'Platform is required' });

    const manager = req.app.locals.messagingManager;
    const result = await manager.connectPlatform(req.session.userId, platform, config || {});
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

// Disconnect from a platform
router.post('/disconnect', async (req, res) => {
  try {
    const { platform } = req.body;
    const manager = req.app.locals.messagingManager;
    const result = await manager.disconnectPlatform(req.session.userId, platform);
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

// Logout from a platform (clear auth)
router.post('/logout', async (req, res) => {
  try {
    const { platform } = req.body;
    const manager = req.app.locals.messagingManager;
    const result = await manager.logoutPlatform(req.session.userId, platform);
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

// Send a message
router.post('/send', async (req, res) => {
  try {
    const { platform, to, content, mediaPath } = req.body;
    if (!platform || !to || !content) return res.status(400).json({ error: 'platform, to, and content required' });

    const manager = req.app.locals.messagingManager;
    const result = await manager.sendMessage(req.session.userId, platform, to, content, mediaPath);
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

// Get message history
router.get('/messages', (req, res) => {
  const { platform, chatId, limit } = req.query;
  let query = 'SELECT * FROM messages WHERE user_id = ?';
  const params = [req.session.userId];

  if (platform) { query += ' AND platform = ?'; params.push(platform); }
  if (chatId) { query += ' AND platform_chat_id = ?'; params.push(chatId); }

  query += ' ORDER BY created_at DESC LIMIT ?';
  params.push(Math.min(parseInt(limit) || 50, 200));

  const messages = db.prepare(query).all(...params);
  res.json(messages);
});

// Get platform-specific status
router.get('/status/:platform', (req, res) => {
  const manager = req.app.locals.messagingManager;
  res.json(manager.getPlatformStatus(req.session.userId, req.params.platform));
});

// Update Telnyx allowed numbers (whitelist)
router.put('/telnyx/whitelist', (req, res) => {
  try {
    const { numbers } = req.body;
    if (!Array.isArray(numbers)) return res.status(400).json({ error: 'numbers must be an array' });
    const list = numbers.map(n => n.replace(/[^0-9+]/g, '')).filter(Boolean);
    db.prepare('INSERT INTO user_settings (user_id, key, value) VALUES (?, ?, ?) ON CONFLICT(user_id, key) DO UPDATE SET value = excluded.value')
      .run(req.session.userId, 'platform_whitelist_telnyx', JSON.stringify(list));
    const manager = req.app.locals.messagingManager;
    if (manager) manager.updateTelnyxAllowedNumbers(req.session.userId, list);
    res.json({ success: true, numbers: list });
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

// Update Discord allowed IDs (whitelist — prefixed: "user:ID", "guild:ID", "channel:ID")
router.put('/discord/whitelist', (req, res) => {
  try {
    const { ids } = req.body;
    if (!Array.isArray(ids)) return res.status(400).json({ error: 'ids must be an array' });
    // Keep prefixed format, strip only clearly unsafe characters
    const list = ids.map(id => String(id).replace(/[^0-9a-z:_-]/gi, '')).filter(Boolean);
    db.prepare('INSERT INTO user_settings (user_id, key, value) VALUES (?, ?, ?) ON CONFLICT(user_id, key) DO UPDATE SET value = excluded.value')
      .run(req.session.userId, 'platform_whitelist_discord', JSON.stringify(list));
    const manager = req.app.locals.messagingManager;
    if (manager) manager.updateDiscordAllowedIds(req.session.userId, list);
    res.json({ success: true, ids: list });
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

// Update Telegram allowed IDs (whitelist — prefixed: "user:ID", "group:ID")
router.put('/telegram/whitelist', (req, res) => {
  try {
    const { ids } = req.body;
    if (!Array.isArray(ids)) return res.status(400).json({ error: 'ids must be an array' });
    // Keep prefixed format; group IDs are negative so allow minus sign
    const list = ids.map(id => String(id).replace(/[^0-9a-z:_-]/gi, '')).filter(Boolean);
    db.prepare('INSERT INTO user_settings (user_id, key, value) VALUES (?, ?, ?) ON CONFLICT(user_id, key) DO UPDATE SET value = excluded.value')
      .run(req.session.userId, 'platform_whitelist_telegram', JSON.stringify(list));
    const manager = req.app.locals.messagingManager;
    if (manager) manager.updateTelegramAllowedIds(req.session.userId, list);
    res.json({ success: true, ids: list });
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

module.exports = router;
