'use strict';

const assert = require('node:assert/strict');
const { afterEach, beforeEach, describe, test } = require('node:test');

const {
  createTestRuntime,
  createTestUser,
  teardownTestRuntime,
} = require('../../helpers/db');

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
    schedule(expression, callback, options) {
      const job = {
        expression,
        callback,
        options,
        stop() {
          this.stopped = true;
        },
      };
      jobs.push(job);
      return job;
    },
  };
}

describe('recurring task cron ticks', () => {
  let ctx;
  let user;
  let runtime;
  let cronHarness;
  let runCalls;

  beforeEach(async () => {
    ctx = createTestRuntime();
    user = await createTestUser(ctx.db);
    const { TaskRuntime } = require('../../../server/services/tasks/runtime');
    cronHarness = createCronHarness();
    runCalls = [];
    runtime = new TaskRuntime(createIoRecorder(), {
      async runWithModel(userId, prompt, options) {
        runCalls.push(options);
        return { content: 'done' };
      },
    }, null, { cron: cronHarness });
    await runtime.createTask(user.userId, {
      name: 'Morning recap',
      triggerType: 'schedule',
      triggerConfig: { mode: 'recurring', cronExpression: '0 6 * * *' },
      taskConfig: { prompt: 'Prepare the morning recap.' },
    });
  });

  afterEach(async () => {
    await runtime?.stop();
    runtime = null;
    teardownTestRuntime(ctx);
  });

  function tickLateBy(ms) {
    const [job] = cronHarness.jobs;
    return job.callback({ date: new Date(Date.now() - ms) });
  }

  test('node-cron hands over ticks that fire seconds late instead of dropping them', () => {
    const [job] = cronHarness.jobs;
    assert.ok(job.options.missedExecutionTolerance >= 60 * 1000);
  });

  test('a tick held up by another task due at the same minute still runs, timed from its slot', async () => {
    await tickLateBy(2000);

    assert.equal(runCalls.length, 1);
    assert.ok(Date.now() - new Date(runCalls[0].scheduledAt).getTime() >= 2000);
  });

  test('a tick that fires minutes after its slot is skipped as stale', async () => {
    const result = await tickLateBy(5 * 60 * 1000);

    assert.equal(runCalls.length, 0);
    assert.equal(result, undefined);
  });
});
