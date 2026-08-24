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

test('messaging manager keeps retrying transient platform disconnects until recovery', async () => {
  const instances = [];
  let connectCalls = 0;
  class RecoveringPlatform extends EventEmitter {
    constructor() {
      super();
      this.status = 'disconnected';
      instances.push(this);
    }

    async connect() {
      connectCalls += 1;
      if (connectCalls === 2 || connectCalls === 3) {
        throw new Error('temporary upstream outage');
      }
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

  const manager = new MessagingManager({
    to() {
      return { emit() {} };
    },
  }, {
    reconnectBaseDelayMs: 1,
    reconnectMaxDelayMs: 2,
  });
  manager.platformTypes.recovering = RecoveringPlatform;

  await manager.connectPlatform(user.userId, 'recovering');
  instances[0].status = 'disconnected';
  instances[0].emit('disconnected', {
    manual: false,
    requiresUserAction: false,
    reason: 'connection_lost',
  });

  await assert.doesNotReject(async () => {
    const deadline = Date.now() + 1000;
    while (connectCalls < 4 && Date.now() < deadline) {
      await new Promise((resolve) => setTimeout(resolve, 5));
    }
    assert.equal(connectCalls, 4);
  });
  const agentId = manager._agentId(user.userId, {});
  const key = manager._key(user.userId, agentId, 'recovering');
  assert.equal(manager.platforms.get(key).getStatus(), 'connected');
  assert.equal(manager.reconnectTimers.size, 0);
  assert.equal(manager.reconnectAttempts.size, 0);
  assert.equal(
    ctx.db.prepare(
      'SELECT status FROM platform_connections WHERE user_id = ? AND agent_id = ? AND platform = ?',
    ).get(user.userId, agentId, 'recovering').status,
    'connected',
  );
  await manager.shutdown();
});

test('messaging manager records adapter-owned recovery without starting a competing reconnect', async () => {
  class SelfRecoveringPlatform extends EventEmitter {
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

  const manager = new MessagingManager({
    to() {
      return { emit() {} };
    },
  }, { reconnectBaseDelayMs: 1, reconnectMaxDelayMs: 1 });
  manager.platformTypes.self_recovering = SelfRecoveringPlatform;
  await manager.connectPlatform(user.userId, 'self_recovering');

  const agentId = manager._agentId(user.userId, {});
  const key = manager._key(user.userId, agentId, 'self_recovering');
  manager.platforms.get(key).emit('disconnected', {
    manual: false,
    willReconnect: true,
    reason: 'connection_lost',
  });

  assert.equal(manager.platforms.get(key).getStatus(), 'reconnecting');
  assert.equal(manager.reconnectTimers.size, 0);
  assert.equal(
    ctx.db.prepare(
      'SELECT status FROM platform_connections WHERE user_id = ? AND agent_id = ? AND platform = ?',
    ).get(user.userId, agentId, 'self_recovering').status,
    'reconnecting',
  );
  await manager.shutdown();

  const restoredManager = new MessagingManager({
    to() {
      return { emit() {} };
    },
  });
  restoredManager.platformTypes.self_recovering = SelfRecoveringPlatform;
  await restoredManager.restoreConnections();
  assert.equal(
    restoredManager.platforms.get(key).getStatus(),
    'connected',
  );
  await restoredManager.shutdown();
});
