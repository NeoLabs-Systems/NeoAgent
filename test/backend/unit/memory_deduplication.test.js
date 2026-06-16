'use strict';

const assert = require('node:assert/strict');
const { afterEach, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

let ctx;

afterEach(() => {
  teardownTestRuntime(ctx);
  ctx = null;
});

test('saveMemory reuses the winner row when an exact-hash insert loses a race', async (t) => {
  ctx = createTestRuntime();
  const db = require('../../../server/db/database');
  const { stableHash } = require('../../../server/services/memory/intelligence');
  const { resolveAgentId } = require('../../../server/services/agents/manager');
  const { MemoryManager } = require('../../../server/services/memory/manager');
  const user = await createTestUser(ctx.db, { username: 'memory_race_guard' });
  const userId = user.userId;
  const agentId = resolveAgentId(userId, null);
  const content = 'Neo prefers deterministic regression tests.';
  const category = 'episodic';
  const memoryHash = stableHash(`${category}:${content}`);
  const manager = new MemoryManager();
  const originalPrepare = db.prepare.bind(db);
  let injectedCompetingInsert = false;

  t.mock.method(db, 'prepare', (sql) => {
    const statement = originalPrepare(sql);
    if (!/INSERT OR IGNORE INTO memories/i.test(sql)) {
      return statement;
    }
    const wrapped = Object.create(statement);
    wrapped.run = (...args) => {
      if (!injectedCompetingInsert) {
        injectedCompetingInsert = true;
        originalPrepare(String(sql).replace('INSERT OR IGNORE', 'INSERT')).run(...args);
      }
      return statement.run(...args);
    };
    return wrapped;
  });

  const memoryId = await manager.saveMemory(userId, content, category, 7, { agentId });

  assert.equal(injectedCompetingInsert, true);
  const rows = db.prepare(
    `SELECT id
     FROM memories
     WHERE user_id = ? AND agent_id = ? AND memory_hash = ? AND archived = 0`
  ).all(userId, agentId, memoryHash);
  assert.equal(rows.length, 1);
  assert.equal(rows[0].id, memoryId);
});
