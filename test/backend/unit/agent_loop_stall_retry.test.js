'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

test('a model call that times out with no fallback left is retried on the same model', async () => {
  const ctx = createTestRuntime();
  const models = require('../../../server/services/ai/models');
  const originalGetSupportedModels = models.getSupportedModels;
  const originalCreateProviderInstance = models.createProviderInstance;

  try {
    const user = await createTestUser(ctx.db, { username: 'stall_retry_user' });
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
      async chat(_messages, _tools, { signal }) {
        modelCalls += 1;
        if (modelCalls === 1) {
          return new Promise((_, reject) => {
            signal.addEventListener('abort', () => reject(signal.reason), { once: true });
          });
        }
        return { content: 'Answered after the stall.', toolCalls: [] };
      },
    });

    const { AgentEngine } = require('../../../server/services/ai/engine');
    const engine = new AgentEngine(null);
    engine.emit = () => {};
    engine.startMessagingProgressSupervisor = () => {};
    engine.stopMessagingProgressSupervisor = () => {};
    engine.buildSystemPrompt = async () => ({ stable: 'You are a test agent.', dynamic: '' });
    engine.getAvailableTools = () => [];
    engine.persistPromptMetrics = async () => {};

    const result = await engine.run(user.userId, 'Say something.', {
      runId: 'stall-retry-run',
      stream: false,
      modelCallTimeoutMs: 50,
      skipGlobalRecall: true,
      skipConversationHistory: true,
      bypassUserRateLimits: true,
    });

    assert.equal(modelCalls, 2);
    assert.equal(result.content, 'Answered after the stall.');
  } finally {
    models.getSupportedModels = originalGetSupportedModels;
    models.createProviderInstance = originalCreateProviderInstance;
    teardownTestRuntime(ctx);
  }
});
