const express = require('express');
const router = express.Router();
const rateLimit = require('express-rate-limit');
const { requireAuth } = require('../middleware/auth');
const { sanitizeError } = require('../utils/security');
const { getAgentIdFromRequest, resolveAgentId } = require('../services/agents/manager');

router.use(requireAuth);

const apiKeyMutationLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 60,
  message: { error: 'Too many API key update attempts, try again later' },
  standardHeaders: true,
  legacyHeaders: false,
});

function normalizeMemoryIds(value) {
  return [...new Set(
    (Array.isArray(value) ? value : [])
      .map((id) => String(id || '').trim())
      .filter(Boolean)
  )];
}

function findOwnedMemoryIds(db, userId, agentId, ids) {
  if (!ids.length) {
    return [];
  }
  const placeholders = ids.map(() => '?').join(', ');
  return db.prepare(
    `SELECT id FROM memories WHERE user_id = ? AND agent_id = ? AND id IN (${placeholders})`
  ).all(userId, agentId, ...ids).map((row) => row.id);
}

function parsePlainObject(input, fieldName) {
  if (input == null) return null;
  if (typeof input === 'string') {
    try {
      input = JSON.parse(input);
    } catch {
      throw new Error(`${fieldName} must be valid JSON.`);
    }
  }
  if (!input || typeof input !== 'object' || Array.isArray(input)) {
    throw new Error(`${fieldName} must be an object.`);
  }
  return input;
}

function normalizeOptionalStringField(value, fieldName, maxLength, pattern = null) {
  if (value == null || value === '') return null;
  if (typeof value !== 'string') {
    throw new Error(`${fieldName} must be a string.`);
  }
  const normalized = value.trim().slice(0, maxLength);
  if (!normalized) return null;
  if (pattern && !pattern.test(normalized)) {
    throw new Error(`${fieldName} has an invalid format.`);
  }
  return normalized;
}

function normalizeSourceRef(input) {
  const raw = parsePlainObject(input, 'sourceRef');
  if (!raw) return undefined;
  return {
    sourceType: normalizeOptionalStringField(raw.sourceType ?? raw.type, 'sourceRef.sourceType', 48, /^[a-z0-9_:-]+$/i),
    sourceId: normalizeOptionalStringField(raw.sourceId ?? raw.id, 'sourceRef.sourceId', 128),
    sourceLabel: normalizeOptionalStringField(raw.sourceLabel ?? raw.label, 'sourceRef.sourceLabel', 160),
  };
}

function normalizeScope(input) {
  const raw = parsePlainObject(input, 'scope');
  if (!raw) return undefined;
  const scopeType = normalizeOptionalStringField(raw.scopeType ?? raw.type, 'scope.scopeType', 32, /^(agent|conversation|task|channel|shared)$/i);
  return {
    scopeType: scopeType ? scopeType.toLowerCase() : null,
    scopeId: normalizeOptionalStringField(raw.scopeId ?? raw.id, 'scope.scopeId', 128),
  };
}

function normalizeMetadata(input) {
  const raw = parsePlainObject(input, 'metadata');
  return raw == null ? undefined : raw;
}

// ─────────────────────────────────────────────────────────────────────────────
// Overview (for initial page load)
// ─────────────────────────────────────────────────────────────────────────────

