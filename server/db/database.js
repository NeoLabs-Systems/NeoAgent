const Database = require('better-sqlite3');
const path = require('path');
const { randomUUID } = require('crypto');
const { DATA_DIR, ensureRuntimeDirs } = require('../../runtime/paths');
const {
  encryptValue,
  isEncryptedValue,
} = require('../services/integrations/secrets');
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

  CREATE TABLE IF NOT EXISTS agents (
    id TEXT PRIMARY KEY,
    user_id INTEGER NOT NULL,
    slug TEXT NOT NULL,
    display_name TEXT NOT NULL,
    description TEXT DEFAULT '',
    responsibilities TEXT DEFAULT '',
    instructions TEXT DEFAULT '',
    status TEXT DEFAULT 'active',
    is_default INTEGER DEFAULT 0,
    can_delegate INTEGER DEFAULT 0,
    can_be_delegated_to INTEGER DEFAULT 1,
    delegate_targets_json TEXT DEFAULT '[]',
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE(user_id, slug)
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
    agent_id TEXT,
    title TEXT,
    status TEXT DEFAULT 'pending',
    trigger_type TEXT DEFAULT 'user',
    trigger_source TEXT,
    model TEXT,
    total_tokens INTEGER DEFAULT 0,
    prompt_metrics TEXT,
    metadata_json TEXT,
    error TEXT,
    final_response TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    completed_at TEXT,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE SET NULL
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
    agent_id TEXT,
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
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE SET NULL
  );

  CREATE TABLE IF NOT EXISTS platform_connections (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    agent_id TEXT,
    platform TEXT NOT NULL,
    config TEXT DEFAULT '{}',
    status TEXT DEFAULT 'disconnected',
    auth_data_path TEXT,
    last_connected TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE SET NULL,
    UNIQUE(user_id, agent_id, platform)
  );

  CREATE TABLE IF NOT EXISTS mcp_servers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    agent_id TEXT,
    name TEXT NOT NULL,
    command TEXT NOT NULL,
    config TEXT DEFAULT '{}',
    enabled INTEGER DEFAULT 1,
    status TEXT DEFAULT 'stopped',
    created_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE SET NULL
  );

  CREATE TABLE IF NOT EXISTS integration_connections (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    agent_id TEXT,
    provider_key TEXT NOT NULL,
    app_key TEXT NOT NULL DEFAULT 'default',
    status TEXT DEFAULT 'not_connected',
    account_email TEXT,
    scopes_json TEXT DEFAULT '[]',
    credentials_json TEXT DEFAULT '{}',
    metadata_json TEXT DEFAULT '{}',
    last_connected_at TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE SET NULL,
    UNIQUE(user_id, agent_id, provider_key, app_key, account_email)
  );

  CREATE TABLE IF NOT EXISTS integration_oauth_states (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    agent_id TEXT,
    provider_key TEXT NOT NULL,
    app_key TEXT NOT NULL DEFAULT 'default',
    state TEXT NOT NULL UNIQUE,
    code_verifier TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    created_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE SET NULL
  );

  CREATE TABLE IF NOT EXISTS scheduled_tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    agent_id TEXT,
    name TEXT NOT NULL,
    cron_expression TEXT,
    run_at TEXT,
    one_time INTEGER DEFAULT 0,
    task_type TEXT DEFAULT 'agent_prompt',
    task_config TEXT DEFAULT '{}',
    enabled INTEGER DEFAULT 1,
    last_run TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE SET NULL
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
    agent_id TEXT,
    platform TEXT DEFAULT 'web',
    platform_chat_id TEXT,
    title TEXT,
    session_key TEXT,
    model TEXT,
    total_tokens INTEGER DEFAULT 0,
    compaction_count INTEGER DEFAULT 0,
    summary TEXT,
    summary_message_count INTEGER DEFAULT 0,
    working_state_json TEXT,
    last_verified_facts_json TEXT,
    last_compaction TEXT,
    last_summary TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE SET NULL
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
  CREATE INDEX IF NOT EXISTS idx_agents_user ON agents(user_id, status, updated_at DESC);
  CREATE INDEX IF NOT EXISTS idx_integration_oauth_states_state ON integration_oauth_states(state);
  CREATE INDEX IF NOT EXISTS idx_integration_oauth_states_expires ON integration_oauth_states(expires_at);
  CREATE INDEX IF NOT EXISTS idx_messages_user ON messages(user_id, created_at DESC);
  CREATE INDEX IF NOT EXISTS idx_messages_platform ON messages(platform, platform_chat_id);
  CREATE INDEX IF NOT EXISTS idx_conv_messages ON conversation_messages(conversation_id, created_at);
  CREATE INDEX IF NOT EXISTS idx_conversations_user ON conversations(user_id, updated_at DESC);
  CREATE INDEX IF NOT EXISTS idx_scheduled_tasks_user ON scheduled_tasks(user_id);

  CREATE TABLE IF NOT EXISTS conversation_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    agent_id TEXT,
    agent_run_id TEXT,
    role TEXT NOT NULL,
    content TEXT,
    metadata TEXT DEFAULT '{}',
    created_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE SET NULL
  );

  CREATE INDEX IF NOT EXISTS idx_conv_history_user ON conversation_history(user_id, created_at DESC);
  CREATE INDEX IF NOT EXISTS idx_conv_history_run ON conversation_history(agent_run_id, created_at);

  CREATE TABLE IF NOT EXISTS memories (
    id TEXT PRIMARY KEY,
    user_id INTEGER NOT NULL,
    agent_id TEXT,
    category TEXT DEFAULT 'episodic',
    content TEXT NOT NULL,
    importance INTEGER DEFAULT 5,
    embedding TEXT,
    access_count INTEGER DEFAULT 0,
    archived INTEGER DEFAULT 0,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE SET NULL
  );

  CREATE TABLE IF NOT EXISTS core_memory (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    agent_id TEXT,
    key TEXT NOT NULL,
    value TEXT,
    updated_at TEXT DEFAULT (datetime('now')),
    UNIQUE(user_id, agent_id, key)
  );

  CREATE INDEX IF NOT EXISTS idx_memories_user ON memories(user_id, archived, updated_at DESC);
  CREATE INDEX IF NOT EXISTS idx_memories_category ON memories(user_id, category, archived);

  CREATE TABLE IF NOT EXISTS agent_settings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    agent_id TEXT NOT NULL,
    key TEXT NOT NULL,
    value TEXT,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE CASCADE,
    UNIQUE(user_id, agent_id, key)
  );

  CREATE TABLE IF NOT EXISTS agent_delegations (
    id TEXT PRIMARY KEY,
    user_id INTEGER NOT NULL,
    parent_agent_id TEXT NOT NULL,
    target_agent_id TEXT NOT NULL,
    parent_run_id TEXT,
    child_run_id TEXT,
    task TEXT NOT NULL,
    context TEXT,
    status TEXT DEFAULT 'pending',
    result_summary TEXT,
    error TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    completed_at TEXT,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (parent_agent_id) REFERENCES agents(id) ON DELETE CASCADE,
    FOREIGN KEY (target_agent_id) REFERENCES agents(id) ON DELETE CASCADE
  );

  CREATE INDEX IF NOT EXISTS idx_agent_settings_agent ON agent_settings(user_id, agent_id, key);
  CREATE INDEX IF NOT EXISTS idx_agent_delegations_parent ON agent_delegations(parent_run_id, created_at);

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

  CREATE TABLE IF NOT EXISTS artifacts (
    id TEXT PRIMARY KEY,
    user_id INTEGER NOT NULL,
    kind TEXT NOT NULL,
    backend TEXT NOT NULL,
    content_type TEXT,
    storage_path TEXT NOT NULL,
    original_filename TEXT,
    byte_size INTEGER DEFAULT 0,
    metadata_json TEXT DEFAULT '{}',
    created_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  );

  CREATE INDEX IF NOT EXISTS idx_artifacts_user ON artifacts(user_id, created_at DESC);

  CREATE TRIGGER IF NOT EXISTS cleanup_expired_oauth_states
  AFTER INSERT ON integration_oauth_states BEGIN
    DELETE FROM integration_oauth_states
    WHERE datetime(expires_at) <= datetime('now');
  END;
