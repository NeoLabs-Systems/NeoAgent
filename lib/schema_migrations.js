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
    try {
      db.exec('ALTER TABLE memory_embedding_bands ADD COLUMN index_version INTEGER');
    } catch (error) {
      const refreshedColumns = new Set(
        db.prepare('PRAGMA table_info(memory_embedding_bands)').all()
          .map((column) => column.name),
      );
      if (!refreshedColumns.has('index_version')) throw error;
    }
  }
  const expectedIndexColumns = [
    'user_id',
    'agent_id',
    'dimension',
    'index_version',
    'band_index',
    'band_value',
  ];
  const indexColumns = db.prepare(
    'PRAGMA index_info(idx_memory_embedding_bands_lookup)',
  ).all().map((column) => column.name);
  if (indexColumns.join('\0') !== expectedIndexColumns.join('\0')) {
    db.exec(`
      DROP INDEX IF EXISTS idx_memory_embedding_bands_lookup;
      CREATE INDEX IF NOT EXISTS idx_memory_embedding_bands_lookup
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

function removeRetiredWidgetData(db) {
  db.prepare("DELETE FROM scheduled_tasks WHERE task_type = 'widget_refresh'").run();
  db.exec(`
    DROP TABLE IF EXISTS ai_widget_snapshots;
    DROP TABLE IF EXISTS ai_widgets;
  `);
}

function removeLegacyDeviceRegistrations(db) {
  const retiredKeys = [
    'browser_backend',
    'browser_extension_token_id',
    'selected_browser_extension_token_id',
    'cli_backend',
    'cli_desktop_device_id',
    'desktop_backend',
    'desktop_device_id',
  ];
  const placeholders = retiredKeys.map(() => '?').join(', ');
  db.prepare(`DELETE FROM user_settings WHERE key IN (${placeholders})`).run(...retiredKeys);
  db.exec(`
    DROP INDEX IF EXISTS idx_browser_extension_pairing_status;
    DROP INDEX IF EXISTS idx_browser_extension_tokens_user;
    DROP INDEX IF EXISTS idx_browser_extension_tokens_hash_status;
    DROP TABLE IF EXISTS browser_extension_pairing_requests;
    DROP TABLE IF EXISTS browser_extension_tokens;
  `);
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

function migrateSkillLearning(db) {
  // The retired observer only counted identical tool-name sequences. It never
  // retained enough semantic evidence to migrate into the new learner safely.
  db.exec('DROP TABLE IF EXISTS skill_workflow_observations');
  db.exec(`
    CREATE TABLE IF NOT EXISTS skill_learning_state (
      user_id INTEGER NOT NULL,
      agent_scope TEXT NOT NULL DEFAULT '',
      activity_score INTEGER NOT NULL DEFAULT 0,
      updated_at TEXT NOT NULL DEFAULT (datetime('now')),
      PRIMARY KEY (user_id, agent_scope),
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS skill_learning_candidates (
      id TEXT PRIMARY KEY,
      user_id INTEGER NOT NULL,
      workflow_key TEXT NOT NULL,
      title TEXT NOT NULL,
      summary TEXT NOT NULL DEFAULT '',
      observation_count INTEGER NOT NULL DEFAULT 1,
      latest_run_id TEXT,
      evidence_json TEXT NOT NULL DEFAULT '[]',
      status TEXT NOT NULL DEFAULT 'observing'
        CHECK(status IN ('observing', 'promoted', 'dismissed')),
      skill_name TEXT,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now')),
      UNIQUE(user_id, workflow_key),
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      FOREIGN KEY (latest_run_id) REFERENCES agent_runs(id) ON DELETE SET NULL
    );

    CREATE INDEX IF NOT EXISTS idx_skill_learning_candidates_user_status
      ON skill_learning_candidates(user_id, status, updated_at DESC);
  `);

  const legacyRows = db.prepare('SELECT id, name, metadata FROM skills').all();
  const updateLegacy = db.prepare(
    'UPDATE skills SET metadata = ?, enabled = ?, updated_at = datetime(\'now\') WHERE id = ?',
  );
  for (const row of legacyRows) {
    let metadata = {};
    try { metadata = JSON.parse(row.metadata || '{}'); } catch {}
    if (!['teach', 'auto-learned'].includes(metadata.source)) continue;
    const wasTaught = metadata.source === 'teach';
    metadata = {
      ...metadata,
      source: 'learned',
      category: wasTaught ? 'computer' : (metadata.category || 'learned'),
      learning: {
        managed: wasTaught,
        origin: wasTaught ? 'computer-demonstration' : 'legacy-draft',
        workflowKey: metadata.workflow_signature || row.name,
        observationCount: Number(metadata.evidence_count || 1),
        sourceRunIds: metadata.created_from_run ? [metadata.created_from_run] : [],
      },
    };
    updateLegacy.run(JSON.stringify(metadata), wasTaught ? 1 : 0, row.id);
  }
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

function migrateCoworkWorkspace(db) {
  const addColumns = (table, columns) => {
    const existing = new Set(
      db.prepare(`PRAGMA table_info(${table})`).all().map((column) => column.name),
    );
    for (const [name, type] of columns) {
      if (!existing.has(name)) db.exec(`ALTER TABLE ${table} ADD COLUMN ${name} ${type}`);
    }
  };

  addColumns('conversations', [
    ['interaction_mode', "TEXT NOT NULL DEFAULT 'agent'"],
    ['device_target_override', 'TEXT'],
    ['manually_titled', 'INTEGER NOT NULL DEFAULT 0'],
    ['workspace_path_override', 'TEXT'],
  ]);
  addColumns('conversation_messages', [
    ['run_id', 'TEXT'],
    ['agent_id', 'TEXT'],
    ['metadata_json', "TEXT NOT NULL DEFAULT '{}'"],
  ]);
  addColumns('agent_runs', [
    ['conversation_id', 'TEXT'],
    ['interaction_mode', "TEXT NOT NULL DEFAULT 'agent'"],
    ['device_target', 'TEXT'],
  ]);
  addColumns('conversation_history', [
    ['conversation_id', 'TEXT'],
  ]);

  db.exec(`
    CREATE TABLE IF NOT EXISTS cowork_input_requests (
      id TEXT PRIMARY KEY,
      conversation_id TEXT NOT NULL,
      run_id TEXT NOT NULL,
      user_id INTEGER NOT NULL,
      agent_id TEXT,
      schema_json TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending'
        CHECK(status IN ('pending', 'answered', 'cancelled')),
      answers_json TEXT,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      answered_at TEXT,
      FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE,
      FOREIGN KEY (run_id) REFERENCES agent_runs(id) ON DELETE CASCADE,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE SET NULL
    );

    CREATE INDEX IF NOT EXISTS idx_cowork_input_requests_conversation
      ON cowork_input_requests(conversation_id, status, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_agent_runs_conversation
      ON agent_runs(conversation_id, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_conversation_messages_run
      ON conversation_messages(run_id, created_at);
    CREATE INDEX IF NOT EXISTS idx_conversation_history_conversation
      ON conversation_history(conversation_id, created_at);
  `);
}

function migrateMessagingInboundJobs(db) {
  db.exec(`
    CREATE TABLE IF NOT EXISTS messaging_inbound_jobs (
      id                TEXT PRIMARY KEY,
      message_id        INTEGER NOT NULL UNIQUE,
      user_id           INTEGER NOT NULL,
      agent_id          TEXT,
      platform          TEXT NOT NULL,
      platform_msg_id   TEXT,
      platform_chat_id  TEXT,
      payload_json      TEXT NOT NULL,
      status            TEXT NOT NULL DEFAULT 'pending'
                        CHECK(status IN ('pending', 'processing', 'completed', 'failed')),
      attempts          INTEGER NOT NULL DEFAULT 0,
      run_id            TEXT,
      last_error        TEXT,
      created_at        TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at        TEXT NOT NULL DEFAULT (datetime('now')),
      completed_at      TEXT,
      FOREIGN KEY (message_id) REFERENCES messages(id) ON DELETE CASCADE,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE SET NULL
    );

    CREATE INDEX IF NOT EXISTS idx_messaging_inbound_jobs_pending
      ON messaging_inbound_jobs(status, platform, user_id, agent_id, created_at);
    CREATE INDEX IF NOT EXISTS idx_messaging_inbound_jobs_run
      ON messaging_inbound_jobs(run_id);
  `);
}

function migrateCredentialBroker(db) {
  db.exec(`
    CREATE TABLE IF NOT EXISTS credential_bindings (
      id TEXT PRIMARY KEY,
      user_id INTEGER NOT NULL,
      agent_id TEXT NOT NULL,
      provider_key TEXT NOT NULL,
      connection_id INTEGER NOT NULL,
      alias TEXT NOT NULL,
      usage_type TEXT NOT NULL CHECK(usage_type IN ('browser', 'http')),
      item_ref_encrypted TEXT NOT NULL,
      field_config_encrypted TEXT NOT NULL,
      target_config_json TEXT NOT NULL DEFAULT '{}',
      created_at TEXT DEFAULT (datetime('now')),
      updated_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE CASCADE,
      FOREIGN KEY (connection_id) REFERENCES integration_connections(id) ON DELETE CASCADE,
      UNIQUE(user_id, agent_id, alias)
    );

    CREATE INDEX IF NOT EXISTS idx_credential_bindings_scope
      ON credential_bindings(user_id, agent_id, provider_key, usage_type);

    CREATE TABLE IF NOT EXISTS credential_usage_audit (
      id TEXT PRIMARY KEY,
      user_id INTEGER NOT NULL,
      agent_id TEXT NOT NULL,
      run_id TEXT,
      binding_id TEXT,
      operation TEXT NOT NULL,
      target TEXT,
      outcome TEXT NOT NULL,
      error_code TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE CASCADE,
      FOREIGN KEY (run_id) REFERENCES agent_runs(id) ON DELETE SET NULL,
      FOREIGN KEY (binding_id) REFERENCES credential_bindings(id) ON DELETE SET NULL
    );

    CREATE INDEX IF NOT EXISTS idx_credential_usage_audit_scope
      ON credential_usage_audit(user_id, agent_id, created_at DESC);
  `);
}

function migrateSetupOnboarding(db) {
  db.exec(`
    CREATE TABLE IF NOT EXISTS neoagent_instance (
      singleton_id INTEGER PRIMARY KEY CHECK(singleton_id = 1),
      instance_id TEXT NOT NULL UNIQUE,
      display_name TEXT NOT NULL,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS setup_claim_tokens (
      id TEXT PRIMARY KEY,
      token_hash TEXT NOT NULL UNIQUE,
      expires_at TEXT NOT NULL,
      exchanged_at TEXT,
      consumed_at TEXT,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE INDEX IF NOT EXISTS idx_setup_claim_tokens_active
      ON setup_claim_tokens(token_hash, expires_at, exchanged_at, consumed_at);
  `);
}

function migrateAgentRuntimeKernel(db) {
  const columns = new Set(
    db.prepare('PRAGMA table_info(agent_runs)').all().map((column) => column.name),
  );
  const additions = [
    ['version', 'INTEGER NOT NULL DEFAULT 0'],
    ['runtime_state', "TEXT NOT NULL DEFAULT 'accepted'"],
    ['final_delivery_id', 'TEXT'],
    ['lease_owner', 'TEXT'],
    ['lease_expires_at', 'TEXT'],
    ['heartbeat_at', 'TEXT'],
  ];
  for (const [name, type] of additions) {
    if (!columns.has(name)) {
      db.exec(`ALTER TABLE agent_runs ADD COLUMN ${name} ${type}`);
    }
  }

  db.exec(`
    CREATE TABLE IF NOT EXISTS agent_task_contracts (
      id TEXT PRIMARY KEY,
      run_id TEXT NOT NULL,
      version INTEGER NOT NULL DEFAULT 1,
      contract_json TEXT NOT NULL DEFAULT '{}',
      created_at TEXT DEFAULT (datetime('now')),
      updated_at TEXT DEFAULT (datetime('now')),
      UNIQUE(run_id, version),
      FOREIGN KEY (run_id) REFERENCES agent_runs(id) ON DELETE CASCADE
    );

    CREATE INDEX IF NOT EXISTS idx_agent_task_contracts_run
      ON agent_task_contracts(run_id, version DESC);

    CREATE TABLE IF NOT EXISTS agent_work_nodes (
      id TEXT PRIMARY KEY,
      run_id TEXT NOT NULL,
      node_key TEXT NOT NULL,
      kind TEXT NOT NULL DEFAULT 'execute',
      status TEXT NOT NULL DEFAULT 'pending',
      version INTEGER NOT NULL DEFAULT 1,
      objective TEXT,
      success_criteria_json TEXT NOT NULL DEFAULT '[]',
      allowed_tools_json TEXT NOT NULL DEFAULT '[]',
      resource_reads_json TEXT NOT NULL DEFAULT '[]',
      resource_writes_json TEXT NOT NULL DEFAULT '[]',
      evidence_json TEXT NOT NULL DEFAULT '[]',
      artifact_ids_json TEXT NOT NULL DEFAULT '[]',
      blockers_json TEXT NOT NULL DEFAULT '[]',
      defects_json TEXT NOT NULL DEFAULT '[]',
      retry_count INTEGER NOT NULL DEFAULT 0,
      attempt_budget INTEGER NOT NULL DEFAULT 5,
      assigned_worker TEXT,
      checkpoint_id TEXT,
      metadata_json TEXT NOT NULL DEFAULT '{}',
      created_at TEXT DEFAULT (datetime('now')),
      updated_at TEXT DEFAULT (datetime('now')),
      UNIQUE(run_id, node_key),
      FOREIGN KEY (run_id) REFERENCES agent_runs(id) ON DELETE CASCADE
    );

    CREATE INDEX IF NOT EXISTS idx_agent_work_nodes_run_status
      ON agent_work_nodes(run_id, status);

    CREATE TABLE IF NOT EXISTS agent_node_dependencies (
      run_id TEXT NOT NULL,
      node_id TEXT NOT NULL,
      depends_on_node_id TEXT NOT NULL,
      PRIMARY KEY (node_id, depends_on_node_id),
      FOREIGN KEY (run_id) REFERENCES agent_runs(id) ON DELETE CASCADE,
      FOREIGN KEY (node_id) REFERENCES agent_work_nodes(id) ON DELETE CASCADE,
      FOREIGN KEY (depends_on_node_id) REFERENCES agent_work_nodes(id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS agent_runtime_checkpoints (
      id TEXT PRIMARY KEY,
      run_id TEXT NOT NULL,
      version INTEGER NOT NULL DEFAULT 1,
      phase TEXT NOT NULL,
      state_json TEXT NOT NULL DEFAULT '{}',
      created_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (run_id) REFERENCES agent_runs(id) ON DELETE CASCADE
    );

    CREATE INDEX IF NOT EXISTS idx_agent_runtime_checkpoints_run
      ON agent_runtime_checkpoints(run_id, version DESC);

    CREATE TABLE IF NOT EXISTS agent_side_effects (
      id TEXT PRIMARY KEY,
      run_id TEXT NOT NULL,
      node_id TEXT,
      tool_name TEXT,
      status TEXT NOT NULL DEFAULT 'unknown'
        CHECK(status IN ('pending', 'applied', 'confirmed', 'failed', 'unknown', 'reconciled')),
      idempotency_key TEXT,
      request_json TEXT NOT NULL DEFAULT '{}',
      result_json TEXT NOT NULL DEFAULT '{}',
      created_at TEXT DEFAULT (datetime('now')),
      updated_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (run_id) REFERENCES agent_runs(id) ON DELETE CASCADE
    );

    CREATE UNIQUE INDEX IF NOT EXISTS idx_agent_side_effects_idempotency
      ON agent_side_effects(run_id, idempotency_key)
      WHERE idempotency_key IS NOT NULL;

    CREATE TABLE IF NOT EXISTS agent_resource_leases (
      id TEXT PRIMARY KEY,
      run_id TEXT NOT NULL,
      resource_key TEXT NOT NULL,
      mode TEXT NOT NULL DEFAULT 'exclusive'
        CHECK(mode IN ('shared_read', 'exclusive')),
      lease_owner TEXT NOT NULL,
      lease_expires_at TEXT NOT NULL,
      heartbeat_at TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      UNIQUE(resource_key, mode, lease_owner),
      FOREIGN KEY (run_id) REFERENCES agent_runs(id) ON DELETE CASCADE
    );

    CREATE INDEX IF NOT EXISTS idx_agent_resource_leases_resource
      ON agent_resource_leases(resource_key, lease_expires_at);

    CREATE TABLE IF NOT EXISTS agent_outbox (
      id TEXT PRIMARY KEY,
      run_id TEXT NOT NULL,
      channel TEXT NOT NULL,
      recipient TEXT,
      message_kind TEXT NOT NULL
        CHECK(message_kind IN ('ack', 'interim', 'final', 'error', 'approval', 'progress')),
      sequence INTEGER NOT NULL DEFAULT 1,
      semantic_hash TEXT,
      payload_json TEXT NOT NULL DEFAULT '{}',
      status TEXT NOT NULL DEFAULT 'pending'
        CHECK(status IN ('pending', 'leased', 'delivered', 'ambiguous', 'failed', 'suppressed')),
      platform_message_id TEXT,
      idempotency_key TEXT,
      lease_owner TEXT,
      lease_expires_at TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      delivered_at TEXT,
      UNIQUE(run_id, channel, message_kind, sequence),
      FOREIGN KEY (run_id) REFERENCES agent_runs(id) ON DELETE CASCADE
    );

    CREATE UNIQUE INDEX IF NOT EXISTS idx_agent_outbox_idempotency
      ON agent_outbox(channel, idempotency_key)
      WHERE idempotency_key IS NOT NULL;

    CREATE INDEX IF NOT EXISTS idx_agent_outbox_pending
      ON agent_outbox(status, created_at);

    CREATE TABLE IF NOT EXISTS agent_delivery_attempts (
      id TEXT PRIMARY KEY,
      outbox_id TEXT NOT NULL,
      run_id TEXT NOT NULL,
      attempt_no INTEGER NOT NULL DEFAULT 1,
      status TEXT NOT NULL
        CHECK(status IN ('started', 'delivered', 'failed', 'ambiguous')),
      platform_message_id TEXT,
      error TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (outbox_id) REFERENCES agent_outbox(id) ON DELETE CASCADE,
      FOREIGN KEY (run_id) REFERENCES agent_runs(id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS agent_memory_write_queue (
      id TEXT PRIMARY KEY,
      user_id INTEGER NOT NULL,
      agent_id TEXT,
      run_id TEXT,
      candidate_json TEXT NOT NULL DEFAULT '{}',
      write_class TEXT NOT NULL DEFAULT 'semantic'
        CHECK(write_class IN ('ephemeral', 'episodic', 'semantic', 'procedural', 'discard')),
      status TEXT NOT NULL DEFAULT 'pending'
        CHECK(status IN ('pending', 'committed', 'rejected', 'failed')),
      idempotency_key TEXT,
      error TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      committed_at TEXT,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      FOREIGN KEY (run_id) REFERENCES agent_runs(id) ON DELETE SET NULL
    );

    CREATE UNIQUE INDEX IF NOT EXISTS idx_agent_memory_write_queue_idempotency
      ON agent_memory_write_queue(idempotency_key)
      WHERE idempotency_key IS NOT NULL;

    CREATE TABLE IF NOT EXISTS agent_skill_versions (
      id TEXT PRIMARY KEY,
      skill_id TEXT NOT NULL,
      version INTEGER NOT NULL DEFAULT 1,
      name TEXT NOT NULL,
      content_md TEXT NOT NULL DEFAULT '',
      metadata_json TEXT NOT NULL DEFAULT '{}',
      evaluation_score REAL,
      validated_at TEXT,
      status TEXT NOT NULL DEFAULT 'candidate'
        CHECK(status IN ('candidate', 'validated', 'retired', 'rolled_back')),
      created_at TEXT DEFAULT (datetime('now')),
      UNIQUE(skill_id, version)
    );

    CREATE TABLE IF NOT EXISTS agent_skill_evaluations (
      id TEXT PRIMARY KEY,
      skill_version_id TEXT NOT NULL,
      run_id TEXT,
      score REAL,
      outcome TEXT,
      notes TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (skill_version_id) REFERENCES agent_skill_versions(id) ON DELETE CASCADE,
      FOREIGN KEY (run_id) REFERENCES agent_runs(id) ON DELETE SET NULL
    );
  `);

  // Strengthen event uniqueness for the append-only event store.
  try {
    db.exec(`
      CREATE UNIQUE INDEX IF NOT EXISTS idx_agent_run_events_run_sequence
        ON agent_run_events(run_id, sequence_index);
    `);
  } catch {
    // Existing data may already violate uniqueness; runtime store still uses transactional max+1.
  }
}

function runSchemaMigrations(db) {
  removeRetiredCaptureData(db);
  removeRetiredWidgetData(db);
  migrateMemoryEmbeddingIndex(db);
  migrateMemoryProvenance(db);
  migrateMemoryRelations(db);
  migrateMemoryRetrievalEvents(db);
  migrateMemoryEmbeddingMetadata(db);
  migrateMemoryRetentionMetadata(db);
  migrateMemoryExactHashUniqueness(db);
  migrateSkillOwnership(db);
  migrateSkillLearning(db);
  migrateToolPermissions(db);
  migrateApprovalPersistence(db);
  migrateToolPoliciesAllowAlways(db);
  migrateBilling(db);
  migrateAgentRunLifecycle(db);
  migrateCoworkWorkspace(db);
  migrateMessagingInboundJobs(db);
  migrateCredentialBroker(db);
  migrateSetupOnboarding(db);
  migrateAgentRuntimeKernel(db);
  removeLegacyDeviceRegistrations(db);
}

module.exports = {
  migrateLegacyTranscriptionSettings,
  removeRetiredCaptureData,
  removeRetiredWidgetData,
  removeLegacyDeviceRegistrations,
  migrateMemoryEmbeddingIndex,
  migrateMemoryProvenance,
  migrateMemoryRelations,
  migrateMemoryRetrievalEvents,
  migrateMemoryEmbeddingMetadata,
  migrateMemoryRetentionMetadata,
  migrateMemoryExactHashUniqueness,
  migrateSkillOwnership,
  migrateSkillLearning,
  migrateToolPermissions,
  migrateApprovalPersistence,
  migrateToolPoliciesAllowAlways,
  migrateBilling,
  migrateAgentRunLifecycle,
  migrateCoworkWorkspace,
  migrateMessagingInboundJobs,
  migrateCredentialBroker,
  migrateSetupOnboarding,
  migrateAgentRuntimeKernel,
  runSchemaMigrations,
};
