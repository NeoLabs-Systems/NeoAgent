const Database = require('better-sqlite3');
const path = require('path');
const { DATA_DIR, ensureRuntimeDirs } = require('../../runtime/paths');
ensureRuntimeDirs();

const DB_PATH = path.join(DATA_DIR, 'neoagent.db');
const db = new Database(DB_PATH);

db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');
db.pragma('busy_timeout = 5000');

db.exec(`
  CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    email TEXT UNIQUE,
    password TEXT NOT NULL,
    created_at TEXT DEFAULT (datetime('now')),
    last_login TEXT
  );

  CREATE TABLE IF NOT EXISTS user_settings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    key TEXT NOT NULL,
    value TEXT,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE(user_id, key)
  );

  CREATE TABLE IF NOT EXISTS agent_runs (
    id TEXT PRIMARY KEY,
    user_id INTEGER NOT NULL,
    title TEXT,
    status TEXT DEFAULT 'pending',
    trigger_type TEXT DEFAULT 'user',
    trigger_source TEXT,
    model TEXT,
    total_tokens INTEGER DEFAULT 0,
    prompt_metrics TEXT,
    error TEXT,
    final_response TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    completed_at TEXT,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  );

  CREATE TABLE IF NOT EXISTS agent_steps (
    id TEXT PRIMARY KEY,
    run_id TEXT NOT NULL,
    step_index INTEGER DEFAULT 0,
    type TEXT NOT NULL,
    description TEXT,
    status TEXT DEFAULT 'pending',
    tool_name TEXT,
    tool_input TEXT,
    result TEXT,
    error TEXT,
    screenshot_path TEXT,
    tokens_used INTEGER DEFAULT 0,
    started_at TEXT,
    completed_at TEXT,
    FOREIGN KEY (run_id) REFERENCES agent_runs(id) ON DELETE CASCADE
  );

  CREATE TABLE IF NOT EXISTS messages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    run_id TEXT,
    role TEXT NOT NULL,
    content TEXT,
    tool_calls TEXT,
    tool_call_id TEXT,
    platform TEXT DEFAULT 'web',
    platform_msg_id TEXT,
    platform_chat_id TEXT,
    media_path TEXT,
    metadata TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  );

  CREATE TABLE IF NOT EXISTS platform_connections (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    platform TEXT NOT NULL,
    config TEXT DEFAULT '{}',
    status TEXT DEFAULT 'disconnected',
    auth_data_path TEXT,
    last_connected TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE(user_id, platform)
  );

  CREATE TABLE IF NOT EXISTS mcp_servers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    command TEXT NOT NULL,
    config TEXT DEFAULT '{}',
    enabled INTEGER DEFAULT 1,
    status TEXT DEFAULT 'stopped',
    created_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  );

  CREATE TABLE IF NOT EXISTS scheduled_tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    cron_expression TEXT,
    run_at TEXT,
    one_time INTEGER DEFAULT 0,
    task_type TEXT DEFAULT 'agent_prompt',
    task_config TEXT DEFAULT '{}',
    enabled INTEGER DEFAULT 1,
    last_run TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  );

  CREATE TABLE IF NOT EXISTS skills (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL,
    description TEXT,
    file_path TEXT NOT NULL,
    metadata TEXT DEFAULT '{}',
    enabled INTEGER DEFAULT 1,
    auto_created INTEGER DEFAULT 0,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
  );

  CREATE TABLE IF NOT EXISTS conversations (
    id TEXT PRIMARY KEY,
    user_id INTEGER NOT NULL,
    platform TEXT DEFAULT 'web',
    platform_chat_id TEXT,
    title TEXT,
    session_key TEXT,
    model TEXT,
    total_tokens INTEGER DEFAULT 0,
    compaction_count INTEGER DEFAULT 0,
    summary TEXT,
    summary_message_count INTEGER DEFAULT 0,
    last_compaction TEXT,
    last_summary TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  );

  CREATE TABLE IF NOT EXISTS conversation_messages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    conversation_id TEXT NOT NULL,
    role TEXT NOT NULL,
    content TEXT,
    tool_calls TEXT,
    tool_call_id TEXT,
    name TEXT,
    tokens INTEGER DEFAULT 0,
    is_compacted INTEGER DEFAULT 0,
    created_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
  );

  CREATE INDEX IF NOT EXISTS idx_agent_runs_user ON agent_runs(user_id, created_at DESC);
  CREATE INDEX IF NOT EXISTS idx_agent_runs_status ON agent_runs(status);
  CREATE INDEX IF NOT EXISTS idx_agent_steps_run ON agent_steps(run_id, step_index);
  CREATE INDEX IF NOT EXISTS idx_messages_user ON messages(user_id, created_at DESC);
  CREATE INDEX IF NOT EXISTS idx_messages_platform ON messages(platform, platform_chat_id);
  CREATE INDEX IF NOT EXISTS idx_conv_messages ON conversation_messages(conversation_id, created_at);
  CREATE INDEX IF NOT EXISTS idx_conversations_user ON conversations(user_id, updated_at DESC);
  CREATE INDEX IF NOT EXISTS idx_scheduled_tasks_user ON scheduled_tasks(user_id);

  CREATE TABLE IF NOT EXISTS conversation_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    agent_run_id TEXT,
    role TEXT NOT NULL,
    content TEXT,
    metadata TEXT DEFAULT '{}',
    created_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  );

  CREATE INDEX IF NOT EXISTS idx_conv_history_user ON conversation_history(user_id, created_at DESC);
  CREATE INDEX IF NOT EXISTS idx_conv_history_run ON conversation_history(agent_run_id, created_at);

  CREATE TABLE IF NOT EXISTS memories (
    id TEXT PRIMARY KEY,
    user_id INTEGER NOT NULL,
    category TEXT DEFAULT 'episodic',
    content TEXT NOT NULL,
    importance INTEGER DEFAULT 5,
    embedding TEXT,
    access_count INTEGER DEFAULT 0,
    archived INTEGER DEFAULT 0,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  );

  CREATE TABLE IF NOT EXISTS core_memory (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    key TEXT NOT NULL,
    value TEXT,
    updated_at TEXT DEFAULT (datetime('now')),
    UNIQUE(user_id, key)
  );

  CREATE INDEX IF NOT EXISTS idx_memories_user ON memories(user_id, archived, updated_at DESC);
  CREATE INDEX IF NOT EXISTS idx_memories_category ON memories(user_id, category, archived);
  CREATE INDEX IF NOT EXISTS idx_core_memory_user ON core_memory(user_id, key);

  CREATE TABLE IF NOT EXISTS health_sync_runs (
    id TEXT PRIMARY KEY,
    user_id INTEGER NOT NULL,
    source TEXT NOT NULL,
    provider TEXT,
    sync_window_start TEXT,
    sync_window_end TEXT,
    record_count INTEGER DEFAULT 0,
    summary_json TEXT,
    payload_json TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  );

  CREATE TABLE IF NOT EXISTS health_metric_samples (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    sync_run_id TEXT NOT NULL,
    metric_type TEXT NOT NULL,
    record_id TEXT NOT NULL,
    start_time TEXT,
    end_time TEXT,
    recorded_at TEXT,
    numeric_value REAL,
    text_value TEXT,
    unit TEXT,
    source_app_id TEXT,
    source_device TEXT,
    last_modified_time TEXT,
    payload_json TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (sync_run_id) REFERENCES health_sync_runs(id) ON DELETE CASCADE,
    UNIQUE(user_id, metric_type, record_id)
  );

  CREATE INDEX IF NOT EXISTS idx_health_sync_runs_user ON health_sync_runs(user_id, created_at DESC);
  CREATE INDEX IF NOT EXISTS idx_health_metric_samples_user ON health_metric_samples(user_id, metric_type, updated_at DESC);
  CREATE INDEX IF NOT EXISTS idx_health_metric_samples_time ON health_metric_samples(user_id, start_time DESC, end_time DESC);

  CREATE TABLE IF NOT EXISTS recording_sessions (
    id TEXT PRIMARY KEY,
    user_id INTEGER NOT NULL,
    title TEXT,
    platform TEXT DEFAULT 'unknown',
    status TEXT DEFAULT 'recording',
    transcript_text TEXT,
    transcript_language TEXT,
    transcript_model TEXT,
    structured_content_json TEXT,
    started_at TEXT DEFAULT (datetime('now')),
    ended_at TEXT,
    duration_ms INTEGER DEFAULT 0,
    last_error TEXT,
    metadata_json TEXT DEFAULT '{}',
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  );

  CREATE TABLE IF NOT EXISTS wearable_devices (
    id TEXT PRIMARY KEY,
    user_id INTEGER NOT NULL,
    mac_address TEXT,
    protocol TEXT NOT NULL,
    name TEXT NOT NULL,
    status TEXT DEFAULT 'disconnected',
    battery_level INTEGER,
    last_seen_at TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE(user_id, mac_address)
  );

  CREATE TABLE IF NOT EXISTS recording_sources (
    id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    source_key TEXT NOT NULL,
    source_kind TEXT NOT NULL,
    media_kind TEXT NOT NULL,
    mime_type TEXT,
    status TEXT DEFAULT 'recording',
    chunk_count INTEGER DEFAULT 0,
    bytes_received INTEGER DEFAULT 0,
    duration_ms INTEGER DEFAULT 0,
    metadata_json TEXT DEFAULT '{}',
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (session_id) REFERENCES recording_sessions(id) ON DELETE CASCADE,
    UNIQUE(session_id, source_key)
  );

  CREATE TABLE IF NOT EXISTS recording_chunks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source_id TEXT NOT NULL,
    sequence_index INTEGER NOT NULL,
    start_ms INTEGER DEFAULT 0,
    end_ms INTEGER DEFAULT 0,
    byte_count INTEGER DEFAULT 0,
    mime_type TEXT,
    file_path TEXT NOT NULL,
    created_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (source_id) REFERENCES recording_sources(id) ON DELETE CASCADE,
    UNIQUE(source_id, sequence_index)
  );

  CREATE TABLE IF NOT EXISTS recording_transcript_segments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL,
    source_id TEXT,
    source_key TEXT,
    speaker TEXT,
    text TEXT NOT NULL,
    start_ms INTEGER DEFAULT 0,
    end_ms INTEGER DEFAULT 0,
    confidence REAL,
    words_json TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (session_id) REFERENCES recording_sessions(id) ON DELETE CASCADE,
    FOREIGN KEY (source_id) REFERENCES recording_sources(id) ON DELETE CASCADE
  );

  CREATE INDEX IF NOT EXISTS idx_recording_sessions_user ON recording_sessions(user_id, created_at DESC);
  CREATE INDEX IF NOT EXISTS idx_recording_sources_session ON recording_sources(session_id, source_key);
  CREATE INDEX IF NOT EXISTS idx_recording_chunks_source ON recording_chunks(source_id, sequence_index);
  CREATE INDEX IF NOT EXISTS idx_recording_segments_session ON recording_transcript_segments(session_id, start_ms, created_at);
`);

