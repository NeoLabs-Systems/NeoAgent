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

test('waits for an in-flight inbound job instead of dropping a platform retry', async () => {
  const manager = new MessagingManager(createIo());
  let release;
  let startedResolve;
  const started = new Promise((resolve) => {
    startedResolve = resolve;
  });
  let calls = 0;
  manager.registerHandler(async () => {
    calls += 1;
    startedResolve();
    await new Promise((resolve) => {
      release = resolve;
    });
    return { runId: 'live-run', result: { status: 'completed' }, error: null };
  });

  const first = manager.ingestMessage(user.userId, 'discord', inboundMessage());
  await started;
  const second = manager.ingestMessage(user.userId, 'discord', inboundMessage());
  assert.equal(calls, 1);
  release();
  await Promise.all([first, second]);
  assert.equal(calls, 1);
  assert.deepEqual(
    ctx.db.prepare('SELECT status, attempts FROM messaging_inbound_jobs').get(),
    { status: 'completed', attempts: 1 },
  );
});

test('replays a duplicate when durable status is processing but no handler is running', async () => {
  const manager = new MessagingManager(createIo());
  await manager.ingestMessage(user.userId, 'discord', inboundMessage());
  ctx.db.prepare(
    "UPDATE messaging_inbound_jobs SET status = 'processing', attempts = 1",
  ).run();

  const calls = [];
  manager.registerHandler(async (_userId, message) => {
    calls.push(message.content);
    return { runId: 'replayed-run', result: { status: 'completed' }, error: null };
  });

  await manager.ingestMessage(user.userId, 'discord', inboundMessage());
  assert.deepEqual(calls, ['Please finish this task.']);
  assert.equal(
    ctx.db.prepare('SELECT status FROM messaging_inbound_jobs').get().status,
    'completed',
  );
});

test('replays a duplicate that failed before an agent run started', async () => {
  const manager = new MessagingManager(createIo());
  await manager.ingestMessage(user.userId, 'discord', inboundMessage());
  ctx.db.prepare(
    "UPDATE messaging_inbound_jobs SET status = 'failed', last_error = 'handler crashed', attempts = 1",
  ).run();

  let calls = 0;
  manager.registerHandler(async () => {
    calls += 1;
    return { runId: 'retried-run', result: { status: 'completed' }, error: null };
  });

  await manager.ingestMessage(user.userId, 'discord', inboundMessage());
  assert.equal(calls, 1);
  assert.equal(
    ctx.db.prepare('SELECT status FROM messaging_inbound_jobs').get().status,
    'completed',
  );
});

test('does not replay a duplicate after an agent run has already started', async () => {
  const manager = new MessagingManager(createIo());
  await manager.ingestMessage(user.userId, 'discord', inboundMessage());
  const job = ctx.db.prepare('SELECT id FROM messaging_inbound_jobs').get();
  const agentId = manager._agentId(user.userId, {});
  ctx.db.prepare(
    `INSERT INTO agent_runs (id, user_id, agent_id, title, status, error)
     VALUES ('started-inbound-run', ?, ?, 'Started inbound run', 'failed', 'send failed')`,
  ).run(user.userId, agentId);
  ctx.db.prepare(
    `UPDATE messaging_inbound_jobs
     SET status = 'failed', attempts = 1, run_id = 'started-inbound-run'
     WHERE id = ?`,
  ).run(job.id);

  let calls = 0;
  manager.registerHandler(async () => {
    calls += 1;
  });

  await manager.ingestMessage(user.userId, 'discord', inboundMessage());
  assert.equal(calls, 0);
  assert.equal(
    ctx.db.prepare('SELECT status FROM messaging_inbound_jobs WHERE id = ?').get(job.id).status,
    'failed',
  );
});

test('/stop cancels platform-scoped queues and lets a stuck Discord retry run', async () => {
  const { CommandRouter } = require('../../../server/services/commands/router');
  const { queueKeyForMessage } = require('../../../server/services/messaging/inbound_queue');
  const manager = new MessagingManager(createIo());
  const agentId = manager._agentId(user.userId, {});
  await manager.ingestMessage(user.userId, 'discord', inboundMessage());
  ctx.db.prepare(
    "UPDATE messaging_inbound_jobs SET status = 'processing', attempts = 1",
  ).run();

  const queueKey = queueKeyForMessage(user.userId, {
    agentId,
    platform: 'discord',
    chatId: 'chat-1',
  });
  const userQueues = {
    [queueKey]: {
      running: false,
      pending: [{ message: { content: 'later' } }],
      cancelRequested: false,
    },
  };
  const router = new CommandRouter({
    locals: {
      userQueues,
      messagingManager: manager,
      agentEngine: { activeRuns: new Map() },
    },
  });

  const status = router.handleStatus(user.userId, agentId);
  assert.match(status.content, /Messaging queue: idle \(1 pending\)/);

  const result = router.handleStop(user.userId, agentId);
  assert.equal(result.content, 'Stopped.');
  assert.deepEqual(Object.keys(userQueues), []);
  assert.equal(
    ctx.db.prepare('SELECT status FROM messaging_inbound_jobs').get().status,
    'pending',
  );

  let calls = 0;
  manager.registerHandler(async () => {
    calls += 1;
    return { runId: 'after-stop', result: { status: 'completed' }, error: null };
  });
  await manager.ingestMessage(user.userId, 'discord', inboundMessage());
  assert.equal(calls, 1);
  assert.equal(
    ctx.db.prepare('SELECT status FROM messaging_inbound_jobs').get().status,
    'completed',
  );
});

test('reclaims abandoned processing jobs on later inbound recovery', async () => {
  const manager = new MessagingManager(createIo());
  await manager.ingestMessage(user.userId, 'discord', inboundMessage());
  manager.inboundJobsReconciled = true;
  ctx.db.prepare(
    "UPDATE messaging_inbound_jobs SET status = 'processing', attempts = 1",
  ).run();

  let calls = 0;
  manager.registerHandler(async () => {
    calls += 1;
    return { runId: 'recovered-run', result: { status: 'completed' }, error: null };
  });
  const agentId = manager._agentId(user.userId, {});
  manager.platforms.set(
    manager._key(user.userId, agentId, 'discord'),
    { getStatus: () => 'connected' },
  );

  assert.deepEqual(await manager.recoverPendingInbound(), { recovered: 1, skipped: 0 });
  assert.equal(calls, 1);
  assert.equal(
    ctx.db.prepare('SELECT status FROM messaging_inbound_jobs').get().status,
    'completed',
  );
});
