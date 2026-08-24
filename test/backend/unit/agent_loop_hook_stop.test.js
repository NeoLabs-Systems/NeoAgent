'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

test('an on_loop_iteration stop is terminally recorded as stopped, never completed', async () => {
  const ctx = createTestRuntime();
  const models = require('../../../server/services/ai/models');
  const { globalHooks } = require('../../../server/services/ai/hooks');
  const originalGetSupportedModels = models.getSupportedModels;
  const originalCreateProviderInstance = models.createProviderInstance;
  const hookId = globalHooks.register('on_loop_iteration', async () => ({
    stop: true,
    reason: 'Stopped by reliability policy.',
  }), { id: 'test-reliability-stop' });
  let engine;

  try {
    const user = await createTestUser(ctx.db, { username: 'hook_stop_user' });
    let modelCalls = 0;
    models.getSupportedModels = async () => [{
      id: 'test-model',
      name: 'Test model',
      provider: 'test-provider',
      available: true,
      purpose: 'general',
      priceTier: 'free',
    }];
    models.createProviderInstance = () => ({
      getContextWindow: () => 128000,
      async chat() {
        modelCalls += 1;
        return { content: 'This should never be returned.', toolCalls: [] };
      },
    });

    const { AgentEngine } = require('../../../server/services/ai/engine');
    engine = new AgentEngine(null);
    engine.emit = () => {};
    engine.startMessagingProgressSupervisor = () => {};
    engine.stopMessagingProgressSupervisor = () => {};
    engine.buildSystemPrompt = async () => ({ stable: 'You are a test agent.', dynamic: '' });
    engine.getAvailableTools = () => [];
    engine.persistPromptMetrics = async () => {};

    const runId = 'hook-stop-run';
    const result = await engine.run(user.userId, 'Run until policy stops you.', {
      runId,
      stream: false,
      skipTaskAnalysis: true,
      skipDeliverableWorkflow: true,
      forceMode: 'execute',
      skipGlobalRecall: true,
      skipConversationHistory: true,
      skipConversationMaintenance: true,
      skipVerifier: true,
      bypassUserRateLimits: true,
    });

    assert.equal(result.status, 'stopped');
    assert.equal(result.content, '');
    assert.equal(modelCalls, 0);
    assert.deepEqual(
      ctx.db.prepare('SELECT status, error, final_response FROM agent_runs WHERE id = ?').get(runId),
      {
        status: 'stopped',
        error: 'Stopped by reliability policy.',
        final_response: null,
      },
    );
  } finally {
    globalHooks.deregister('on_loop_iteration', hookId);
    models.getSupportedModels = originalGetSupportedModels;
    models.createProviderInstance = originalCreateProviderInstance;
    teardownTestRuntime(ctx);
  }
});
