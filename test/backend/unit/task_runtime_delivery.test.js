'use strict';

const assert = require('node:assert/strict');
const { afterEach, beforeEach, describe, test } = require('node:test');

const {
  createTestRuntime,
  createTestUser,
  teardownTestRuntime,
} = require('../../helpers/db');

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

function createMessagingManager() {
  const sent = [];
  return {
    sent,
    getPlatformStatus() {
      return { status: 'connected' };
    },
    async sendMessage(userId, platform, to, content, options) {
      sent.push({ userId, platform, to, content, options });
      return { success: true };
    },
  };
}

describe('scheduled task result delivery', () => {
  let ctx;
  let user;
  let TaskRuntime;
  let runtime;

  beforeEach(async () => {
    ctx = createTestRuntime();
    user = await createTestUser(ctx.db);
    ({ TaskRuntime } = require('../../../server/services/tasks/runtime'));
  });

  afterEach(() => {
    runtime?.stop();
    runtime = null;
    teardownTestRuntime(ctx);
  });

  async function createScheduledTask(agentEngine, messagingManager) {
    runtime = new TaskRuntime(createIoRecorder(), agentEngine, {
      locals: { messagingManager },
    });
    return runtime.createTask(user.userId, {
      name: 'Daily summary',
      triggerType: 'schedule',
      triggerConfig: {
        mode: 'recurring',
        cronExpression: '0 6 * * *',
      },
      taskConfig: {
        prompt: 'Prepare the daily summary.',
        notifyPlatform: 'whatsapp',
        notifyTo: 'recipient',
      },
    });
  }

  test('retries an empty result and delivers the recovered result', async () => {
    const messagingManager = createMessagingManager();
    const responses = [
      { content: '' },
      { content: 'The daily summary is ready.' },
    ];
    const calls = [];
    const task = await createScheduledTask({
      async runWithModel(userId, prompt, options) {
        calls.push({ userId, prompt, options });
        return responses.shift();
      },
    }, messagingManager);

    const result = await runtime._executeTaskSerial(task.id, user.userId, {
      manual: true,
      triggerType: 'schedule',
      triggerSource: 'schedule',
      scheduledAt: new Date().toISOString(),
    });

    assert.equal(calls.length, 2);
    assert.match(calls[1].prompt, /Previous task attempt failed/);
    assert.equal(result.content, 'The daily summary is ready.');
    assert.equal(messagingManager.sent.length, 1);
    assert.equal(messagingManager.sent[0].content, 'The daily summary is ready.');
  });

  test('delivers a failure notice when every attempt returns empty', async () => {
    const messagingManager = createMessagingManager();
    let callCount = 0;
    const task = await createScheduledTask({
      async runWithModel() {
        callCount += 1;
        return { content: '' };
      },
    }, messagingManager);

    const result = await runtime._executeTaskSerial(task.id, user.userId, {
      manual: true,
      triggerType: 'schedule',
      triggerSource: 'schedule',
      scheduledAt: new Date().toISOString(),
    });

    assert.equal(callCount, 2);
    assert.match(result.error, /without producing a result/);
    assert.equal(messagingManager.sent.length, 1);
    assert.match(messagingManager.sent[0].content, /could not complete after retrying/);
  });

  test('accepts an explicit no-response decision without fallback delivery', async () => {
    const messagingManager = createMessagingManager();
    const task = await createScheduledTask({
      async runWithModel(userId, prompt, options) {
        options.deliveryState.noResponse = true;
        return { content: '' };
      },
    }, messagingManager);

    const result = await runtime._executeTaskSerial(task.id, user.userId, {
      manual: true,
      triggerType: 'schedule',
      triggerSource: 'schedule',
      scheduledAt: new Date().toISOString(),
    });

    assert.equal(result.content, '');
    assert.equal(messagingManager.sent.length, 0);
  });

  test('marks explicit no-response tool decisions in both delivery states', async () => {
    const { executeTool } = require('../../../server/services/ai/tools');
    const deliveryState = {};
    const runState = {};
    const engine = {
      activeRuns: new Map([['run-id', runState]]),
      messagingManager: {},
    };

    const result = await executeTool('send_message', {
      platform: 'whatsapp',
      to: 'recipient',
      content: '[NO RESPONSE]',
      purpose: 'no_response',
    }, {
      userId: user.userId,
      runId: 'run-id',
      triggerSource: 'schedule',
      deliveryState,
    }, engine);

    assert.equal(result.skipped, true);
    assert.equal(result.reason, 'no_response');
    assert.equal(runState.noResponse, true);
    assert.equal(deliveryState.noResponse, true);
  });
});
