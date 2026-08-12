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

function deferred() {
  let resolve;
  const promise = new Promise((done) => {
    resolve = done;
  });
  return { promise, resolve };
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

function createCronHarness({ failAt = null } = {}) {
  const jobs = [];
  return {
    jobs,
    schedule(expression, callback) {
      if (failAt != null && jobs.length === failAt) {
        throw new Error('cron registration failed');
      }
      const job = {
        expression,
        callback,
        stopped: false,
        stop() {
          this.stopped = true;
        },
      };
      jobs.push(job);
      return job;
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

  afterEach(async () => {
    await runtime?.stop();
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
    assert.equal(calls[0].options.bypassUserRateLimits, true);
    assert.equal(calls[0].options.triggerSource, 'schedule');
    assert.match(calls[1].prompt, /Previous task attempt failed/);
    assert.equal(result.content, 'The daily summary is ready.');
    assert.equal(messagingManager.sent.length, 1);
    assert.equal(messagingManager.sent[0].content, 'The daily summary is ready.');
  });

  test('automatic scheduled runs do not fallback-send plain assistant text', async () => {
    const messagingManager = createMessagingManager();
    const prompts = [];
    const optionsSeen = [];
    const task = await createScheduledTask({
      async runWithModel(userId, prompt, options) {
        prompts.push({ userId, prompt });
        optionsSeen.push(options);
        return { content: 'No relevant calendar changes.' };
      },
    }, messagingManager);

    const result = await runtime._executeTaskSerial(task.id, user.userId, {
      manual: false,
      triggerType: 'schedule',
      triggerSource: 'schedule',
      scheduledAt: new Date().toISOString(),
    });

    assert.equal(result.content, 'No relevant calendar changes.');
    assert.equal(result.taskDelivery.sent, false);
    assert.equal(result.taskDelivery.reason, 'explicit_delivery_required');
    assert.equal(messagingManager.sent.length, 0);
    assert.match(prompts[0].prompt, /content="\[NO RESPONSE\]" exactly; never leave content blank/);
    assert.match(prompts[0].prompt, /decide from that evidence instead of re-running nearby variants/);
    assert.equal(optionsSeen[0].bypassUserRateLimits, true);
    assert.equal(optionsSeen[0].triggerSource, 'schedule');
    assert.equal(optionsSeen[0].stageProactiveMessages, true);
    assert.equal(optionsSeen[0].skipVerifier, false);
  });

  test('manual task runs bypass user token admission limits', async () => {
    const optionsSeen = [];
    const task = await createScheduledTask({
      async runWithModel(_userId, _prompt, options) {
        optionsSeen.push(options);
        return { content: 'Manual task completed.' };
      },
    }, createMessagingManager());

    const result = await runtime._executeTaskSerial(task.id, user.userId, {
      manual: true,
      triggerType: 'schedule',
      triggerSource: 'manual',
      scheduledAt: new Date().toISOString(),
    });

    assert.equal(result.content, 'Manual task completed.');
    assert.equal(optionsSeen.length, 1);
    assert.equal(optionsSeen[0].bypassUserRateLimits, true);
    assert.equal(optionsSeen[0].triggerSource, 'manual');
  });

  test('does not enforce legacy per-day task loop limits', async () => {
    let callCount = 0;
    runtime = new TaskRuntime(createIoRecorder(), {
      async runWithModel() {
        callCount += 1;
        return { content: 'task ran without a daily hard limit' };
      },
    });
    const task = await runtime.createTask(user.userId, {
      name: 'Budgeted task',
      triggerType: 'schedule',
      triggerConfig: {
        mode: 'recurring',
        cronExpression: '0 6 * * *',
      },
      taskConfig: {
        prompt: 'Check the inbox.',
        loopBudget: {
          maxRunsPerDay: 1,
          maxTokensPerDay: 1000,
        },
      },
    });
    ctx.db.prepare(
      `INSERT INTO agent_runs (
        id, user_id, agent_id, title, status, trigger_type, trigger_source,
        total_tokens, metadata_json, created_at
      ) VALUES (?, ?, ?, ?, 'completed', 'schedule', 'schedule', ?, ?, datetime('now'))`
    ).run(
      'budget-run-1',
      user.userId,
      task.agentId,
      'Budgeted task',
      100,
      JSON.stringify({ taskId: task.id }),
    );

    const result = await runtime._executeTaskSerial(task.id, user.userId, {
      manual: false,
      triggerType: 'schedule',
      triggerSource: 'schedule',
      scheduledAt: new Date().toISOString(),
    });

    assert.equal(callCount, 1);
    assert.equal(result.content, 'task ran without a daily hard limit');
  });

  test('serializes task loop pause state without a budget', async () => {
    const task = await createScheduledTask({
      async runWithModel() {
        return { content: 'unused' };
      },
    }, createMessagingManager());

    assert.equal(task.loopPaused, false);
    assert.equal(task.loopBudget, undefined);
  });

  test('skips task execution when the task loop budget is paused', async () => {
    let callCount = 0;
    runtime = new TaskRuntime(createIoRecorder(), {
      async runWithModel() {
        callCount += 1;
        return { content: 'should not run' };
      },
    });
    const task = await runtime.createTask(user.userId, {
      name: 'Paused budget task',
      triggerType: 'schedule',
      triggerConfig: {
        mode: 'recurring',
        cronExpression: '0 6 * * *',
      },
      taskConfig: {
        prompt: 'Check the inbox.',
        loopBudget: {
          paused: true,
        },
      },
    });

    const result = await runtime._executeTaskSerial(task.id, user.userId, {
      manual: false,
      triggerType: 'schedule',
      triggerSource: 'schedule',
      scheduledAt: new Date().toISOString(),
    });

    assert.equal(callCount, 0);
    assert.equal(result.skipped, true);
    assert.equal(result.reason, 'loop_paused');
  });

  test('automatic scheduled runs deliver staged proactive replies after verification', async () => {
    const messagingManager = createMessagingManager();
    const task = await createScheduledTask({
      async runWithModel(_userId, _prompt, options) {
        options.deliveryState.proactiveMessageStaged = true;
        options.deliveryState.stagedProactiveMessage = {
          platform: 'whatsapp',
          to: 'recipient',
          content: 'Wetter in Braunschweig: sonnig. Keine neue Mail.',
          purpose: 'final_result',
          mediaPath: null,
        };
        return { content: 'Wetter in Braunschweig: sonnig. Keine neue Mail.' };
      },
    }, messagingManager);

    const result = await runtime._executeTaskSerial(task.id, user.userId, {
      manual: false,
      triggerType: 'schedule',
      triggerSource: 'schedule',
      scheduledAt: new Date().toISOString(),
    });

    assert.equal(result.content, 'Wetter in Braunschweig: sonnig. Keine neue Mail.');
    assert.equal(result.taskDelivery.sent, true);
    assert.equal(messagingManager.sent.length, 1);
    assert.equal(messagingManager.sent[0].platform, 'whatsapp');
    assert.equal(messagingManager.sent[0].to, 'recipient');
    assert.equal(messagingManager.sent[0].content, 'Wetter in Braunschweig: sonnig. Keine neue Mail.');
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
    assert.match(messagingManager.sent[0].content, /could not complete:/);
    assert.match(messagingManager.sent[0].content, /without producing a result or an explicit no-response decision/);
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

  test('accepts empty no-response content for proactive task runs', async () => {
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
      content: '',
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

  test('stages proactive send_message decisions for background verification', async () => {
    const { executeTool } = require('../../../server/services/ai/tools');
    const sendCalls = [];
    const deliveryState = {};
    const runState = {};
    const engine = {
      activeRuns: new Map([['run-id', runState]]),
      messagingManager: {
        async sendMessage(...args) {
          sendCalls.push(args);
          return { success: true };
        },
      },
    };

    const result = await executeTool('send_message', {
      platform: 'whatsapp',
      to: 'recipient',
      content: 'Weather for Braunschweig: sunny.',
      purpose: 'final_result',
    }, {
      userId: user.userId,
      runId: 'run-id',
      triggerSource: 'schedule',
      deliveryState,
      stageProactiveMessages: true,
    }, engine);

    assert.equal(result.staged, true);
    assert.equal(sendCalls.length, 0);
    assert.equal(runState.proactiveMessageStaged, true);
    assert.equal(deliveryState.proactiveMessageStaged, true);
    assert.equal(deliveryState.stagedProactiveMessage.platform, 'whatsapp');
    assert.equal(deliveryState.stagedProactiveMessage.to, 'recipient');
    assert.equal(deliveryState.stagedProactiveMessage.content, 'Weather for Braunschweig: sunny.');
  });

  test('failed explicit send_message does not mark terminal delivery', async () => {
    const { executeTool } = require('../../../server/services/ai/tools');
    const runState = {
      messagingSent: false,
      explicitMessageSent: false,
      finalDeliverySent: false,
      sentMessages: [],
    };
    const engine = {
      activeRuns: new Map([['run-id', runState]]),
      messagingManager: {
        async sendMessage() {
          return { success: false, error: 'transport unavailable' };
        },
      },
    };

    const result = await executeTool('send_message', {
      platform: 'whatsapp',
      to: 'recipient',
      content: 'Finished result.',
    }, {
      userId: user.userId,
      runId: 'run-id',
      triggerSource: 'messaging',
      source: 'whatsapp',
      chatId: 'recipient@s.whatsapp.net',
    }, engine);

    assert.equal(result.success, false);
    assert.equal(runState.messagingSent, false);
    assert.equal(runState.explicitMessageSent, false);
    assert.equal(runState.finalDeliverySent, false);
    assert.deepEqual(runState.sentMessages, []);
  });

  test('explicit messaging delivery is terminal only for the originating chat', async () => {
    const { executeTool } = require('../../../server/services/ai/tools');
    const runState = {
      messagingSent: false,
      explicitMessageSent: false,
      finalDeliverySent: false,
      sentMessages: [],
    };
    const sent = [];
    const engine = {
      activeRuns: new Map([['run-id', runState]]),
      messagingManager: {
        async sendMessage(userId, platform, to, content) {
          sent.push({ userId, platform, to, content });
          return { success: true };
        },
      },
    };
    const context = {
      userId: user.userId,
      runId: 'run-id',
      triggerSource: 'messaging',
      source: 'whatsapp',
      chatId: '49123456789:7@s.whatsapp.net',
    };

    await executeTool('send_message', {
      platform: 'whatsapp',
      to: '49987654321',
      content: 'Side-effect notification.',
    }, context, engine);

    assert.equal(sent.length, 1);
    assert.equal(runState.messagingSent, false);
    assert.equal(runState.explicitMessageSent, false);
    assert.equal(runState.finalDeliverySent, false);

    await executeTool('send_message', {
      platform: 'WHATSAPP',
      to: '49123456789',
      content: 'Finished result.',
    }, context, engine);

    assert.equal(sent.length, 2);
    assert.equal(runState.messagingSent, true);
    assert.equal(runState.explicitMessageSent, true);
    assert.equal(runState.finalDeliverySent, true);
    assert.deepEqual(runState.sentMessages, ['Finished result.']);
  });

  test('send_message does not use phrase matching to classify an origin reply', async () => {
    const { executeTool } = require('../../../server/services/ai/tools');
    const sent = [];
    const runState = {
      messagingSent: false,
      explicitMessageSent: false,
      finalDeliverySent: false,
      sentMessages: [],
    };
    const engine = {
      activeRuns: new Map([['run-id', runState]]),
      messagingManager: {
        async sendMessage(...args) {
          sent.push(args);
          return { success: true };
        },
      },
      async stopMessagingProgressSupervisor() {},
    };
    const context = {
      userId: user.userId,
      runId: 'run-id',
      triggerSource: 'messaging',
      source: 'whatsapp',
      chatId: '49123456789@s.whatsapp.net',
    };

    const result = await executeTool('send_message', {
      platform: 'whatsapp',
      to: '49123456789',
      content: "I'm working on that and will update you.",
    }, context, engine);

    assert.equal(result.success, true);
    assert.equal(sent.length, 1);
    assert.equal(runState.finalDeliverySent, true);

    await executeTool('send_message', {
      platform: 'whatsapp',
      to: '49987654321',
      content: "I'm working on that and will update you.",
    }, context, engine);
    assert.equal(sent.length, 2, 'a requested message to a third party is not reclassified');
  });

  test('task runtime start is idempotent and reports truthful state', async () => {
    const cronHarness = createCronHarness();
    runtime = new TaskRuntime(
      createIoRecorder(),
      {},
      null,
      { cron: cronHarness },
    );

    const first = runtime.start();
    const second = runtime.start();

    assert.equal(first.state, 'running');
    assert.equal(second.state, 'running');
    assert.equal(cronHarness.jobs.length, 2);
    assert.equal(runtime.getStatus().started, true);

    const stopped = await runtime.stop();
    assert.equal(stopped.state, 'stopped');
    assert.ok(cronHarness.jobs.every((job) => job.stopped));
  });

  test('task runtime rolls back partial startup when cron registration fails', () => {
    const cronHarness = createCronHarness({ failAt: 1 });
    runtime = new TaskRuntime(
      createIoRecorder(),
      {},
      null,
      { cron: cronHarness },
    );

    assert.throws(() => runtime.start(), /cron registration failed/);
    assert.equal(runtime.getStatus().state, 'error');
    assert.equal(runtime.getStatus().started, false);
    assert.equal(cronHarness.jobs[0].stopped, true);
  });

  test('task runtime coalesces overlapping poll ticks and waits for them on stop', async () => {
    const cronHarness = createCronHarness();
    const pollStarted = deferred();
    const releasePoll = deferred();
    let pollCount = 0;
    runtime = new TaskRuntime(
      createIoRecorder(),
      {},
      null,
      { cron: cronHarness },
    );
    runtime._runDueOneTimeTasks = async () => {
      pollCount += 1;
      pollStarted.resolve();
      await releasePoll.promise;
    };
    runtime.start();

    const firstPoll = cronHarness.jobs[0].callback();
    const secondPoll = cronHarness.jobs[0].callback();
    assert.equal(firstPoll, secondPoll);
    await pollStarted.promise;
    assert.equal(pollCount, 1);

    let stopCompleted = false;
    const stop = runtime.stop().then((status) => {
      stopCompleted = true;
      return status;
    });
    await Promise.resolve();
    assert.equal(stopCompleted, false);

    releasePoll.resolve();
    const status = await stop;
    assert.equal(status.state, 'stopped');
    assert.equal(pollCount, 1);
  });

  test('task runtime cancels active execution results and rejects new work during shutdown', async () => {
    const cronHarness = createCronHarness();
    const runStarted = deferred();
    const releaseRun = deferred();
    runtime = new TaskRuntime(
      createIoRecorder(),
      {
        async runWithModel() {
          runStarted.resolve();
          await releaseRun.promise;
          return { content: 'Completed before shutdown.' };
        },
      },
      null,
      { cron: cronHarness },
    );
    runtime.start();
    const task = await runtime.createTask(user.userId, {
      name: 'Shutdown test',
      triggerType: 'schedule',
      triggerConfig: {
        mode: 'recurring',
        cronExpression: '0 6 * * *',
      },
      taskConfig: {
        prompt: 'Finish the active work.',
      },
    });

    const execution = runtime._executeTask(task.id, user.userId, {
      manual: true,
      triggerType: 'schedule',
      triggerSource: 'manual',
      scheduledAt: new Date().toISOString(),
    });
    await runStarted.promise;

    const stopping = runtime.stop();
    const rejected = await runtime._executeTask(task.id, user.userId, {
      manual: true,
      triggerType: 'schedule',
      triggerSource: 'manual',
    });
    assert.deepEqual(rejected, { skipped: true, reason: 'runtime_stopping' });
    assert.equal(runtime.getStatus().state, 'stopping');

    releaseRun.resolve();
    assert.deepEqual(await execution, {
      skipped: true,
      reason: 'runtime_stopping',
      runId: null,
    });
    assert.equal((await stopping).state, 'stopped');

    let pollCalled = false;
    assert.deepEqual(
      runtime.runTaskNow(task.id, user.userId),
      { running: false, skipped: true, reason: 'runtime_stopping' },
    );
    assert.deepEqual(
      await runtime._executeTask(task.id, user.userId, {
        manual: true,
        triggerType: 'schedule',
        triggerSource: 'manual',
      }),
      { skipped: true, reason: 'runtime_stopping' },
    );
    assert.deepEqual(
      await runtime._runPoll('after_stop', async () => {
        pollCalled = true;
      }, () => {}),
      { skipped: true, reason: 'runtime_stopping' },
    );
    assert.equal(pollCalled, false);
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

  test('builds task linkage metadata at run creation', () => {
    const { buildInitialRunMetadata } = require('../../../server/services/ai/engine');

    assert.deepEqual(buildInitialRunMetadata({ taskId: 12 }), {
      taskId: 12,
    });
    assert.deepEqual(buildInitialRunMetadata({}), {});
  });
});
