const express = require('express');
const router = express.Router();
const { requireAuth } = require('../middleware/auth');
const { sanitizeError } = require('../utils/security');

router.use(requireAuth);

// ─────────────────────────────────────────────────────────────────────────────
// Overview (for initial page load)
// ─────────────────────────────────────────────────────────────────────────────

router.get('/', (req, res) => {
  const mm = req.app.locals.memoryManager;
  const userId = req.session.userId;
  res.json({
    soul: mm.readSoul(),
    dailyLogs: mm.listDailyLogs(7),
    apiKeys: Object.keys(mm.readApiKeys()),
    coreMemory: mm.getCoreMemory(userId)
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// Semantic Memories
// ─────────────────────────────────────────────────────────────────────────────

// List memories (with optional ?category= and ?limit= filters)
router.get('/memories', (req, res) => {
  const mm = req.app.locals.memoryManager;
  const userId = req.session.userId;
  const { category, limit = 50, offset = 0, archived = false } = req.query;
  try {
    const memories = mm.listMemories(userId, {
      category: category || null,
      limit: parseInt(limit),
      offset: parseInt(offset),
      includeArchived: archived === 'true'
    });
    res.json(memories);
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

// Save a new memory
router.post('/memories', async (req, res) => {
  const mm = req.app.locals.memoryManager;
  const userId = req.session.userId;
  const { content, category = 'episodic', importance = 5 } = req.body;
  if (!content || !content.trim()) return res.status(400).json({ error: 'content is required' });
  try {
    const id = await mm.saveMemory(userId, content, category, importance);
    res.json({ success: true, id });
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

// Update a memory
router.put('/memories/:id', async (req, res) => {
  const mm = req.app.locals.memoryManager;
  const db = require('../db/database');
  // Verify ownership before updating
  const existing = db.prepare('SELECT id FROM memories WHERE id = ? AND user_id = ?').get(req.params.id, req.session.userId);
  if (!existing) return res.status(404).json({ error: 'Memory not found' });
  const { content, importance, category } = req.body;
  try {
    const updated = await mm.updateMemory(req.params.id, { content, importance, category });
    if (!updated) return res.status(404).json({ error: 'Memory not found' });
    res.json(updated);
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

// Delete a memory
router.delete('/memories/:id', (req, res) => {
  const mm = req.app.locals.memoryManager;
  const db = require('../db/database');
  // Verify ownership before deleting
  const existing = db.prepare('SELECT id FROM memories WHERE id = ? AND user_id = ?').get(req.params.id, req.session.userId);
  if (!existing) return res.status(404).json({ error: 'Memory not found' });
  mm.deleteMemory(req.params.id);
  res.json({ success: true });
});

// Semantic recall (search)
router.post('/memories/recall', async (req, res) => {
  const mm = req.app.locals.memoryManager;
  const userId = req.session.userId;
  const { query, limit = 10 } = req.body;
  if (!query) return res.status(400).json({ error: 'query is required' });
  try {
    const results = await mm.recallMemory(userId, query, parseInt(limit));
    res.json(results);
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Core Memory
// ─────────────────────────────────────────────────────────────────────────────

router.get('/core', (req, res) => {
  const mm = req.app.locals.memoryManager;
  const userId = req.session.userId;
  res.json(mm.getCoreMemory(userId));
});

router.put('/core/:key', (req, res) => {
  const mm = req.app.locals.memoryManager;
  const userId = req.session.userId;
  const { value } = req.body;
  if (value === undefined) return res.status(400).json({ error: 'value is required' });
  mm.updateCore(userId, req.params.key, value);
  res.json({ success: true });
});

router.delete('/core/:key', (req, res) => {
  const mm = req.app.locals.memoryManager;
  const userId = req.session.userId;
  mm.deleteCore(userId, req.params.key);
  res.json({ success: true });
});

// ─────────────────────────────────────────────────────────────────────────────
// SOUL.md
// ─────────────────────────────────────────────────────────────────────────────

router.get('/soul', (req, res) => {
  res.json({ content: req.app.locals.memoryManager.readSoul() });
});

router.put('/soul', (req, res) => {
  req.app.locals.memoryManager.writeSoul(req.body.content);
  res.json({ success: true });
});

// ─────────────────────────────────────────────────────────────────────────────
// Daily Logs
// ─────────────────────────────────────────────────────────────────────────────

router.get('/daily', (req, res) => {
  const limit = parseInt(req.query.limit) || 7;
  res.json(req.app.locals.memoryManager.listDailyLogs(limit));
});

router.get('/daily/:date', (req, res) => {
  const content = req.app.locals.memoryManager.readDailyLog(new Date(req.params.date));
  res.json({ date: req.params.date, content });
});

// ─────────────────────────────────────────────────────────────────────────────
// API Keys (agent-managed)
// ─────────────────────────────────────────────────────────────────────────────

router.get('/api-keys', (req, res) => {
  const keys = req.app.locals.memoryManager.readApiKeys();
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

// ─────────────────────────────────────────────────────────────────────────────
// Conversation History
// ─────────────────────────────────────────────────────────────────────────────

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
