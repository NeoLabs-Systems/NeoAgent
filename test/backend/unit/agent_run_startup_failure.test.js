'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

test('provider-selection failures leave a durable failed run instead of disappearing', async () => {
  const ctx = createTestRuntime();
  const models = require('../../../server/services/ai/models');
  const originalGetSupportedModels = models.getSupportedModels;
  try {
    const user = await createTestUser(ctx.db, { username: 'startup_failure_user' });
    models.getSupportedModels = async () => [];
    const { AgentEngine } = require('../../../server/services/ai/engine');
    const engine = new AgentEngine(null);
    engine.emit = () => {};

    await assert.rejects(
      engine.run(user.userId, 'Do something.', {
        runId: 'provider-selection-failure',
        bypassUserRateLimits: true,
      }),
      /No AI providers are currently available/,
    );

    const row = ctx.db.prepare(
      'SELECT status, error, completed_at FROM agent_runs WHERE id = ?',
    ).get('provider-selection-failure');
    assert.equal(row.status, 'failed');
    assert.match(row.error, /No AI providers are currently available/);
    assert.ok(row.completed_at);
    assert.equal(engine.activeRuns.has('provider-selection-failure'), false);
  } finally {
    models.getSupportedModels = originalGetSupportedModels;
    teardownTestRuntime(ctx);
  }
});

test('duplicate run ids are rejected without reviving or mutating the original run', async () => {
  const ctx = createTestRuntime();
  try {
    const user = await createTestUser(ctx.db, { username: 'duplicate_run_user' });
    ctx.db.prepare(
      `INSERT INTO agent_runs (
        id, user_id, title, status, model, final_response, completed_at
      ) VALUES (?, ?, ?, 'completed', ?, ?, datetime('now'))`,
    ).run('duplicate-run', user.userId, 'Original', 'test-model', 'Original result.');

    const { AgentEngine } = require('../../../server/services/ai/engine');
    const engine = new AgentEngine(null);
    await assert.rejects(
      engine.run(user.userId, 'A duplicate request.', {
        runId: 'duplicate-run',
        bypassUserRateLimits: true,
      }),
      (error) => error.code === 'RUN_ID_CONFLICT',
    );

    assert.deepEqual(
      ctx.db.prepare(
        'SELECT status, model, final_response FROM agent_runs WHERE id = ?',
      ).get('duplicate-run'),
      {
        status: 'completed',
        model: 'test-model',
        final_response: 'Original result.',
      },
    );
  } finally {
    teardownTestRuntime(ctx);
  }
});
