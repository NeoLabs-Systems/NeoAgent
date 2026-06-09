'use strict';

const assert = require('node:assert/strict');
const EventEmitter = require('node:events');
const { afterEach, beforeEach, describe, test } = require('node:test');

const {
  createTestRuntime,
  createTestUser,
  teardownTestRuntime,
} = require('../../helpers/db');

class MessagingManagerStub extends EventEmitter {
  constructor() {
    super();
    this.handler = null;
    this.readCalls = [];
    this.typingCalls = [];
  }

  registerHandler(handler) {
    this.handler = handler;
  }

  async markRead(userId, platform, chatId, messageId, options) {
    this.readCalls.push({ userId, platform, chatId, messageId, options });
  }

  async sendTyping(userId, platform, chatId, isTyping, options) {
    this.typingCalls.push({ userId, platform, chatId, isTyping, options });
  }
}

function createIoRecorder() {
  const events = [];
  return {
    events,
    to(room) {
      return {
        emit(event, payload) {
          events.push({ room, event, payload });
        },
      };
    },
  };
}

function createMessage(agentId, content, overrides = {}) {
  return {
    agentId,
    platform: 'telegram',
    chatId: 'chat-1',
    messageId: `message-${content}`,
    sender: 'sender-1',
    senderName: 'Sender',
    content,
    isGroup: false,
    ...overrides,
  };
}

function waitForTurn() {
  return new Promise((resolve) => setImmediate(resolve));
}

