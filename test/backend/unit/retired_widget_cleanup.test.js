'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');
const Sqlite = require('better-sqlite3');

const { removeRetiredWidgetData } = require('../../../lib/schema_migrations');

test('retired widget data cleanup removes legacy tables and managed tasks', () => {
  const db = new Sqlite(':memory:');
  try {
    db.exec(`
      CREATE TABLE scheduled_tasks (
        id INTEGER PRIMARY KEY,
        task_type TEXT NOT NULL
      );
      CREATE TABLE ai_widgets (id TEXT PRIMARY KEY);
      CREATE TABLE ai_widget_snapshots (
        id INTEGER PRIMARY KEY,
        widget_id TEXT NOT NULL
      );
      INSERT INTO scheduled_tasks (id, task_type)
      VALUES (1, 'agent_prompt'), (2, 'widget_refresh');
    `);

    removeRetiredWidgetData(db);

    assert.deepEqual(
      db.prepare('SELECT id, task_type FROM scheduled_tasks ORDER BY id').all(),
      [{ id: 1, task_type: 'agent_prompt' }],
    );
    assert.equal(
      db.prepare(
        "SELECT COUNT(*) AS count FROM sqlite_master WHERE type = 'table' AND name IN ('ai_widgets', 'ai_widget_snapshots')",
      ).get().count,
      0,
    );
  } finally {
    db.close();
  }
});
