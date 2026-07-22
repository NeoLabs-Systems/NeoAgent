'use strict';

function migrateMemoryEmbeddingIndex(db) {
  db.exec(`
    CREATE TABLE IF NOT EXISTS memory_embedding_bands (
      memory_id TEXT NOT NULL,
      user_id INTEGER NOT NULL,
      agent_id TEXT NOT NULL,
      dimension INTEGER NOT NULL,
      index_version INTEGER NOT NULL DEFAULT 3,
      band_index INTEGER NOT NULL,
      band_value INTEGER NOT NULL,
      updated_at TEXT DEFAULT (datetime('now')),
      PRIMARY KEY (memory_id, band_index),
      FOREIGN KEY (memory_id) REFERENCES memories(id) ON DELETE CASCADE,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    );

    CREATE INDEX IF NOT EXISTS idx_memory_embedding_bands_lookup
      ON memory_embedding_bands(
        user_id,
        agent_id,
        dimension,
        band_index,
        band_value
      );
  `);
  const columns = new Set(
    db.prepare('PRAGMA table_info(memory_embedding_bands)').all()
      .map((column) => column.name),
  );
  if (!columns.has('index_version')) {
    db.exec('ALTER TABLE memory_embedding_bands ADD COLUMN index_version INTEGER');
  }
  db.exec(`
    DROP INDEX IF EXISTS idx_memory_embedding_bands_lookup;
    CREATE INDEX idx_memory_embedding_bands_lookup
      ON memory_embedding_bands(
        user_id,
        agent_id,
        dimension,
        index_version,
        band_index,
        band_value
      );
  `);
}

function removeRetiredCaptureData(db) {
  migrateLegacyTranscriptionSettings(db);

  for (const table of [
    'screen_history_fts',
    'screen_history',
    'recording_transcript_segments',
    'recording_chunks',
    'recording_sources',
    'recording_sessions',
  ]) {
    db.exec(`DROP TABLE IF EXISTS ${table}`);
  }

  db.prepare("DELETE FROM timeline_events WHERE source_kind = 'screen'").run();

  for (const column of [
    'passive_history_enabled',
    'passive_history_last_uploaded_at',
    'passive_history_last_error',
  ]) {
    try {
      db.exec(`ALTER TABLE desktop_companion_devices DROP COLUMN ${column}`);
    } catch {
      // The column was already removed or never existed.
    }
  }
}

function migrateLegacyTranscriptionSettings(db) {
  const keyMappings = [
    ['default_recording_transcription_provider', 'voice_stt_provider'],
    ['default_recording_transcription_model', 'voice_stt_model'],
  ];

  const migrateUserSetting = db.prepare(`
    INSERT INTO user_settings (user_id, key, value)
    SELECT source.user_id, ?, source.value
    FROM user_settings AS source
    WHERE source.key = ?
      AND NOT EXISTS (
        SELECT 1
        FROM user_settings AS target
        WHERE target.user_id = source.user_id
          AND target.key = ?
      )
  `);
  const migrateAgentSetting = db.prepare(`
    INSERT INTO agent_settings (user_id, agent_id, key, value)
    SELECT source.user_id, source.agent_id, ?, source.value
    FROM agent_settings AS source
    WHERE source.key = ?
      AND NOT EXISTS (
        SELECT 1
        FROM agent_settings AS target
        WHERE target.user_id = source.user_id
          AND target.agent_id = source.agent_id
          AND target.key = ?
      )
  `);

  const transaction = db.transaction(() => {
    for (const [legacyKey, currentKey] of keyMappings) {
      migrateUserSetting.run(currentKey, legacyKey, currentKey);
      migrateAgentSetting.run(currentKey, legacyKey, currentKey);
      db.prepare('DELETE FROM user_settings WHERE key = ?').run(legacyKey);
      db.prepare('DELETE FROM agent_settings WHERE key = ?').run(legacyKey);
    }
  });
  transaction();
}

