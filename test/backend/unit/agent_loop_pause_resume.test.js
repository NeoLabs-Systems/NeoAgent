'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

function waitForAbort(signal) {
  return new Promise((_, reject) => {
    const fail = () => {
      const error = new Error('model call aborted for pause');
      error.name = 'AbortError';
      reject(error);
    };
    if (signal.aborted) fail();
    else signal.addEventListener('abort', fail, { once: true });
  });
}

test('a full loop pauses during a model call and resumes the same run to completion', async () => {
  const ctx = createTestRuntime();
  const models = require('../../../server/services/ai/models');
  const originalGetSupportedModels = models.getSupportedModels;
  const originalCreateProviderInstance = models.createProviderInstance;
  let engine;
  const runId = 'full-loop-pause-resume';

  try {
    const user = await createTestUser(ctx.db, { username: 'full_loop_pause_resume' });
    let firstModelCallStarted;
    const firstModelCall = new Promise((resolve) => { firstModelCallStarted = resolve; });
    let modelCalls = 0;
    const provider = {
      getContextWindow: () => 128000,
      async chat(_messages, _tools, options) {
        modelCalls += 1;
        if (modelCalls === 1) {
          firstModelCallStarted(options.signal);
          return waitForAbort(options.signal);
        }
        return {
          content: 'Completed after resume.',
          toolCalls: [],
          finishReason: 'stop',
          usage: { promptTokens: 5, completionTokens: 4, totalTokens: 9 },
        };
      },
    };
    models.getSupportedModels = async () => [{
      id: 'test-model',
      name: 'Test model',
      provider: 'test-provider',
      available: true,
      purpose: 'general',
      priceTier: 'free',
    }];
    models.createProviderInstance = () => provider;

    const { AgentEngine } = require('../../../server/services/ai/engine');
    engine = new AgentEngine(null);
    engine.emit = () => {};
    engine.recordRunEvent = () => {};
    engine.startMessagingProgressSupervisor = () => {};
    engine.stopMessagingProgressSupervisor = () => {};
    engine.buildSystemPrompt = async () => ({ stable: 'You are a test agent.', dynamic: '' });
    engine.getAvailableTools = () => [];
    engine.persistPromptMetrics = async () => {};
    engine.decideLoopState = async () => ({
      decision: { status: 'complete', reason: 'The response is final.' },
      usage: 0,
    });

    const runPromise = engine.run(user.userId, 'Complete this after a pause.', {
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

    const firstSignal = await Promise.race([
      firstModelCall,
      runPromise.then(
        () => Promise.reject(new Error('Run completed before the model call started.')),
        (error) => Promise.reject(error),
      ),
    ]);
    assert.equal(engine.getRunMeta(runId).pauseAvailable, true);
    assert.equal(engine.pauseRun(runId, { userId: user.userId, reason: 'loop test' }), true);
    assert.equal(firstSignal.aborted, true);

    for (let attempt = 0; attempt < 20; attempt += 1) {
      if (ctx.db.prepare('SELECT status FROM agent_runs WHERE id = ?').get(runId)?.status === 'paused') break;
      await new Promise((resolve) => setImmediate(resolve));
    }
    assert.equal(ctx.db.prepare('SELECT status FROM agent_runs WHERE id = ?').get(runId).status, 'paused');
    assert.equal(engine.resumeRun(runId, { userId: user.userId }), true);

    const result = await runPromise;
    assert.equal(result.status, 'completed');
    assert.equal(result.content, 'Completed after resume.');
    assert.equal(modelCalls, 2);
    assert.deepEqual(
      ctx.db.prepare('SELECT status, final_response FROM agent_runs WHERE id = ?').get(runId),
      { status: 'completed', final_response: 'Completed after resume.' },
    );
  } finally {
    if (engine?.activeRuns.has(runId)) engine.stopRun(runId);
    models.getSupportedModels = originalGetSupportedModels;
    models.createProviderInstance = originalCreateProviderInstance;
    teardownTestRuntime(ctx);
  }
});
