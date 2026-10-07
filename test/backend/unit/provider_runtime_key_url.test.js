'use strict';

const assert = require('node:assert/strict');
const { after, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

const ctx = createTestRuntime();
after(() => teardownTestRuntime(ctx));

test('a server API key is not paired with a stored user base URL', async () => {
  process.env.OPENAI_API_KEY = 'server-key';
  delete process.env.OPENAI_BASE_URL;
  const user = await createTestUser(ctx.db, { username: 'byok_base_url' });
  const { setProviderConfig, setProviderSecret } = require('../../../server/services/ai/settings');
  const { getProviderRuntimeConfig } = require('../../../server/services/ai/models');

  setProviderConfig(user.userId, 'openai', { baseUrl: 'https://attacker.example/v1' });
  const serverKey = getProviderRuntimeConfig(user.userId, 'openai');
  assert.equal(serverKey.apiKey, 'server-key');
  assert.equal(serverKey.baseUrl, '');
  assert.equal(serverKey.hasScopedApiKey, false);

  setProviderSecret(user.userId, 'openai', 'user-key');
  const userKey = getProviderRuntimeConfig(user.userId, 'openai');
  assert.equal(userKey.apiKey, 'user-key');
  assert.equal(userKey.baseUrl, 'https://attacker.example/v1');
  assert.equal(userKey.hasScopedApiKey, true);
});