function migrateMemoryProvenance(db) {
  db.exec(`
    CREATE TABLE IF NOT EXISTS memory_source_chunks (
      id TEXT PRIMARY KEY,
      document_id TEXT NOT NULL,
      user_id INTEGER NOT NULL,
      agent_id TEXT NOT NULL,
      chunk_index INTEGER NOT NULL,
      char_start INTEGER NOT NULL,
      char_end INTEGER NOT NULL,
      content TEXT NOT NULL,
      content_hash TEXT NOT NULL,
      metadata_json TEXT DEFAULT '{}',
      created_at TEXT DEFAULT (datetime('now')),
      updated_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (document_id) REFERENCES memory_ingestion_documents(id) ON DELETE CASCADE,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      UNIQUE(document_id, content_hash)
    );

    CREATE TABLE IF NOT EXISTS memory_source_links (
      memory_id TEXT NOT NULL,
      chunk_id TEXT NOT NULL,
      source_document_id TEXT NOT NULL,
      source_timestamp TEXT,
      relevance_score REAL DEFAULT 1,
      extraction_method TEXT DEFAULT 'source_chunk',
      metadata_json TEXT DEFAULT '{}',
      created_at TEXT DEFAULT (datetime('now')),
      PRIMARY KEY (memory_id, chunk_id),
      FOREIGN KEY (memory_id) REFERENCES memories(id) ON DELETE CASCADE,
      FOREIGN KEY (chunk_id) REFERENCES memory_source_chunks(id) ON DELETE CASCADE,
      FOREIGN KEY (source_document_id) REFERENCES memory_ingestion_documents(id) ON DELETE CASCADE
    );

    CREATE INDEX IF NOT EXISTS idx_memory_source_chunks_document
      ON memory_source_chunks(document_id, chunk_index);
    CREATE INDEX IF NOT EXISTS idx_memory_source_links_memory
      ON memory_source_links(memory_id);
    CREATE INDEX IF NOT EXISTS idx_memory_source_links_document
      ON memory_source_links(source_document_id);
  `);
}

function migrateMemoryRelations(db) {
  db.exec(`
    CREATE TABLE IF NOT EXISTS memory_relations (
      id TEXT PRIMARY KEY,
      user_id INTEGER NOT NULL,
      agent_id TEXT,
      from_memory_id TEXT NOT NULL,
      to_memory_id TEXT NOT NULL,
      relation_type TEXT NOT NULL CHECK(relation_type IN ('updates', 'extends', 'derives')),
      confidence REAL DEFAULT 0.7,
      metadata_json TEXT DEFAULT '{}',
      created_at TEXT DEFAULT (datetime('now')),
      UNIQUE(from_memory_id, to_memory_id, relation_type),
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE SET NULL,
      FOREIGN KEY (from_memory_id) REFERENCES memories(id) ON DELETE CASCADE,
      FOREIGN KEY (to_memory_id) REFERENCES memories(id) ON DELETE CASCADE
    );

    CREATE INDEX IF NOT EXISTS idx_memory_relations_from
      ON memory_relations(user_id, agent_id, from_memory_id);
    CREATE INDEX IF NOT EXISTS idx_memory_relations_to
      ON memory_relations(user_id, agent_id, to_memory_id);
  `);
}

function migrateMemoryRetrievalEvents(db) {
  db.exec(`
    CREATE TABLE IF NOT EXISTS memory_retrieval_events (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      agent_id TEXT NOT NULL,
      query_hash TEXT NOT NULL,
      scope_type TEXT NOT NULL,
      scope_id TEXT,
      requested_k INTEGER NOT NULL,
      candidate_count INTEGER DEFAULT 0,
      semantic_candidate_count INTEGER DEFAULT 0,
      lexical_candidate_count INTEGER DEFAULT 0,
      entity_candidate_count INTEGER DEFAULT 0,
      relation_candidate_count INTEGER DEFAULT 0,
      result_count INTEGER DEFAULT 0,
      result_ids_json TEXT DEFAULT '[]',
      context_tokens_estimate INTEGER DEFAULT 0,
      latency_ms REAL DEFAULT 0,
      created_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    );

    CREATE INDEX IF NOT EXISTS idx_memory_retrieval_events_user
      ON memory_retrieval_events(user_id, agent_id, created_at DESC);

    CREATE TABLE IF NOT EXISTS memory_retrieval_enhancements (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      agent_id TEXT NOT NULL,
      run_id TEXT,
      query_hash TEXT NOT NULL,
      trigger_reason TEXT NOT NULL,
      plan_json TEXT,
      initial_count INTEGER DEFAULT 0,
      merged_count INTEGER DEFAULT 0,
      result_ids_json TEXT DEFAULT '[]',
      latency_ms REAL DEFAULT 0,
      created_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      FOREIGN KEY (run_id) REFERENCES agent_runs(id) ON DELETE SET NULL
    );

    CREATE INDEX IF NOT EXISTS idx_memory_retrieval_enhancements_user
      ON memory_retrieval_enhancements(user_id, agent_id, created_at DESC);
  `);
}

