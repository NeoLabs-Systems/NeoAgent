'use strict';

const assert = require('node:assert/strict');
const { afterEach, beforeEach, describe, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

describe('provider selector', () => {
  let ctx;
  let user;
  let agentId;
  let modelsModule;
  let originalCreateProviderInstance;
  let originalGetSupportedModels;
  let getProviderForUser;
  let modelFailureCache;

  const catalog = [
    {
      id: 'github-copilot::gpt-5.3',
      modelId: 'gpt-5.3',
      provider: 'github-copilot',
      purpose: 'general',
      available: true,
    },
    {
      id: 'openai::gpt-5.3',
      modelId: 'gpt-5.3',
      provider: 'openai',
      purpose: 'general',
      available: true,
    },
  ];

  function setSetting(key, value) {
    ctx.db.prepare(
      `INSERT INTO agent_settings (user_id, agent_id, key, value)
       VALUES (?, ?, ?, ?)
       ON CONFLICT(user_id, agent_id, key) DO UPDATE SET value = excluded.value`,
    ).run(user.userId, agentId, key, JSON.stringify(value));
  }

  beforeEach(async () => {
    ctx = createTestRuntime();
    user = await createTestUser(ctx.db, {
      username: 'provider_selector_user',
      password: 'ProviderSelector1!',
      email: 'provider_selector_user@example.com',
    });
    const { resolveAgentId } = require('../../../server/services/agents/manager');
    agentId = resolveAgentId(user.userId, null);

    modelsModule = require('../../../server/services/ai/models');
    originalCreateProviderInstance = modelsModule.createProviderInstance;
    originalGetSupportedModels = modelsModule.getSupportedModels;
    modelsModule.getSupportedModels = async () => catalog;
    modelsModule.createProviderInstance = (provider) => ({ provider });
    modelFailureCache = require('../../../server/services/ai/model_failure_cache');

    delete require.cache[require.resolve('../../../server/services/ai/provider_selector')];
    ({ getProviderForUser } = require('../../../server/services/ai/provider_selector'));
  });

  afterEach(() => {
    modelFailureCache.clearModelFailureCache();
    modelsModule.createProviderInstance = originalCreateProviderInstance;
    modelsModule.getSupportedModels = originalGetSupportedModels;
    delete require.cache[require.resolve('../../../server/services/ai/provider_selector')];
    teardownTestRuntime(ctx);
  });

  test('routes equal raw model ids to the explicitly selected provider', async () => {
    setSetting('enabled_models', catalog.map((model) => model.id));
    setSetting('default_chat_model', 'openai::gpt-5.3');

    const selected = await getProviderForUser(user.userId, '', false, null, { agentId });
    assert.equal(selected.providerName, 'openai');
    assert.equal(selected.model, 'gpt-5.3');
    assert.equal(selected.modelSelectionId, 'openai::gpt-5.3');
  });

  test('keeps deterministic catalog ordering for legacy raw settings', async () => {
    setSetting('enabled_models', ['gpt-5.3']);
    setSetting('default_chat_model', 'gpt-5.3');

    const selected = await getProviderForUser(user.userId, '', false, null, { agentId });
    assert.equal(selected.providerName, 'github-copilot');
    assert.equal(selected.modelSelectionId, 'github-copilot::gpt-5.3');
  });

  test('allows an explicit available fallback outside the smart-selector pool', async () => {
    setSetting('enabled_models', ['github-copilot::gpt-5.3']);

    const selected = await getProviderForUser(
      user.userId,
      '',
      false,
      'openai::gpt-5.3',
      { agentId },
    );
    assert.equal(selected.providerName, 'openai');
  });

  test('does not silently widen an explicitly configured but invalid model pool', async () => {
    setSetting('enabled_models', ['missing-provider::missing-model']);

    await assert.rejects(
      getProviderForUser(user.userId, '', false, null, { agentId }),
      /None of the enabled AI models are currently available/,
    );
  });

  test('skips a model that recently returned a permanent not-found error', async () => {
    setSetting('enabled_models', catalog.map((model) => model.id));
    setSetting('default_chat_model', 'github-copilot::gpt-5.3');
    setSetting('fallback_model_id', 'openai::gpt-5.3');
    modelFailureCache.recordModelFailure(
      user.userId,
      agentId,
      'github-copilot::gpt-5.3',
      Object.assign(new Error('model request returned 404'), { status: 404 }),
    );

    const statuses = [];
    const selected = await getProviderForUser(user.userId, '', false, null, {
      agentId,
      onStatus: (status) => statuses.push(status),
    });

    assert.equal(selected.modelSelectionId, 'openai::gpt-5.3');
    assert.equal(statuses[0]?.phase, 'model_fallback');
  });
});
