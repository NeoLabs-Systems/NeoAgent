'use strict';

const assert = require('node:assert/strict');
const { afterEach, beforeEach, describe, test } = require('node:test');

const {
  createTestRuntime,
  createTestUser,
  teardownTestRuntime,
} = require('../../helpers/db');

describe('timeline prompt context', () => {
  let ctx;
  let user;
  let TimelineService;

  beforeEach(async () => {
    ctx = createTestRuntime();
    user = await createTestUser(ctx.db, { username: 'timeline_prompt_user' });
    ({ TimelineService } = require('../../../server/services/timeline/service'));
  });

  afterEach(() => {
    teardownTestRuntime(ctx);
  });

  test('buildPromptContext returns a small formatted recent context slice', () => {
    const timeline = new TimelineService({ db: ctx.db });
    timeline.recordRunLifecycle({
      userId: user.userId,
      runId: 'run-1',
      title: 'Implement timeline context injection',
      eventKind: 'run_started',
      occurredAt: '2026-06-23T09:00:00.000Z',
      status: 'running',
      triggerSource: 'web',
    });
    timeline.recordTaskLifecycle({
      userId: user.userId,
      taskId: 17,
      taskName: 'Daily summary',
      eventKind: 'task_completed',
      occurredAt: '2026-06-23T09:10:00.000Z',
      runId: 'run-17',
      triggerType: 'schedule',
      triggerSource: 'schedule',
    });
    const context = timeline.buildPromptContext(user.userId, {
      query: 'timeline implementation',
      limit: 2,
      sources: ['runs', 'tasks'],
    });

    assert.match(context, /Recent timeline context/);
    assert.match(context, /\[run 2026-06-23 09:00]/);
    assert.doesNotMatch(context, /Daily summary/);
  });

  test('buildPromptContext returns an empty string when there is no activity', () => {
    const timeline = new TimelineService({ db: ctx.db });
    assert.equal(timeline.buildPromptContext(user.userId), '');
  });
});
