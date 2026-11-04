'use strict';

const assert = require('node:assert/strict');
const { afterEach, beforeEach, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

let runtime;
let savedEnv;
let savedFetch;

beforeEach(() => {
  runtime = createTestRuntime();
  savedEnv = { ...process.env };
  const { AI_PROVIDER_DEFINITIONS } = require('../../../server/services/ai/models');
  for (const definition of Object.values(AI_PROVIDER_DEFINITIONS)) {
    if (definition.envKey) delete process.env[definition.envKey];
  }
  // A local Ollama on this machine must not count as a provider here.
  savedFetch = globalThis.fetch;
  globalThis.fetch = async () => { throw new Error('offline'); };
});

afterEach(() => {
  process.env = savedEnv;
  globalThis.fetch = savedFetch;
  teardownTestRuntime(runtime);
});

async function providersRow(userId) {
  const { runHealthChecks } = require('../../../server/services/admin/health');
  const { results } = await runHealthChecks({}, userId);
  return results.find((result) => result.id === 'ai_providers');
}

test('an account with no provider is told so', async () => {
  const { userId } = await createTestUser(runtime.db, { username: 'health_no_provider' });
  const row = await providersRow(userId);
  assert.equal(row.passed, false);
  assert.match(row.detail, /No providers/);
});

test('a key the account added itself counts, with no server key at all', async () => {
  const { setProviderSecret } = require('../../../server/services/ai/settings');
  const { userId } = await createTestUser(runtime.db, { username: 'health_own_key' });
  setProviderSecret(userId, 'anthropic', 'sk-ant-test');
  const row = await providersRow(userId);
  assert.equal(row.passed, true);
  assert.match(row.detail, /Anthropic/);
});

test('a key on another of the account\'s agents counts', async () => {
  const { setProviderSecret } = require('../../../server/services/ai/settings');
  const { createAgent } = require('../../../server/services/agents/manager');
  const { userId } = await createTestUser(runtime.db, { username: 'health_agent_key' });
  const agent = createAgent(userId, { displayName: 'Second' });
  setProviderSecret(userId, 'anthropic', 'sk-ant-test', agent.id);
  const row = await providersRow(userId);
  assert.equal(row.passed, true, row.detail);
});

test('a server key counts, and another account\'s key does not', async () => {
  const { setProviderSecret } = require('../../../server/services/ai/settings');
  const owner = await createTestUser(runtime.db, { username: 'health_owner' });
  const other = await createTestUser(runtime.db, { username: 'health_other' });
  setProviderSecret(other.userId, 'anthropic', 'sk-ant-test');
  assert.equal((await providersRow(owner.userId)).passed, false);

  process.env.ANTHROPIC_API_KEY = 'sk-ant-server';
  assert.equal((await providersRow(owner.userId)).passed, true);
});