function migrateMemoryEmbeddingMetadata(db) {
  const columns = new Set(
    db.prepare('PRAGMA table_info(memories)').all().map((column) => column.name),
  );
  const additions = [
    ['embedding_provider', 'TEXT'],
    ['embedding_model', 'TEXT'],
    ['embedding_dimensions', 'INTEGER'],
    ['embedded_at', 'TEXT'],
  ];
  for (const [name, type] of additions) {
    if (!columns.has(name)) {
      db.exec(`ALTER TABLE memories ADD COLUMN ${name} ${type}`);
    }
  }
  try {
    db.exec(`
      UPDATE memories
      SET embedding_dimensions = json_array_length(embedding),
          embedding_provider = COALESCE(embedding_provider, 'legacy_unknown')
      WHERE embedding IS NOT NULL AND embedding_dimensions IS NULL
    `);
  } catch {
    // JSON1 may be unavailable. New writes still carry complete metadata.
  }
}

function migrateMemoryRetentionMetadata(db) {
  const columns = new Set(
    db.prepare('PRAGMA table_info(memories)').all().map((column) => column.name),
  );
  const additions = [
    ['memory_strength', 'REAL DEFAULT 1'],
    ['last_accessed_at', 'TEXT'],
    ['pinned', 'INTEGER DEFAULT 0'],
  ];
  for (const [name, type] of additions) {
    if (!columns.has(name)) {
      db.exec(`ALTER TABLE memories ADD COLUMN ${name} ${type}`);
    }
  }
  db.exec(`
    UPDATE memories
    SET memory_strength = COALESCE(memory_strength, 1),
        pinned = COALESCE(pinned, 0)
  `);
}

function migrateMemoryExactHashUniqueness(db) {
  const columns = new Set(
    db.prepare('PRAGMA table_info(memories)').all().map((column) => column.name),
  );
  if (!columns.has('memory_hash')) return;

  const groups = db.prepare(
    `SELECT
       user_id,
       COALESCE(agent_id, '') AS agent_key,
       memory_hash,
       COALESCE(scope_type, 'agent') AS scope_type_key,
       COALESCE(scope_id, '') AS scope_id_key,
       COUNT(*) AS duplicate_count
     FROM memories
     WHERE archived = 0
       AND memory_hash IS NOT NULL
       AND trim(memory_hash) <> ''
     GROUP BY
       user_id,
       COALESCE(agent_id, ''),
       memory_hash,
       COALESCE(scope_type, 'agent'),
       COALESCE(scope_id, '')
     HAVING COUNT(*) > 1`
  ).all();

  const selectGroupRows = db.prepare(
    `SELECT id, importance, confidence, access_count
     FROM memories
     WHERE user_id = ?
       AND COALESCE(agent_id, '') = ?
       AND memory_hash = ?
       AND COALESCE(scope_type, 'agent') = ?
       AND COALESCE(scope_id, '') = ?
       AND archived = 0
     ORDER BY updated_at DESC, created_at DESC, id DESC`
  );

  const archiveDuplicates = db.transaction(() => {
    for (const group of groups) {
      const rows = selectGroupRows.all(
        group.user_id,
        group.agent_key,
        group.memory_hash,
        group.scope_type_key,
        group.scope_id_key,
      );
      if (rows.length < 2) continue;

      const winner = rows[0];
      const mergedImportance = Math.max(...rows.map((row) => Number(row.importance || 0)));
      const mergedConfidence = Math.max(...rows.map((row) => Number(row.confidence || 0)));
      const mergedAccessCount = rows.reduce(
        (sum, row) => sum + Math.max(0, Number(row.access_count || 0)),
        0,
      );

      db.prepare(
        `UPDATE memories
         SET importance = MAX(importance, ?),
             confidence = MAX(confidence, ?),
             access_count = ?,
             updated_at = datetime('now')
         WHERE id = ?`
      ).run(
        mergedImportance,
        Math.min(1, mergedConfidence),
        mergedAccessCount,
        winner.id,
      );

      const duplicateIds = rows.slice(1).map((row) => row.id);
      if (!duplicateIds.length) continue;
      const placeholders = duplicateIds.map(() => '?').join(', ');
      db.prepare(
        `UPDATE memories
         SET archived = 1,
             updated_at = datetime('now')
         WHERE id IN (${placeholders})`
      ).run(...duplicateIds);
    }
  });
  archiveDuplicates();

  db.exec(`
    CREATE UNIQUE INDEX IF NOT EXISTS idx_memories_hash_unique
      ON memories(
        user_id,
        COALESCE(agent_id, ''),
        memory_hash,
        COALESCE(scope_type, 'agent'),
        COALESCE(scope_id, '')
      )
      WHERE archived = 0 AND memory_hash IS NOT NULL
  `);
}

