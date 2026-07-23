'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

test('a run can be stopped while model discovery is still pending', async () => {
  const ctx = createTestRuntime();
  const models = require('../../../server/services/ai/models');
  const originalGetSupportedModels = models.getSupportedModels;
  let signalSeen;
  let notifyStarted;
  const started = new Promise((resolve) => { notifyStarted = resolve; });

  try {
    const user = await createTestUser(ctx.db, { username: 'startup_abort_user' });
    models.getSupportedModels = async (_userId, _agentId, options = {}) => {
      signalSeen = options.signal;
      notifyStarted();
      return new Promise((_, reject) => {
        const onAbort = () => {
          const error = new Error(String(options.signal?.reason || 'aborted'));
          error.name = 'AbortError';
          error.code = 'ABORT_ERR';
          reject(error);
        };
        if (options.signal?.aborted) onAbort();
        else options.signal?.addEventListener('abort', onAbort, { once: true });
      });
    };

    const { AgentEngine } = require('../../../server/services/ai/engine');
    const engine = new AgentEngine(null);
    engine.emit = () => {};
    const runId = 'startup-abort-run';
    const run = engine.run(user.userId, 'Do something after discovery.', {
      runId,
      bypassUserRateLimits: true,
    });

    await started;
    assert.equal(engine.activeRuns.has(runId), true);
    assert.equal(engine.abort(runId, {
      userId: user.userId,
      reason: 'Stopped during provider discovery.',
    }), true);
    assert.equal(signalSeen.aborted, true);

    const result = await run;
    assert.equal(result.status, 'stopped');
    assert.equal(engine.activeRuns.has(runId), false);
    assert.deepEqual(
      ctx.db.prepare('SELECT status, error FROM agent_runs WHERE id = ?').get(runId),
      {
        status: 'stopped',
        error: 'Stopped during provider discovery.',
      },
    );
  } finally {
    models.getSupportedModels = originalGetSupportedModels;
    teardownTestRuntime(ctx);
  }
});

test('a caller AbortSignal interrupts a run while model discovery is pending', async () => {
  const ctx = createTestRuntime();
  const models = require('../../../server/services/ai/models');
  const originalGetSupportedModels = models.getSupportedModels;
  let notifyStarted;
  const started = new Promise((resolve) => { notifyStarted = resolve; });

  try {
    const user = await createTestUser(ctx.db, { username: 'external_abort_user' });
    models.getSupportedModels = async (_userId, _agentId, options = {}) => {
      notifyStarted();
      return new Promise((_, reject) => {
        options.signal.addEventListener('abort', () => reject(options.signal.reason), {
          once: true,
        });
      });
    };

    const { AgentEngine } = require('../../../server/services/ai/engine');
    const engine = new AgentEngine(null);
    engine.emit = () => {};
    const controller = new AbortController();
    const runId = 'external-startup-abort-run';
    const run = engine.run(user.userId, 'Do something after discovery.', {
      runId,
      signal: controller.signal,
      bypassUserRateLimits: true,
    });

    await started;
    controller.abort('Scheduled task runtime stopped.');
    const result = await run;

    assert.equal(result.status, 'interrupted');
    assert.equal(engine.activeRuns.has(runId), false);
    assert.equal(
      ctx.db.prepare('SELECT status FROM agent_runs WHERE id = ?').get(runId).status,
      'interrupted',
    );
  } finally {
    models.getSupportedModels = originalGetSupportedModels;
    teardownTestRuntime(ctx);
  }
});
