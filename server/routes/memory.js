const express = require('express');
const router = express.Router();
const { requireAuth } = require('../middleware/auth');

router.use(requireAuth);

// Get all memory data
router.get('/', (req, res) => {
  const mm = req.app.locals.memoryManager;
  res.json({
    memory: mm.readMemory(),
    soul: mm.readSoul(),
    dailyLogs: mm.listDailyLogs(7),
    apiKeys: Object.keys(mm.readApiKeys())
  });
});

// ── MEMORY.md ──

router.get('/memory', (req, res) => {
  res.json({ content: req.app.locals.memoryManager.readMemory() });
});

router.put('/memory', (req, res) => {
  req.app.locals.memoryManager.writeMemory(req.body.content);
  res.json({ success: true });
});

router.post('/memory/append', (req, res) => {
  const line = req.app.locals.memoryManager.appendMemory(req.body.entry);
  res.json({ success: true, line });
});

router.post('/memory/search', (req, res) => {
  const results = req.app.locals.memoryManager.searchMemory(req.body.query);
  res.json(results);
});

// ── SOUL.md ──

router.get('/soul', (req, res) => {
  res.json({ content: req.app.locals.memoryManager.readSoul() });
});

router.put('/soul', (req, res) => {
  req.app.locals.memoryManager.writeSoul(req.body.content);
  res.json({ success: true });
});

// ── Daily Logs ──

router.get('/daily', (req, res) => {
  const limit = parseInt(req.query.limit) || 7;
  res.json(req.app.locals.memoryManager.listDailyLogs(limit));
});

router.get('/daily/:date', (req, res) => {
  const content = req.app.locals.memoryManager.readDailyLog(new Date(req.params.date));
  res.json({ date: req.params.date, content });
});

// ── API Keys (agent-managed) ──

router.get('/api-keys', (req, res) => {
  const keys = req.app.locals.memoryManager.readApiKeys();
  // Return key names only, not values
  const masked = {};
  for (const [k, v] of Object.entries(keys)) {
    masked[k] = v ? `${v.slice(0, 4)}...${v.slice(-4)}` : null;
  }
  res.json(masked);
});

router.put('/api-keys/:service', (req, res) => {
  req.app.locals.memoryManager.setApiKey(req.params.service, req.body.key);
  res.json({ success: true });
});

router.delete('/api-keys/:service', (req, res) => {
  req.app.locals.memoryManager.deleteApiKey(req.params.service);
  res.json({ success: true });
});

// ── Conversation History ──

router.get('/conversations', (req, res) => {
  const mm = req.app.locals.memoryManager;
  const conversations = mm.getRecentConversations(req.session.userId, parseInt(req.query.limit) || 20);
  res.json(conversations);
});

router.post('/conversations/search', (req, res) => {
  const mm = req.app.locals.memoryManager;
  const results = mm.searchConversations(req.session.userId, req.body.query);
  res.json(results);
});

module.exports = router;
