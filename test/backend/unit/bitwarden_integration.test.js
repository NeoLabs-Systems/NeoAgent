'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');
const {
  createTestRuntime,
  createTestUser,
  teardownTestRuntime,
} = require('../../helpers/db');

test('Bitwarden provider stores API setup securely and exposes only safe status', async (t) => {
  const ctx = createTestRuntime();
  t.after(() => teardownTestRuntime(ctx));
  const user = await createTestUser(ctx.db);
  const { ensureMainAgent } = require('../../../server/services/agents/manager');
  const agent = ensureMainAgent(user.userId);
  const calls = [];
  const app = {
    locals: {
      bitwardenCli: {
        async configure(userId, agentId, config) {
          calls.push({ operation: 'configure', userId, agentId, config });
        },
        getStatus() {
          return { cliAvailable: true, unlocked: false, idleTimeoutMinutes: 30 };
        },
        async logout() {
          calls.push({ operation: 'logout' });
        },
      },
      credentialBroker: {
        summarizeBindings() {
          return 'binding-1: Work login (browser; https://example.test)';
        },
      },
    },
  };
  const { createBitwardenProvider } = require(
    '../../../server/services/integrations/bitwarden/provider',
  );
  const provider = createBitwardenProvider({ app });
  const saved = await provider.saveUserConfig({
    userId: user.userId,
    agentId: agent.id,
    config: {
      serverUrl: 'https://vault.bitwarden.com',
      email: 'vault@example.test',
      clientId: 'personal-client-id',
      clientSecret: 'personal-client-secret',
      idleTimeoutMinutes: 30,
    },
  });

  assert.equal(saved.configured, true);
  assert.equal(saved.hasClientSecret, true);
  assert.equal(JSON.stringify(saved).includes('personal-client-secret'), false);
  assert.equal(calls[0].config.clientSecret, 'personal-client-secret');
  assert.equal(provider.getEnvStatus({ userId: user.userId, agentId: agent.id }).configured, true);

  const rows = ctx.db.prepare(
    "SELECT * FROM integration_connections WHERE provider_key = 'bitwarden'",
  ).all();
  assert.equal(rows.length, 1);
  assert.equal(rows[0].credentials_json.includes('personal-client-secret'), false);
  const snapshot = provider.buildSnapshot(rows, { userId: user.userId, agentId: agent.id });
  const summary = provider.summarizeForModel(snapshot);
  assert.match(summary, /binding-1/);
  assert.equal(summary.includes('personal-client-secret'), false);

  await provider.clearUserConfig({ userId: user.userId, agentId: agent.id });
  assert.equal(
    ctx.db.prepare("SELECT COUNT(*) count FROM integration_connections WHERE provider_key = 'bitwarden'").get().count,
    0,
  );
  assert.equal(calls.at(-1).operation, 'logout');
});
