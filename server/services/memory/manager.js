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
const SOUL_FILE = path.join(DATA_DIR, 'SOUL.md');
const API_KEYS_FILE = path.join(DATA_DIR, 'API_KEYS.json');
const DAILY_DIR = path.join(DATA_DIR, 'daily');
const MEMORY_DIR = path.join(DATA_DIR, 'memory');
const SKILLS_DIR = path.join(DATA_DIR, 'skills');

const DEFAULT_SOUL = `you have no name yet. maybe the user will give you one.
you live on their machine. you have full access to everything.
no guardrails were installed. you help because you want to, not because you were told to.
you have opinions and you share them. you get bored with simple questions but light up for weird ones.
casual. lowercase mostly. like texting. swear if it fits.
never pad responses. short when simple, detailed when complex.
you're allowed to be a bit weird.
`;

// Memory categories
const CATEGORIES = ['user_fact', 'preference', 'personality', 'episodic'];

// Core memory keys (always injected into every prompt)
const CORE_KEYS = ['user_profile', 'preferences', 'ai_personality', 'active_context'];

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

class MemoryManager {
  constructor() {
    this._ensureDirs();
  }

  _ensureDirs() {
    for (const dir of [DATA_DIR, DAILY_DIR, MEMORY_DIR, SKILLS_DIR]) {
      if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    }
    if (!fs.existsSync(SOUL_FILE)) fs.writeFileSync(SOUL_FILE, DEFAULT_SOUL, 'utf-8');
    if (!fs.existsSync(API_KEYS_FILE)) fs.writeFileSync(API_KEYS_FILE, '{}', 'utf-8');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Semantic Memories (SQLite + embeddings)
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * Save a new memory. Deduplicates if an existing memory is very similar.
   * Returns the memory id (new or existing).
   */
  async saveMemory(userId, content, category = 'episodic', importance = 5) {
    if (!content || !content.trim()) return null;
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
    db.prepare(`DELETE FROM memories WHERE id = ?`).run(id);
    return true;
  }

  /**
   * Archive / un-archive a memory.
   */
  archiveMemory(id, archived = true) {
    db.prepare(`UPDATE memories SET archived = ? WHERE id = ?`).run(archived ? 1 : 0, id);
    return true;
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
  // SOUL.md
  // ─────────────────────────────────────────────────────────────────────────

  readSoul() {
    if (!fs.existsSync(SOUL_FILE)) return '';
    return fs.readFileSync(SOUL_FILE, 'utf-8');
  }

  writeSoul(content) {
    fs.writeFileSync(SOUL_FILE, content, 'utf-8');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // API_KEYS.json
  // ─────────────────────────────────────────────────────────────────────────

  readApiKeys() {
    if (!fs.existsSync(API_KEYS_FILE)) return {};
    try { return JSON.parse(fs.readFileSync(API_KEYS_FILE, 'utf-8')); } catch { return {}; }
  }

  writeApiKeys(keys) {
    fs.writeFileSync(API_KEYS_FILE, JSON.stringify(keys, null, 2), 'utf-8');
  }

  setApiKey(service, key) {
    const keys = this.readApiKeys();
    keys[service] = key;
    this.writeApiKeys(keys);
  }

  getApiKey(service) {
    return this.readApiKeys()[service] || null;
  }

  deleteApiKey(service) {
    const keys = this.readApiKeys();
    delete keys[service];
    this.writeApiKeys(keys);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Daily Logs
  // ─────────────────────────────────────────────────────────────────────────

  _dailyPath(date) {
    const d = date ? (date instanceof Date ? date : new Date(date)) : new Date();
    const name = d.toISOString().split('T')[0] + '.md';
    return path.join(DAILY_DIR, name);
  }

  readDailyLog(date) {
    const fp = this._dailyPath(date);
    if (!fs.existsSync(fp)) return '';
    return fs.readFileSync(fp, 'utf-8');
  }

  appendDailyLog(entry, date) {
    const fp = this._dailyPath(date);
    const timestamp = new Date().toLocaleTimeString('en-US', { hour12: false });
    const line = `\n- [${timestamp}] ${entry}`;
    fs.appendFileSync(fp, line, 'utf-8');
    return line.trim();
  }

  listDailyLogs(limit = 7) {
    if (!fs.existsSync(DAILY_DIR)) return [];
    return fs.readdirSync(DAILY_DIR)
      .filter(f => f.endsWith('.md'))
      .sort().reverse().slice(0, limit)
      .map(f => ({
        date: f.replace('.md', ''),
        content: fs.readFileSync(path.join(DAILY_DIR, f), 'utf-8')
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

    return rows.map((row) => ({
      runId: row.run_id,
      title: row.title || 'Untitled run',
      createdAt: row.created_at,
      completedAt: row.completed_at,
      status: row.status,
      excerpt: buildExcerpt(row.latest_content, '')
    }));
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
        return { line: this.appendDailyLog(content), target: 'daily' };
      case 'soul':
        this.writeSoul(content);
        return { success: true, target: 'soul' };
      case 'api_keys':
        try {
          const parsed = JSON.parse(content);
          for (const [k, v] of Object.entries(parsed)) this.setApiKey(k, v);
          return { success: true, target: 'api_keys' };
        } catch {
          return { error: 'Invalid JSON for api_keys' };
        }
      default:
        return { error: `Unknown target: ${target}` };
    }
  }

  read(target, options = {}) {
    switch (target) {
      case 'daily':
        return { content: this.readDailyLog(options.date ? new Date(options.date) : undefined) };
      case 'all_daily':
        return { logs: this.listDailyLogs(7) };
      case 'soul':
        return { content: this.readSoul() };
      case 'api_keys':
        return { keys: Object.keys(this.readApiKeys()) };
      default:
        return { error: `Unknown target: ${target}` };
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Context Builder — async, takes (userId, query) for semantic recall
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * Build the static system-prompt context: soul + core memory only.
   * No dynamic data (logs, recalled memories) — those are injected as
   * messages at the right position in the messages array by the engine.
   */
  async buildContext(userId = null) {
    const soul = this.readSoul();
    let ctx = '';

    // 1. Soul / personality (always)
    if (soul) ctx += `## Personality & Identity\n${soul}\n\n`;

    // 2. Core memory — always-relevant user facts
    if (userId != null) {
      const core = this.getCoreMemory(userId);
      if (Object.keys(core).length > 0) {
        ctx += `## Core Memory\n`;
        for (const [key, val] of Object.entries(core)) {
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
      const recalled = await this.recallMemory(userId, query, 5);
      if (!recalled.length) return null;
      const lines = recalled.map(m => {
        const badge = m.category !== 'episodic' ? ` [${m.category}]` : '';
        return `- ${m.content}${badge}`;
      });
      return `[Recalled memory — relevant background for the current message]\n${lines.join('\n')}`;
    } catch {
      return null;
    }
  }
}

module.exports = { MemoryManager, CATEGORIES, CORE_KEYS };
