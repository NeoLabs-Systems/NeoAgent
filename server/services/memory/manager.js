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

const DATA_DIR = path.join(__dirname, '../../../agent-data');
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

class MemoryManager {
  constructor() {
    this._ensureDirs();
  }

  _ensureDirs() {
    for (const dir of [DATA_DIR, DAILY_DIR, MEMORY_DIR, SKILLS_DIR]) {
      if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    }
    if (!fs.existsSync(SOUL_FILE))     fs.writeFileSync(SOUL_FILE, DEFAULT_SOUL, 'utf-8');
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

    const embedding = await getEmbedding(content);

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

    const queryVec = await getEmbedding(query);

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
      .filter(m => m.score > 0.15)
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

    const newContent   = content   ?? mem.content;
    const newImportance = importance != null ? Math.max(1, Math.min(10, Number(importance))) : mem.importance;
    const newCategory  = (category && CATEGORIES.includes(category)) ? category : mem.category;

    let newEmbed = mem.embedding;
    if (content && content !== mem.content) {
      const vec = await getEmbedding(newContent);
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
    return db.prepare(`
      SELECT ch.*, ar.task FROM conversation_history ch
      JOIN agent_runs ar ON ch.agent_run_id = ar.id
      WHERE ch.user_id = ? ORDER BY ch.created_at DESC LIMIT ?
    `).all(userId, limit);
  }

  searchConversations(userId, query) {
    return db.prepare(`
      SELECT ch.*, ar.task FROM conversation_history ch
      JOIN agent_runs ar ON ch.agent_run_id = ar.id
      WHERE ch.user_id = ? AND ch.content LIKE ? ORDER BY ch.created_at DESC LIMIT 50
    `).all(userId, `%${query}%`);
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

  async buildContext(userId = null, query = null) {
    const soul = this.readSoul();
    const todayLog = this.readDailyLog();

    let ctx = '';

    // 1. Soul (always)
    if (soul) ctx += `## Personality & Identity\n${soul}\n\n`;

    // 2. Core memory (always — critical facts the agent should always know)
    if (userId != null) {
      const core = this.getCoreMemory(userId);
      if (Object.keys(core).length > 0) {
        ctx += `## Core Memory (always remember)\n`;
        for (const [key, val] of Object.entries(core)) {
          const display = typeof val === 'object' ? JSON.stringify(val, null, 2) : val;
          ctx += `**${key}**: ${display}\n`;
        }
        ctx += '\n';
      }
    }

    // 3. Semantically recalled memories (relevant to current query)
    if (userId != null && query) {
      try {
        const recalled = await this.recallMemory(userId, query, 6);
        if (recalled.length > 0) {
          ctx += `## Relevant Memories\n`;
          for (const mem of recalled) {
            const badge = mem.category !== 'episodic' ? ` [${mem.category}]` : '';
            ctx += `- ${mem.content}${badge}\n`;
          }
          ctx += '\n';
        }
      } catch {
        // Silently skip if recall fails
      }
    }

    // 4. Today's activity log (always)
    if (todayLog) ctx += `## Today's Activity Log\n${todayLog}\n\n`;

    return ctx;
  }
}

module.exports = { MemoryManager, CATEGORIES, CORE_KEYS };
