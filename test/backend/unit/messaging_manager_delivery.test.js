'use strict';

const assert = require('node:assert/strict');
const EventEmitter = require('node:events');
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

test('messaging manager forwards cancellation and never starts a pre-aborted delivery', async () => {
  const manager = new MessagingManager({
    to() {
      return { emit() {} };
    },
  });
  const agentId = manager._agentId(user.userId, {});
  const key = manager._key(user.userId, agentId, 'whatsapp');
  let sendCalls = 0;
  manager.platforms.set(key, {
    async sendMessage() {
      sendCalls += 1;
      return { success: true };
    },
  });
  const controller = new AbortController();
  const reason = new Error('caller stopped delivery');
  controller.abort(reason);

  await assert.rejects(
    manager.sendMessage(user.userId, 'whatsapp', 'chat-1', 'Never send.', {
      agentId,
      signal: controller.signal,
    }),
    (error) => error === reason,
  );
  assert.equal(sendCalls, 0);
});

test('messaging manager shutdown aborts active delivery and refuses new work', async () => {
  const manager = new MessagingManager({
    to() {
      return { emit() {} };
    },
  });
  const agentId = manager._agentId(user.userId, {});
  const key = manager._key(user.userId, agentId, 'whatsapp');
  let disconnectCalls = 0;
  let forwardedSignal = null;
  manager.platforms.set(key, {
    sendMessage(_to, _content, options) {
      forwardedSignal = options.signal;
      return new Promise(() => {});
    },
    async disconnect() {
      disconnectCalls += 1;
    },
  });

  const delivery = manager.sendMessage(
    user.userId,
    'whatsapp',
    'chat-1',
    'In flight.',
    { agentId },
  );
  await new Promise((resolve) => setImmediate(resolve));
  assert.ok(forwardedSignal);
  assert.equal(forwardedSignal.aborted, false);

  const firstShutdown = manager.shutdown();
  const secondShutdown = manager.shutdown();
  await assert.rejects(
    delivery,
    (error) => error.code === 'MESSAGING_SHUTTING_DOWN',
  );
  const [firstStatus, secondStatus] = await Promise.all([firstShutdown, secondShutdown]);

  assert.equal(firstStatus.state, 'stopped');
  assert.deepEqual(secondStatus, firstStatus);
  assert.equal(forwardedSignal.aborted, true);
  assert.equal(disconnectCalls, 1);
  await assert.rejects(
    manager.sendMessage(user.userId, 'whatsapp', 'chat-1', 'Too late.', { agentId }),
    (error) => error.code === 'MESSAGING_SHUTTING_DOWN',
  );
});

test('messaging manager emits attention alerts only for disconnects that need user action', async () => {
  class TestPlatform extends EventEmitter {
    constructor() {
      super();
      this.status = 'disconnected';
    }

    async connect() {
      this.status = 'connected';
      this.emit('connected');
    }

    async disconnect() {
      this.status = 'disconnected';
      this.emit('disconnected', { manual: true });
    }

    getStatus() {
      return this.status;
    }
  }

  const emitted = [];
  const manager = new MessagingManager({
    to(room) {
      return {
        emit(event, payload) {
          emitted.push({ room, event, payload });
        },
      };
    },
  });
  manager.platformTypes.test_platform = TestPlatform;

  await manager.connectPlatform(user.userId, 'test_platform');
  const agentId = manager._agentId(user.userId, {});
  const platform = manager.platforms.get(
    manager._key(user.userId, agentId, 'test_platform'),
  );

  platform.emit('disconnected', { manual: false, requiresUserAction: false });
  assert.equal(
    emitted.filter((item) => item.event === 'messaging:attention_required').length,
    0,
  );

  platform.emit('disconnected', {
    manual: false,
    requiresUserAction: true,
    reason: 'reconnect_exhausted',
  });
  assert.deepEqual(
    emitted.find((item) => item.event === 'messaging:attention_required'),
    {
      room: `user:${user.userId}`,
      event: 'messaging:attention_required',
      payload: {
        agentId,
        platform: 'test_platform',
        reason: 'reconnect_exhausted',
      },
    },
  );
});

test('messaging manager requests user attention when a platform logs out', async () => {
  class TestPlatform extends EventEmitter {
    async connect() {
      this.emit('connected');
    }

    async disconnect() {}

    getStatus() {
      return 'connected';
    }
  }

  const emitted = [];
  const manager = new MessagingManager({
    to() {
      return {
        emit(event, payload) {
          emitted.push({ event, payload });
        },
      };
    },
  });
  manager.platformTypes.test_platform = TestPlatform;

  await manager.connectPlatform(user.userId, 'test_platform');
  const agentId = manager._agentId(user.userId, {});
  manager.platforms
    .get(manager._key(user.userId, agentId, 'test_platform'))
    .emit('logged_out');

  assert.deepEqual(
    emitted.find((item) => item.event === 'messaging:attention_required')?.payload,
    {
      agentId,
      platform: 'test_platform',
      reason: 'authentication_required',
    },
  );
});
