'use strict';

const assert = require('node:assert/strict');
const { afterEach, beforeEach, test } = require('node:test');

const {
  createTestRuntime,
  createTestUser,
  teardownTestRuntime,
} = require('../../helpers/db');

let ctx;
let user;
let MessagingManager;

beforeEach(async () => {
  ctx = createTestRuntime();
  user = await createTestUser(ctx.db);
  ({ MessagingManager } = require('../../../server/services/messaging/manager'));
});

afterEach(() => {
  teardownTestRuntime(ctx);
});

test('messaging manager rejects an unconfirmed platform delivery before persistence', async () => {
  const io = {
    to() {
      return { emit() {} };
    },
  };
  const manager = new MessagingManager(io);
  const agentId = manager._agentId(user.userId, {});
  const key = manager._key(user.userId, agentId, 'whatsapp');
  manager.platforms.set(key, {
    async sendMessage() {
      return { success: false, reason: 'upstream rejected message' };
    },
  });

  await assert.rejects(
    manager.sendMessage(
      user.userId,
      'whatsapp',
      'chat-1',
      'Final result.',
      { agentId, runId: 'run-id' },
    ),
    (error) => error.code === 'MESSAGING_DELIVERY_FAILED',
  );

  const persisted = ctx.db.prepare(
    'SELECT COUNT(*) AS count FROM messages WHERE run_id = ?'
  ).get('run-id');
  assert.equal(persisted.count, 0);
});