function migrateSkillOwnership(db) {
  const tableInfo = db.prepare("PRAGMA table_info(skills)").all();
  if (!tableInfo.length) return;

  const skillsSql = db.prepare(
    "SELECT sql FROM sqlite_master WHERE type='table' AND name='skills'",
  ).get()?.sql || '';
  const hasUserIdColumn = tableInfo.some((column) => column.name === 'user_id');
  const hasLegacyNameUniqueConstraint = /\bname\s+TEXT\s+UNIQUE\b/i.test(skillsSql);

  if (!hasUserIdColumn || hasLegacyNameUniqueConstraint) {
    db.exec(`
      DROP TABLE IF EXISTS skills_v2;
      CREATE TABLE IF NOT EXISTS skills_v2 (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL DEFAULT 0,
        name TEXT NOT NULL,
        description TEXT,
        file_path TEXT NOT NULL,
        metadata TEXT DEFAULT '{}',
        enabled INTEGER DEFAULT 1,
        auto_created INTEGER DEFAULT 0,
        created_at TEXT DEFAULT (datetime('now')),
        updated_at TEXT DEFAULT (datetime('now'))
      );
    `);

    if (hasUserIdColumn) {
      db.exec(`
        INSERT INTO skills_v2 (
          id, user_id, name, description, file_path, metadata,
          enabled, auto_created, created_at, updated_at
        )
        SELECT
          id,
          COALESCE(user_id, 0),
          name,
          description,
          file_path,
          COALESCE(metadata, '{}'),
          COALESCE(enabled, 1),
          COALESCE(auto_created, 0),
          created_at,
          updated_at
        FROM skills
      `);
    } else {
      db.exec(`
        INSERT INTO skills_v2 (
          id, user_id, name, description, file_path, metadata,
          enabled, auto_created, created_at, updated_at
        )
        SELECT
          id,
          0,
          name,
          description,
          file_path,
          COALESCE(metadata, '{}'),
          COALESCE(enabled, 1),
          COALESCE(auto_created, 0),
          created_at,
          updated_at
        FROM skills
      `);
    }

    db.exec(`
      DROP TABLE skills;
      ALTER TABLE skills_v2 RENAME TO skills;
    `);
  } else {
    db.exec('UPDATE skills SET user_id = 0 WHERE user_id IS NULL');
  }

  db.exec(`
    CREATE UNIQUE INDEX IF NOT EXISTS idx_skills_user_name
      ON skills(user_id, name);
    CREATE INDEX IF NOT EXISTS idx_skills_user_enabled
      ON skills(user_id, enabled, name);
  `);
}

function migrateToolPermissions(db) {
  db.exec(`
    CREATE TABLE IF NOT EXISTS tool_policies (
      user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      category   TEXT    NOT NULL,
      policy     TEXT    NOT NULL CHECK(policy IN ('allow','deny','require_approval','allow_always')),
      updated_at TEXT    DEFAULT (datetime('now')),
      PRIMARY KEY (user_id, category)
    );

    CREATE TABLE IF NOT EXISTS tool_approval_log (
      id             TEXT    PRIMARY KEY,
      user_id        INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      run_id         TEXT    NOT NULL,
      tool_name      TEXT    NOT NULL,
      tool_args_json TEXT,
      decision       TEXT    NOT NULL CHECK(decision IN ('approved','denied','timeout')),
      scope          TEXT    NOT NULL CHECK(scope IN ('once','session','always')),
      decided_at     TEXT    DEFAULT (datetime('now'))
    );

    CREATE INDEX IF NOT EXISTS idx_approval_log_user
      ON tool_approval_log(user_id, decided_at DESC);
  `);
}