`);

try {
  db.exec(`
    CREATE VIRTUAL TABLE IF NOT EXISTS conversation_history_fts USING fts5(
      content,
      role UNINDEXED,
      user_id UNINDEXED,
      agent_id UNINDEXED,
      agent_run_id UNINDEXED,
      tokenize = 'porter unicode61'
    );

    CREATE TRIGGER IF NOT EXISTS conversation_history_fts_ai AFTER INSERT ON conversation_history BEGIN
      INSERT INTO conversation_history_fts(rowid, content, role, user_id, agent_id, agent_run_id)
      VALUES (new.id, COALESCE(new.content, ''), new.role, new.user_id, COALESCE(new.agent_id, ''), COALESCE(new.agent_run_id, ''));
    END;

    CREATE TRIGGER IF NOT EXISTS conversation_history_fts_ad AFTER DELETE ON conversation_history BEGIN
      DELETE FROM conversation_history_fts WHERE rowid = old.id;
    END;

    CREATE TRIGGER IF NOT EXISTS conversation_history_fts_au AFTER UPDATE ON conversation_history BEGIN
      DELETE FROM conversation_history_fts WHERE rowid = old.id;
      INSERT INTO conversation_history_fts(rowid, content, role, user_id, agent_id, agent_run_id)
      VALUES (new.id, COALESCE(new.content, ''), new.role, new.user_id, COALESCE(new.agent_id, ''), COALESCE(new.agent_run_id, ''));
    END;

    CREATE VIRTUAL TABLE IF NOT EXISTS messages_fts USING fts5(
      content,
      role UNINDEXED,
      user_id UNINDEXED,
      agent_id UNINDEXED,
      run_id UNINDEXED,
      platform UNINDEXED,
      platform_chat_id UNINDEXED,
      tokenize = 'porter unicode61'
    );

    CREATE TRIGGER IF NOT EXISTS messages_fts_ai AFTER INSERT ON messages BEGIN
      INSERT INTO messages_fts(rowid, content, role, user_id, agent_id, run_id, platform, platform_chat_id)
      VALUES (new.id, COALESCE(new.content, ''), new.role, new.user_id, COALESCE(new.agent_id, ''), COALESCE(new.run_id, ''), COALESCE(new.platform, ''), COALESCE(new.platform_chat_id, ''));
    END;

    CREATE TRIGGER IF NOT EXISTS messages_fts_ad AFTER DELETE ON messages BEGIN
      DELETE FROM messages_fts WHERE rowid = old.id;
    END;

    CREATE TRIGGER IF NOT EXISTS messages_fts_au AFTER UPDATE ON messages BEGIN
      DELETE FROM messages_fts WHERE rowid = old.id;
      INSERT INTO messages_fts(rowid, content, role, user_id, agent_id, run_id, platform, platform_chat_id)
      VALUES (new.id, COALESCE(new.content, ''), new.role, new.user_id, COALESCE(new.agent_id, ''), COALESCE(new.run_id, ''), COALESCE(new.platform, ''), COALESCE(new.platform_chat_id, ''));
    END;
  `);
} catch {
  // FTS5 is optional. The app still works with LIKE-based fallbacks if unavailable.
}

// Migrations for existing databases
for (const col of [
  "ALTER TABLE agent_runs ADD COLUMN agent_id TEXT",
  "ALTER TABLE agents ADD COLUMN can_delegate INTEGER",
  "ALTER TABLE agents ADD COLUMN can_be_delegated_to INTEGER",
  "ALTER TABLE agents ADD COLUMN delegate_targets_json TEXT",
  "ALTER TABLE messages ADD COLUMN agent_id TEXT",
  "ALTER TABLE platform_connections ADD COLUMN agent_id TEXT",
  "ALTER TABLE mcp_servers ADD COLUMN agent_id TEXT",
  "ALTER TABLE integration_connections ADD COLUMN agent_id TEXT",
  "ALTER TABLE integration_oauth_states ADD COLUMN agent_id TEXT",
  "ALTER TABLE scheduled_tasks ADD COLUMN agent_id TEXT",
  "ALTER TABLE conversations ADD COLUMN agent_id TEXT",
  "ALTER TABLE conversation_history ADD COLUMN agent_id TEXT",
  "ALTER TABLE memories ADD COLUMN agent_id TEXT",
  "ALTER TABLE core_memory ADD COLUMN agent_id TEXT",
  "ALTER TABLE scheduled_tasks ADD COLUMN run_at TEXT",
  "ALTER TABLE scheduled_tasks ADD COLUMN one_time INTEGER DEFAULT 0",
  "ALTER TABLE agent_runs ADD COLUMN prompt_metrics TEXT",
  "ALTER TABLE agent_runs ADD COLUMN metadata_json TEXT",
  "ALTER TABLE agent_runs ADD COLUMN final_response TEXT",
  "ALTER TABLE conversations ADD COLUMN summary TEXT",
  "ALTER TABLE conversations ADD COLUMN summary_message_count INTEGER DEFAULT 0",
  "ALTER TABLE conversations ADD COLUMN working_state_json TEXT",
  "ALTER TABLE conversations ADD COLUMN last_verified_facts_json TEXT",
  "ALTER TABLE conversations ADD COLUMN last_summary TEXT",
  "ALTER TABLE recording_sessions ADD COLUMN transcript_language TEXT",
  "ALTER TABLE recording_sessions ADD COLUMN transcript_model TEXT",
  "ALTER TABLE recording_sessions ADD COLUMN duration_ms INTEGER DEFAULT 0",
  "ALTER TABLE recording_sessions ADD COLUMN structured_content_json TEXT",
  "ALTER TABLE artifacts ADD COLUMN metadata_json TEXT DEFAULT '{}'",
]) {
  try { db.exec(col); } catch { /* column already exists */ }
}

function tableHasColumn(tableName, columnName) {
  try {
    return db
      .prepare(`PRAGMA table_info(${tableName})`)
      .all()
      .some((column) => column.name === columnName);
  } catch {
    return false;
  }
}

function createAgentScopedIndexes() {
  const statements = [
    ['agent_runs', 'CREATE INDEX IF NOT EXISTS idx_agent_runs_agent ON agent_runs(user_id, agent_id, created_at DESC)'],
    ['integration_connections', 'CREATE INDEX IF NOT EXISTS idx_integration_connections_agent ON integration_connections(user_id, agent_id, provider_key, app_key)'],
    ['messages', 'CREATE INDEX IF NOT EXISTS idx_messages_agent ON messages(user_id, agent_id, created_at DESC)'],
    ['conversations', 'CREATE INDEX IF NOT EXISTS idx_conversations_agent ON conversations(user_id, agent_id, updated_at DESC)'],
    ['scheduled_tasks', 'CREATE INDEX IF NOT EXISTS idx_scheduled_tasks_agent ON scheduled_tasks(user_id, agent_id)'],
    ['conversation_history', 'CREATE INDEX IF NOT EXISTS idx_conv_history_agent ON conversation_history(user_id, agent_id, created_at DESC)'],
    ['memories', 'CREATE INDEX IF NOT EXISTS idx_memories_agent ON memories(user_id, agent_id, archived, updated_at DESC)'],
    ['core_memory', 'CREATE INDEX IF NOT EXISTS idx_core_memory_agent ON core_memory(user_id, agent_id, key)'],
  ];
  for (const [table, statement] of statements) {
    if (!tableHasColumn(table, 'agent_id')) continue;
    try {
      db.exec(statement);
    } catch {
      // Keep startup resilient for partially migrated local databases.
    }
  }
}

function getMainAgentId(userId) {
  if (!userId) return null;
  const user = db.prepare('SELECT id FROM users WHERE id = ?').get(userId);
  if (!user) return null;
  let row = db.prepare('SELECT id FROM agents WHERE user_id = ? AND slug = ?').get(userId, 'main');
  if (row?.id) return row.id;

  const id = randomUUID();
  db.prepare(
    `INSERT INTO agents (
       id, user_id, slug, display_name, description, responsibilities, instructions,
       is_default, can_delegate, can_be_delegated_to, delegate_targets_json
     )
     VALUES (?, ?, 'main', 'Main', 'Default personal assistant and fallback agent.',
       'Handle general requests and delegate to specialist agents only when there is a clear match.',
       '', 1, 1, 0, '[]'
     )`
  ).run(id, userId);
  return id;
}

function backfillAgentIds() {
  const users = db.prepare('SELECT id FROM users').all();
  if (!users.length) return;
  const scopedTables = [
    'agent_runs',
    'messages',
    'platform_connections',
    'mcp_servers',
    'integration_connections',
    'integration_oauth_states',
    'scheduled_tasks',
    'conversations',
    'conversation_history',
    'memories',
    'core_memory',
  ];
  const tx = db.transaction(() => {
    for (const user of users) {
      const agentId = getMainAgentId(user.id);
      db.prepare('UPDATE agents SET is_default = CASE WHEN id = ? THEN 1 ELSE 0 END WHERE user_id = ?')
        .run(agentId, user.id);
      for (const table of scopedTables) {
        if (!tableHasColumn(table, 'agent_id')) continue;
        db.prepare(`UPDATE ${table} SET agent_id = ? WHERE user_id = ? AND agent_id IS NULL`)
          .run(agentId, user.id);
      }
    }
  });
  tx();
}

function backfillAgentPolicies() {
  if (
    !tableHasColumn('agents', 'can_delegate') ||
    !tableHasColumn('agents', 'can_be_delegated_to') ||
    !tableHasColumn('agents', 'delegate_targets_json')
  ) {
    return;
  }
  try {
    db.prepare(
      `UPDATE agents
       SET can_delegate = COALESCE(can_delegate, 1),
           can_be_delegated_to = COALESCE(can_be_delegated_to, 0),
           delegate_targets_json = COALESCE(delegate_targets_json, '[]')
       WHERE slug = 'main'`
    ).run();
    db.prepare(
      `UPDATE agents
       SET can_delegate = COALESCE(can_delegate, 0),
           can_be_delegated_to = COALESCE(can_be_delegated_to, 1),
           delegate_targets_json = COALESCE(delegate_targets_json, '[]')
       WHERE slug != 'main'`
    ).run();
  } catch {
    // Keep startup resilient for partially migrated databases.
  }
}

function tableHasUniqueIndex(tableName, columns) {
  try {
    const indexes = db.prepare(`PRAGMA index_list(${tableName})`).all();
    const expected = columns.join(',');
    for (const index of indexes) {
      if (!index.unique) continue;
      const actual = db
        .prepare(`PRAGMA index_info(${index.name})`)
        .all()
        .sort((a, b) => a.seqno - b.seqno)
        .map((column) => column.name)
        .join(',');
      if (actual === expected) return true;
    }
  } catch {
    return false;
  }
  return false;
}

function rebuildPlatformConnectionsForAgents() {
  if (tableHasUniqueIndex('platform_connections', ['user_id', 'agent_id', 'platform'])) {
    return;
  }

  const rows = db.prepare('SELECT * FROM platform_connections ORDER BY id ASC').all();
  db.exec(`
    ALTER TABLE platform_connections RENAME TO platform_connections_legacy_agent_scope;

    CREATE TABLE platform_connections (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      agent_id TEXT,
      platform TEXT NOT NULL,
      config TEXT DEFAULT '{}',
      status TEXT DEFAULT 'disconnected',
      auth_data_path TEXT,
      last_connected TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE SET NULL,
      UNIQUE(user_id, agent_id, platform)
    );
  `);
  const insert = db.prepare(`
    INSERT OR REPLACE INTO platform_connections (
      id, user_id, agent_id, platform, config, status, auth_data_path, last_connected, created_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
  `);
  for (const row of rows) {
    const agentId = row.agent_id || getMainAgentId(row.user_id);
    if (!agentId) continue;
    insert.run(
      row.id,
      row.user_id,
      agentId,
      row.platform,
      row.config || '{}',
      row.status || 'disconnected',
      row.auth_data_path || null,
      row.last_connected || null,
      row.created_at || null,
    );
  }
  db.exec('DROP TABLE platform_connections_legacy_agent_scope;');
}

function rebuildCoreMemoryForAgents() {
  if (tableHasUniqueIndex('core_memory', ['user_id', 'agent_id', 'key'])) {
    return;
  }

  const rows = db.prepare('SELECT * FROM core_memory ORDER BY id ASC').all();
  let beganTransaction = false;
  try {
    db.exec('BEGIN');
    beganTransaction = true;
    db.exec(`
      ALTER TABLE core_memory RENAME TO core_memory_legacy_agent_scope;

      CREATE TABLE core_memory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        agent_id TEXT,
        key TEXT NOT NULL,
        value TEXT,
        updated_at TEXT DEFAULT (datetime('now')),
        UNIQUE(user_id, agent_id, key)
      );
    `);
    const insert = db.prepare(`
      INSERT OR REPLACE INTO core_memory (id, user_id, agent_id, key, value, updated_at)
      VALUES (?, ?, ?, ?, ?, ?)
    `);
    for (const row of rows) {
      const agentId = row.agent_id || getMainAgentId(row.user_id);
      if (!agentId) continue;
      insert.run(
        row.id,
        row.user_id,
        agentId,
        row.key,
        row.value,
        row.updated_at || null,
      );
    }
    db.exec('DROP TABLE core_memory_legacy_agent_scope;');
    db.exec('COMMIT');
    beganTransaction = false;
  } catch (error) {
    if (beganTransaction) {
      try {
        db.exec('ROLLBACK');
      } catch {
        // Best effort rollback; preserve original migration error.
      }
    }
    throw error;
  }
}

function rebuildFtsForAgents() {
  try {
    const conversationHasAgentId = tableHasColumn('conversation_history_fts', 'agent_id');
    const messagesHasAgentId = tableHasColumn('messages_fts', 'agent_id');
    if (conversationHasAgentId && messagesHasAgentId) return;

    db.exec(`
      DROP TRIGGER IF EXISTS conversation_history_fts_ai;
      DROP TRIGGER IF EXISTS conversation_history_fts_ad;
      DROP TRIGGER IF EXISTS conversation_history_fts_au;
      DROP TABLE IF EXISTS conversation_history_fts;

      DROP TRIGGER IF EXISTS messages_fts_ai;
      DROP TRIGGER IF EXISTS messages_fts_ad;
      DROP TRIGGER IF EXISTS messages_fts_au;
      DROP TABLE IF EXISTS messages_fts;

      CREATE VIRTUAL TABLE IF NOT EXISTS conversation_history_fts USING fts5(
        content,
        role UNINDEXED,
        user_id UNINDEXED,
        agent_id UNINDEXED,
        agent_run_id UNINDEXED,
        tokenize = 'porter unicode61'
      );

      CREATE TRIGGER IF NOT EXISTS conversation_history_fts_ai AFTER INSERT ON conversation_history BEGIN
        INSERT INTO conversation_history_fts(rowid, content, role, user_id, agent_id, agent_run_id)
        VALUES (new.id, COALESCE(new.content, ''), new.role, new.user_id, COALESCE(new.agent_id, ''), COALESCE(new.agent_run_id, ''));
      END;

      CREATE TRIGGER IF NOT EXISTS conversation_history_fts_ad AFTER DELETE ON conversation_history BEGIN
        DELETE FROM conversation_history_fts WHERE rowid = old.id;
      END;

      CREATE TRIGGER IF NOT EXISTS conversation_history_fts_au AFTER UPDATE ON conversation_history BEGIN
        DELETE FROM conversation_history_fts WHERE rowid = old.id;
        INSERT INTO conversation_history_fts(rowid, content, role, user_id, agent_id, agent_run_id)
        VALUES (new.id, COALESCE(new.content, ''), new.role, new.user_id, COALESCE(new.agent_id, ''), COALESCE(new.agent_run_id, ''));
      END;

      CREATE VIRTUAL TABLE IF NOT EXISTS messages_fts USING fts5(
        content,
        role UNINDEXED,
        user_id UNINDEXED,
        agent_id UNINDEXED,
        run_id UNINDEXED,
        platform UNINDEXED,
        platform_chat_id UNINDEXED,
        tokenize = 'porter unicode61'
      );

      CREATE TRIGGER IF NOT EXISTS messages_fts_ai AFTER INSERT ON messages BEGIN
        INSERT INTO messages_fts(rowid, content, role, user_id, agent_id, run_id, platform, platform_chat_id)
        VALUES (new.id, COALESCE(new.content, ''), new.role, new.user_id, COALESCE(new.agent_id, ''), COALESCE(new.run_id, ''), COALESCE(new.platform, ''), COALESCE(new.platform_chat_id, ''));
      END;

      CREATE TRIGGER IF NOT EXISTS messages_fts_ad AFTER DELETE ON messages BEGIN
        DELETE FROM messages_fts WHERE rowid = old.id;
      END;

      CREATE TRIGGER IF NOT EXISTS messages_fts_au AFTER UPDATE ON messages BEGIN
        DELETE FROM messages_fts WHERE rowid = old.id;
        INSERT INTO messages_fts(rowid, content, role, user_id, agent_id, run_id, platform, platform_chat_id)
        VALUES (new.id, COALESCE(new.content, ''), new.role, new.user_id, COALESCE(new.agent_id, ''), COALESCE(new.run_id, ''), COALESCE(new.platform, ''), COALESCE(new.platform_chat_id, ''));
      END;
    `);
  } catch {
    // FTS5 is optional. Leave LIKE-based recall available if rebuild fails.
  }
}

function parseIntegrationMetadata(metadataJson) {
  try {
    const parsed = JSON.parse(metadataJson || '{}');
    return parsed && typeof parsed === 'object' ? parsed : {};
  } catch {
    return {};
  }
}

function migrateIntegrationConnectionsTable() {
  if (tableHasColumn('integration_connections', 'app_key') && tableHasColumn('integration_connections', 'agent_id')) {
    if (tableHasUniqueIndex('integration_connections', ['user_id', 'agent_id', 'provider_key', 'app_key', 'account_email'])) {
      return;
    }
  }

  if (tableHasColumn('integration_connections', 'app_key') && !tableHasColumn('integration_connections', 'agent_id')) {
    try { db.exec('ALTER TABLE integration_connections ADD COLUMN agent_id TEXT'); } catch { /* column exists */ }
  }

  if (tableHasColumn('integration_connections', 'app_key') && tableHasUniqueIndex('integration_connections', ['user_id', 'agent_id', 'provider_key', 'app_key', 'account_email'])) {
    return;
  }

  const legacyRows = db
    .prepare('SELECT * FROM integration_connections ORDER BY id ASC')
    .all();

  db.exec(`
    ALTER TABLE integration_connections RENAME TO integration_connections_legacy;

    CREATE TABLE integration_connections (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      agent_id TEXT,
      provider_key TEXT NOT NULL,
      app_key TEXT NOT NULL DEFAULT 'default',
      status TEXT DEFAULT 'not_connected',
      account_email TEXT,
      scopes_json TEXT DEFAULT '[]',
      credentials_json TEXT DEFAULT '{}',
      metadata_json TEXT DEFAULT '{}',
      last_connected_at TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      updated_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE SET NULL,
      UNIQUE(user_id, agent_id, provider_key, app_key, account_email)
    );
  `);

  const insert = db.prepare(`
    INSERT OR REPLACE INTO integration_connections (
      user_id,
      agent_id,
      provider_key,
      app_key,
      status,
      account_email,
      scopes_json,
      credentials_json,
      metadata_json,
      last_connected_at,
      created_at,
      updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `);

  const legacyGoogleApps = ['gmail', 'calendar', 'drive', 'docs', 'sheets'];
  for (const row of legacyRows) {
    const agentId = row.agent_id || getMainAgentId(row.user_id);
    if (!agentId) continue;
    const metadata = parseIntegrationMetadata(row.metadata_json);
    const appIds = Array.isArray(metadata.apps)
      ? metadata.apps
          .map((item) => String(item || '').trim())
          .filter(Boolean)
      : row.provider_key === 'google_workspace'
      ? legacyGoogleApps
      : ['default'];

    for (const appId of appIds) {
      insert.run(
        row.user_id,
        agentId,
        row.provider_key,
        appId,
        row.status || 'not_connected',
        row.account_email || null,
        row.scopes_json || '[]',
        row.credentials_json || '{}',
        row.metadata_json || '{}',
        row.last_connected_at || null,
        row.created_at || null,
        row.updated_at || null,
      );
    }
  }

  db.exec(`
    DROP TABLE integration_connections_legacy;
    DROP INDEX IF EXISTS idx_integration_connections_user;
    CREATE INDEX IF NOT EXISTS idx_integration_connections_user
      ON integration_connections(user_id, agent_id, provider_key, app_key);
  `);
}

function migrateIntegrationOauthStatesTable() {
  if (tableHasColumn('integration_oauth_states', 'app_key') && tableHasColumn('integration_oauth_states', 'agent_id')) {
    return;
  }

  if (tableHasColumn('integration_oauth_states', 'app_key') && !tableHasColumn('integration_oauth_states', 'agent_id')) {
    try { db.exec('ALTER TABLE integration_oauth_states ADD COLUMN agent_id TEXT'); } catch { /* column exists */ }
    return;
  }

  db.exec(`
    ALTER TABLE integration_oauth_states RENAME TO integration_oauth_states_legacy;

    CREATE TABLE integration_oauth_states (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      agent_id TEXT,
      provider_key TEXT NOT NULL,
      app_key TEXT NOT NULL DEFAULT 'default',
      state TEXT NOT NULL UNIQUE,
      code_verifier TEXT NOT NULL,
      expires_at TEXT NOT NULL,
      created_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE SET NULL
    );

    DROP TABLE integration_oauth_states_legacy;
  `);
}

function migrateIntegrationSecretStorage() {
  try {
    const connectionRows = db
      .prepare('SELECT id, credentials_json FROM integration_connections')
      .all();
    const updateConnection = db.prepare(
      'UPDATE integration_connections SET credentials_json = ? WHERE id = ?',
    );
    for (const row of connectionRows) {
      const current = String(row.credentials_json || '');
      if (!current || isEncryptedValue(current)) continue;
      updateConnection.run(encryptValue(current), row.id);
    }
  } catch {
    // Preserve startup even if a row cannot be re-encrypted.
  }

  try {
    const stateRows = db
      .prepare('SELECT id, code_verifier FROM integration_oauth_states')
      .all();
    const updateState = db.prepare(
      'UPDATE integration_oauth_states SET code_verifier = ? WHERE id = ?',
    );
    for (const row of stateRows) {
      const current = String(row.code_verifier || '');
      if (!current || isEncryptedValue(current)) continue;
      updateState.run(encryptValue(current), row.id);
    }
  } catch {
    // Preserve startup even if a row cannot be re-encrypted.
  }
}

backfillAgentIds();
backfillAgentPolicies();
rebuildPlatformConnectionsForAgents();
rebuildCoreMemoryForAgents();
migrateIntegrationConnectionsTable();
migrateIntegrationOauthStatesTable();
backfillAgentIds();
backfillAgentPolicies();
createAgentScopedIndexes();
migrateIntegrationSecretStorage();
rebuildFtsForAgents();

try {
  db.exec(`
    INSERT OR REPLACE INTO conversation_history_fts(rowid, content, role, user_id, agent_id, agent_run_id)
    SELECT id, COALESCE(content, ''), role, user_id, COALESCE(agent_id, ''), COALESCE(agent_run_id, '')
    FROM conversation_history;

    INSERT OR REPLACE INTO messages_fts(rowid, content, role, user_id, agent_id, run_id, platform, platform_chat_id)
    SELECT id, COALESCE(content, ''), role, user_id, COALESCE(agent_id, ''), COALESCE(run_id, ''), COALESCE(platform, ''), COALESCE(platform_chat_id, '')
    FROM messages;
  `);
} catch {
  // Older SQLite builds without FTS5 should still let the app boot.
}

module.exports = db;
