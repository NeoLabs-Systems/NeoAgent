'use strict';

// Skill versioning is created twice: once in the base schema every install
// starts from, and once by the migration that added it, for databases that
// predate the base-schema entry. Both need the identical definition, so it
// lives here rather than being restated in each place and drifting apart.
const SKILL_VERSIONING_TABLES = `
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
`;

module.exports = { SKILL_VERSIONING_TABLES };
