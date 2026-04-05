const express = require('express');
const router = express.Router();
const { requireAuth } = require('../middleware/auth');
const { sanitizeError } = require('../utils/security');

router.use(requireAuth);

function normalizeMemoryIds(value) {
  return [...new Set(
    (Array.isArray(value) ? value : [])
      .map((id) => String(id || '').trim())
      .filter(Boolean)
  )];
}

function findOwnedMemoryIds(db, userId, ids) {
  if (!ids.length) {
    return [];
  }
  const placeholders = ids.map(() => '?').join(', ');
  return db.prepare(
    `SELECT id FROM memories WHERE user_id = ? AND id IN (${placeholders})`
  ).all(userId, ...ids).map((row) => row.id);
}

// ─────────────────────────────────────────────────────────────────────────────
// Overview (for initial page load)
// ─────────────────────────────────────────────────────────────────────────────

router.get('/', (req, res) => {
  const mm = req.app.locals.memoryManager;
  const userId = req.session.userId;
  const coreMemory = { ...(mm.getCoreMemory(userId) || {}) };
  delete coreMemory.active_context;
  res.json({
    assistantBehaviorNotes: mm.getAssistantBehaviorNotes(userId),
    dailyLogs: mm.listDailyLogs(7, userId),
    apiKeys: Object.keys(mm.readApiKeys(userId)),
    coreMemory
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

router.post('/memories/bulk-delete', (req, res) => {
  const mm = req.app.locals.memoryManager;
  const db = require('../db/database');
  const ids = normalizeMemoryIds(req.body?.ids);
  if (!ids.length) {
    return res.status(400).json({ error: 'ids is required' });
  }
  try {
    const ownedIds = findOwnedMemoryIds(db, req.session.userId, ids);
    if (!ownedIds.length) {
      return res.status(404).json({ error: 'Memory not found' });
    }
    const deletedCount = mm.deleteMemories(ownedIds);
    res.json({ success: true, deletedCount });
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

router.post('/memories/bulk-archive', (req, res) => {
  const mm = req.app.locals.memoryManager;
  const db = require('../db/database');
  const ids = normalizeMemoryIds(req.body?.ids);
  const archived = req.body?.archived !== false;
  if (!ids.length) {
    return res.status(400).json({ error: 'ids is required' });
  }
  try {
    const ownedIds = findOwnedMemoryIds(db, req.session.userId, ids);
    if (!ownedIds.length) {
      return res.status(404).json({ error: 'Memory not found' });
    }
    const archivedCount = mm.archiveMemories(ownedIds, archived);
    res.json({ success: true, archivedCount });
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

// Semantic recall (search)
router.post('/memories/recall', async (req, res) => {
  const mm = req.app.locals.memoryManager;
  const userId = req.session.userId;
  const { query, limit = 8 } = req.body;
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
  const coreMemory = { ...(mm.getCoreMemory(userId) || {}) };
  delete coreMemory.active_context;
  res.json(coreMemory);
});

router.put('/core/:key', (req, res) => {
  const mm = req.app.locals.memoryManager;
  const userId = req.session.userId;
  const { value } = req.body;
  if (value === undefined) return res.status(400).json({ error: 'value is required' });
  if (req.params.key === 'active_context') {
    return res.status(400).json({ error: 'active_context is no longer a supported core memory key' });
  }
  mm.updateCore(userId, req.params.key, value);
  res.json({ success: true });
});

router.delete('/core/:key', (req, res) => {
  const mm = req.app.locals.memoryManager;
  const userId = req.session.userId;
  if (req.params.key === 'active_context') {
    return res.status(400).json({ error: 'active_context is no longer a supported core memory key' });
  }
  mm.deleteCore(userId, req.params.key);
  res.json({ success: true });
});

// ─────────────────────────────────────────────────────────────────────────────
// Daily Logs
// ─────────────────────────────────────────────────────────────────────────────

router.get('/daily', (req, res) => {
  const limit = parseInt(req.query.limit) || 7;
  res.json(req.app.locals.memoryManager.listDailyLogs(limit, req.session.userId));
});

router.get('/daily/:date', (req, res) => {
  const content = req.app.locals.memoryManager.readDailyLog(new Date(req.params.date), req.session.userId);
  res.json({ date: req.params.date, content });
});

// ─────────────────────────────────────────────────────────────────────────────
// API Keys (agent-managed)
// ─────────────────────────────────────────────────────────────────────────────

router.get('/api-keys', (req, res) => {
  const keys = req.app.locals.memoryManager.readApiKeys(req.session.userId);
  const masked = {};
  for (const [k, v] of Object.entries(keys)) {
    masked[k] = v ? `${v.slice(0, 4)}...${v.slice(-4)}` : null;
  }
  res.json(masked);
});

router.put('/api-keys/:service', (req, res) => {
  req.app.locals.memoryManager.setApiKey(req.params.service, req.body.key, req.session.userId);
  res.json({ success: true });
});

router.delete('/api-keys/:service', (req, res) => {
  req.app.locals.memoryManager.deleteApiKey(req.params.service, req.session.userId);
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
  const results = mm.searchConversations(req.session.userId, req.body.query, {
    sessions: parseInt(req.body.limit) || 8
  });
  res.json(results);
});

module.exports = router;
