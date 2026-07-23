'use strict';

const assert = require('node:assert/strict');
const { afterEach, test } = require('node:test');
const {
  createTestRuntime,
  createTestUser,
  teardownTestRuntime,
} = require('../../helpers/db');

let ctx = null;
const originalFetch = global.fetch;

afterEach(() => {
  global.fetch = originalFetch;
  teardownTestRuntime(ctx);
  ctx = null;
});

async function setupBroker(options = {}) {
  ctx = createTestRuntime();
  const user = await createTestUser(ctx.db);
  const { ensureMainAgent } = require('../../../server/services/agents/manager');
  const agent = ensureMainAgent(user.userId);
  const connection = ctx.db.prepare(
    `INSERT INTO integration_connections (
       user_id, agent_id, provider_key, app_key, status, account_email, credentials_json
     ) VALUES (?, ?, 'bitwarden', 'password_manager', 'connected', ?, '{}')`,
  ).run(user.userId, agent.id, 'vault@example.test');
  const item = {
    id: 'vault-item-1',
    name: 'Production login',
    login: {
      username: 'person@example.test',
      password: 'do-not-leak-password',
      uris: [{ uri: 'https://accounts.example.test/login' }],
    },
    fields: [{ id: 'api-field', name: 'API token', type: 1, value: 'do-not-leak-token' }],
  };
  const bitwarden = {
    async sync() {},
    async listItems() { return [item]; },
    async getItem() { return item; },
  };
  if (options.mockNetworkValidation) {
    const modulePath = require.resolve('../../../server/utils/cloud-security');
    require(modulePath);
    require.cache[modulePath].exports.validateCloudUrlWithDns = async () => ({ allowed: true });
  }
  const { CredentialBroker } = require('../../../server/services/credentials/broker');
  return {
    user,
    agent,
    item,
    connectionId: Number(connection.lastInsertRowid),
    broker: new CredentialBroker({
      bitwarden,
      runtimeManager: options.runtimeManager || null,
    }),
  };
}

test('vault item and binding responses contain metadata but no secret values', async () => {
  const fixture = await setupBroker();
  const items = await fixture.broker.listVaultItems(fixture.user.userId, fixture.agent.id);
  const serializedItems = JSON.stringify(items);
  assert.equal(serializedItems.includes('do-not-leak-password'), false);
  assert.equal(serializedItems.includes('do-not-leak-token'), false);
  assert.equal(items[0].usernameMasked.includes('person@example.test'), false);

  const binding = await fixture.broker.createBinding(fixture.user.userId, fixture.agent.id, {
    connectionId: fixture.connectionId,
    alias: 'Example login',
    usageType: 'browser',
    itemId: fixture.item.id,
    origins: ['https://accounts.example.test'],
  });
  assert.deepEqual(binding.target.origins, ['https://accounts.example.test']);
  assert.equal(JSON.stringify(binding).includes(fixture.item.id), false);
  const stored = ctx.db.prepare('SELECT * FROM credential_bindings WHERE id = ?').get(binding.id);
  assert.equal(stored.item_ref_encrypted.includes(fixture.item.id), false);
  assert.equal(stored.field_config_encrypted.includes('login.password'), false);
});

test('protected browser fill returns only opaque state and submits through the provider', async () => {
  const providerCalls = [];
  const provider = {
    async getPageInfo() {
      return { url: 'https://accounts.example.test/login', title: 'Sign in' };
    },
    async fillCredential(input) {
      providerCalls.push({ operation: 'fill', input });
      return { success: true, protectedFillId: 'protected-1' };
    },
    async submitProtectedCredential(id) {
      providerCalls.push({ operation: 'submit', id });
      return { success: true, url: 'https://accounts.example.test/home', protected: false };
    },
  };
  const fixture = await setupBroker({
    runtimeManager: {
      async getBrowserProviderForUser() { return provider; },
    },
  });
  const binding = await fixture.broker.createBinding(fixture.user.userId, fixture.agent.id, {
    connectionId: fixture.connectionId,
    alias: 'Example login',
    usageType: 'browser',
    itemId: fixture.item.id,
    origins: ['https://accounts.example.test'],
  });
  const result = await fixture.broker.fillBrowser(fixture.user.userId, fixture.agent.id, {
    binding_id: binding.id,
    username_selector: '#email',
    password_selector: '#password',
  });

  assert.equal(result.protected_fill_id, 'protected-1');
  assert.equal(JSON.stringify(result).includes('do-not-leak'), false);
  assert.equal(providerCalls[0].input.password, 'do-not-leak-password');
  const submitted = await fixture.broker.submitProtected(
    fixture.user.userId,
    fixture.agent.id,
    result.protected_fill_id,
  );
  assert.equal(submitted.protected, false);
  assert.deepEqual(providerCalls[1], { operation: 'submit', id: 'protected-1' });
});

test('username-first sign-in stages never send the password to the browser backend', async () => {
  let fillInput = null;
  const provider = {
    async getPageInfo() {
      return { url: 'https://accounts.example.test/login', title: 'Sign in' };
    },
    async fillCredential(input) {
      fillInput = input;
      return { success: true, protectedFillId: 'username-stage-1' };
    },
  };
  const fixture = await setupBroker({
    runtimeManager: {
      async getBrowserProviderForUser() { return provider; },
    },
  });
  const binding = await fixture.broker.createBinding(fixture.user.userId, fixture.agent.id, {
    connectionId: fixture.connectionId,
    alias: 'Example login',
    usageType: 'browser',
    itemId: fixture.item.id,
    origins: ['https://accounts.example.test'],
  });

  await fixture.broker.fillBrowser(fixture.user.userId, fixture.agent.id, {
    binding_id: binding.id,
    stage: 'username',
    username_selector: '#email',
  });
  assert.equal(fillInput.username, 'person@example.test');
  assert.equal(fillInput.password, '');
  assert.equal(fillInput.passwordSelector, '');
});

test('credential HTTP requests inject auth, enforce path boundaries, and redact echoes', async () => {
  const fixture = await setupBroker({ mockNetworkValidation: true });
  const binding = await fixture.broker.createBinding(fixture.user.userId, fixture.agent.id, {
    connectionId: fixture.connectionId,
    alias: 'Example API',
    usageType: 'http',
    itemId: fixture.item.id,
    authType: 'bearer',
    secretField: 'api-field',
    origin: 'https://api.example.test',
    pathPrefix: '/v1',
    methods: ['GET'],
  });
  global.fetch = async (_url, options) => new Response(
    JSON.stringify({ authorization: options.headers.Authorization }),
    {
      status: 200,
      headers: { 'X-Echo': options.headers.Authorization },
    },
  );

  const response = await fixture.broker.httpRequest(fixture.user.userId, fixture.agent.id, {
    binding_id: binding.id,
    method: 'GET',
    url: 'https://api.example.test/v1/profile',
  });
  assert.equal(JSON.stringify(response).includes('do-not-leak-token'), false);
  assert.match(response.body, /\[redacted\]/);
  assert.equal(response.headers['x-echo'].includes('[redacted]'), true);
  await assert.rejects(
    fixture.broker.httpRequest(fixture.user.userId, fixture.agent.id, {
      binding_id: binding.id,
      method: 'GET',
      url: 'https://api.example.test/v10/profile',
    }),
    /target policy/,
  );
});
