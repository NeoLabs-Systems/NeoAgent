'use strict';

const assert = require('node:assert/strict');
const { afterEach, beforeEach, describe, test } = require('node:test');

const {
  createTestRuntime,
  createTestUser,
  teardownTestRuntime,
} = require('../../helpers/db');
const { resolveLeadTimeMs } = require('../../../server/services/tasks/schedule_utils');

const MINUTE_MS = 60 * 1000;
const FIXED_NOW = new Date('2026-03-10T12:00:00.000Z').getTime();

function createIoRecorder() {
  return {
    to() {
      return { emit() {} };
    },
  };
}

function createCronHarness() {
  const jobs = [];
  return {
    jobs,
    schedule(expression, callback) {
      const job = {
        expression,
        callback,
        stop() {
          this.stopped = true;
        },
      };
      jobs.push(job);
      return job;
    },
  };
}

// A cron expression whose next occurrence is `minutesAhead` minutes from the
// frozen clock, expressed in the local time zone cron matching uses.
function cronAt(minutesAhead) {
  const target = new Date(FIXED_NOW + (minutesAhead * MINUTE_MS));
  return `${target.getMinutes()} ${target.getHours()} * * *`;
}

describe('lead-time task scheduling', () => {
  let ctx;
  let user;
  let TaskRuntime;
  let runtime;
  let cronHarness;
  let runCalls;

  beforeEach(async () => {
    ctx = createTestRuntime();
    user = await createTestUser(ctx.db);
    ({ TaskRuntime } = require('../../../server/services/tasks/runtime'));
    cronHarness = createCronHarness();
    runCalls = [];
    runtime = new TaskRuntime(createIoRecorder(), {
      async runWithModel(userId, prompt, options) {
        runCalls.push(options);
        return { content: 'done' };
      },
    }, null, { cron: cronHarness });
  });

  afterEach(async () => {
    await runtime?.stop();
    runtime = null;
    teardownTestRuntime(ctx);
  });

  function createTask(triggerConfig) {
    return runtime.createTask(user.userId, {
      name: 'Morning briefing',
      triggerType: 'schedule',
      triggerConfig: { mode: 'recurring', ...triggerConfig },
      taskConfig: { prompt: 'Prepare the morning briefing.' },
    });
  }

  // Seed completed runs of the task so it has a measurable average duration.
  function recordRunHistory(taskId, durationsSeconds) {
    durationsSeconds.forEach((seconds, index) => {
      const startedAt = new Date(FIXED_NOW - ((index + 1) * 24 * 60 * MINUTE_MS));
      const completedAt = new Date(startedAt.getTime() + (seconds * 1000));
      ctx.db.prepare(
        `INSERT INTO agent_runs (id, user_id, status, metadata_json, created_at, completed_at)
         VALUES (?, ?, 'completed', ?, ?, ?)`
      ).run(
        `run_${taskId}_${index}`,
        user.userId,
        JSON.stringify({ taskId }),
        startedAt.toISOString().replace('T', ' ').slice(0, 19),
        completedAt.toISOString().replace('T', ' ').slice(0, 19),
      );
    });
  }

  async function tick(t) {
    t.mock.timers.enable({ apis: ['Date'], now: FIXED_NOW });
    try {
      runtime._runDueLeadTimeTasks();
    } finally {
      t.mock.timers.reset();
    }
    await Promise.allSettled([...runtime.activeExecutionPromises]);
  }

  test('no head start is applied until the task has completed runs', () => {
    assert.equal(resolveLeadTimeMs(null), 0);
    assert.equal(resolveLeadTimeMs(0), 0);
    assert.equal(resolveLeadTimeMs(240), 240 * 1000);
    // The head start one occurrence can claim is capped at an hour.
    assert.equal(resolveLeadTimeMs(24 * 60 * 60), 60 * 60 * 1000);
  });

  test('a task without a head start stays on node-cron', async () => {
    await createTask({ cronExpression: '0 6 * * *' });
    assert.deepEqual(cronHarness.jobs.map((job) => job.expression), ['0 6 * * *']);
  });

  test('a task with a head start is driven by the poller, not node-cron', async () => {
    await createTask({ cronExpression: '0 6 * * *', finishOnTime: true });
    assert.deepEqual(cronHarness.jobs, []);
  });

  test('a task without run history starts at its configured time', async (t) => {
    const task = await createTask({ cronExpression: cronAt(0), finishOnTime: true });
    await tick(t);

    assert.equal(runCalls.length, 1);
    assert.equal(runCalls[0].scheduledAt, new Date(FIXED_NOW).toISOString());
    assert.equal(runtime._serializeTask(
      runtime.taskRepository.getTaskById(task.id, user.userId),
      user.userId,
    ).averageRunSeconds, null);
  });

  test('a task starts early enough to finish at its configured time', async (t) => {
    const task = await createTask({ cronExpression: cronAt(4), finishOnTime: true });
    recordRunHistory(task.id, [300, 300]);

    const serialized = runtime._serializeTask(
      runtime.taskRepository.getTaskById(task.id, user.userId),
      user.userId,
    );
    assert.equal(serialized.averageRunSeconds, 300);

    await tick(t);
    assert.equal(runCalls.length, 1);
    // The run is launched now but reports the configured time it must finish at.
    assert.equal(runCalls[0].scheduledAt, new Date(FIXED_NOW + (4 * MINUTE_MS)).toISOString());
  });

  test('a run is not started before its head start begins', async (t) => {
    const task = await createTask({ cronExpression: cronAt(4), finishOnTime: true });
    recordRunHistory(task.id, [90]);

    await tick(t);
    assert.equal(runCalls.length, 0);
  });

  test('an occurrence already started before a restart is not started again', async (t) => {
    const task = await createTask({ cronExpression: cronAt(4), finishOnTime: true });
    recordRunHistory(task.id, [300]);
    // A fresh runtime has no memory of the head start it already gave out; the
    // recorded last run is what keeps the occurrence from running twice.
    ctx.db.prepare("UPDATE scheduled_tasks SET last_run = datetime('now') WHERE id = ?").run(task.id);

    await tick(t);
    assert.equal(runCalls.length, 0);
  });

  test('an occurrence is only started once', async (t) => {
    const task = await createTask({ cronExpression: cronAt(4), finishOnTime: true });
    recordRunHistory(task.id, [300]);

    await tick(t);
    await tick(t);
    assert.equal(runCalls.length, 1);
  });
});