function migrateApprovalPersistence(db) {
  db.exec(`
    CREATE TABLE IF NOT EXISTS pending_approvals (
      id             TEXT PRIMARY KEY,
      user_id        INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      run_id         TEXT REFERENCES agent_runs(id) ON DELETE CASCADE,
      tool_name      TEXT NOT NULL,
      tool_args_json TEXT,
      category       TEXT,
      status         TEXT NOT NULL CHECK(status IN ('pending','approved','denied','timeout','expired')),
      scope          TEXT CHECK(scope IN ('once','session','always')),
      expires_at     TEXT NOT NULL,
      decided_at     TEXT,
      created_at     TEXT DEFAULT (datetime('now')),
      updated_at     TEXT DEFAULT (datetime('now'))
    );

    CREATE INDEX IF NOT EXISTS idx_pending_approvals_user
      ON pending_approvals(user_id, status, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_pending_approvals_run
      ON pending_approvals(run_id, status, expires_at);

    CREATE TABLE IF NOT EXISTS approval_session_grants (
      user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      run_id     TEXT NOT NULL,
      tool_name  TEXT NOT NULL,
      expires_at TEXT NOT NULL,
      created_at TEXT DEFAULT (datetime('now')),
      updated_at TEXT DEFAULT (datetime('now')),
      PRIMARY KEY (user_id, run_id, tool_name)
    );

    CREATE INDEX IF NOT EXISTS idx_approval_session_grants_expiry
      ON approval_session_grants(expires_at);
  `);
}

function migrateToolPoliciesAllowAlways(db) {
  // SQLite doesn't support ALTER COLUMN — recreate the table to add 'allow_always'
  // to the CHECK constraint on existing installations.
  const tableInfo = db.prepare("PRAGMA table_info(tool_policies)").all();
  if (!tableInfo.length) return; // table doesn't exist yet; migrateToolPermissions will create it correctly
  const checkRow = db.prepare(
    "SELECT sql FROM sqlite_master WHERE type='table' AND name='tool_policies'",
  ).get();
  if (checkRow && checkRow.sql.includes("'allow_always'")) return; // already migrated
  db.exec(`
    CREATE TABLE IF NOT EXISTS tool_policies_v2 (
      user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      category   TEXT    NOT NULL,
      policy     TEXT    NOT NULL CHECK(policy IN ('allow','deny','require_approval','allow_always')),
      updated_at TEXT    DEFAULT (datetime('now')),
      PRIMARY KEY (user_id, category)
    );
    INSERT OR IGNORE INTO tool_policies_v2 SELECT * FROM tool_policies;
    DROP TABLE tool_policies;
    ALTER TABLE tool_policies_v2 RENAME TO tool_policies;
  `);
}

