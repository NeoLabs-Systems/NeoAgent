const fs = require('fs');
const path = require('path');
const { v4: uuidv4 } = require('uuid');
const db = require('../../db/database');
const {
  getEmbedding,
  cosineSimilarity,
  serializeEmbedding,
  deserializeEmbedding,
  keywordSimilarity
} = require('./embeddings');
const { getMemoryStorageDecision } = require('./policy');
const { AGENT_DATA_DIR } = require('../../../runtime/paths');

async function getActiveProvider(userId) {
  try {
    const { getSupportedModels } = require('../ai/models');
    const models = await getSupportedModels(userId);
    const rows = db.prepare('SELECT key, value FROM user_settings WHERE user_id = ? AND key IN (?, ?)')
      .all(userId || 1, 'default_chat_model', 'enabled_models');

    let defaultChatModel = null;
    let enabledIds = null;
    for (const row of rows) {
      try {
        const v = JSON.parse(row.value);
        if (row.key === 'default_chat_model') defaultChatModel = v;
        if (row.key === 'enabled_models') enabledIds = v;
      } catch { }
    }

    const modelId = defaultChatModel && defaultChatModel !== 'auto'
      ? defaultChatModel
      : (Array.isArray(enabledIds) && enabledIds.length > 0 ? enabledIds[0] : null);

    if (modelId) {
      const def = models.find(m => m.id === modelId && m.available !== false);
      if (def) return def.provider;
    }
  } catch { }
  return null;
}

const DATA_DIR = AGENT_DATA_DIR;
const SHARED_API_KEYS_FILE = path.join(DATA_DIR, 'API_KEYS.json');
const SHARED_DAILY_DIR = path.join(DATA_DIR, 'daily');
const MEMORY_DIR = path.join(DATA_DIR, 'memory');
const SKILLS_DIR = path.join(DATA_DIR, 'skills');
const USERS_DIR = path.join(DATA_DIR, 'users');

// Memory categories
const CATEGORIES = ['user_fact', 'preference', 'personality', 'episodic'];

// Core memory keys (always injected into every prompt)
const CORE_KEYS = ['user_profile', 'preferences', 'ai_personality'];

function buildFtsQuery(query) {
  const tokens = String(query || '')
    .match(/[\p{L}\p{N}_-]{2,}/gu) || [];
  if (!tokens.length) return null;
  return tokens.map((token) => `${token.replace(/"/g, '')}*`).join(' AND ');
}

function stripHighlight(text) {
  return String(text || '').replace(/<\/?mark>/g, '');
}

function buildExcerpt(text, query) {
  const raw = stripHighlight(text);
  const needle = String(query || '').trim().toLowerCase();
  if (!raw) return '';
  if (!needle) return raw.slice(0, 220);

  const pos = raw.toLowerCase().indexOf(needle);
  if (pos === -1) return raw.slice(0, 220);

  const start = Math.max(0, pos - 80);
  const end = Math.min(raw.length, pos + needle.length + 140);
  const prefix = start > 0 ? '...' : '';
  const suffix = end < raw.length ? '...' : '';
  return `${prefix}${raw.slice(start, end)}${suffix}`;
}

function tokenizeRecallQuery(query) {
  return (String(query || '').toLowerCase().match(/[\p{L}\p{N}_-]{3,}/gu) || [])
    .slice(0, 12);
}

function scoreSchedulerRunMatch(queryTokens, title, finalResponse) {
  if (!queryTokens.length) return 0;
  const haystack = `${String(title || '')} ${String(finalResponse || '')}`.toLowerCase();
  let score = 0;
  for (const token of queryTokens) {
    if (haystack.includes(token)) score += 1;
  }
  return score;
}

class MemoryManager {
  constructor() {
    this._ensureDirs();
  }

  _ensureDirs() {
    for (const dir of [DATA_DIR, USERS_DIR, SHARED_DAILY_DIR, MEMORY_DIR, SKILLS_DIR]) {
      if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    }
    if (!fs.existsSync(SHARED_API_KEYS_FILE)) fs.writeFileSync(SHARED_API_KEYS_FILE, '{}', 'utf-8');
  }

