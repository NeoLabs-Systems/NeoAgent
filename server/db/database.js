const Database = require('better-sqlite3');
const fs = require('fs');
const path = require('path');
const { randomUUID } = require('crypto');
const { DATA_DIR, ensureRuntimeDirs } = require('../../runtime/paths');
const {
  encryptValue,
  isEncryptedValue,
} = require('../services/integrations/secrets');
ensureRuntimeDirs();

const DB_PATH = path.join(DATA_DIR, 'neoagent.db');

function removeWalSidecars(dbPath) {
  for (const suffix of ['-wal', '-shm']) {
    try {
      fs.rmSync(`${dbPath}${suffix}`, { force: true });
    } catch {}
  }
}

function initializeDatabase(db, dbPath) {
  try {
    db.pragma('journal_mode = WAL');
  } catch (error) {
    console.warn(
      `[Database] Failed to enable WAL for ${dbPath}: ${error.message}. ` +
      'Retrying after clearing WAL sidecar files.',
    );
    try {
      db.close();
    } catch {}

    removeWalSidecars(dbPath);

    db = new Database(dbPath);
    try {
      db.pragma('journal_mode = WAL');
    } catch (retryError) {
      console.warn(
        `[Database] WAL is unavailable for ${dbPath}: ${retryError.message}. ` +
        'Falling back to DELETE journal mode.',
      );
      db.pragma('journal_mode = DELETE');
    }
  }

  db.pragma('foreign_keys = ON');
  db.pragma('busy_timeout = 5000');
  return db;
}

let db = new Database(DB_PATH);
db = initializeDatabase(db, DB_PATH);

