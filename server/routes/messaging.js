const express = require('express');
const router = express.Router();
const db = require('../db/database');
const { requireAuth } = require('../middleware/auth');
const { sanitizeError } = require('../utils/security');
const { getAgentIdFromRequest, resolveAgentId } = require('../services/agents/manager');

const PREFIXED_ENTRY_RE = /[^0-9a-z:_.@#+=\-!$*]/gi;

// External platform callbacks. Each connected platform instance verifies its
// own signature or inbound secret before emitting a message.
router.post('/webhook/:platform', async (req, res) => {
  try {
    const manager = req.app.locals.messagingManager;
    if (!manager || typeof manager.handlePlatformWebhook !== 'function') {
      return res.status(503).send('Messaging manager unavailable');
    }
    const result = await manager.handlePlatformWebhook(req.params.platform, req);
    const status = result?.status || (result?.handled ? 200 : 404);
    if (typeof result?.body === 'object') return res.status(status).json(result.body);
    return res.status(status).send(result?.body || (result?.handled ? 'OK' : 'Not found'));
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

router.use(requireAuth);

function upsertAgentSetting(userId, agentId, key, value) {
  db.prepare(
    `INSERT INTO agent_settings (user_id, agent_id, key, value)
     VALUES (?, ?, ?, ?)
     ON CONFLICT(user_id, agent_id, key) DO UPDATE SET value = excluded.value`
  ).run(userId, agentId, key, JSON.stringify(value));
}

function logMessagingRouteError(action, err, details = {}) {
  const context = Object.entries(details)
    .filter(([, value]) => value !== undefined && value !== null && value !== '')
    .map(([key, value]) => `${key}=${value}`)
    .join(' ');
  const suffix = context ? ` (${context})` : '';
  console.error(`[Messaging] ${action} failed${suffix}:`, err);
}

// Get all platform statuses
router.get('/status', (req, res) => {
  const manager = req.app.locals.messagingManager;
  const agentId = resolveAgentId(req.session.userId, getAgentIdFromRequest(req));
  res.json(manager.getAllStatuses(req.session.userId, { agentId }));
});

// Connect to a platform
router.post('/connect', async (req, res) => {
  try {
    const { platform, config } = req.body;
    const agentId = resolveAgentId(req.session.userId, getAgentIdFromRequest(req));
    if (!platform) return res.status(400).json({ error: 'Platform is required' });

    const manager = req.app.locals.messagingManager;
    const result = await manager.connectPlatform(req.session.userId, platform, config || {}, { agentId });
    res.json(result);
  } catch (err) {
    logMessagingRouteError('connect', err, {
      userId: req.session?.userId,
      agentId: resolveAgentId(req.session.userId, getAgentIdFromRequest(req)),
      platform: req.body?.platform,
    });
    res.status(500).json({ error: sanitizeError(err) });
  }
});

// Disconnect from a platform
router.post('/disconnect', async (req, res) => {
  try {
    const { platform } = req.body;
    const agentId = resolveAgentId(req.session.userId, getAgentIdFromRequest(req));
    const manager = req.app.locals.messagingManager;
    const result = await manager.disconnectPlatform(req.session.userId, platform, { agentId });
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

// Logout from a platform (clear auth)
router.post('/logout', async (req, res) => {
  try {
    const { platform } = req.body;
    const agentId = resolveAgentId(req.session.userId, getAgentIdFromRequest(req));
    const manager = req.app.locals.messagingManager;
    const result = await manager.logoutPlatform(req.session.userId, platform, { agentId });
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

// Send a message
router.post('/send', async (req, res) => {
  try {
    const { platform, to, content, mediaPath } = req.body;
    const agentId = resolveAgentId(req.session.userId, getAgentIdFromRequest(req));
    if (!platform || !to || !content) return res.status(400).json({ error: 'platform, to, and content required' });

    const manager = req.app.locals.messagingManager;
    const result = await manager.sendMessage(req.session.userId, platform, to, content, { mediaPath, agentId });
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

// Get message history
router.get('/messages', (req, res) => {
  const { platform, chatId, limit } = req.query;
  const agentId = resolveAgentId(req.session.userId, getAgentIdFromRequest(req));
  let query = 'SELECT * FROM messages WHERE user_id = ? AND agent_id = ?';
  const params = [req.session.userId, agentId];

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
  const agentId = resolveAgentId(req.session.userId, getAgentIdFromRequest(req));
  res.json(manager.getPlatformStatus(req.session.userId, req.params.platform, { agentId }));
});

router.get('/:platform/devices', (req, res) => {
  try {
    const manager = req.app.locals.messagingManager;
    const agentId = resolveAgentId(req.session.userId, getAgentIdFromRequest(req));
    const devices = manager.getPlatformDevices(req.session.userId, req.params.platform, { agentId });
    res.json({ devices });
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

// Update Telnyx voice secret code (for non-whitelisted caller gating)
router.put('/telnyx/voice-secret', (req, res) => {
  try {
    const code = String(req.body.secret || '').replace(/\D/g, ''); // digits only
    const agentId = resolveAgentId(req.session.userId, getAgentIdFromRequest(req));
    upsertAgentSetting(req.session.userId, agentId, 'platform_voice_secret_telnyx', code);
    const manager = req.app.locals.messagingManager;
    if (manager) manager.updateTelnyxVoiceSecret(req.session.userId, code, { agentId });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

// Update Telnyx allowed numbers (whitelist)
router.put('/telnyx/whitelist', (req, res) => {
  try {
    const { numbers } = req.body;
    if (!Array.isArray(numbers)) return res.status(400).json({ error: 'numbers must be an array' });
    const list = numbers.map(n => n.replace(/[^0-9+]/g, '')).filter(Boolean);
    const agentId = resolveAgentId(req.session.userId, getAgentIdFromRequest(req));
    upsertAgentSetting(req.session.userId, agentId, 'platform_whitelist_telnyx', list);
    const manager = req.app.locals.messagingManager;
    if (manager) manager.updateTelnyxAllowedNumbers(req.session.userId, list, { agentId });
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
    const agentId = resolveAgentId(req.session.userId, getAgentIdFromRequest(req));
    upsertAgentSetting(req.session.userId, agentId, 'platform_whitelist_discord', list);
    const manager = req.app.locals.messagingManager;
    if (manager) manager.updateDiscordAllowedIds(req.session.userId, list, { agentId });
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
    const agentId = resolveAgentId(req.session.userId, getAgentIdFromRequest(req));
    upsertAgentSetting(req.session.userId, agentId, 'platform_whitelist_telegram', list);
    const manager = req.app.locals.messagingManager;
    if (manager) manager.updateTelegramAllowedIds(req.session.userId, list, { agentId });
    res.json({ success: true, ids: list });
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

// Update generic allowed IDs (whitelist — supports raw IDs and prefixed IDs)
router.put('/:platform/whitelist', (req, res) => {
  try {
    const { ids } = req.body;
    if (!Array.isArray(ids)) return res.status(400).json({ error: 'ids must be an array' });
    const platform = String(req.params.platform || '').replace(/[^0-9a-z_+-]/gi, '');
    if (!platform) return res.status(400).json({ error: 'platform is required' });
    const list = ids.map(id => String(id).replace(PREFIXED_ENTRY_RE, '')).filter(Boolean);
    const agentId = resolveAgentId(req.session.userId, getAgentIdFromRequest(req));
    upsertAgentSetting(req.session.userId, agentId, `platform_whitelist_${platform}`, list);
    const manager = req.app.locals.messagingManager;
    if (manager?.updateAllowedEntries) manager.updateAllowedEntries(req.session.userId, platform, list, { agentId });
    res.json({ success: true, ids: list });
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

module.exports = router;
