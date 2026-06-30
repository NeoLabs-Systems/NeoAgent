'use strict';

const assert = require('node:assert/strict');
const { afterEach, test } = require('node:test');

const {
  createTestRuntime,
  createTestUser,
  teardownTestRuntime,
} = require('../../helpers/db');

let ctx;

afterEach(() => {
  teardownTestRuntime(ctx);
  ctx = null;
});

function seedUserData(db, userId) {
  const convId = `conv_${userId}`;
  db.prepare('INSERT INTO conversations (id, user_id, title) VALUES (?, ?, ?)').run(
    convId,
    userId,
    'Test conversation',
  );
  db.prepare(
    'INSERT INTO conversation_messages (conversation_id, role, content) VALUES (?, ?, ?)',
  ).run(convId, 'user', 'hello');
  db.prepare('INSERT INTO memories (id, user_id, content) VALUES (?, ?, ?)').run(
    `mem_${userId}`,
    userId,
    'a memory',
  );
  db.prepare('INSERT INTO user_settings (user_id, key, value) VALUES (?, ?, ?)').run(
    userId,
    'theme',
    'dark',
  );
}

test('eraseUserData removes all data for the target user only', async () => {
  ctx = createTestRuntime();
  const { eraseUserData } = require('../../../server/services/account/erasure');

  const victim = await createTestUser(ctx.db, { username: 'erase_victim' });
  const bystander = await createTestUser(ctx.db, { username: 'erase_bystander' });
  seedUserData(ctx.db, victim.userId);
  seedUserData(ctx.db, bystander.userId);

  const result = eraseUserData(victim.userId);
  assert.equal(result.ok, true);
  assert.ok(result.tablesCleared > 0);

  // The user row and all their scoped rows are gone.
  assert.equal(
    ctx.db.prepare('SELECT COUNT(*) AS n FROM users WHERE id = ?').get(victim.userId).n,
    0,
  );
  for (const table of ['conversations', 'memories', 'user_settings']) {
    assert.equal(
      ctx.db.prepare(`SELECT COUNT(*) AS n FROM ${table} WHERE user_id = ?`).get(victim.userId).n,
      0,
      `${table} should be empty for the erased user`,
    );
  }
  // Child row keyed by conversation_id is gone too.
  assert.equal(
    ctx.db
      .prepare('SELECT COUNT(*) AS n FROM conversation_messages WHERE conversation_id = ?')
      .get(`conv_${victim.userId}`).n,
    0,
  );

  // The bystander is completely untouched.
  assert.equal(
    ctx.db.prepare('SELECT COUNT(*) AS n FROM users WHERE id = ?').get(bystander.userId).n,
    1,
  );
  assert.equal(
    ctx.db.prepare('SELECT COUNT(*) AS n FROM memories WHERE user_id = ?').get(bystander.userId).n,
    1,
  );
  assert.equal(
    ctx.db
      .prepare('SELECT COUNT(*) AS n FROM conversation_messages WHERE conversation_id = ?')
      .get(`conv_${bystander.userId}`).n,
    1,
  );
});

test('eraseUserData rejects unknown and invalid ids', async () => {
  ctx = createTestRuntime();
  const { eraseUserData } = require('../../../server/services/account/erasure');

  assert.throws(() => eraseUserData(999999), (err) => err.code === 'NOT_FOUND');
  assert.throws(() => eraseUserData(0), (err) => err.code === 'INVALID_ID');
  assert.throws(() => eraseUserData('abc'), (err) => err.code === 'INVALID_ID');
});

test('userScopedTables excludes global and admin tables', async () => {
  ctx = createTestRuntime();
  const { userScopedTables } = require('../../../server/services/account/erasure');
  const tables = userScopedTables();

  assert.ok(tables.includes('memories'));
  assert.ok(tables.includes('user_settings'));
  assert.ok(!tables.includes('users'));
  assert.ok(!tables.includes('billing_plans'));
  assert.ok(!tables.some((t) => t.startsWith('admin_')));
});

test('exportUserData returns the user data with secrets redacted', async () => {
  ctx = createTestRuntime();
  const { exportUserData } = require('../../../server/services/account/erasure');

  const user = await createTestUser(ctx.db, { username: 'export_me' });
  seedUserData(ctx.db, user.userId);

  const dump = exportUserData(user.userId);
  assert.equal(dump.userId, user.userId);
  assert.equal(dump.schema, 'neoagent.user-export.v1');
  // Personal data is present.
  assert.equal(dump.data.account.username, 'export_me');
  assert.ok(Array.isArray(dump.data.memories) && dump.data.memories.length === 1);
  // The bcrypt password hash must never be echoed back.
  assert.equal(dump.data.account.password, '[redacted]');
});