db.exec(`
  CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    email TEXT UNIQUE,
    email_verified_at TEXT,
    password TEXT NOT NULL,
    password_login_enabled INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now')),
    last_login TEXT,
    has_completed_onboarding INTEGER DEFAULT 0
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

  CREATE TABLE IF NOT EXISTS user_two_factor (
    user_id INTEGER PRIMARY KEY,
    secret TEXT,
    pending_secret TEXT,
    enabled INTEGER DEFAULT 0,
    created_at TEXT DEFAULT (datetime('now')),
    enabled_at TEXT,
    updated_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  );

  CREATE TABLE IF NOT EXISTS user_recovery_codes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    code_hash TEXT NOT NULL,
    used_at TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  );

  CREATE TABLE IF NOT EXISTS user_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    session_hash TEXT UNIQUE NOT NULL,
    ip_address TEXT,
    user_agent TEXT,
    location_label TEXT,
    location_json TEXT DEFAULT '{}',
    created_at TEXT DEFAULT (datetime('now')),
    last_seen_at TEXT DEFAULT (datetime('now')),
    expires_at TEXT,
    revoked_at TEXT,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  );

  CREATE TABLE IF NOT EXISTS user_qr_login_challenges (
    id TEXT PRIMARY KEY,
    poll_token_hash TEXT UNIQUE NOT NULL,
    approve_secret_hash TEXT NOT NULL,
    status TEXT DEFAULT 'pending',
    request_user_agent TEXT,
    request_ip_address TEXT,
    request_location_label TEXT,
    request_location_json TEXT DEFAULT '{}',
    request_metadata_json TEXT DEFAULT '{}',
    approved_by_user_id INTEGER,
    approved_session_hash TEXT,
    approved_metadata_json TEXT DEFAULT '{}',
    expires_at TEXT NOT NULL,
    approved_at TEXT,
    claimed_at TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (approved_by_user_id) REFERENCES users(id) ON DELETE SET NULL
  );

  CREATE TABLE IF NOT EXISTS user_email_tokens (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    type TEXT NOT NULL,
    email TEXT NOT NULL,
    token_hash TEXT UNIQUE NOT NULL,
    created_at TEXT DEFAULT (datetime('now')),
    expires_at TEXT NOT NULL,
    consumed_at TEXT,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  );

  CREATE TABLE IF NOT EXISTS user_auth_providers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    provider_key TEXT NOT NULL,
    provider_user_id TEXT NOT NULL,
    email TEXT,
    metadata_json TEXT DEFAULT '{}',
    last_used_at TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE(provider_key, provider_user_id)
  );

  CREATE TABLE IF NOT EXISTS auth_oauth_states (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    provider_key TEXT NOT NULL,
    mode TEXT NOT NULL,
    state TEXT NOT NULL UNIQUE,
    code_verifier TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    status TEXT DEFAULT 'pending',
    result_json TEXT,
    error_message TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    completed_at TEXT,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
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

  CREATE TABLE IF NOT EXISTS integration_provider_configs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    agent_id TEXT,
    provider_key TEXT NOT NULL,
    config_json TEXT DEFAULT '{}',
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE SET NULL,
    UNIQUE(user_id, agent_id, provider_key)
  );

  CREATE TABLE IF NOT EXISTS browser_extension_pairing_requests (
    id TEXT PRIMARY KEY,
    user_id INTEGER,
    pairing_secret_hash TEXT NOT NULL,
    status TEXT DEFAULT 'pending',
    approved_at TEXT,
    claimed_at TEXT,
    expires_at TEXT NOT NULL,
    metadata_json TEXT DEFAULT '{}',
    created_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  );

  CREATE TABLE IF NOT EXISTS browser_extension_tokens (
    id TEXT PRIMARY KEY,
    user_id INTEGER NOT NULL,
    token_hash TEXT UNIQUE NOT NULL,
    name TEXT DEFAULT 'Chrome Extension',
    status TEXT DEFAULT 'active',
    last_connected_at TEXT,
    last_seen_at TEXT,
    revoked_at TEXT,
    metadata_json TEXT DEFAULT '{}',
    created_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  );

  CREATE TABLE IF NOT EXISTS desktop_companion_devices (
    id TEXT PRIMARY KEY,
    user_id INTEGER NOT NULL,
    device_id TEXT NOT NULL,
    activation_id TEXT,
    label TEXT NOT NULL,
    hostname TEXT,
    platform TEXT,
    platform_version TEXT,
    app_version TEXT,
    companion_enabled INTEGER DEFAULT 0,
    paused INTEGER DEFAULT 0,
    status TEXT DEFAULT 'offline',
    display_count INTEGER DEFAULT 0,
    active_display_id TEXT,
    permissions_json TEXT DEFAULT '{}',
    capabilities_json TEXT DEFAULT '{}',
    metadata_json TEXT DEFAULT '{}',
    session_id INTEGER,
    last_connected_at TEXT,
    last_seen_at TEXT,
    revoked_at TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE(user_id, device_id)
  );

  CREATE TABLE IF NOT EXISTS scheduled_tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    agent_id TEXT,
    name TEXT NOT NULL,
    trigger_type TEXT DEFAULT 'schedule',
    trigger_config TEXT DEFAULT '{}',
    cron_expression TEXT,
    run_at TEXT,
    one_time INTEGER DEFAULT 0,
    execution_mode TEXT DEFAULT 'prompt',
    task_type TEXT DEFAULT 'agent_prompt',
    task_config TEXT DEFAULT '{}',
    enabled INTEGER DEFAULT 1,
    last_run TEXT,
    last_triggered_at TEXT,
    last_trigger_fingerprint TEXT,
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
  CREATE INDEX IF NOT EXISTS idx_user_recovery_codes_user ON user_recovery_codes(user_id, used_at);
  CREATE INDEX IF NOT EXISTS idx_user_sessions_user ON user_sessions(user_id, revoked_at, last_seen_at DESC);
  CREATE INDEX IF NOT EXISTS idx_user_qr_login_challenges_status ON user_qr_login_challenges(status, expires_at);
  CREATE INDEX IF NOT EXISTS idx_user_qr_login_challenges_approver ON user_qr_login_challenges(approved_by_user_id, created_at DESC);
  CREATE INDEX IF NOT EXISTS idx_user_email_tokens_lookup ON user_email_tokens(token_hash, consumed_at, expires_at);
  CREATE INDEX IF NOT EXISTS idx_user_email_tokens_user ON user_email_tokens(user_id, type, consumed_at);
  CREATE INDEX IF NOT EXISTS idx_user_auth_providers_user ON user_auth_providers(user_id, provider_key, updated_at DESC);
  CREATE INDEX IF NOT EXISTS idx_auth_oauth_states_state ON auth_oauth_states(state);
  CREATE INDEX IF NOT EXISTS idx_auth_oauth_states_expires ON auth_oauth_states(expires_at, status);
  CREATE INDEX IF NOT EXISTS idx_integration_oauth_states_state ON integration_oauth_states(state);
  CREATE INDEX IF NOT EXISTS idx_integration_oauth_states_expires ON integration_oauth_states(expires_at);
  CREATE INDEX IF NOT EXISTS idx_browser_extension_pairing_status ON browser_extension_pairing_requests(status, expires_at);
  CREATE INDEX IF NOT EXISTS idx_browser_extension_tokens_user ON browser_extension_tokens(user_id, status, created_at DESC);
  CREATE INDEX IF NOT EXISTS idx_browser_extension_tokens_hash_status ON browser_extension_tokens(token_hash, status);
  CREATE INDEX IF NOT EXISTS idx_desktop_companion_devices_user ON desktop_companion_devices(user_id, status, created_at DESC);
  CREATE INDEX IF NOT EXISTS idx_messages_user ON messages(user_id, created_at DESC);
  CREATE INDEX IF NOT EXISTS idx_messages_platform ON messages(platform, platform_chat_id);
  CREATE INDEX IF NOT EXISTS idx_conv_messages ON conversation_messages(conversation_id, created_at);
  CREATE INDEX IF NOT EXISTS idx_conversations_user ON conversations(user_id, updated_at DESC);
  CREATE INDEX IF NOT EXISTS idx_scheduled_tasks_user ON scheduled_tasks(user_id);

  CREATE TABLE IF NOT EXISTS ai_widgets (
    id TEXT PRIMARY KEY,
    user_id INTEGER NOT NULL,
    agent_id TEXT,
    name TEXT NOT NULL,
    widget_kind TEXT DEFAULT 'custom',
    system_key TEXT,
    is_system INTEGER DEFAULT 0,
    template TEXT NOT NULL,
    layout_variant TEXT NOT NULL,
    definition_json TEXT DEFAULT '{}',
    refresh_cron TEXT NOT NULL,
    enabled INTEGER DEFAULT 1,
    scheduled_task_id INTEGER,
    last_snapshot_at TEXT,
    last_error TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE SET NULL,
    FOREIGN KEY (scheduled_task_id) REFERENCES scheduled_tasks(id) ON DELETE SET NULL
  );

  CREATE TABLE IF NOT EXISTS ai_widget_snapshots (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    widget_id TEXT NOT NULL,
    payload_json TEXT DEFAULT '{}',
    generated_at TEXT DEFAULT (datetime('now')),
    source_run_id TEXT,
    status TEXT DEFAULT 'ready',
    FOREIGN KEY (widget_id) REFERENCES ai_widgets(id) ON DELETE CASCADE,
    FOREIGN KEY (source_run_id) REFERENCES agent_runs(id) ON DELETE SET NULL
  );

  CREATE INDEX IF NOT EXISTS idx_ai_widgets_user ON ai_widgets(user_id, updated_at DESC);
  CREATE INDEX IF NOT EXISTS idx_ai_widgets_agent ON ai_widgets(user_id, agent_id, updated_at DESC);
  CREATE INDEX IF NOT EXISTS idx_ai_widget_snapshots_widget ON ai_widget_snapshots(widget_id, id DESC);

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
    scope_type TEXT DEFAULT 'agent',
    scope_id TEXT,
    source_type TEXT,
    source_id TEXT,
    source_label TEXT,
    stale_after_days INTEGER,
    metadata_json TEXT DEFAULT '{}',
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

  CREATE TABLE IF NOT EXISTS assistant_self_state (
    user_id INTEGER NOT NULL,
    agent_id TEXT NOT NULL,
    identity_json TEXT DEFAULT '{}',
    focus_json TEXT DEFAULT '{}',
    updated_at TEXT DEFAULT (datetime('now')),
    PRIMARY KEY (user_id, agent_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE CASCADE
  );

  CREATE TABLE IF NOT EXISTS agent_run_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    run_id TEXT NOT NULL,
    user_id INTEGER NOT NULL,
    agent_id TEXT,
    event_type TEXT NOT NULL,
    request_id TEXT,
    step_id TEXT,
    sequence_index INTEGER DEFAULT 0,
    payload_json TEXT DEFAULT '{}',
    created_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (run_id) REFERENCES agent_runs(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE SET NULL
  );

  CREATE INDEX IF NOT EXISTS idx_agent_run_events_run ON agent_run_events(run_id, sequence_index, id);
  CREATE INDEX IF NOT EXISTS idx_agent_run_events_user ON agent_run_events(user_id, created_at DESC);

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

  CREATE TABLE IF NOT EXISTS screen_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    timestamp TEXT DEFAULT (datetime('now')),
    app_name TEXT,
    text_content TEXT,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  );

  CREATE TABLE IF NOT EXISTS notification_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    app_package TEXT,
    title TEXT,
    body TEXT,
    timestamp TEXT DEFAULT (datetime('now')),
    action_taken TEXT,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  );

  CREATE TABLE IF NOT EXISTS geofences (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    label TEXT,
    latitude REAL NOT NULL,
    longitude REAL NOT NULL,
    radius_meters INTEGER NOT NULL,
    trigger_action TEXT,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  );

  CREATE INDEX IF NOT EXISTS idx_screen_history_user ON screen_history(user_id, timestamp DESC);
  CREATE INDEX IF NOT EXISTS idx_notification_history_user ON notification_history(user_id, timestamp DESC);

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
    CREATE VIRTUAL TABLE IF NOT EXISTS screen_history_fts USING fts5(
      text_content,
      app_name,
      timestamp UNINDEXED,
      user_id UNINDEXED,
      tokenize = 'porter unicode61'
    );

    CREATE TRIGGER IF NOT EXISTS screen_history_fts_ai AFTER INSERT ON screen_history BEGIN
      INSERT INTO screen_history_fts(rowid, text_content, app_name, timestamp, user_id)
      VALUES (new.id, COALESCE(new.text_content, ''), COALESCE(new.app_name, ''), new.timestamp, new.user_id);
    END;

    CREATE TRIGGER IF NOT EXISTS screen_history_fts_ad AFTER DELETE ON screen_history BEGIN
      DELETE FROM screen_history_fts WHERE rowid = old.id;
    END;

    CREATE TRIGGER IF NOT EXISTS screen_history_fts_au AFTER UPDATE ON screen_history BEGIN
      DELETE FROM screen_history_fts WHERE rowid = old.id;
      INSERT INTO screen_history_fts(rowid, text_content, app_name, timestamp, user_id)
      VALUES (new.id, COALESCE(new.text_content, ''), COALESCE(new.app_name, ''), new.timestamp, new.user_id);
    END;

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

try {
  db.exec(`
    DROP INDEX IF EXISTS idx_wearable_pairing_codes_user;
    DROP INDEX IF EXISTS idx_wearable_pairing_codes_agent;
    DROP INDEX IF EXISTS idx_wearable_device_tokens_user;
    DROP INDEX IF EXISTS idx_wearable_device_tokens_mac;
    DROP INDEX IF EXISTS idx_wearable_device_cursors_updated;
    DROP TABLE IF EXISTS wearable_device_message_cursors;
    DROP TABLE IF EXISTS wearable_device_tokens;
    DROP TABLE IF EXISTS wearable_pairing_codes;
    DROP TABLE IF EXISTS wearable_devices;
  `);
} catch {
  // Ignore cleanup failures for obsolete wearable tables.
}

// Migrations for existing databases
for (const col of [
  "ALTER TABLE agent_runs ADD COLUMN agent_id TEXT",
  "ALTER TABLE agents ADD COLUMN can_delegate INTEGER",
  "ALTER TABLE agents ADD COLUMN can_be_delegated_to INTEGER",
  "ALTER TABLE agents ADD COLUMN delegate_targets_json TEXT",
  "ALTER TABLE users ADD COLUMN email_verified_at TEXT",
  "ALTER TABLE users ADD COLUMN password_login_enabled INTEGER DEFAULT 1",
  "ALTER TABLE messages ADD COLUMN agent_id TEXT",
  "ALTER TABLE platform_connections ADD COLUMN agent_id TEXT",
  "ALTER TABLE mcp_servers ADD COLUMN agent_id TEXT",
  "ALTER TABLE integration_connections ADD COLUMN agent_id TEXT",
  "ALTER TABLE integration_oauth_states ADD COLUMN agent_id TEXT",
  "ALTER TABLE scheduled_tasks ADD COLUMN agent_id TEXT",
  "ALTER TABLE scheduled_tasks ADD COLUMN trigger_type TEXT DEFAULT 'schedule'",
  "ALTER TABLE scheduled_tasks ADD COLUMN trigger_config TEXT DEFAULT '{}'",
  "ALTER TABLE conversations ADD COLUMN agent_id TEXT",
  "ALTER TABLE conversation_history ADD COLUMN agent_id TEXT",
  "ALTER TABLE memories ADD COLUMN agent_id TEXT",
  "ALTER TABLE core_memory ADD COLUMN agent_id TEXT",
  "ALTER TABLE ai_widgets ADD COLUMN widget_kind TEXT DEFAULT 'custom'",
  "ALTER TABLE ai_widgets ADD COLUMN system_key TEXT",
  "ALTER TABLE ai_widgets ADD COLUMN is_system INTEGER DEFAULT 0",
  "ALTER TABLE memories ADD COLUMN scope_type TEXT DEFAULT 'agent'",
  "ALTER TABLE memories ADD COLUMN scope_id TEXT",
  "ALTER TABLE memories ADD COLUMN source_type TEXT",
  "ALTER TABLE memories ADD COLUMN source_id TEXT",
  "ALTER TABLE memories ADD COLUMN source_label TEXT",
  "ALTER TABLE memories ADD COLUMN stale_after_days INTEGER",
  "ALTER TABLE memories ADD COLUMN metadata_json TEXT DEFAULT '{}'",
  "ALTER TABLE scheduled_tasks ADD COLUMN run_at TEXT",
  "ALTER TABLE scheduled_tasks ADD COLUMN one_time INTEGER DEFAULT 0",
  "ALTER TABLE scheduled_tasks ADD COLUMN execution_mode TEXT DEFAULT 'prompt'",
  "ALTER TABLE scheduled_tasks ADD COLUMN last_triggered_at TEXT",
  "ALTER TABLE scheduled_tasks ADD COLUMN last_trigger_fingerprint TEXT",
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
  "ALTER TABLE desktop_companion_devices ADD COLUMN activation_id TEXT",
  "ALTER TABLE desktop_companion_devices ADD COLUMN app_version TEXT",
  "ALTER TABLE desktop_companion_devices ADD COLUMN companion_enabled INTEGER DEFAULT 0",
  "ALTER TABLE desktop_companion_devices ADD COLUMN paused INTEGER DEFAULT 0",
  "ALTER TABLE desktop_companion_devices ADD COLUMN status TEXT DEFAULT 'offline'",
  "ALTER TABLE desktop_companion_devices ADD COLUMN display_count INTEGER DEFAULT 0",
  "ALTER TABLE desktop_companion_devices ADD COLUMN active_display_id TEXT",
  "ALTER TABLE desktop_companion_devices ADD COLUMN permissions_json TEXT DEFAULT '{}'",
  "ALTER TABLE desktop_companion_devices ADD COLUMN capabilities_json TEXT DEFAULT '{}'",
  "ALTER TABLE desktop_companion_devices ADD COLUMN metadata_json TEXT DEFAULT '{}'",
  "ALTER TABLE desktop_companion_devices ADD COLUMN session_id INTEGER",
  "ALTER TABLE desktop_companion_devices ADD COLUMN last_connected_at TEXT",
  "ALTER TABLE desktop_companion_devices ADD COLUMN last_seen_at TEXT",
  "ALTER TABLE desktop_companion_devices ADD COLUMN revoked_at TEXT",
  "ALTER TABLE desktop_companion_devices ADD COLUMN updated_at TEXT DEFAULT (datetime('now'))",
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
    ['integration_provider_configs', 'CREATE INDEX IF NOT EXISTS idx_integration_provider_configs_agent ON integration_provider_configs(user_id, agent_id, provider_key)'],
    ['messages', 'CREATE INDEX IF NOT EXISTS idx_messages_agent ON messages(user_id, agent_id, created_at DESC)'],
    ['conversations', 'CREATE INDEX IF NOT EXISTS idx_conversations_agent ON conversations(user_id, agent_id, updated_at DESC)'],
    ['scheduled_tasks', 'CREATE INDEX IF NOT EXISTS idx_scheduled_tasks_agent ON scheduled_tasks(user_id, agent_id)'],
    ['conversation_history', 'CREATE INDEX IF NOT EXISTS idx_conv_history_agent ON conversation_history(user_id, agent_id, created_at DESC)'],
    ['memories', 'CREATE INDEX IF NOT EXISTS idx_memories_agent ON memories(user_id, agent_id, archived, updated_at DESC)'],
    ['memories', 'CREATE INDEX IF NOT EXISTS idx_memories_scope ON memories(user_id, agent_id, scope_type, scope_id, archived, updated_at DESC)'],
    ['core_memory', 'CREATE INDEX IF NOT EXISTS idx_core_memory_agent ON core_memory(user_id, agent_id, key)'],
    ['ai_widgets', 'CREATE UNIQUE INDEX IF NOT EXISTS idx_ai_widgets_system_key ON ai_widgets(user_id, agent_id, system_key) WHERE system_key IS NOT NULL'],
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
    'integration_provider_configs',
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

function migrateIntegrationProviderConfigsTable() {
  if (
    tableHasColumn('integration_provider_configs', 'agent_id') &&
    tableHasUniqueIndex('integration_provider_configs', ['user_id', 'agent_id', 'provider_key'])
  ) {
    const users = db.prepare('SELECT id FROM users').all();
    for (const user of users) {
      const agentId = getMainAgentId(user.id);
      db.prepare(
        'UPDATE integration_provider_configs SET agent_id = ? WHERE user_id = ? AND agent_id IS NULL'
      ).run(agentId, user.id);
    }
    return;
  }

  const rows = db
    .prepare('SELECT * FROM integration_provider_configs ORDER BY id ASC')
    .all();

  db.exec('BEGIN');
  try {
    db.exec(`
      ALTER TABLE integration_provider_configs RENAME TO integration_provider_configs_legacy_agent_scope;

      CREATE TABLE integration_provider_configs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        agent_id TEXT,
        provider_key TEXT NOT NULL,
        config_json TEXT DEFAULT '{}',
        created_at TEXT DEFAULT (datetime('now')),
        updated_at TEXT DEFAULT (datetime('now')),
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE SET NULL,
        UNIQUE(user_id, agent_id, provider_key)
      );
    `);
    const insert = db.prepare(`
      INSERT OR REPLACE INTO integration_provider_configs (
        id,
        user_id,
        agent_id,
        provider_key,
        config_json,
        created_at,
        updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
    `);

    for (const row of rows) {
      insert.run(
        row.id,
        row.user_id,
        row.agent_id || getMainAgentId(row.user_id),
        row.provider_key,
        row.config_json,
        row.created_at,
        row.updated_at,
      );
    }

    db.exec(`
      DROP TABLE integration_provider_configs_legacy_agent_scope;
      CREATE INDEX IF NOT EXISTS idx_integration_provider_configs_agent
        ON integration_provider_configs(user_id, agent_id, provider_key);
    `);
    db.exec('COMMIT');
  } catch (error) {
    try {
      db.exec('ROLLBACK');
    } catch {
      // Ignore rollback errors and rethrow the original migration failure.
    }
    throw error;
  }
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

  try {
    const providerRows = db
      .prepare('SELECT id, config_json FROM integration_provider_configs')
      .all();
    const updateProviderConfig = db.prepare(
      'UPDATE integration_provider_configs SET config_json = ? WHERE id = ?',
    );
    for (const row of providerRows) {
      const current = String(row.config_json || '');
      if (!current || isEncryptedValue(current)) continue;
      updateProviderConfig.run(encryptValue(current), row.id);
    }
  } catch {
    // Preserve startup even if a row cannot be re-encrypted.
  }
}

function backfillVerifiedAccountEmails() {
  try {
    if (!tableHasColumn('users', 'email_verified_at')) return;
    db.prepare(`
      UPDATE users
      SET email_verified_at = COALESCE(created_at, datetime('now'))
      WHERE email IS NOT NULL
        AND trim(email) != ''
        AND email_verified_at IS NULL
    `).run();
  } catch {
    // Existing local accounts should not be locked out by a best-effort backfill.
  }
}

function backfillTaskTriggers() {
  try {
    db.prepare(
      `UPDATE scheduled_tasks
       SET trigger_type = CASE
         WHEN COALESCE(trigger_type, '') = '' THEN 'schedule'
         ELSE trigger_type
       END`
    ).run();
  } catch {}

  try {
    const rows = db
      .prepare(
        `SELECT id, cron_expression, run_at, one_time, trigger_type, trigger_config
         FROM scheduled_tasks`,
      )
      .all();
    const update = db.prepare(
      `UPDATE scheduled_tasks
       SET trigger_type = ?, trigger_config = ?, execution_mode = COALESCE(NULLIF(execution_mode, ''), 'prompt')
       WHERE id = ?`,
    );
    const tx = db.transaction(() => {
      for (const row of rows) {
        const triggerType = String(row.trigger_type || 'schedule').trim() || 'schedule';
        let parsedConfig = {};
        try {
          parsedConfig = JSON.parse(String(row.trigger_config || '{}')) || {};
        } catch {
          parsedConfig = {};
        }
        const hasConfig = parsedConfig && typeof parsedConfig === 'object' && !Array.isArray(parsedConfig) && Object.keys(parsedConfig).length > 0;
        if (triggerType !== 'schedule' && hasConfig) {
          update.run(triggerType, JSON.stringify(parsedConfig), row.id);
          continue;
        }

        const mode = row.one_time ? 'one_time' : 'recurring';
        const config = row.one_time
          ? { mode, runAt: row.run_at || null }
          : { mode, cronExpression: row.cron_expression || null };
        update.run('schedule', JSON.stringify(config), row.id);
      }
    });
    tx();
  } catch {}
}

backfillAgentIds();
backfillAgentPolicies();
backfillTaskTriggers();
rebuildPlatformConnectionsForAgents();
rebuildCoreMemoryForAgents();
migrateIntegrationConnectionsTable();
migrateIntegrationOauthStatesTable();
migrateIntegrationProviderConfigsTable();
createAgentScopedIndexes();
backfillAgentIds();
migrateIntegrationSecretStorage();
backfillVerifiedAccountEmails();
rebuildFtsForAgents();

function migrateUsersOnboarding() {
  try {
    const columns = db.pragma('table_info(users)');
    const hasOnboardingCol = columns.some((c) => c.name === 'has_completed_onboarding');
    if (!hasOnboardingCol) {
      db.exec('ALTER TABLE users ADD COLUMN has_completed_onboarding INTEGER DEFAULT 0');
    }
  } catch (err) {
    console.warn('Could not add has_completed_onboarding column:', err.message);
  }
}
migrateUsersOnboarding();

function migrateUsersDisplayName() {
  try {
    const columns = db.pragma('table_info(users)');
    const hasDisplayNameCol = columns.some((c) => c.name === 'display_name');
    if (!hasDisplayNameCol) {
      db.exec('ALTER TABLE users ADD COLUMN display_name TEXT');
    }
  } catch (err) {
    console.warn('Could not add display_name column:', err.message);
  }
}
migrateUsersDisplayName();

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
