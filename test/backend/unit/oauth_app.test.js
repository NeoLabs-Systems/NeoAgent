'use strict';

const assert = require('node:assert/strict');
const { after, afterEach, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

const ctx = createTestRuntime();
after(() => teardownTestRuntime(ctx));

const ENV_NAMES = ['SLACK_OAUTH_CLIENT_ID', 'SLACK_OAUTH_CLIENT_SECRET', 'MICROSOFT_OAUTH_TENANT_ID'];
const savedEnvironment = Object.fromEntries(ENV_NAMES.map((name) => [name, process.env[name]]));
afterEach(() => {
  for (const name of ENV_NAMES) {
    if (savedEnvironment[name] === undefined) delete process.env[name];
    else process.env[name] = savedEnvironment[name];
  }
});

function createApp(fields = []) {
  const { createOAuthApp } = require('../../../server/services/integrations/oauth_app');
  return createOAuthApp({
    providerKey: 'slack',
    label: 'Slack',
    envPrefix: 'SLACK',
    consoleUrl: 'https://api.slack.com/apps',
    scopes: ['search:read', 'search:read'],
    fields,
  });
}

test('a user-registered OAuth app is stored encrypted per account and its secret is write-only', async () => {
  for (const name of ENV_NAMES) delete process.env[name];
  const user = await createTestUser(ctx.db, { username: 'own_oauth_app' });
  const scope = { userId: user.userId };
  const app = createApp();

  assert.equal(app.getEnvStatus(scope).configured, false);
  assert.equal(app.getEnvStatus(scope).setupMode, 'user');

  app.userConfigHandlers.saveUserConfig({ ...scope, config: { clientId: 'client-1', clientSecret: 'secret-1' } });
  const row = ctx.db
    .prepare("SELECT config_json FROM integration_oauth_apps WHERE user_id = ? AND provider_key = 'slack'")
    .get(user.userId);
  assert.match(row.config_json, /^enc:v1:/);
  assert.doesNotMatch(row.config_json, /secret-1/);

  const shown = app.userConfigHandlers.getUserConfig(scope);
  assert.equal(shown.clientId, 'client-1');
  assert.equal(shown.hasClientSecret, true);
  assert.deepEqual(shown.scopes, ['search:read']);
  assert.match(shown.redirectUri, /\/api\/integrations\/oauth\/callback$/);
  assert.doesNotMatch(JSON.stringify(shown), /secret-1/);

  // A blank secret keeps the stored one.
  app.userConfigHandlers.saveUserConfig({ ...scope, config: { clientId: 'client-2', clientSecret: '' } });
  const resolved = app.resolve(scope);
  assert.equal(resolved.source, 'user');
  assert.equal(resolved.clientId, 'client-2');
  assert.equal(resolved.clientSecret, 'secret-1');
  assert.equal(app.getEnvStatus(scope).configured, true);

  // Every agent of the account signs in through the same app.
  const { createAgent } = require('../../../server/services/agents/manager');
  const otherAgent = createAgent(user.userId, { displayName: 'Second agent' });
  assert.equal(app.resolve({ ...scope, agentId: otherAgent.id }).clientId, 'client-2');

  app.userConfigHandlers.clearUserConfig(scope);
  assert.equal(app.resolve(scope).configured, false);
});

test('a global server app wins and locks per-user setup', async () => {
  for (const name of ENV_NAMES) delete process.env[name];
  const user = await createTestUser(ctx.db, { username: 'global_oauth_app' });
  const scope = { userId: user.userId };
  const app = createApp();
  app.userConfigHandlers.saveUserConfig({ ...scope, config: { clientId: 'mine', clientSecret: 'mine-secret' } });

  process.env.SLACK_OAUTH_CLIENT_ID = 'server-client';
  process.env.SLACK_OAUTH_CLIENT_SECRET = 'server-secret';
  const resolved = app.resolve(scope);
  assert.equal(resolved.source, 'server');
  assert.equal(resolved.clientId, 'server-client');
  assert.equal(app.getEnvStatus(scope).setupMode, 'server');
  assert.equal(app.userConfigHandlers.getUserConfig(scope).clientId, '');
  assert.throws(
    () => app.userConfigHandlers.saveUserConfig({ ...scope, config: { clientId: 'x', clientSecret: 'y' } }),
    /configured globally/,
  );
  assert.throws(() => app.userConfigHandlers.clearUserConfig(scope), /configured globally/);
});

test('extra fields fall back to their default and reject malformed values', async () => {
  for (const name of ENV_NAMES) delete process.env[name];
  const user = await createTestUser(ctx.db, { username: 'oauth_app_fields' });
  const scope = { userId: user.userId };
  const app = createApp([
    { name: 'tenantId', label: 'Tenant ID', env: 'MICROSOFT_OAUTH_TENANT_ID', defaultValue: 'common' },
  ]);

  app.userConfigHandlers.saveUserConfig({ ...scope, config: { clientId: 'id', clientSecret: 'secret', tenantId: '' } });
  assert.equal(app.resolve(scope).tenantId, 'common');
  app.userConfigHandlers.saveUserConfig({ ...scope, config: { clientId: 'id', tenantId: 'contoso.onmicrosoft.com' } });
  assert.equal(app.resolve(scope).tenantId, 'contoso.onmicrosoft.com');
  assert.throws(
    () => app.userConfigHandlers.saveUserConfig({ ...scope, config: { clientId: 'id', tenantId: 'bad tenant' } }),
    /unsupported characters/,
  );
  assert.throws(
    () => app.userConfigHandlers.saveUserConfig({ ...scope, config: { clientId: '' } }),
    /Client ID is required/,
  );
});
