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

  test('fails explicitly when configured result delivery cannot connect', async () => {
    let callCount = 0;
    const messagingManager = createMessagingManager();
    messagingManager.getPlatformStatus = () => ({ status: 'disconnected' });
    const task = await createScheduledTask({
      async runWithModel() {
        callCount += 1;
        ctx.db.prepare(
          `INSERT INTO agent_runs (
            id, user_id, agent_id, title, status, trigger_type, trigger_source, metadata_json
          ) VALUES (?, ?, ?, ?, 'completed', 'schedule', 'schedule', ?)`
        ).run(
          'delivery-run',
          user.userId,
          task.agentId,
          'Daily summary',
          JSON.stringify({ taskId: task.id }),
        );
        return { runId: 'delivery-run', content: 'The daily summary is ready.' };
      },
    }, messagingManager);

    const result = await runtime._executeTaskSerial(task.id, user.userId, {
      manual: true,
      triggerType: 'schedule',
      triggerSource: 'schedule',
      scheduledAt: new Date().toISOString(),
    });

    assert.equal(callCount, 1);
    assert.match(result.error, /not connected/);
    assert.equal(messagingManager.sent.length, 0);
    const persistedRun = ctx.db.prepare(
      'SELECT status, error FROM agent_runs WHERE id = ?'
    ).get('delivery-run');
    assert.equal(persistedRun.status, 'failed');
    assert.match(persistedRun.error, /not connected/);
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

  test('deletes a completed one-time task after its due poll', async () => {
    const io = createIoRecorder();
    runtime = new TaskRuntime(io, {
      async runWithModel() {
        return { content: 'One-time task completed.' };
      },
    });
    const task = await runtime.createTask(user.userId, {
      name: 'One-time check',
      triggerType: 'schedule',
      triggerConfig: {
        mode: 'one_time',
        runAt: new Date(Date.now() - 60_000).toISOString(),
      },
      taskConfig: {
        prompt: 'Run the one-time check.',
      },
    });

    await runtime._runDueOneTimeTasks();

    assert.equal(runtime.taskRepository.getTaskById(task.id, user.userId), undefined);
    assert.ok(io.events.some((event) =>
      event.event === 'tasks:task_deleted' && event.payload.taskId === task.id
    ));
  });

  test('keeps a due one-time task when its previous execution is still running', async () => {
    runtime = new TaskRuntime(createIoRecorder(), {
      async runWithModel() {
        throw new Error('should not run');
      },
    });
    const task = await runtime.createTask(user.userId, {
      name: 'Busy one-time check',
      triggerType: 'schedule',
      triggerConfig: {
        mode: 'one_time',
        runAt: new Date(Date.now() - 60_000).toISOString(),
      },
      taskConfig: {
        prompt: 'Run the one-time check.',
      },
    });
    runtime.runningTaskExecutions.add(`${user.userId}:${task.id}`);

    await runtime._runDueOneTimeTasks();

    assert.ok(runtime.taskRepository.getTaskById(task.id, user.userId));
  });

  test('checkpoints integration events only after successful execution', async () => {
    let shouldFail = true;
    runtime = new TaskRuntime(createIoRecorder(), {
      async runWithModel() {
        if (shouldFail) return { content: '' };
        return { content: 'Event processed.' };
      },
    });
    const task = await runtime.createTask(user.userId, {
      name: 'Event handler',
      triggerType: 'schedule',
      triggerConfig: {
        mode: 'recurring',
        cronExpression: '0 6 * * *',
      },
      taskConfig: {
        prompt: 'Process the event.',
      },
    });
    const triggerPayload = {
      fingerprint: 'event:123',
      timestamp: new Date().toISOString(),
      context: { eventId: '123' },
    };

    const failed = await runtime.fireTaskFromTrigger(task.id, user.userId, triggerPayload);
    assert.match(failed.error, /without producing a result/);
    assert.equal(
      runtime.taskRepository.getTaskById(task.id, user.userId).last_trigger_fingerprint,
      null,
    );

    shouldFail = false;
    const completed = await runtime.fireTaskFromTrigger(task.id, user.userId, triggerPayload);
    assert.equal(completed.content, 'Event processed.');
    assert.equal(
      runtime.taskRepository.getTaskById(task.id, user.userId).last_trigger_fingerprint,
      'event:123',
    );
  });

  test('stops an integration poll batch after a retryable execution failure', async () => {
    const { pollIntegrationTask } = require('../../../server/services/tasks/integration_runtime');
    const fired = [];
    const task = {
      id: 42,
      user_id: user.userId,
      agent_id: 'agent-id',
      trigger_type: 'slack_message_received',
      trigger_config: JSON.stringify({
        connectionId: 'connection-id',
        channel: 'channel-id',
      }),
      last_trigger_fingerprint: 'slack:connection-id:channel-id:1',
    };
    const fakeRuntime = {
      integrationManager: {
        async executeTool() {
          return {
            messages: [
              { ts: '1', text: 'already processed' },
              { ts: '2', text: 'first pending' },
              { ts: '3', text: 'second pending' },
            ],
          };
        },
      },
      async fireTaskFromTrigger(taskId, userId, payload) {
        fired.push({ taskId, userId, payload });
        return { skipped: false, error: 'transient failure' };
      },
    };

    await pollIntegrationTask(fakeRuntime, task);

    assert.equal(fired.length, 1);
    assert.equal(fired[0].payload.fingerprint, 'slack:connection-id:channel-id:2');
  });

  test('includes the latest linked run outcome when listing tasks', async () => {
    runtime = new TaskRuntime(createIoRecorder(), {});
    const task = await runtime.createTask(user.userId, {
      name: 'Run history task',
      triggerType: 'schedule',
      triggerConfig: {
        mode: 'recurring',
        cronExpression: '0 6 * * *',
      },
      taskConfig: {
        prompt: 'Report the current state.',
      },
    });
    ctx.db.prepare(
      `INSERT INTO agent_runs (
        id, user_id, agent_id, title, status, trigger_type, trigger_source,
        metadata_json, error, final_response, created_at, completed_at
      ) VALUES (?, ?, ?, ?, 'failed', 'schedule', 'schedule', ?, ?, ?, ?, ?)`
    ).run(
      'linked-run',
      user.userId,
      task.agentId,
      'Run history task',
      JSON.stringify({ taskId: task.id }),
      'Remote service unavailable.',
      'Partial result.',
      '2026-06-06 10:00:00',
      '2026-06-06 10:01:00',
    );
    ctx.db.prepare(
      `INSERT INTO agent_runs (
        id, user_id, agent_id, title, status, trigger_type, trigger_source,
        metadata_json, final_response, created_at, completed_at
      ) VALUES (?, ?, ?, ?, 'completed', 'schedule', 'schedule', ?, ?, ?, ?)`
    ).run(
      'linked-run-latest',
      user.userId,
      task.agentId,
      'Run history task retry',
      JSON.stringify({ taskId: task.id }),
      'Recovered result.',
      '2026-06-06 10:00:00',
      '2026-06-06 10:02:00',
    );
    ctx.db.prepare(
      `INSERT INTO agent_runs (
        id, user_id, agent_id, title, status, trigger_type, trigger_source,
        metadata_json, created_at
      ) VALUES (?, ?, ?, ?, 'completed', 'user', 'web', ?, ?)`
    ).run(
      'legacy-invalid-metadata',
      user.userId,
      task.agentId,
      'Legacy run',
      '{invalid',
      '2026-06-06 11:00:00',
    );

    const listed = runtime.listTasks(user.userId);
    const listedTask = listed.find((item) => item.id === task.id);

    assert.equal(listedTask.lastRunId, 'linked-run-latest');
    assert.equal(listedTask.lastRunStatus, 'completed');
    assert.equal(listedTask.lastRunError, null);
    assert.equal(listedTask.lastRun, '2026-06-06 10:00:00');
  });

  test('builds task and widget linkage metadata at run creation', () => {
    const { buildInitialRunMetadata } = require('../../../server/services/ai/engine');

    assert.deepEqual(buildInitialRunMetadata({ taskId: 12, widgetId: 'weather' }), {
      taskId: 12,
      widgetId: 'weather',
    });
    assert.deepEqual(buildInitialRunMetadata({}), {});
  });
});