function migrateBilling(db) {
  db.exec(`
    CREATE TABLE IF NOT EXISTS billing_plans (
      id                  TEXT PRIMARY KEY,
      name                TEXT NOT NULL,
      description         TEXT DEFAULT '',
      price_cents         INTEGER NOT NULL DEFAULT 0,
      currency            TEXT NOT NULL DEFAULT 'usd',
      interval            TEXT DEFAULT 'month',
      stripe_price_id     TEXT,
      token_limit_4h      INTEGER,
      token_limit_weekly  INTEGER,
      allowed_models_json TEXT DEFAULT '[]',
      features_json       TEXT DEFAULT '[]',
      is_active           INTEGER DEFAULT 1,
      sort_order          INTEGER DEFAULT 0,
      created_at          TEXT DEFAULT (datetime('now')),
      updated_at          TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS billing_customers (
      user_id            INTEGER PRIMARY KEY,
      stripe_customer_id TEXT UNIQUE,
      created_at         TEXT DEFAULT (datetime('now')),
      updated_at         TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS user_subscriptions (
      id                     TEXT PRIMARY KEY,
      user_id                INTEGER NOT NULL,
      plan_id                TEXT NOT NULL,
      stripe_subscription_id TEXT UNIQUE,
      status                 TEXT NOT NULL,
      trial_ends_at          TEXT,
      current_period_start   TEXT,
      current_period_end     TEXT,
      cancel_at_period_end   INTEGER DEFAULT 0,
      canceled_at            TEXT,
      created_at             TEXT DEFAULT (datetime('now')),
      updated_at             TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      FOREIGN KEY (plan_id) REFERENCES billing_plans(id)
    );

    CREATE TABLE IF NOT EXISTS subscription_events (
      id              INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id         INTEGER NOT NULL,
      subscription_id TEXT,
      event_type      TEXT NOT NULL,
      stripe_event_id TEXT UNIQUE,
      payload_json    TEXT DEFAULT '{}',
      created_at      TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS trial_fingerprints (
      id               INTEGER PRIMARY KEY AUTOINCREMENT,
      fingerprint_hash TEXT NOT NULL,
      fingerprint_type TEXT NOT NULL,
      user_id          INTEGER,
      used_at          TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
    );

    CREATE INDEX IF NOT EXISTS idx_billing_customers_stripe
      ON billing_customers(stripe_customer_id);

    CREATE INDEX IF NOT EXISTS idx_user_subscriptions_user
      ON user_subscriptions(user_id, status, updated_at DESC);

    CREATE INDEX IF NOT EXISTS idx_user_subscriptions_stripe
      ON user_subscriptions(stripe_subscription_id);

    CREATE INDEX IF NOT EXISTS idx_subscription_events_stripe
      ON subscription_events(stripe_event_id);

    CREATE INDEX IF NOT EXISTS idx_trial_fingerprints_hash
      ON trial_fingerprints(fingerprint_hash, fingerprint_type);
  `);
}

function migrateAgentRunLifecycle(db) {
  db.exec(`
    CREATE TABLE IF NOT EXISTS agent_run_controls (
      run_id       TEXT PRIMARY KEY,
      user_id      INTEGER NOT NULL,
      action       TEXT NOT NULL CHECK(action IN ('pause', 'stop', 'interrupt')),
      reason       TEXT DEFAULT '',
      requested_at TEXT DEFAULT (datetime('now')),
      consumed_at  TEXT,
      FOREIGN KEY (run_id) REFERENCES agent_runs(id) ON DELETE CASCADE,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS agent_run_checkpoints (
      run_id          TEXT PRIMARY KEY,
      version         INTEGER NOT NULL DEFAULT 1,
      phase           TEXT NOT NULL,
      state_json      TEXT NOT NULL DEFAULT '{}',
      created_at      TEXT DEFAULT (datetime('now')),
      updated_at      TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (run_id) REFERENCES agent_runs(id) ON DELETE CASCADE
    );

    CREATE INDEX IF NOT EXISTS idx_agent_run_controls_pending
      ON agent_run_controls(user_id, consumed_at, requested_at);
  `);
}

function runSchemaMigrations(db) {
  removeRetiredCaptureData(db);
  migrateMemoryEmbeddingIndex(db);
  migrateMemoryProvenance(db);
  migrateMemoryRelations(db);
  migrateMemoryRetrievalEvents(db);
  migrateMemoryEmbeddingMetadata(db);
  migrateMemoryRetentionMetadata(db);
  migrateMemoryExactHashUniqueness(db);
  migrateSkillOwnership(db);
  migrateToolPermissions(db);
  migrateApprovalPersistence(db);
  migrateToolPoliciesAllowAlways(db);
  migrateBilling(db);
  migrateAgentRunLifecycle(db);
}

module.exports = {
  migrateLegacyTranscriptionSettings,
  removeRetiredCaptureData,
  migrateMemoryEmbeddingIndex,
  migrateMemoryProvenance,
  migrateMemoryRelations,
  migrateMemoryRetrievalEvents,
  migrateMemoryEmbeddingMetadata,
  migrateMemoryRetentionMetadata,
  migrateMemoryExactHashUniqueness,
  migrateSkillOwnership,
  migrateToolPermissions,
  migrateApprovalPersistence,
  migrateToolPoliciesAllowAlways,
  migrateBilling,
  migrateAgentRunLifecycle,
  runSchemaMigrations,
};
