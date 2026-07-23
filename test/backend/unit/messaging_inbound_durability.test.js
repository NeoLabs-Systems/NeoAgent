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

function createIo() {
  return {
    to() {
      return { emit() {} };
    },
  };
}

function inboundMessage(overrides = {}) {
  return {
    chatId: 'chat-1',
    messageId: 'platform-message-1',
    sender: 'sender-1',
    senderName: 'Sender',
    content: 'Please finish this task.',
    isGroup: false,
    timestamp: new Date().toISOString(),
    ...overrides,
  };
}

beforeEach(async () => {
  ctx = createTestRuntime();
  user = await createTestUser(ctx.db);
  ({ MessagingManager } = require('../../../server/services/messaging/manager'));
});

afterEach(() => {
  teardownTestRuntime(ctx);
});

test('persists an inbound job before dispatch and deduplicates platform retries', async () => {
  const manager = new MessagingManager(createIo());

  await manager.ingestMessage(user.userId, 'telegram', inboundMessage());
  await manager.ingestMessage(user.userId, 'telegram', inboundMessage());

  const messages = ctx.db.prepare(
    "SELECT COUNT(*) AS count FROM messages WHERE role = 'user' AND platform_msg_id = ?",
  ).get('platform-message-1');
  const jobs = ctx.db.prepare(
    'SELECT status, attempts FROM messaging_inbound_jobs',
  ).all();
  assert.equal(messages.count, 1);
  assert.deepEqual(jobs, [{ status: 'pending', attempts: 0 }]);
});

test('recovers a pending inbound job once its platform and handler are ready', async () => {
  const firstManager = new MessagingManager(createIo());
  const stored = await firstManager.ingestMessage(
    user.userId,
    'telegram',
    inboundMessage(),
  );
  const secondManager = new MessagingManager(createIo());
  const calls = [];
  secondManager.registerHandler(async (userId, message) => {
    calls.push({ userId, message });
    return { runId: 'recovered-run', result: { status: 'completed' }, error: null };
  });
  const agentId = secondManager._agentId(user.userId, {});
  secondManager.platforms.set(
    secondManager._key(user.userId, agentId, 'telegram'),
    { getStatus: () => 'connected' },
  );

  const recovery = await secondManager.recoverPendingInbound();

  assert.deepEqual(recovery, { recovered: 1, skipped: 0 });
  assert.equal(calls.length, 1);
  assert.equal(calls[0].userId, user.userId);
  assert.equal(calls[0].message.content, stored.content);
  assert.ok(calls[0].message.inboundJobId);
  assert.deepEqual(
    ctx.db.prepare(
      'SELECT status, attempts, completed_at IS NOT NULL AS completed FROM messaging_inbound_jobs',
    ).get(),
    { status: 'completed', attempts: 1, completed: 1 },
  );
});

test('does not replay an inbound job whose agent run began before restart', async () => {
  const firstManager = new MessagingManager(createIo());
  await firstManager.ingestMessage(user.userId, 'telegram', inboundMessage());
  const job = ctx.db.prepare('SELECT id FROM messaging_inbound_jobs').get();
  const agentId = firstManager._agentId(user.userId, {});
  ctx.db.prepare(
    `INSERT INTO agent_runs (id, user_id, agent_id, title, status, error)
     VALUES ('interrupted-inbound-run', ?, ?, 'Interrupted inbound run', 'interrupted', 'restart')`,
  ).run(user.userId, agentId);
  ctx.db.prepare(
    `UPDATE messaging_inbound_jobs
     SET status = 'processing', attempts = 1, run_id = 'interrupted-inbound-run'
     WHERE id = ?`,
  ).run(job.id);

  const secondManager = new MessagingManager(createIo());
  let handlerCalls = 0;
  secondManager.registerHandler(async () => {
    handlerCalls += 1;
  });
  secondManager.platforms.set(
    secondManager._key(user.userId, agentId, 'telegram'),
    { getStatus: () => 'connected' },
  );

  assert.deepEqual(
    await secondManager.recoverPendingInbound(),
    { recovered: 0, skipped: 0 },
  );
  assert.equal(handlerCalls, 0);
  const persisted = ctx.db.prepare(
    'SELECT status, last_error FROM messaging_inbound_jobs WHERE id = ?',
  ).get(job.id);
  assert.equal(persisted.status, 'failed');
  assert.match(persisted.last_error, /will not be replayed automatically/i);
});
