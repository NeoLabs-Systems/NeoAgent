'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { afterEach, test } = require('node:test');
const Sqlite = require('better-sqlite3');

const { flushProjectCache } = require('../../helpers/db');

let cleanup = null;

afterEach(() => {
  if (cleanup) {
    cleanup();
    cleanup = null;
  }
});

function setupLegacyRuntime() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-legacy-db-'));
  const homeDir = path.join(dir, 'home');
  const dataDir = path.join(dir, 'data');
  const agentDataDir = path.join(dir, 'agent-data');
  const envFile = path.join(dir, '.env');
  const previousEnv = {};
  for (const key of [
    'NODE_ENV',
    'NEOAGENT_HOME',
    'NEOAGENT_DATA_DIR',
    'NEOAGENT_AGENT_DATA_DIR',
    'NEOAGENT_ENV_FILE',
    'NEOAGENT_PROFILE',
    'SESSION_SECRET',
    'ALLOWED_ORIGINS',
    'PUBLIC_URL',
    'SECURE_COOKIES',
    'TRUST_PROXY',
    'OPENAI_API_KEY',
    'GOOGLE_AI_KEY',
  ]) {
    previousEnv[key] = process.env[key];
  }

  Object.assign(process.env, {
    NODE_ENV: 'test',
    NEOAGENT_HOME: homeDir,
    NEOAGENT_DATA_DIR: dataDir,
    NEOAGENT_AGENT_DATA_DIR: agentDataDir,
    NEOAGENT_ENV_FILE: envFile,
    NEOAGENT_PROFILE: 'private',
    SESSION_SECRET: 'test-secret-32-chars-long-for-suite',
    ALLOWED_ORIGINS: '',
    PUBLIC_URL: '',
    SECURE_COOKIES: 'false',
    TRUST_PROXY: 'true',
    OPENAI_API_KEY: '',
    GOOGLE_AI_KEY: '',
  });

  fs.mkdirSync(dataDir, { recursive: true });
  fs.mkdirSync(agentDataDir, { recursive: true });
  flushProjectCache();

  cleanup = () => {
    try {
      const db = require('../../../server/db/database');
      if (db?.open) db.close();
    } catch {}
    flushProjectCache();
    for (const [key, value] of Object.entries(previousEnv)) {
      if (value == null) {
        delete process.env[key];
      } else {
        process.env[key] = value;
      }
    }
    fs.rmSync(dir, { recursive: true, force: true });
  };

  return { dataDir };
}

test('database bootstrap tolerates legacy desktop device tables', () => {
  const { dataDir } = setupLegacyRuntime();
  const dbPath = path.join(dataDir, 'neoagent.db');
  const legacyDb = new Sqlite(dbPath);

  legacyDb.exec(`
    CREATE TABLE desktop_companion_devices (
      id TEXT PRIMARY KEY,
      user_id INTEGER NOT NULL,
      device_id TEXT NOT NULL,
      label TEXT NOT NULL,
      hostname TEXT,
      platform TEXT,
      platform_version TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      UNIQUE(user_id, device_id)
    );
  `);
  legacyDb.close();

  assert.doesNotThrow(() => require('../../../server/db/database'));
  const db = require('../../../server/db/database');

  const desktopColumns = new Set(
    db.prepare('PRAGMA table_info(desktop_companion_devices)').all().map((column) => column.name),
  );
  assert.ok(desktopColumns.has('status'));
  assert.ok(desktopColumns.has('updated_at'));

  const desktopIndexes = db.prepare('PRAGMA index_list(desktop_companion_devices)').all();
  assert.ok(desktopIndexes.some((index) => index.name === 'idx_desktop_companion_devices_user'));
});

test('capture cleanup preserves legacy transcription choices for voice features', () => {
  const db = new Sqlite(':memory:');
  db.exec(`
    CREATE TABLE user_settings (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      key TEXT NOT NULL,
      value TEXT,
      UNIQUE(user_id, key)
    );
    CREATE TABLE agent_settings (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      agent_id TEXT NOT NULL,
      key TEXT NOT NULL,
      value TEXT,
      UNIQUE(user_id, agent_id, key)
    );
  `);
  db.prepare('INSERT INTO user_settings (user_id, key, value) VALUES (?, ?, ?)')
    .run(1, 'default_recording_transcription_provider', '"deepgram"');
  db.prepare('INSERT INTO user_settings (user_id, key, value) VALUES (?, ?, ?)')
    .run(1, 'default_recording_transcription_model', '"nova-3"');
  db.prepare('INSERT INTO user_settings (user_id, key, value) VALUES (?, ?, ?)')
    .run(2, 'voice_stt_provider', '"gemini"');
  db.prepare('INSERT INTO user_settings (user_id, key, value) VALUES (?, ?, ?)')
    .run(2, 'default_recording_transcription_provider', '"deepgram"');
  db.prepare('INSERT INTO agent_settings (user_id, agent_id, key, value) VALUES (?, ?, ?, ?)')
    .run(1, 'agent-1', 'default_recording_transcription_provider', '"deepgram"');

  const { migrateLegacyTranscriptionSettings } = require('../../../lib/schema_migrations');
  migrateLegacyTranscriptionSettings(db);

  assert.equal(
    db.prepare('SELECT value FROM user_settings WHERE user_id = 1 AND key = ?')
      .get('voice_stt_provider').value,
    '"deepgram"',
  );
  assert.equal(
    db.prepare('SELECT value FROM user_settings WHERE user_id = 1 AND key = ?')
      .get('voice_stt_model').value,
    '"nova-3"',
  );
  assert.equal(
    db.prepare('SELECT value FROM user_settings WHERE user_id = 2 AND key = ?')
      .get('voice_stt_provider').value,
    '"gemini"',
  );
  assert.equal(
    db.prepare('SELECT value FROM agent_settings WHERE user_id = 1 AND agent_id = ? AND key = ?')
      .get('agent-1', 'voice_stt_provider').value,
    '"deepgram"',
  );
  assert.equal(
    db.prepare("SELECT COUNT(*) AS count FROM user_settings WHERE key LIKE 'default_recording_transcription_%'")
      .get().count,
    0,
  );
  db.close();
});

test('memory embedding index migration is idempotent and keeps the current lookup shape', () => {
  const db = new Sqlite(':memory:');
  const { migrateMemoryEmbeddingIndex } = require('../../../lib/schema_migrations');

  migrateMemoryEmbeddingIndex(db);
  assert.doesNotThrow(() => migrateMemoryEmbeddingIndex(db));

  const columns = db.prepare(
    'PRAGMA index_info(idx_memory_embedding_bands_lookup)',
  ).all().map((column) => column.name);
  assert.deepEqual(columns, [
    'user_id',
    'agent_id',
    'dimension',
    'index_version',
    'band_index',
    'band_value',
  ]);
  db.close();
});