try {
  db.exec(`
    CREATE VIRTUAL TABLE IF NOT EXISTS conversation_history_fts USING fts5(
      content,
      role UNINDEXED,
      user_id UNINDEXED,
      agent_run_id UNINDEXED,
      tokenize = 'porter unicode61'
    );

    CREATE TRIGGER IF NOT EXISTS conversation_history_fts_ai AFTER INSERT ON conversation_history BEGIN
      INSERT INTO conversation_history_fts(rowid, content, role, user_id, agent_run_id)
      VALUES (new.id, COALESCE(new.content, ''), new.role, new.user_id, COALESCE(new.agent_run_id, ''));
    END;

    CREATE TRIGGER IF NOT EXISTS conversation_history_fts_ad AFTER DELETE ON conversation_history BEGIN
      DELETE FROM conversation_history_fts WHERE rowid = old.id;
    END;

    CREATE TRIGGER IF NOT EXISTS conversation_history_fts_au AFTER UPDATE ON conversation_history BEGIN
      DELETE FROM conversation_history_fts WHERE rowid = old.id;
      INSERT INTO conversation_history_fts(rowid, content, role, user_id, agent_run_id)
      VALUES (new.id, COALESCE(new.content, ''), new.role, new.user_id, COALESCE(new.agent_run_id, ''));
    END;

    CREATE VIRTUAL TABLE IF NOT EXISTS messages_fts USING fts5(
      content,
      role UNINDEXED,
      user_id UNINDEXED,
      run_id UNINDEXED,
      platform UNINDEXED,
      platform_chat_id UNINDEXED,
      tokenize = 'porter unicode61'
    );

    CREATE TRIGGER IF NOT EXISTS messages_fts_ai AFTER INSERT ON messages BEGIN
      INSERT INTO messages_fts(rowid, content, role, user_id, run_id, platform, platform_chat_id)
      VALUES (new.id, COALESCE(new.content, ''), new.role, new.user_id, COALESCE(new.run_id, ''), COALESCE(new.platform, ''), COALESCE(new.platform_chat_id, ''));
    END;

    CREATE TRIGGER IF NOT EXISTS messages_fts_ad AFTER DELETE ON messages BEGIN
      DELETE FROM messages_fts WHERE rowid = old.id;
    END;

    CREATE TRIGGER IF NOT EXISTS messages_fts_au AFTER UPDATE ON messages BEGIN
      DELETE FROM messages_fts WHERE rowid = old.id;
      INSERT INTO messages_fts(rowid, content, role, user_id, run_id, platform, platform_chat_id)
      VALUES (new.id, COALESCE(new.content, ''), new.role, new.user_id, COALESCE(new.run_id, ''), COALESCE(new.platform, ''), COALESCE(new.platform_chat_id, ''));
    END;
  `);
} catch {
  // FTS5 is optional. The app still works with LIKE-based fallbacks if unavailable.
}