describe('messaging automation queue', () => {
  let ctx;
  let user;
  let mainAgentId;
  let automation;

  beforeEach(async () => {
    ctx = createTestRuntime();
    user = await createTestUser(ctx.db);
    const { ensureMainAgent } = require('../../../server/services/agents/manager');
    mainAgentId = ensureMainAgent(user.userId).id;
    automation = require('../../../server/services/messaging/automation');
  });

  afterEach(() => {
    teardownTestRuntime(ctx);
  });

  test('continues queued work after a failed run and removes the idle queue', async () => {
    const manager = new MessagingManagerStub();
    const userQueues = Object.create(null);
    const calls = [];
    const failures = [];
    let rejectFirst;
    const firstRun = new Promise((resolve, reject) => {
      rejectFirst = reject;
    });
    const agentEngine = {
      async run(userId, prompt, options) {
        calls.push({ userId, prompt, options });
        if (calls.length === 1) return firstRun;
        return { status: 'completed', content: 'done' };
      },
    };

    const firstProcessing = automation.processQueuedMessage({
      userQueues,
      messagingManager: manager,
      agentEngine,
      userId: user.userId,
      msg: createMessage(mainAgentId, 'first'),
      onProcessingError(details) {
        failures.push(details);
      },
    });
    await waitForTurn();

    const queued = await automation.processQueuedMessage({
      userQueues,
      messagingManager: manager,
      agentEngine,
      userId: user.userId,
      msg: createMessage(mainAgentId, 'second'),
    });
    assert.deepEqual(queued, { queued: true });

    rejectFirst(new Error('provider unavailable'));
    const result = await firstProcessing;

    assert.equal(result.processedCount, 2);
    assert.equal(result.failedCount, 1);
    assert.equal(result.cancelled, false);
    assert.equal(calls.length, 2);
    assert.match(calls[1].prompt, /second/);
    assert.equal(failures.length, 1);
    assert.match(failures[0].error.message, /provider unavailable/);
    assert.deepEqual(Object.keys(userQueues), []);
  });

  test('coalesces adjacent pending messages from the same sender', async () => {
    const manager = new MessagingManagerStub();
    const userQueues = Object.create(null);
    const prompts = [];
    let resolveFirst;
    const firstRun = new Promise((resolve) => {
      resolveFirst = resolve;
    });
    const agentEngine = {
      async run(userId, prompt) {
        prompts.push(prompt);
        if (prompts.length === 1) return firstRun;
        return { status: 'completed', content: 'done' };
      },
    };

    const processing = automation.processQueuedMessage({
      userQueues,
      messagingManager: manager,
      agentEngine,
      userId: user.userId,
      msg: createMessage(mainAgentId, 'first'),
    });
    await waitForTurn();

    await automation.processQueuedMessage({
      userQueues,
      messagingManager: manager,
      agentEngine,
      userId: user.userId,
      msg: createMessage(mainAgentId, 'second'),
    });
    await automation.processQueuedMessage({
      userQueues,
      messagingManager: manager,
      agentEngine,
      userId: user.userId,
      msg: createMessage(mainAgentId, 'third'),
    });

    resolveFirst({ status: 'completed', content: 'done' });
    const result = await processing;

    assert.equal(result.processedCount, 2);
    assert.equal(prompts.length, 2);
    assert.match(prompts[1], /second\nthird/);
    assert.deepEqual(Object.keys(userQueues), []);
  });

  test('cancellation drops pending messages and cleans up queue state', async () => {
    const manager = new MessagingManagerStub();
    const userQueues = Object.create(null);
    let resolveFirst;
    let callCount = 0;
    const firstRun = new Promise((resolve) => {
      resolveFirst = resolve;
    });
    const agentEngine = {
      async run() {
        callCount += 1;
        return firstRun;
      },
    };

    const processing = automation.processQueuedMessage({
      userQueues,
      messagingManager: manager,
      agentEngine,
      userId: user.userId,
      msg: createMessage(mainAgentId, 'first'),
    });
    await waitForTurn();
    await automation.processQueuedMessage({
      userQueues,
      messagingManager: manager,
      agentEngine,
      userId: user.userId,
      msg: createMessage(mainAgentId, 'second'),
    });

    const queueKey = `${user.userId}:${mainAgentId}`;
    userQueues[queueKey].cancelRequested = true;
    resolveFirst({ status: 'stopped', content: '' });
    const result = await processing;

    assert.equal(result.cancelled, true);
    assert.equal(result.processedCount, 1);
    assert.equal(callCount, 1);
    assert.deepEqual(Object.keys(userQueues), []);
  });

  test('read and typing failures do not fail an otherwise successful run', async (t) => {
    const manager = new MessagingManagerStub();
    manager.markRead = async () => {
      throw new Error('read receipt unavailable');
    };
    manager.sendTyping = () => {
      throw new Error('typing unavailable');
    };
    const warnings = [];
    const originalWarn = console.warn;
    console.warn = (...args) => warnings.push(args.join(' '));
    t.after(() => {
      console.warn = originalWarn;
    });
    let runCount = 0;

    const result = await automation.processQueuedMessage({
      userQueues: Object.create(null),
      messagingManager: manager,
      agentEngine: {
        async run() {
          runCount += 1;
          return { status: 'completed', content: 'done' };
        },
      },
      userId: user.userId,
      msg: createMessage(mainAgentId, 'first'),
    });

    assert.equal(runCount, 1);
    assert.equal(result.processedCount, 1);
    assert.equal(result.failedCount, 0);
    assert.ok(warnings.some((entry) => entry.includes('mark read failed')));
    assert.ok(warnings.some((entry) => entry.includes('send typing indicator failed')));
    assert.ok(warnings.some((entry) => entry.includes('clear typing indicator failed')));
  });

  test('registered automation emits a user-visible error when processing cannot recover', async () => {
    const manager = new MessagingManagerStub();
    const io = createIoRecorder();
    const app = { locals: {} };
    const { accessPolicyKey } = require('../../../server/services/messaging/access_policy');
    ctx.db.prepare(
      `INSERT INTO agent_settings (user_id, agent_id, key, value)
       VALUES (?, ?, ?, ?)`
    ).run(
      user.userId,
      mainAgentId,
      accessPolicyKey('telegram'),
      JSON.stringify({
        directPolicy: 'open',
        sharedPolicy: 'disabled',
        requireMentionInShared: true,
        directRules: [],
        sharedSpaceRules: [],
        sharedActorRules: [],
      }),
    );
    automation.registerMessagingAutomation({
      app,
      io,
      messagingManager: manager,
      agentEngine: {
        async run() {
          throw new Error('all providers failed');
        },
      },
    });

    await manager.handler(
      user.userId,
      createMessage(mainAgentId, 'please help'),
    );

    const errorEvent = io.events.find((entry) => entry.event === 'messaging:error');
    assert.ok(errorEvent);
    assert.equal(errorEvent.room, `user:${user.userId}`);
    assert.equal(errorEvent.payload.platform, 'telegram');
    assert.match(errorEvent.payload.error, /could not finish/);
    assert.ok(errorEvent.payload.runId);
    assert.deepEqual(Object.keys(app.locals.userQueues), []);
  });
});
