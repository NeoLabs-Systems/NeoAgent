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

function migrateToolPermissions(db) {
  db.exec(`
    CREATE TABLE IF NOT EXISTS tool_policies (
      user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      category   TEXT    NOT NULL,
      policy     TEXT    NOT NULL CHECK(policy IN ('allow','deny','require_approval')),
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
      scope          TEXT    NOT NULL CHECK(scope IN ('once','session')),
      decided_at     TEXT    DEFAULT (datetime('now'))
    );

    CREATE INDEX IF NOT EXISTS idx_approval_log_user
      ON tool_approval_log(user_id, decided_at DESC);
  `);
}

function runSchemaMigrations(db) {
  migrateMemoryEmbeddingIndex(db);
  migrateMemoryProvenance(db);
  migrateMemoryRelations(db);
  migrateMemoryRetrievalEvents(db);
  migrateMemoryEmbeddingMetadata(db);
  migrateToolPermissions(db);
}

module.exports = {
  migrateMemoryEmbeddingIndex,
  migrateMemoryProvenance,
  migrateMemoryRelations,
  migrateMemoryRetrievalEvents,
  migrateMemoryEmbeddingMetadata,
  migrateToolPermissions,
  runSchemaMigrations,
};
