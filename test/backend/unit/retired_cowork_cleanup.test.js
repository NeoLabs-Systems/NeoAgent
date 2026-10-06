'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');
const Sqlite = require('better-sqlite3');

const { removeRetiredCoworkData } = require('../../../lib/schema_migrations');

test('retired cowork cleanup removes chats, input requests, and cowork columns', () => {
  const db = new Sqlite(':memory:');
  try {
    db.exec(`
      CREATE TABLE conversations (
        id TEXT PRIMARY KEY,
        platform TEXT,
        interaction_mode TEXT,
        device_target_override TEXT,
        manually_titled INTEGER,
        workspace_path_override TEXT,
        model_override TEXT
      );
      CREATE TABLE conversation_messages (id INTEGER PRIMARY KEY, conversation_id TEXT);
      CREATE TABLE conversation_history (id INTEGER PRIMARY KEY, conversation_id TEXT);
      CREATE TABLE agent_runs (id TEXT PRIMARY KEY, interaction_mode TEXT, device_target TEXT);
      CREATE TABLE cowork_input_requests (id TEXT PRIMARY KEY);
      INSERT INTO conversations (id, platform) VALUES ('web', 'web'), ('cw', 'cowork');
      INSERT INTO conversation_messages (conversation_id) VALUES ('web'), ('cw');
      INSERT INTO conversation_history (conversation_id) VALUES ('web'), ('cw');
    `);

    removeRetiredCoworkData(db);

    assert.deepEqual(db.prepare('SELECT id FROM conversations').all(), [{ id: 'web' }]);
    assert.equal(db.prepare('SELECT COUNT(*) AS count FROM conversation_messages').get().count, 1);
    assert.equal(db.prepare('SELECT COUNT(*) AS count FROM conversation_history').get().count, 1);
    assert.equal(
      db.prepare("SELECT COUNT(*) AS count FROM sqlite_master WHERE name = 'cowork_input_requests'").get().count,
      0,
    );
    const columns = (table) => db.prepare(`PRAGMA table_info(${table})`).all().map((c) => c.name);
    assert.deepEqual(columns('conversations'), ['id', 'platform']);
    assert.deepEqual(columns('agent_runs'), ['id', 'device_target']);
  } finally {
    db.close();
  }
});