// Migrations for existing databases
for (const col of [
  "ALTER TABLE scheduled_tasks ADD COLUMN run_at TEXT",
  "ALTER TABLE scheduled_tasks ADD COLUMN one_time INTEGER DEFAULT 0",
  "ALTER TABLE agent_runs ADD COLUMN prompt_metrics TEXT",
  "ALTER TABLE agent_runs ADD COLUMN final_response TEXT",
  "ALTER TABLE conversations ADD COLUMN summary TEXT",
  "ALTER TABLE conversations ADD COLUMN summary_message_count INTEGER DEFAULT 0",
  "ALTER TABLE conversations ADD COLUMN last_summary TEXT",
  "ALTER TABLE recording_sessions ADD COLUMN transcript_language TEXT",
  "ALTER TABLE recording_sessions ADD COLUMN transcript_model TEXT",
  "ALTER TABLE recording_sessions ADD COLUMN duration_ms INTEGER DEFAULT 0",
  "ALTER TABLE recording_sessions ADD COLUMN structured_content_json TEXT",
]) {
  try { db.exec(col); } catch { /* column already exists */ }
}

try {
  db.exec(`
    INSERT OR REPLACE INTO conversation_history_fts(rowid, content, role, user_id, agent_run_id)
    SELECT id, COALESCE(content, ''), role, user_id, COALESCE(agent_run_id, '')
    FROM conversation_history;

    INSERT OR REPLACE INTO messages_fts(rowid, content, role, user_id, run_id, platform, platform_chat_id)
    SELECT id, COALESCE(content, ''), role, user_id, COALESCE(run_id, ''), COALESCE(platform, ''), COALESCE(platform_chat_id, '')
    FROM messages;
  `);
} catch {
  // Older SQLite builds without FTS5 should still let the app boot.
}

module.exports = db;
