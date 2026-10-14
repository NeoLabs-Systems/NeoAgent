'use strict';

const assert = require('node:assert/strict');
const { afterEach, test } = require('node:test');
const Sqlite = require('better-sqlite3');

const { pruneMemoryBloat } = require('../../../lib/schema_migrations');
const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

let ctx = null;

afterEach(() => {
  if (ctx) teardownTestRuntime(ctx);
  ctx = null;
});

test('memory bloat cleanup drops overlap windows, ingested-chunk facts, extra heuristic facts, and orphan entities', () => {
  const db = new Sqlite(':memory:');
  try {
    db.pragma('foreign_keys = ON');
    db.exec(`
      CREATE TABLE memories (id TEXT PRIMARY KEY, source_type TEXT, metadata_json TEXT DEFAULT '{}');
      CREATE TABLE memory_facts (
        id TEXT PRIMARY KEY,
        memory_id TEXT REFERENCES memories(id) ON DELETE CASCADE,
        metadata_json TEXT DEFAULT '{}'
      );
      CREATE TABLE memory_entities (id TEXT PRIMARY KEY, mention_count INTEGER DEFAULT 0);
      CREATE TABLE memory_entity_mentions (
        entity_id TEXT REFERENCES memory_entities(id) ON DELETE CASCADE,
        memory_id TEXT REFERENCES memories(id) ON DELETE CASCADE,
        PRIMARY KEY (entity_id, memory_id)
      );
    `);
    const local = JSON.stringify({ extractedBy: 'local_memory_intelligence' });
    const llm = JSON.stringify({ extractedBy: 'llm_memory_consolidation' });
    db.prepare('INSERT INTO memories VALUES (?, ?, ?)').run('chunk', 'memory_ingestion', '{}');
    db.prepare('INSERT INTO memories VALUES (?, ?, ?)')
      .run('window', 'memory_ingestion', JSON.stringify({ isOverlapWindow: true }));
    db.prepare('INSERT INTO memories VALUES (?, ?, ?)').run('manual', 'manual', '{}');
    const fact = db.prepare('INSERT INTO memory_facts VALUES (?, ?, ?)');
    fact.run('chunk-1', 'chunk', local);
    fact.run('window-1', 'window', local);
    fact.run('manual-1', 'manual', local);
    fact.run('manual-2', 'manual', local);
    fact.run('manual-llm', 'manual', llm);
    db.exec(`
      INSERT INTO memory_entities VALUES ('kept', 9), ('window-only', 1), ('orphan', 4);
      INSERT INTO memory_entity_mentions VALUES
        ('kept', 'chunk'), ('kept', 'window'), ('kept', 'manual'), ('window-only', 'window');
    `);

    pruneMemoryBloat(db);
    pruneMemoryBloat(db);

    assert.deepEqual(db.prepare('SELECT id FROM memories ORDER BY id').all().map((r) => r.id), ['chunk', 'manual']);
    assert.deepEqual(
      db.prepare('SELECT id FROM memory_facts ORDER BY id').all().map((r) => r.id),
      ['manual-1', 'manual-llm'],
    );
    assert.deepEqual(
      db.prepare('SELECT id, mention_count FROM memory_entities').all(),
      [{ id: 'kept', mention_count: 2 }],
    );
  } finally {
    db.close();
  }
});

test('entity mentions stay exact across re-index, update, and delete', async () => {
  ctx = createTestRuntime();
  const { resolveAgentId } = require('../../../server/services/agents/manager');
  const { MemoryManager } = require('../../../server/services/memory/manager');
  const user = await createTestUser(ctx.db, { username: 'entity_user' });
  const agentId = resolveAgentId(user.userId, null);
  const mm = new MemoryManager();
  const entity = (name) => mm.listEntities(user.userId, { agentId, limit: 100 })
    .find((item) => item.name === name);

  const first = await mm.saveMemory(user.userId, 'Alice Cooper reviews the Orion Launch plan.', 'projects', 6, { agentId });
  await mm.saveMemory(user.userId, 'Alice Cooper prefers async status updates.', 'preferences', 6, { agentId });
  assert.equal(entity('Alice Cooper').mentionCount, 2);

  mm._backfillMemoryIntelligence();
  await mm.updateMemory(first, { importance: 7 });
  assert.equal(entity('Alice Cooper').mentionCount, 2);

  await mm.updateMemory(first, { content: 'The Vega Rollout plan is due next week.' });
  assert.equal(entity('Orion Launch'), undefined);
  assert.equal(entity('Alice Cooper').mentionCount, 1);

  mm.deleteMemory(first);
  assert.equal(entity('Vega Rollout'), undefined);
  assert.equal(entity('Alice Cooper').mentionCount, 1);
  assert.equal(mm.getMemoryStats(user.userId, { agentId }).facts, 1);
});
