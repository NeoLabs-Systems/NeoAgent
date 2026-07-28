'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  createTestRuntime,
  createTestUser,
  teardownTestRuntime,
} = require('../../helpers/db');

test('connection test runs a provider health check and records only safe status', async (t) => {
  const ctx = createTestRuntime();
  t.after(() => teardownTestRuntime(ctx));
  const user = await createTestUser(ctx.db);
  const { ensureMainAgent } = require('../../../server/services/agents/manager');
  const { IntegrationManager } = require(
    '../../../server/services/integrations/manager',
  );
  const agent = ensureMainAgent(user.userId);
  let testedConnectionId = null;
  const provider = {
    key: 'test_provider',
    label: 'Test Provider',
    description: 'Connection test provider.',
    apps: [{ id: 'account', label: 'Account' }],
    getApp() {
      return this.apps[0];
    },
    getEnvStatus() {
      return { configured: true, missing: [], summary: 'Ready.' };
    },
    getToolDefinitions() {
      return [];
    },
    supportsTool() {
      return false;
    },
    buildSnapshot(rows) {
      const accounts = rows.map((row) => ({
        id: row.id,
        status: row.status,
        connected: row.status === 'connected',
        accountEmail: row.account_email,
      }));
      return {
        id: this.key,
        label: this.label,
        description: this.description,
        apps: [{
          id: 'account',
          label: 'Account',
          accounts,
          connection: { connected: accounts.length > 0 },
        }],
        connection: { connected: accounts.length > 0 },
        env: this.getEnvStatus(),
      };
    },
    async testConnection(connection) {
      testedConnectionId = connection.id;
      return {};
    },
  };
  const inserted = ctx.db.prepare(
    `INSERT INTO integration_connections (
       user_id, agent_id, provider_key, app_key, status, account_email,
       scopes_json, credentials_json, metadata_json, last_connected_at, updated_at
     ) VALUES (?, ?, ?, ?, 'connected', ?, '[]', '{}', '{}', datetime('now'), datetime('now'))`,
  ).run(
    user.userId,
    agent.id,
    provider.key,
    'account',
    'person@example.test',
  );
  const manager = new IntegrationManager();
  manager.registry = {
    get: (key) => key === provider.key ? provider : null,
    list: () => [provider],
  };

  const snapshot = manager.listProviders(user.userId, agent.id)[0];
  assert.equal(snapshot.apps[0].accounts[0].supportsConnectionTest, true);
  const result = await manager.testConnection(user.userId, provider.key, {
    connectionId: Number(inserted.lastInsertRowid),
    agentId: agent.id,
  });
  assert.equal(result.ok, true);
  assert.equal(result.message, 'Test Provider is connected and responding.');
  assert.equal(testedConnectionId, Number(inserted.lastInsertRowid));

  const stored = ctx.db.prepare(
    'SELECT metadata_json FROM integration_connections WHERE id = ?',
  ).get(inserted.lastInsertRowid);
  const metadata = JSON.parse(stored.metadata_json);
  assert.equal(metadata.last_connection_test_status, 'passed');
  assert.ok(Date.parse(metadata.last_connection_test_at) > 0);
});

test('automatic connection tests select only input-free read tools', () => {
  const { IntegrationManager } = require(
    '../../../server/services/integrations/manager',
  );
  const manager = Object.create(IntegrationManager.prototype);
  const provider = {
    getToolDefinitions() {
      return [
        {
          name: 'write_without_input',
          access: 'write',
          parameters: { type: 'object', properties: {} },
        },
        {
          name: 'read_with_input',
          access: 'read',
          parameters: {
            type: 'object',
            properties: { id: { type: 'string' } },
            required: ['id'],
          },
        },
        {
          name: 'safe_health_read',
          access: 'read',
          parameters: { type: 'object', properties: {} },
        },
      ];
    },
  };
  assert.equal(
    manager.getSafeConnectionTestTool(provider, 'account').name,
    'safe_health_read',
  );
});

test('OAuth connection tests persist credentials refreshed by a provider probe', async () => {
  const {
    createOAuthProvider,
  } = require('../../../server/services/integrations/oauth_provider');
  const provider = createOAuthProvider({
    key: 'oauth_test',
    label: 'OAuth Test',
    description: 'OAuth connection test.',
    apps: [{ id: 'account', label: 'Account' }],
    toolDefinitions: [],
    getEnvStatus() {
      return { configured: true };
    },
    async testConnection(context) {
      context.updateCredentials({
        ...context.credentials,
        access_token: 'refreshed-access-token',
      });
      return {};
    },
  });
  const execution = await provider.testConnection({
    user_id: 1,
    agent_id: 'main',
    app_key: 'account',
    credentials_json: JSON.stringify({ access_token: 'old-access-token' }),
  });

  assert.equal(execution.credentials.access_token, 'refreshed-access-token');
});
