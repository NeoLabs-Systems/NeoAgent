'use strict';

const assert = require('node:assert/strict');
const { afterEach, beforeEach, describe, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

describe('model catalog', () => {
  let ctx;
  let user;
  let agentId;
  let originalApiKey;
  let originalListModels;

  beforeEach(async () => {
    ctx = createTestRuntime();
    user = await createTestUser(ctx.db, {
      username: 'model_catalog_user',
      password: 'ModelCatalog1!',
      email: 'model_catalog_user@example.com',
    });
    const { resolveAgentId } = require('../../../server/services/agents/manager');
    const { createDefaultAiSettings } = require('../../../server/services/ai/settings');
    const { OpenAIProvider } = require('../../../server/services/ai/providers/openai');
    agentId = resolveAgentId(user.userId, null);

    const configs = createDefaultAiSettings().ai_provider_configs;
    for (const config of Object.values(configs)) config.enabled = false;
    configs.openai.enabled = true;
    ctx.db.prepare(
      `INSERT INTO agent_settings (user_id, agent_id, key, value)
       VALUES (?, ?, 'ai_provider_configs', ?)`,
    ).run(user.userId, agentId, JSON.stringify(configs));

    originalApiKey = process.env.OPENAI_API_KEY;
    process.env.OPENAI_API_KEY = `catalog-test-${process.pid}-${Date.now()}`;
    originalListModels = OpenAIProvider.prototype.listModels;
    OpenAIProvider.prototype.listModels = async () => [
      { id: 'gpt-5.3', name: 'gpt-5.3' },
      { id: 'gpt-5.6', name: 'gpt-5.6' },
    ];
  });

  afterEach(() => {
    const { OpenAIProvider } = require('../../../server/services/ai/providers/openai');
    OpenAIProvider.prototype.listModels = originalListModels;
    if (originalApiKey === undefined) delete process.env.OPENAI_API_KEY;
    else process.env.OPENAI_API_KEY = originalApiKey;
    teardownTestRuntime(ctx);
  });

  test('returns only models reported by live provider discovery', async () => {
    const { getSupportedModels } = require('../../../server/services/ai/models');
    const models = await getSupportedModels(user.userId, agentId, {
      providerCatalog: [{
        id: 'openai',
        available: true,
        status: 'healthy',
        statusLabel: 'Healthy',
      }],
    });

    const openai = models.find((model) => model.id === 'openai::gpt-5.3');
    assert.equal(openai?.modelId, 'gpt-5.3');
    assert.equal(openai?.available, true);
    assert.equal(models.some((model) => model.provider !== 'openai'), false);
  });

  test('marks a model with persisted runtime failures unavailable without deleting it', async () => {
    const { recordModelFailure } = require('../../../server/services/ai/model_failure_cache');
    const { getSupportedModels } = require('../../../server/services/ai/models');
    recordModelFailure(
      user.userId,
      agentId,
      'openai::gpt-5.3',
      Object.assign(new Error('provider returned not found'), { status: 404 }),
    );

    const models = await getSupportedModels(user.userId, agentId, {
      providerCatalog: [{
        id: 'openai',
        available: true,
        status: 'healthy',
        statusLabel: 'Healthy',
      }],
    });
    const failed = models.find((model) => model.id === 'openai::gpt-5.3');

    assert.equal(failed?.available, false);
    assert.equal(failed?.runtimeUnavailable, true);
    assert.equal(models.find((model) => model.id === 'openai::gpt-5.6')?.available, true);
  });
});
