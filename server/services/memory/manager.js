const fs = require('fs');
const path = require('path');
const db = require('../../db/database');

const DATA_DIR = path.join(__dirname, '../../../agent-data');
const MEMORY_FILE = path.join(DATA_DIR, 'MEMORY.md');
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

class MemoryManager {
  constructor() {
    this._ensureDirs();
  }

  _ensureDirs() {
    for (const dir of [DATA_DIR, DAILY_DIR, MEMORY_DIR, SKILLS_DIR]) {
      if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    }
    // Auto-create files with defaults if missing
    if (!fs.existsSync(SOUL_FILE))     fs.writeFileSync(SOUL_FILE, DEFAULT_SOUL, 'utf-8');
    if (!fs.existsSync(MEMORY_FILE))   fs.writeFileSync(MEMORY_FILE, '', 'utf-8');
    if (!fs.existsSync(API_KEYS_FILE)) fs.writeFileSync(API_KEYS_FILE, '{}', 'utf-8');
  }

  // ── MEMORY.md ──

  readMemory() {
    if (!fs.existsSync(MEMORY_FILE)) return '';
    return fs.readFileSync(MEMORY_FILE, 'utf-8');
  }

  writeMemory(content) {
    fs.writeFileSync(MEMORY_FILE, content, 'utf-8');
  }

  appendMemory(entry) {
    const timestamp = new Date().toISOString();
    const line = `\n- [${timestamp}] ${entry}`;
    fs.appendFileSync(MEMORY_FILE, line, 'utf-8');
    return line.trim();
  }

  searchMemory(query) {
    const content = this.readMemory();
    if (!content) return [];

    const lines = content.split('\n').filter(l => l.trim());
    const q = query.toLowerCase();
    return lines.filter(l => l.toLowerCase().includes(q));
  }

  deleteMemoryLine(lineIndex) {
    const content = this.readMemory();
    const lines = content.split('\n');
    if (lineIndex >= 0 && lineIndex < lines.length) {
      lines.splice(lineIndex, 1);
      this.writeMemory(lines.join('\n'));
      return true;
    }
    return false;
  }

  // ── SOUL.md ──

  readSoul() {
    if (!fs.existsSync(SOUL_FILE)) return '';
    return fs.readFileSync(SOUL_FILE, 'utf-8');
  }

  writeSoul(content) {
    fs.writeFileSync(SOUL_FILE, content, 'utf-8');
  }

  // ── API_KEYS.json ──

  readApiKeys() {
    if (!fs.existsSync(API_KEYS_FILE)) return {};
    try {
      return JSON.parse(fs.readFileSync(API_KEYS_FILE, 'utf-8'));
    } catch {
      return {};
    }
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
    const keys = this.readApiKeys();
    return keys[service] || null;
  }

  deleteApiKey(service) {
    const keys = this.readApiKeys();
    delete keys[service];
    this.writeApiKeys(keys);
  }

  // ── Daily Logs ──

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
    const files = fs.readdirSync(DAILY_DIR)
      .filter(f => f.endsWith('.md'))
      .sort()
      .reverse()
      .slice(0, limit);

    return files.map(f => {
      const content = fs.readFileSync(path.join(DAILY_DIR, f), 'utf-8');
      return { date: f.replace('.md', ''), content };
    });
  }

  // ── Conversation History (DB-backed) ──

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
      WHERE ch.user_id = ?
      ORDER BY ch.created_at DESC LIMIT ?
    `).all(userId, limit);
  }

  searchConversations(userId, query) {
    return db.prepare(`
      SELECT ch.*, ar.task FROM conversation_history ch
      JOIN agent_runs ar ON ch.agent_run_id = ar.id
      WHERE ch.user_id = ? AND ch.content LIKE ?
      ORDER BY ch.created_at DESC LIMIT 50
    `).all(userId, `%${query}%`);
  }

  // ── Generic write/read for engine.js ──

  write(target, content, mode = 'append') {
    switch (target) {
      case 'memory':
        if (mode === 'replace') { this.writeMemory(content); return { success: true, target: 'memory' }; }
        return { line: this.appendMemory(content), target: 'memory' };
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
      case 'memory': {
        const content = this.readMemory();
        if (options.search) return { results: this.searchMemory(options.search) };
        return { content };
      }
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

  // ── Context Builder ──

  buildContext() {
    const soul = this.readSoul();
    const memory = this.readMemory();
    const todayLog = this.readDailyLog();

    let ctx = '';
    if (soul) ctx += `## Personality & Identity\n${soul}\n\n`;
    if (memory) ctx += `## Long-term Memory\n${memory}\n\n`;
    if (todayLog) ctx += `## Today's Activity Log\n${todayLog}\n\n`;

    return ctx;
  }
}

module.exports = { MemoryManager };
