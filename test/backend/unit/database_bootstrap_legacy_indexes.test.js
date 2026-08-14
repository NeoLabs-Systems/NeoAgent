'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');
const Sqlite = require('better-sqlite3');

test('legacy extension registrations are removed while local computer devices remain', () => {
  const db = new Sqlite(':memory:');
  db.exec(`
    CREATE TABLE user_settings (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      key TEXT NOT NULL,
      value TEXT,
      UNIQUE(user_id, key)
    );
    CREATE TABLE browser_extension_pairing_requests (id TEXT PRIMARY KEY);
    CREATE TABLE browser_extension_tokens (id TEXT PRIMARY KEY);
    CREATE TABLE desktop_companion_devices (id TEXT PRIMARY KEY);
    INSERT INTO user_settings (user_id, key, value)
      VALUES (1, 'browser_backend', '"extension"');
  `);

  const { removeLegacyDeviceRegistrations } = require('../../../lib/schema_migrations');
  removeLegacyDeviceRegistrations(db);

  for (const table of [
    'browser_extension_pairing_requests',
    'browser_extension_tokens',
  ]) {
    assert.equal(
      db.prepare("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?").get(table),
      undefined,
    );
  }
  assert.deepEqual(
    db.prepare("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?")
      .get('desktop_companion_devices'),
    { 1: 1 },
  );
  assert.equal(db.prepare('SELECT 1 FROM user_settings').get(), undefined);
  db.close();
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