  _userDir(userId) {
    return path.join(USERS_DIR, String(userId || 'shared'));
  }

  _ensureUserDirs(userId) {
    const userDir = this._userDir(userId);
    const dailyDir = path.join(userDir, 'daily');
    fs.mkdirSync(userDir, { recursive: true });
    fs.mkdirSync(dailyDir, { recursive: true });
    return { userDir, dailyDir };
  }

  _userApiKeysPath(userId) {
    if (userId == null) return SHARED_API_KEYS_FILE;
    const { userDir } = this._ensureUserDirs(userId);
    return path.join(userDir, 'API_KEYS.json');
  }

  _userDailyDir(userId) {
    if (userId == null) return SHARED_DAILY_DIR;
    return this._ensureUserDirs(userId).dailyDir;
  }

  getAssistantBehaviorNotes(userId) {
    if (userId == null) return '';
    const row = db.prepare('SELECT value FROM user_settings WHERE user_id = ? AND key = ?')
      .get(userId, 'assistant_behavior_notes');
    return typeof row?.value === 'string' ? row.value : '';
  }

  setAssistantBehaviorNotes(userId, content) {
    if (userId == null) return;
    db.prepare(
      `INSERT INTO user_settings (user_id, key, value)
       VALUES (?, ?, ?)
       ON CONFLICT(user_id, key) DO UPDATE SET value = excluded.value`
    ).run(userId, 'assistant_behavior_notes', String(content || ''));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Semantic Memories (SQLite + embeddings)
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * Save a new memory. Deduplicates if an existing memory is very similar.
   * Returns the memory id (new or existing).
   */
  async saveMemory(userId, content, category = 'episodic', importance = 5) {
    const decision = getMemoryStorageDecision(content);
    if (!decision.allow) return null;
    content = decision.normalized;
    category = CATEGORIES.includes(category) ? category : 'episodic';
    importance = Math.max(1, Math.min(10, Number(importance) || 5));

    const embedding = await getEmbedding(content, await getActiveProvider(userId));

    // Dedup check: compare against existing non-archived memories for this user
    const existing = db.prepare(
      `SELECT id, content, embedding FROM memories WHERE user_id = ? AND archived = 0`
    ).all(userId);

    for (const mem of existing) {
      let sim = 0;
      if (embedding && mem.embedding) {
        const memVec = deserializeEmbedding(mem.embedding);
        if (memVec) sim = cosineSimilarity(embedding, memVec);
      } else {
        sim = keywordSimilarity(content, mem.content);
      }

      if (sim > 0.85) {
        // Very similar — update in place if new content is longer, otherwise skip
        if (content.length > mem.content.length) {
          db.prepare(
            `UPDATE memories SET content = ?, importance = MAX(importance, ?), embedding = ?,
             updated_at = datetime('now') WHERE id = ?`
          ).run(content, importance, embedding ? serializeEmbedding(embedding) : mem.embedding, mem.id);
          return mem.id;
        }
        return mem.id; // already covered, skip
      }
    }

    // Save new
    const id = uuidv4();
    db.prepare(
      `INSERT INTO memories (id, user_id, category, content, importance, embedding)
       VALUES (?, ?, ?, ?, ?, ?)`
    ).run(id, userId, category, content, importance, embedding ? serializeEmbedding(embedding) : null);

    return id;
  }

  /**
   * Semantic search over memories. Returns top-K most relevant.
   * Falls back to keyword search if embeddings unavailable.
   */
  async recallMemory(userId, query, topK = 6) {
    if (!query || !query.trim()) return [];

    const all = db.prepare(
      `SELECT id, category, content, importance, embedding, access_count, created_at
       FROM memories WHERE user_id = ? AND archived = 0 ORDER BY updated_at DESC`
    ).all(userId);

    if (!all.length) return [];

    const queryVec = await getEmbedding(query, await getActiveProvider(userId));

    const scored = all.map(mem => {
      let score = 0;
      if (queryVec && mem.embedding) {
        const memVec = deserializeEmbedding(mem.embedding);
        if (memVec) {
          score = cosineSimilarity(queryVec, memVec);
          // Boost by importance (1–10 → up to +50% weight)
          score = score * (0.5 + mem.importance / 20);
        }
      }
      if (!score) {
        // Keyword fallback
        score = keywordSimilarity(query, mem.content) * 0.7;
      }
      return { ...mem, score };
    });

    const results = scored
      .filter(m => m.score > 0.45)
      .sort((a, b) => b.score - a.score)
      .slice(0, topK);

    // Update access counts
    if (results.length) {
      const ids = results.map(r => `'${r.id}'`).join(',');
      db.prepare(`UPDATE memories SET access_count = access_count + 1 WHERE id IN (${ids})`).run();
    }

    return results.map(({ id, category, content, importance, created_at }) => ({
      id, category, content, importance, created_at
    }));
  }

  /**
   * List memories (for UI). Supports category filter + pagination.
   */
  listMemories(userId, { category, limit = 50, offset = 0, includeArchived = false } = {}) {
    let sql = `SELECT id, category, content, importance, access_count, archived, created_at, updated_at
               FROM memories WHERE user_id = ? AND archived = ?`;
    const params = [userId, includeArchived ? 1 : 0];
    if (category && CATEGORIES.includes(category)) {
      sql += ` AND category = ?`;
      params.push(category);
    }
    sql += ` ORDER BY importance DESC, updated_at DESC LIMIT ? OFFSET ?`;
    params.push(limit, offset);
    return db.prepare(sql).all(...params);
  }

  /**
   * Update a memory's content and/or importance.
   */
  async updateMemory(id, { content, importance, category }) {
    const mem = db.prepare(`SELECT * FROM memories WHERE id = ?`).get(id);
    if (!mem) return null;

    const newContent = content ?? mem.content;
    const newImportance = importance != null ? Math.max(1, Math.min(10, Number(importance))) : mem.importance;
    const newCategory = (category && CATEGORIES.includes(category)) ? category : mem.category;

    let newEmbed = mem.embedding;
    if (content && content !== mem.content) {
      const vec = await getEmbedding(newContent, await getActiveProvider(null));
      newEmbed = vec ? serializeEmbedding(vec) : mem.embedding;
    }

    db.prepare(
      `UPDATE memories SET content = ?, importance = ?, category = ?, embedding = ?,
       updated_at = datetime('now') WHERE id = ?`
    ).run(newContent, newImportance, newCategory, newEmbed, id);

    return db.prepare(`SELECT id, category, content, importance, created_at, updated_at FROM memories WHERE id = ?`).get(id);
  }

  /**
   * Delete a memory permanently.
   */
  deleteMemory(id) {
    return this.deleteMemories([id]) > 0;
  }

  deleteMemories(ids) {
    const uniqueIds = [...new Set(
      (Array.isArray(ids) ? ids : [])
        .map((id) => String(id || '').trim())
        .filter(Boolean)
    )];
    if (!uniqueIds.length) return 0;
    const placeholders = uniqueIds.map(() => '?').join(', ');
    const result = db.prepare(`DELETE FROM memories WHERE id IN (${placeholders})`).run(...uniqueIds);
    return result.changes || 0;
  }

  /**
   * Archive / un-archive a memory.
   */
  archiveMemory(id, archived = true) {
    return this.archiveMemories([id], archived) > 0;
  }

  archiveMemories(ids, archived = true) {
    const uniqueIds = [...new Set(
      (Array.isArray(ids) ? ids : [])
        .map((id) => String(id || '').trim())
        .filter(Boolean)
    )];
    if (!uniqueIds.length) return 0;
    const placeholders = uniqueIds.map(() => '?').join(', ');
    const result = db.prepare(
      `UPDATE memories SET archived = ? WHERE id IN (${placeholders})`
    ).run(archived ? 1 : 0, ...uniqueIds);
    return result.changes || 0;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Core Memory (always-injected key-value pairs)
  // ─────────────────────────────────────────────────────────────────────────

  getCoreMemory(userId) {
    const rows = db.prepare(`SELECT key, value FROM core_memory WHERE user_id = ?`).all(userId);
    const result = {};
    for (const row of rows) {
      try { result[row.key] = JSON.parse(row.value); } catch { result[row.key] = row.value; }
    }
    return result;
  }

  updateCore(userId, key, value) {
    const strVal = typeof value === 'object' ? JSON.stringify(value) : String(value);
    db.prepare(
      `INSERT INTO core_memory (user_id, key, value, updated_at)
       VALUES (?, ?, ?, datetime('now'))
       ON CONFLICT(user_id, key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at`
    ).run(userId, key, strVal);
  }

  deleteCore(userId, key) {
    db.prepare(`DELETE FROM core_memory WHERE user_id = ? AND key = ?`).run(userId, key);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Conversation State
  // ─────────────────────────────────────────────────────────────────────────

  ensureConversation(userId, {
    platform = 'web',
    platformChatId = null,
    title = 'Conversation',
    sessionKey = null,
  } = {}) {
    const existing = db.prepare(
      'SELECT id FROM conversations WHERE user_id = ? AND platform = ? AND COALESCE(platform_chat_id, \'\') = COALESCE(?, \'\')'
    ).get(userId, platform, platformChatId);

    if (existing?.id) return existing.id;

    const conversationId = uuidv4();
    let migratedSummary = '';
    if (platform === 'web') {
      const legacySummary = db.prepare(
        'SELECT value FROM user_settings WHERE user_id = ? AND key = ?'
      ).get(userId, 'web_chat_summary');
      migratedSummary = typeof legacySummary?.value === 'string'
        ? (() => {
            try { return JSON.parse(legacySummary.value); } catch { return legacySummary.value; }
          })()
        : '';
    }

    db.prepare(
      `INSERT INTO conversations (id, user_id, platform, platform_chat_id, title, session_key, summary, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, datetime('now'))`
    ).run(
      conversationId,
      userId,
      platform,
      platformChatId,
      title,
      sessionKey,
      migratedSummary || null
    );

    return conversationId;
  }

  getDefaultWebConversationId(userId) {
    return this.ensureConversation(userId, {
      platform: 'web',
      platformChatId: 'primary',
      title: 'Web chat',
      sessionKey: 'web:primary',
    });
  }

  getConversationState(conversationId) {
    const row = db.prepare(
      'SELECT working_state_json, last_verified_facts_json FROM conversations WHERE id = ?'
    ).get(conversationId);

    let workingState = null;
    let lastVerifiedFacts = [];
    try {
      workingState = row?.working_state_json ? JSON.parse(row.working_state_json) : null;
    } catch {
      workingState = null;
    }
    try {
      lastVerifiedFacts = row?.last_verified_facts_json ? JSON.parse(row.last_verified_facts_json) : [];
    } catch {
      lastVerifiedFacts = [];
    }

    return {
      ...(workingState && typeof workingState === 'object' ? workingState : {}),
      last_verified_facts: Array.isArray(lastVerifiedFacts) ? lastVerifiedFacts : [],
    };
  }

  updateConversationState(conversationId, state = {}) {
    const payload = state && typeof state === 'object' && !Array.isArray(state) ? state : {};
    const verifiedFacts = Array.isArray(payload.last_verified_facts) ? payload.last_verified_facts : [];

    db.prepare(
      `UPDATE conversations
       SET working_state_json = ?, last_verified_facts_json = ?, updated_at = datetime('now')
       WHERE id = ?`
    ).run(
      JSON.stringify(payload),
      JSON.stringify(verifiedFacts),
      conversationId
    );
  }

  buildConversationStateMessage(conversationId) {
    if (!conversationId) return null;
    const state = this.getConversationState(conversationId);
    if (!state || Object.keys(state).length === 0) return null;

    const sections = [];
    if (state.summary) sections.push(`Summary: ${state.summary}`);
    if (Array.isArray(state.open_commitments) && state.open_commitments.length) {
      sections.push(`Open commitments:\n- ${state.open_commitments.join('\n- ')}`);
    }
    if (Array.isArray(state.unresolved_questions) && state.unresolved_questions.length) {
      sections.push(`Unresolved questions:\n- ${state.unresolved_questions.join('\n- ')}`);
    }
    if (Array.isArray(state.referenced_entities) && state.referenced_entities.length) {
      sections.push(`Referenced entities: ${state.referenced_entities.join(', ')}`);
    }
    if (Array.isArray(state.last_verified_facts) && state.last_verified_facts.length) {
      sections.push(`Last verified facts:\n- ${state.last_verified_facts.join('\n- ')}`);
    }

    if (sections.length === 0) return null;
    return `[Thread working state]\n${sections.join('\n\n')}`;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // API_KEYS.json
  // ─────────────────────────────────────────────────────────────────────────

  readApiKeys(userId = null) {
    const filePath = this._userApiKeysPath(userId);
    if (!fs.existsSync(filePath)) {
      if (userId != null && fs.existsSync(SHARED_API_KEYS_FILE)) {
        fs.copyFileSync(SHARED_API_KEYS_FILE, filePath);
      } else {
        return {};
      }
    }
    try { return JSON.parse(fs.readFileSync(filePath, 'utf-8')); } catch { return {}; }
  }

  writeApiKeys(keys, userId = null) {
    fs.writeFileSync(this._userApiKeysPath(userId), JSON.stringify(keys, null, 2), 'utf-8');
  }

  setApiKey(service, key, userId = null) {
    const keys = this.readApiKeys(userId);
    keys[service] = key;
    this.writeApiKeys(keys, userId);
  }

  getApiKey(service, userId = null) {
    return this.readApiKeys(userId)[service] || null;
  }

  deleteApiKey(service, userId = null) {
    const keys = this.readApiKeys(userId);
    delete keys[service];
    this.writeApiKeys(keys, userId);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Daily Logs
  // ─────────────────────────────────────────────────────────────────────────

  _dailyPath(date, userId = null) {
    const d = date ? (date instanceof Date ? date : new Date(date)) : new Date();
    const name = d.toISOString().split('T')[0] + '.md';
    return path.join(this._userDailyDir(userId), name);
  }

  readDailyLog(date, userId = null) {
    const fp = this._dailyPath(date, userId);
    if (!fs.existsSync(fp)) return '';
    return fs.readFileSync(fp, 'utf-8');
  }

  appendDailyLog(entry, date, userId = null) {
    const fp = this._dailyPath(date, userId);
    const timestamp = new Date().toLocaleTimeString('en-US', { hour12: false });
    const line = `\n- [${timestamp}] ${entry}`;
    fs.appendFileSync(fp, line, 'utf-8');
    return line.trim();
  }

  listDailyLogs(limit = 7, userId = null) {
    const dailyDir = this._userDailyDir(userId);
    if (userId != null && fs.existsSync(SHARED_DAILY_DIR) && (!fs.existsSync(dailyDir) || fs.readdirSync(dailyDir).length === 0)) {
      for (const entry of fs.readdirSync(SHARED_DAILY_DIR)) {
        if (!entry.endsWith('.md')) continue;
        const dest = path.join(dailyDir, entry);
        if (!fs.existsSync(dest)) {
          fs.copyFileSync(path.join(SHARED_DAILY_DIR, entry), dest);
        }
      }
    }
    if (!fs.existsSync(dailyDir)) return [];
    return fs.readdirSync(dailyDir)
      .filter(f => f.endsWith('.md'))
      .sort().reverse().slice(0, limit)
      .map(f => ({
        date: f.replace('.md', ''),
        content: fs.readFileSync(path.join(dailyDir, f), 'utf-8')
      }));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Conversation History (DB-backed)
  // ─────────────────────────────────────────────────────────────────────────

  saveConversation(userId, agentRunId, role, content, metadata = {}) {
    db.prepare('INSERT INTO conversation_history (user_id, agent_run_id, role, content, metadata) VALUES (?, ?, ?, ?, ?)')
      .run(userId, agentRunId, role, content, JSON.stringify(metadata));
  }

  getConversation(agentRunId, limit = 100) {
    return db.prepare('SELECT * FROM conversation_history WHERE agent_run_id = ? ORDER BY created_at ASC LIMIT ?')
      .all(agentRunId, limit);
  }

  getRecentConversations(userId, limit = 20) {
    const rows = db.prepare(`
      SELECT
        c.id,
        c.title,
        c.platform,
        c.platform_chat_id,
        c.summary,
        c.working_state_json,
        c.updated_at,
        (
          SELECT content
          FROM conversation_messages cm
          WHERE cm.conversation_id = c.id
          ORDER BY cm.created_at DESC, cm.id DESC
          LIMIT 1
        ) AS latest_content
      FROM conversations c
      WHERE c.user_id = ?
      ORDER BY datetime(c.updated_at) DESC
      LIMIT ?
    `).all(userId, limit);

    if (rows.length === 0) {
      const fallback = db.prepare(`
        SELECT
          ar.id AS run_id,
          ar.title,
          ar.created_at,
          ar.completed_at,
          ar.status,
          (
            SELECT content
            FROM conversation_history ch
            WHERE ch.agent_run_id = ar.id
            ORDER BY ch.created_at DESC
            LIMIT 1
          ) AS latest_content
        FROM agent_runs ar
        WHERE ar.user_id = ?
        ORDER BY COALESCE(ar.completed_at, ar.created_at) DESC
        LIMIT ?
      `).all(userId, limit);

      return fallback.map((row) => {
        const summary = buildExcerpt(row.latest_content, '') || 'No summary available.';
        return {
          id: row.run_id,
          title: row.title || 'web conversation',
          platform: 'web',
          platformChatId: null,
          updatedAt: row.completed_at || row.created_at,
          summary,
          preview: summary,
        };
      });
    }

    return rows.map((row) => {
      let workingState = null;
      try {
        workingState = row.working_state_json ? JSON.parse(row.working_state_json) : null;
      } catch {
        workingState = null;
      }

      const summary = row.summary
        || workingState?.summary
        || buildExcerpt(row.latest_content, '');

      return {
        id: row.id,
        title: row.title || `${row.platform || 'chat'} conversation`,
        platform: row.platform || 'web',
        platformChatId: row.platform_chat_id || null,
        updatedAt: row.updated_at,
        summary: summary || 'No summary available.',
        preview: summary || 'No summary available.',
      };
    });
  }

  searchConversations(userId, query, options = {}) {
    const ftsQuery = buildFtsQuery(query);
    const maxHits = Math.max(6, Math.min(Number(options.limit) || 24, 60));
    if (!ftsQuery) return [];

    let webHits = [];
    let messageHits = [];
    try {
      webHits = db.prepare(`
        SELECT
          'web' AS source,
          ch.id AS message_id,
          COALESCE(ch.agent_run_id, 'web:' || ch.id) AS session_id,
          COALESCE(ar.title, 'Web chat') AS title,
          ch.role,
          ch.created_at,
          snippet(conversation_history_fts, 0, '<mark>', '</mark>', ' ... ', 16) AS snippet,
          bm25(conversation_history_fts) AS score
        FROM conversation_history_fts
        JOIN conversation_history ch ON ch.id = conversation_history_fts.rowid
        LEFT JOIN agent_runs ar ON ar.id = ch.agent_run_id
        WHERE conversation_history_fts MATCH ? AND ch.user_id = ?
        ORDER BY score
        LIMIT ?
      `).all(ftsQuery, userId, maxHits);

      messageHits = db.prepare(`
        SELECT
          'message' AS source,
          m.id AS message_id,
          COALESCE(m.run_id, m.platform || ':' || COALESCE(m.platform_chat_id, m.id)) AS session_id,
          COALESCE(ar.title, json_extract(m.metadata, '$.senderName'), m.platform_chat_id, m.platform, 'Message thread') AS title,
          m.role,
          m.created_at,
          m.platform,
          snippet(messages_fts, 0, '<mark>', '</mark>', ' ... ', 16) AS snippet,
          bm25(messages_fts) AS score
        FROM messages_fts
        JOIN messages m ON m.id = messages_fts.rowid
        LEFT JOIN agent_runs ar ON ar.id = m.run_id
        WHERE messages_fts MATCH ? AND m.user_id = ?
        ORDER BY score
        LIMIT ?
      `).all(ftsQuery, userId, maxHits);
    } catch {
      const likeQuery = `%${String(query || '').trim()}%`;
      webHits = db.prepare(`
        SELECT
          'web' AS source,
          ch.id AS message_id,
          COALESCE(ch.agent_run_id, 'web:' || ch.id) AS session_id,
          COALESCE(ar.title, 'Web chat') AS title,
          ch.role,
          ch.created_at,
          ch.content AS snippet,
          0 AS score
        FROM conversation_history ch
        LEFT JOIN agent_runs ar ON ar.id = ch.agent_run_id
        WHERE ch.user_id = ? AND ch.content LIKE ?
        ORDER BY ch.created_at DESC
        LIMIT ?
      `).all(userId, likeQuery, maxHits);

      messageHits = db.prepare(`
        SELECT
          'message' AS source,
          m.id AS message_id,
          COALESCE(m.run_id, m.platform || ':' || COALESCE(m.platform_chat_id, m.id)) AS session_id,
          COALESCE(ar.title, json_extract(m.metadata, '$.senderName'), m.platform_chat_id, m.platform, 'Message thread') AS title,
          m.role,
          m.created_at,
          m.platform,
          m.content AS snippet,
          0 AS score
        FROM messages m
        LEFT JOIN agent_runs ar ON ar.id = m.run_id
        WHERE m.user_id = ? AND m.content LIKE ?
        ORDER BY m.created_at DESC
        LIMIT ?
      `).all(userId, likeQuery, maxHits);
    }

    const grouped = new Map();
    for (const hit of [...webHits, ...messageHits]) {
      const key = `${hit.source}:${hit.session_id}`;
      if (!grouped.has(key)) {
        grouped.set(key, {
          sessionId: hit.session_id,
          source: hit.source,
          title: hit.title || 'Untitled session',
          platform: hit.platform || 'web',
          createdAt: hit.created_at,
          score: Number(hit.score || 0),
          matches: []
        });
      }

      const group = grouped.get(key);
      group.score = Math.min(group.score, Number(hit.score || 0));
      group.createdAt = hit.created_at > group.createdAt ? hit.created_at : group.createdAt;
      if (group.matches.length < 3) {
        group.matches.push({
          role: hit.role,
          createdAt: hit.created_at,
          excerpt: buildExcerpt(hit.snippet, query)
        });
      }
    }

    return Array.from(grouped.values())
      .sort((a, b) => a.score - b.score || String(b.createdAt).localeCompare(String(a.createdAt)))
      .slice(0, Math.max(1, Math.min(Number(options.sessions) || 8, 12)))
      .map((session) => ({
        ...session,
        matchCount: session.matches.length,
        summary: session.matches.map((match) => `${match.role}: ${match.excerpt}`).join('\n')
      }));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Generic write/read (used by engine.js legacy paths)
  // ─────────────────────────────────────────────────────────────────────────

  write(target, content, mode = 'append', userId = null) {
    switch (target) {
      case 'daily':
        return { line: this.appendDailyLog(content, undefined, userId), target: 'daily' };
      case 'api_keys':
        try {
          const parsed = JSON.parse(content);
          for (const [k, v] of Object.entries(parsed)) this.setApiKey(k, v, userId);
          return { success: true, target: 'api_keys' };
        } catch {
          return { error: 'Invalid JSON for api_keys' };
        }
      default:
        return { error: `Unknown target: ${target}` };
    }
  }

  read(target, options = {}) {
    const userId = options.userId ?? null;
    switch (target) {
      case 'daily':
        return { content: this.readDailyLog(options.date ? new Date(options.date) : undefined, userId) };
      case 'all_daily':
        return { logs: this.listDailyLogs(7, userId) };
      case 'api_keys':
        return { keys: Object.keys(this.readApiKeys(userId)) };
      default:
        return { error: `Unknown target: ${target}` };
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Context Builder — async, takes (userId, query) for semantic recall
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * Build the static system-prompt context: assistant behavior notes + core memory.
   * No dynamic data (logs, recalled memories) — those are injected as
   * messages at the right position in the messages array by the engine.
   */
  async buildContext(userId = null) {
    let ctx = '';

    const behaviorNotes = this.getAssistantBehaviorNotes(userId);
    if (behaviorNotes) {
      ctx += `## Assistant Behavior Notes\n`;
      ctx += `These are durable preferences for how the assistant should usually behave. Follow system rules and the active user request first.\n`;
      ctx += `${behaviorNotes}\n\n`;
    }

    // 2. Core memory — always-relevant user facts
    if (userId != null) {
      const core = this.getCoreMemory(userId);
      const filteredCore = Object.fromEntries(
        Object.entries(core).filter(([key]) => key !== 'active_context')
      );
      if (Object.keys(filteredCore).length > 0) {
        ctx += `## Core Memory\n`;
        for (const [key, val] of Object.entries(filteredCore)) {
          const display = typeof val === 'object' ? JSON.stringify(val, null, 2) : val;
          ctx += `**${key}**: ${display}\n`;
        }
        ctx += '\n';
      }
    }

    return ctx;
  }

  /**
   * Returns a recalled-memory block string for a given query,
   * to be injected as a system message in the messages array.
   * Returns null if nothing relevant found.
   */
  async buildRecallMessage(userId, query) {
    if (!userId || !query || !query.trim()) return null;
    try {
      const sections = [];
      const recalled = await this.recallMemory(userId, query, 5);
      if (recalled.length) {
        const memoryLines = recalled.map(m => {
          const badge = m.category !== 'episodic' ? ` [${m.category}]` : '';
          return `- ${m.content}${badge}`;
        });
        sections.push(`Relevant memory:\n${memoryLines.join('\n')}`);
      }

      const queryTokens = tokenizeRecallQuery(query);
      if (queryTokens.length) {
        const recentSchedulerRuns = db.prepare(
          `SELECT title, final_response, completed_at
           FROM agent_runs
           WHERE user_id = ? AND trigger_source = 'scheduler' AND status = 'completed'
           ORDER BY completed_at DESC, created_at DESC
           LIMIT 12`
        ).all(userId);

        const schedulerMatches = recentSchedulerRuns
          .map((run) => ({
            ...run,
            score: scoreSchedulerRunMatch(queryTokens, run.title, run.final_response),
          }))
          .filter((run) => run.score > 0)
          .slice(0, 3);

        if (schedulerMatches.length) {
          const schedulerLines = schedulerMatches.map((run) => {
            const when = run.completed_at ? String(run.completed_at) : 'unknown time';
            const title = String(run.title || 'scheduler task').replace(/\s+/g, ' ').trim();
            const outcome = buildExcerpt(String(run.final_response || ''), query) || String(run.final_response || '').slice(0, 180);
            return `- ${when}: ${title} -> ${outcome || '(no final response stored)'}`;
          });
          sections.push(`Relevant recent scheduler runs:\n${schedulerLines.join('\n')}`);
        }
      }

      if (!sections.length) return null;
      return `[Recalled context — relevant background for the current message]\n${sections.join('\n\n')}`;
    } catch {
      return null;
    }
  }

  readMemory(userId = null) {
    return this.read('all_daily', { userId });
  }

  searchMemory(query, userId = null) {
    return this.recallMemory(userId, query, 6);
  }
}

module.exports = { MemoryManager, CATEGORIES, CORE_KEYS };
