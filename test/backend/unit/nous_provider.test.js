'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { NOUS_BASE_URL, NousProvider } = require('../../../server/services/ai/providers/nous');
const { AI_PROVIDER_DEFINITIONS } = require('../../../server/services/ai/provider_definitions');

test('Nous Portal defaults to its inference endpoint', () => {
  const provider = new NousProvider({ apiKey: 'sk-nous' });
  assert.equal(provider.name, 'nous');
  assert.equal(provider.baseURL, NOUS_BASE_URL);
  assert.equal(AI_PROVIDER_DEFINITIONS.nous.defaultBaseUrl, NOUS_BASE_URL);
  assert.equal(AI_PROVIDER_DEFINITIONS.nous.envKey, 'NOUS_API_KEY');
});

test('Nous Portal leaves batch-only models out of its list', async () => {
  const provider = new NousProvider({ apiKey: 'sk-nous' });
  provider.client.models.list = async () => ({
    data: [{ id: 'deepseek/deepseek-v4.1-flash-1017' }, { id: 'deepseek/deepseek-v4.1-flash:batch' }],
  });
  const models = await provider.listModels();
  assert.deepEqual(models.map((model) => model.id), ['deepseek/deepseek-v4.1-flash-1017']);
});