router.get('/', (req, res) => {
  const mm = req.app.locals.memoryManager;
  const userId = req.session.userId;
  const agentId = resolveAgentId(userId, getAgentIdFromRequest(req));
  const coreMemory = { ...(mm.getCoreMemory(userId, { agentId }) || {}) };
  delete coreMemory.active_context;
  res.json({
    agentId,
    assistantBehaviorNotes: mm.getAssistantBehaviorNotes(userId, { agentId }),
    assistantSelfState: mm.getAssistantSelfState(userId, { agentId }),
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
  const agentId = resolveAgentId(userId, getAgentIdFromRequest(req));
  const { category, limit = 50, offset = 0, archived = false } = req.query;
  try {
    const memories = mm.listMemories(userId, {
      category: category || null,
      limit: parseInt(limit),
      offset: parseInt(offset),
      includeArchived: archived === 'true',
      agentId,
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
  const agentId = resolveAgentId(userId, getAgentIdFromRequest(req));
  const { content, category = 'episodic', importance = 5, sourceRef, scope, staleAfterDays, metadata } = req.body;
  if (!content || !content.trim()) return res.status(400).json({ error: 'content is required' });
  try {
    let normalizedStaleAfterDays;
    if (staleAfterDays != null && staleAfterDays !== '') {
      normalizedStaleAfterDays = Number.parseInt(staleAfterDays, 10);
      if (!Number.isInteger(normalizedStaleAfterDays) || normalizedStaleAfterDays <= 0) {
        return res.status(400).json({ error: 'staleAfterDays must be a positive integer.' });
      }
    }

    const id = await mm.saveMemory(userId, content, category, importance, {
      agentId,
      sourceRef: normalizeSourceRef(sourceRef),
      scope: normalizeScope(scope),
      staleAfterDays: normalizedStaleAfterDays,
      metadata: normalizeMetadata(metadata),
    });
    res.json({ success: true, id });
  } catch (err) {
    const message = sanitizeError(err);
    if (/must be valid JSON|must be an object|must be a string|has an invalid format/i.test(message)) {
      return res.status(400).json({ error: message });
    }
    res.status(500).json({ error: message });
  }
});

// Update a memory
router.put('/memories/:id', async (req, res) => {
  const mm = req.app.locals.memoryManager;
  const db = require('../db/database');
  // Verify ownership before updating
  const agentId = resolveAgentId(req.session.userId, getAgentIdFromRequest(req));
  const existing = db.prepare('SELECT id FROM memories WHERE id = ? AND user_id = ? AND agent_id = ?').get(req.params.id, req.session.userId, agentId);
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
  const agentId = resolveAgentId(req.session.userId, getAgentIdFromRequest(req));
  const existing = db.prepare('SELECT id FROM memories WHERE id = ? AND user_id = ? AND agent_id = ?').get(req.params.id, req.session.userId, agentId);
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
    const agentId = resolveAgentId(req.session.userId, getAgentIdFromRequest(req));
    const ownedIds = findOwnedMemoryIds(db, req.session.userId, agentId, ids);
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
    const agentId = resolveAgentId(req.session.userId, getAgentIdFromRequest(req));
    const ownedIds = findOwnedMemoryIds(db, req.session.userId, agentId, ids);
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
  const agentId = resolveAgentId(userId, getAgentIdFromRequest(req));
  const { query, limit = 8 } = req.body;
  if (!query) return res.status(400).json({ error: 'query is required' });
  try {
    const results = await mm.recallMemory(userId, query, parseInt(limit), { agentId });
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
  const agentId = resolveAgentId(userId, getAgentIdFromRequest(req));
  const coreMemory = { ...(mm.getCoreMemory(userId, { agentId }) || {}) };
  delete coreMemory.active_context;
  res.json(coreMemory);
});

router.put('/core/:key', (req, res) => {
  const mm = req.app.locals.memoryManager;
  const userId = req.session.userId;
  const agentId = resolveAgentId(userId, getAgentIdFromRequest(req));
  const { value } = req.body;
  if (value === undefined) return res.status(400).json({ error: 'value is required' });
  if (req.params.key === 'active_context') {
    return res.status(400).json({ error: 'active_context is no longer a supported core memory key' });
  }
  mm.updateCore(userId, req.params.key, value, { agentId });
  res.json({ success: true });
});

router.delete('/core/:key', (req, res) => {
  const mm = req.app.locals.memoryManager;
  const userId = req.session.userId;
  const agentId = resolveAgentId(userId, getAgentIdFromRequest(req));
  if (req.params.key === 'active_context') {
    return res.status(400).json({ error: 'active_context is no longer a supported core memory key' });
  }
  mm.deleteCore(userId, req.params.key, { agentId });
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

router.put('/api-keys/:service', apiKeyMutationLimiter, (req, res) => {
  req.app.locals.memoryManager.setApiKey(req.params.service, req.body.key, req.session.userId);
  res.json({ success: true });
});

router.delete('/api-keys/:service', apiKeyMutationLimiter, (req, res) => {
  req.app.locals.memoryManager.deleteApiKey(req.params.service, req.session.userId);
  res.json({ success: true });
});

// ─────────────────────────────────────────────────────────────────────────────
// Conversation History
// ─────────────────────────────────────────────────────────────────────────────

router.get('/conversations', (req, res) => {
  const mm = req.app.locals.memoryManager;
  const agentId = resolveAgentId(req.session.userId, getAgentIdFromRequest(req));
  const conversations = mm.getRecentConversations(req.session.userId, parseInt(req.query.limit) || 20, { agentId });
  res.json(conversations);
});

router.post('/conversations/search', (req, res) => {
  const mm = req.app.locals.memoryManager;
  const agentId = resolveAgentId(req.session.userId, getAgentIdFromRequest(req));
  const results = mm.searchConversations(req.session.userId, req.body.query, {
    sessions: parseInt(req.body.limit) || 8,
    agentId
  });
  res.json(results);
});

module.exports = router;
