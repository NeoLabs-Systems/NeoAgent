'use strict';

const assert = require('node:assert/strict');
const { afterEach, beforeEach, describe, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

describe('model fallback selection', () => {
  let ctx;
  let user;
  let agentId;
  let modelsModule;
  let getFailureFallbackModelId;
  let originalGetSupportedModels;

  beforeEach(async () => {
    ctx = createTestRuntime();
    user = await createTestUser(ctx.db, {
      username: 'fallback_user',
      password: 'FallbackPass1!',
      email: 'fallback_user@example.com',
    });

    const { resolveAgentId } = require('../../../server/services/agents/manager');
    agentId = resolveAgentId(user.userId, null);
    ctx.db.prepare(
      `INSERT INTO agent_settings (user_id, agent_id, key, value)
       VALUES (?, ?, ?, ?)
       ON CONFLICT(user_id, agent_id, key) DO UPDATE SET value = excluded.value`
    ).run(user.userId, agentId, 'enabled_models', JSON.stringify(['google/gemini-2.5-flash-lite']));
    ctx.db.prepare(
      `INSERT INTO agent_settings (user_id, agent_id, key, value)
       VALUES (?, ?, ?, ?)
       ON CONFLICT(user_id, agent_id, key) DO UPDATE SET value = excluded.value`
    ).run(user.userId, agentId, 'fallback_model_id', JSON.stringify('google/gemini-2.5-flash-lite'));

    modelsModule = require('../../../server/services/ai/models');
    originalGetSupportedModels = modelsModule.getSupportedModels;
    modelsModule.getSupportedModels = async () => ([
      { id: 'google/gemini-2.5-flash-lite', provider: 'openrouter', available: true },
      { id: 'google/gemini-3.1-flash-image', provider: 'openrouter', available: true },
      { id: 'openai/gpt-5-nano', provider: 'openai', available: true },
    ]);

    ({ getFailureFallbackModelId } = require('../../../server/services/ai/loop/conversation_loop'));
  });

  afterEach(() => {
    if (modelsModule && originalGetSupportedModels) {
      modelsModule.getSupportedModels = originalGetSupportedModels;
    }
    teardownTestRuntime(ctx);
  });

  test('does not fall back outside the enabled model pool', async () => {
    const fallback = await getFailureFallbackModelId(
      user.userId,
      agentId,
      'google/gemini-2.5-flash-lite',
      'google/gemini-2.5-flash-lite',
      new Error('Model google/gemini-2.5-flash-lite returned an empty response.'),
    );

    assert.equal(fallback, null);
  });
});
