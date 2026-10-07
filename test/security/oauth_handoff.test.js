'use strict';

const assert = require('node:assert/strict');
const { after, before, describe, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../helpers/db');
const { createTestApp, loginAs } = require('../helpers/app');
const { agent } = require('../helpers/supertest');

function stateFrom(url) {
  return new URL(url).searchParams.get('state');
}

function confirmPathFrom(html) {
  const match = html.match(/href="callback\/confirm\?token=([^"]+)"/);
  assert.ok(match, 'confirmation page carries a confirm link');
  return `/api/integrations/oauth/callback/confirm?token=${match[1]}`;
}

describe('OAuth state is bound to the client that started it', () => {
  let ctx;
  let app;
  let owner;

  before(async () => {
    ctx = createTestRuntime();
    const { AuthProviderManager } = require('../../server/services/account/auth_provider_manager');
    const { IntegrationManager } = require('../../server/services/integrations/manager');

    const signInProvider = {
      key: 'google',
      label: 'Google',
      getEnvStatus: () => ({ configured: true }),
      beginOAuth: ({ state }) => ({ url: `https://idp.example.test/authorize?state=${state}` }),
      finishOAuth: ({ code }) => ({ providerUserId: `sub-${code}`, email: `${code}@example.test` }),
    };
    const authProviderManager = new AuthProviderManager();
    authProviderManager.registry = { get: (key) => (key === 'google' ? signInProvider : null), list: () => [signInProvider] };

    const integrationProvider = {
      key: 'test_oauth',
      label: 'Test OAuth',
      requiresRefreshToken: false,
      getApp: (appKey) => (appKey === 'mail' ? { id: 'mail', label: 'Mail' } : null),
      getEnvStatus: () => ({ configured: true }),
      beginOAuth: ({ state }) => ({ url: `https://provider.example.test/authorize?state=${state}` }),
      finishOAuth: async ({ code }) => ({
        accountEmail: `${code}@example.test`,
        credentials: { access_token: `token-${code}` },
        scopes: ['mail.read'],
      }),
    };
    const integrationManager = new IntegrationManager();
    integrationManager.registry = {
      get: (key) => (key === integrationProvider.key ? integrationProvider : null),
      list: () => [integrationProvider],
    };

    app = createTestApp({ locals: { authProviderManager, integrationManager } }).app;
    owner = await createTestUser(ctx.db, { username: 'oauth_handoff_owner' });
    ctx.db.prepare(
      'INSERT INTO user_auth_providers (user_id, provider_key, provider_user_id, email) VALUES (?, ?, ?, ?)',
    ).run(owner.userId, 'google', 'sub-victim', 'victim@example.test');
  });

  after(() => teardownTestRuntime(ctx));

  test('a sign-in started elsewhere is held for confirmation, then only the starter can collect it', async () => {
    const attacker = agent(app);
    const begun = await attacker.post('/api/auth/providers/google/begin').send({ mode: 'login' }).expect(200);
    const state = stateFrom(begun.body.url);

    const victimBrowser = agent(app);
    const callback = await victimBrowser.get(`/api/integrations/oauth/callback?state=${state}&code=victim`).expect(200);
    assert.match(callback.text, /Do you want to finish signing in to NeoAgent with Google\?/);
    assert.equal((await attacker.get(`/api/auth/providers/complete?state=${state}`).expect(200)).body.status, 'pending');

    await victimBrowser.get(confirmPathFrom(callback.text)).expect(200);
    await victimBrowser.get(`/api/auth/providers/complete?state=${state}`).expect(404);
    const completed = await attacker.get(`/api/auth/providers/complete?state=${state}`).expect(200);
    assert.equal(completed.body.user.id, owner.userId);
  });

  test('the same browser finishes a sign-in without a confirmation step', async () => {
    const browser = agent(app);
    const begun = await browser.post('/api/auth/providers/google/begin').send({ mode: 'login' }).expect(200);
    const state = stateFrom(begun.body.url);
    const callback = await browser.get(`/api/integrations/oauth/callback?state=${state}&code=victim`).expect(200);
    assert.doesNotMatch(callback.text, /Do you want to/);
    const completed = await browser.get(`/api/auth/providers/complete?state=${state}`).expect(200);
    assert.equal(completed.body.user.id, owner.userId);
  });

  test('an integration callback from another browser stores nothing until confirmed', async () => {
    const starter = agent(app);
    await loginAs(starter, owner);
    const begun = await starter.post('/api/integrations/test_oauth/connect').send({ appId: 'mail' }).expect(200);
    const state = stateFrom(begun.body.url);

    const otherBrowser = agent(app);
    const callback = await otherBrowser.get(`/api/integrations/oauth/callback?state=${state}&code=other`).expect(200);
    assert.match(callback.text, /connect Test OAuth Mail to the NeoAgent account <strong>oauth_handoff_owner<\/strong>/);
    const countConnections = () => ctx.db.prepare(
      'SELECT COUNT(*) AS count FROM integration_connections WHERE user_id = ?',
    ).get(owner.userId).count;
    assert.equal(countConnections(), 0);

    const confirmPath = confirmPathFrom(callback.text);
    await otherBrowser.get(confirmPath).expect(200);
    assert.equal(countConnections(), 1);
    await otherBrowser.get(confirmPath).expect(400);
  });
});
