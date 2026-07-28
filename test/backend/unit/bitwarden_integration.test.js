'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');
const {
  createTestRuntime,
  createTestUser,
  teardownTestRuntime,
} = require('../../helpers/db');

test('Bitwarden provider connects with a master password without storing it', async (t) => {
  const ctx = createTestRuntime();
  t.after(() => teardownTestRuntime(ctx));
  const user = await createTestUser(ctx.db);
  const { ensureMainAgent } = require('../../../server/services/agents/manager');
  const agent = ensureMainAgent(user.userId);
  const calls = [];
  let cliStatus = {
    cliAvailable: true,
    unlocked: false,
    persistent: false,
  };
  const app = {
    locals: {
      bitwardenCli: {
        async unlock(userId, agentId, masterPassword, idleTimeoutMinutes, options) {
          calls.push({
            operation: 'unlock',
            userId,
            agentId,
            masterPassword,
            idleTimeoutMinutes,
            options,
          });
          cliStatus = {
            cliAvailable: true,
            unlocked: true,
            persistent: options.persistSession,
          };
        },
        getStatus() {
          return cliStatus;
        },
        async sync() {
          calls.push({ operation: 'sync' });
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
    },
  });

  assert.equal(saved.configured, true);
  assert.equal(saved.hasClientSecret, false);
  assert.equal(saved.hasConnectedAccount, false);
  assert.equal(provider.getEnvStatus({ userId: user.userId, agentId: agent.id }).configured, true);
  const connected = await provider.unlock({
    userId: user.userId,
    agentId: agent.id,
    masterPassword: 'master-password',
    persistSession: true,
  });
  assert.equal(connected.unlocked, true);
  assert.equal(connected.persistent, true);
  assert.equal(JSON.stringify(connected).includes('master-password'), false);
  assert.equal(calls[0].operation, 'unlock');
  assert.equal(calls[0].masterPassword, 'master-password');
  assert.equal(calls[0].options.config.email, 'vault@example.test');

  const rows = ctx.db.prepare(
    "SELECT * FROM integration_connections WHERE provider_key = 'bitwarden'",
  ).all();
  assert.equal(rows.length, 1);
  assert.equal(rows[0].credentials_json.includes('master-password'), false);
  const snapshot = provider.buildSnapshot(rows, { userId: user.userId, agentId: agent.id });
  const summary = provider.summarizeForModel(snapshot);
  assert.match(summary, /binding-1/);
  assert.equal(summary.includes('master-password'), false);

  await provider.testConnection(rows[0]);
  assert.equal(calls.at(-1).operation, 'sync');

  await provider.clearUserConfig({ userId: user.userId, agentId: agent.id });
  assert.equal(
    ctx.db.prepare("SELECT COUNT(*) count FROM integration_connections WHERE provider_key = 'bitwarden'").get().count,
    0,
  );
  assert.equal(calls.at(-1).operation, 'logout');
});
