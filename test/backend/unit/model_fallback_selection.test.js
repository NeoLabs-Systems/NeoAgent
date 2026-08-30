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

  test('widens beyond a failed enabled-only pool to keep the run alive', async () => {
    const fallback = await getFailureFallbackModelId(
      user.userId,
      agentId,
      'google/gemini-2.5-flash-lite',
      new Error('Model google/gemini-2.5-flash-lite returned an empty response.'),
    );

    assert.equal(fallback, 'openai/gpt-5-nano');
  });

  test('does not cycle back to models that already failed in the same run', async () => {
    const modelIds = [
      'google::gemini-primary',
      'openrouter::gemini-fallback',
      'openai::gpt-backup',
    ];
    ctx.db.prepare(
      `INSERT INTO agent_settings (user_id, agent_id, key, value)
       VALUES (?, ?, ?, ?)
       ON CONFLICT(user_id, agent_id, key) DO UPDATE SET value = excluded.value`
    ).run(user.userId, agentId, 'enabled_models', JSON.stringify(modelIds));
    modelsModule.getSupportedModels = async () => ([
      { id: modelIds[0], provider: 'google', available: true },
      { id: modelIds[1], provider: 'openrouter', available: true },
      { id: modelIds[2], provider: 'openai', available: true },
    ]);

    const fallback = await getFailureFallbackModelId(
      user.userId,
      agentId,
      modelIds[1],
      new Error('Model returned an empty response.'),
      null,
      new Set([modelIds[0], modelIds[1]]),
    );

    assert.equal(fallback, modelIds[2]);
  });

  test('provider-wide failures prefer another provider over a configured sibling model', async () => {
    const modelIds = [
      'google::gemini-primary',
      'google::gemini-fallback',
      'openrouter::gemini-backup',
    ];
    ctx.db.prepare(
      `INSERT INTO agent_settings (user_id, agent_id, key, value)
       VALUES (?, ?, ?, ?)
       ON CONFLICT(user_id, agent_id, key) DO UPDATE SET value = excluded.value`
    ).run(user.userId, agentId, 'enabled_models', JSON.stringify(modelIds));
    modelsModule.getSupportedModels = async () => ([
      { id: modelIds[0], provider: 'google', available: true },
      { id: modelIds[1], provider: 'google', available: true },
      { id: modelIds[2], provider: 'openrouter', available: true },
    ]);

    const fallback = await getFailureFallbackModelId(
      user.userId,
      agentId,
      modelIds[0],
      Object.assign(new Error('Google service unavailable'), { status: 503 }),
    );

    assert.equal(fallback, modelIds[2]);
  });
});
