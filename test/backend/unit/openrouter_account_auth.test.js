'use strict';

const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const { before, after, afterEach, test } = require('node:test');
const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');
const { createTestApp, loginAs } = require('../../helpers/app');
const { agent, request } = require('../../helpers/supertest');

let ctx;
let app;
let manager;
let accountId;
let exchanges;
let attempts = 0;
const realFetch = global.fetch;
const previousAllowSignup = process.env.NEOAGENT_ALLOW_SIGNUP;

before(() => {
  ctx = createTestRuntime();
  process.env.NEOAGENT_ALLOW_SIGNUP = 'true';
  const { AuthProviderManager } = require('../../../server/services/account/auth_provider_manager');
  manager = new AuthProviderManager();
  app = createTestApp({ locals: { authProviderManager: manager } }).app;
  app.locals.httpRuntimeConfig.publicUrl = 'https://agent.example.test';
});

afterEach(() => {
  global.fetch = realFetch;
  process.env.NEOAGENT_ALLOW_SIGNUP = 'true';
  app.locals.httpRuntimeConfig.publicUrl = 'https://agent.example.test';
});

after(() => {
  global.fetch = realFetch;
  if (previousAllowSignup === undefined) delete process.env.NEOAGENT_ALLOW_SIGNUP;
  else process.env.NEOAGENT_ALLOW_SIGNUP = previousAllowSignup;
  teardownTestRuntime(ctx);
});

async function begin(client, mode, signupKey) {
  const res = await client.post('/api/auth/providers/openrouter/begin')
    .set('X-Forwarded-For', `10.88.0.${++attempts}`).send({ mode, signupKey }).expect(200);
  const url = new URL(res.body.url);
  assert.equal(url.origin + url.pathname, 'https://openrouter.ai/auth');
  assert.equal(url.searchParams.get('state'), res.body.state);
  assert.equal(url.searchParams.get('callback_url'), 'https://agent.example.test/api/integrations/oauth/callback');
  assert.equal(url.searchParams.get('code_challenge_method'), 'S256');
  const stored = ctx.db.prepare('SELECT code_verifier FROM auth_oauth_states WHERE state = ?').get(res.body.state);
  const challenge = url.searchParams.get('code_challenge');
  assert.notEqual(stored.code_verifier, challenge);
  return { state: res.body.state, challenge };
}

function stubExchange(flow, identity = 'openrouter-account', key = 'sk-or-account-test') {
  exchanges = [];
  global.fetch = async (url, options) => {
    assert.equal(url, 'https://openrouter.ai/api/v1/auth/keys');
    const body = JSON.parse(options.body);
    exchanges.push(body);
    assert.equal(body.code_challenge_method, 'S256');
    assert.equal(crypto.createHash('sha256').update(body.code_verifier).digest('base64url'), flow.challenge);
    const valid = body.code === 'approved';
    return new Response(JSON.stringify(valid
      ? { key, user_id: identity }
      : { error: { message: 'Invalid code or code_verifier' } }), { status: valid ? 200 : 403 });
  };
}

async function callback(client, flow, status = 200, code = 'approved') {
  const res = await client.get('/api/integrations/oauth/callback')
    .query({ state: flow.state, code });
  const row = ctx.db.prepare('SELECT status FROM auth_oauth_states WHERE state = ?').get(flow.state);
  if (res.status === 200 && row?.status === 'requires_username') {
    const registration = await client.post('/api/auth/providers/register').send({
      state: flow.state, username: `account_${crypto.randomBytes(6).toString('hex')}`,
    });
    if (status === 200) assert.equal(registration.status, 200);
    else assert.ok([400, 403].includes(registration.status));
  } else {
    assert.equal(res.status, status);
  }
  assert.equal(res.text.includes('sk-or-account-test'), false);
  return res;
}

async function collect(client, flow, status = 200) {
  const res = await client.get('/api/auth/providers/complete').query({ state: flow.state }).expect(status);
  assert.equal(res.text.includes('sk-or-account-test'), false);
  return res.body;
}

test('OpenRouter is available without an OAuth app on HTTPS or localhost, but not HTTP LAN', async () => {
  for (const baseUrl of ['https://agent.example.test', 'http://localhost:3333', 'http://127.0.0.1:3333']) {
    app.locals.httpRuntimeConfig.publicUrl = baseUrl;
    const res = await request(app).get('/api/auth/status').expect(200);
    assert.equal(res.body.providers.find((p) => p.id === 'openrouter').configured, true);
  }
  app.locals.httpRuntimeConfig.publicUrl = 'http://192.168.1.50:3333';
  const res = await request(app).get('/api/auth/providers').expect(200);
  assert.equal(res.body.providers.find((p) => p.id === 'openrouter').configured, false);
  await request(app).post('/api/auth/providers/openrouter/begin').send({ mode: 'register' }).expect(400);
});

test('registration creates an email-free account, encrypted model key, and a normal session', async () => {
  process.env.NEOAGENT_ALLOW_SIGNUP = 'false';
  const client = agent(app);
  const flow = await begin(client, 'register');
  stubExchange(flow);
  await callback(client, flow);
  await request(app).get('/api/auth/providers/complete').query({ state: flow.state }).expect(404);
  const done = await collect(client, flow);
  accountId = done.user.id;
  assert.equal(done.success, true);
  assert.equal(done.user.email, null);
  assert.equal(done.user.emailVerifiedAt, null);
  assert.equal(done.user.hasPassword, false);
  await client.get('/api/auth/me').expect(200);
  const { getProviderSecrets } = require('../../../server/services/ai/settings');
  assert.equal(getProviderSecrets(accountId).openrouter, 'sk-or-account-test');
  const raw = ctx.db.prepare("SELECT value FROM agent_settings WHERE user_id = ? AND key = 'ai_provider_api_keys'").get(accountId);
  assert.equal(raw.value.includes('sk-or-account-test'), false);
  const link = ctx.db.prepare('SELECT * FROM user_auth_providers WHERE user_id = ?').get(accountId);
  assert.equal(link.provider_user_id, 'openrouter-account');
  assert.equal(link.email, null);
  assert.equal(link.metadata_json.includes('sk-or-account-test'), false);
  await collect(client, flow, 404);
});

test('later logins use the provider identity and update the model key without another account', async () => {
  const count = ctx.db.prepare('SELECT COUNT(*) AS n FROM users').get().n;
  const client = agent(app);
  const flow = await begin(client, 'login');
  stubExchange(flow, 'openrouter-account', 'sk-or-rotated');
  await callback(client, flow);
  const done = await collect(client, flow);
  assert.equal(done.user.id, accountId);
  assert.equal(ctx.db.prepare('SELECT COUNT(*) AS n FROM users').get().n, count);
  const { getProviderSecrets } = require('../../../server/services/ai/settings');
  assert.equal(getProviderSecrets(accountId).openrouter, 'sk-or-rotated');
});

test('registering an already linked OpenRouter account reuses the existing NeoAgent account', async () => {
  const client = agent(app);
  const flow = await begin(client, 'register');
  stubExchange(flow);
  await callback(client, flow);
  assert.equal((await collect(client, flow)).user.id, accountId);
});

test('a missing provider user ID or invalid code cannot create an account', async () => {
  const count = ctx.db.prepare('SELECT COUNT(*) AS n FROM users').get().n;
  for (const [identity, code] of [[null, 'approved'], ['', 'approved'], ['unknown', 'wrong']]) {
    const client = agent(app);
    const flow = await begin(client, 'register');
    stubExchange(flow, identity);
    await callback(client, flow, 500, code);
    await collect(client, flow, 400);
  }
  assert.equal(ctx.db.prepare('SELECT COUNT(*) AS n FROM users').get().n, count);
});

test('login with an unlinked OpenRouter account fails rather than creating an account', async () => {
  const client = agent(app);
  const flow = await begin(client, 'login');
  stubExchange(flow, 'unlinked-account');
  await callback(client, flow, 500);
  assert.match((await collect(client, flow, 400)).error, /Register first/);
});

test('native-browser callbacks require confirmation, and only the starter gets the session', async () => {
  const client = agent(app);
  const flow = await begin(client, 'login');
  stubExchange(flow);
  const browser = agent(app);
  const held = await callback(browser, flow);
  assert.match(held.text, /Do you want to finish signing in to NeoAgent with OpenRouter/);
  assert.equal(exchanges.length, 0);
  assert.equal((await collect(client, flow)).status, 'pending');
  const token = held.text.match(/callback\/confirm\?token=([^"&]+)/)[1];
  await browser.get('/api/integrations/oauth/callback/confirm').query({ token }).expect(200);
  await browser.get('/api/auth/providers/complete').query({ state: flow.state }).expect(404);
  assert.equal((await collect(client, flow)).user.id, accountId);
  await browser.get('/api/auth/me').expect(401);
});

test('linking works for an existing account and cannot steal another account identity', async () => {
  const user = await createTestUser(ctx.db, { username: 'link_openrouter' });
  const client = agent(app);
  await loginAs(client, user);
  const flow = await begin(client, 'link');
  stubExchange(flow, 'linked-other-identity');
  await callback(client, flow);
  assert.equal((await collect(client, flow)).result.userId, user.userId);
  const { getProviderSecrets } = require('../../../server/services/ai/settings');
  assert.equal(getProviderSecrets(user.userId).openrouter, 'sk-or-account-test');
  const conflict = await begin(client, 'link');
  stubExchange(conflict, 'openrouter-account', 'sk-or-stolen');
  await callback(client, conflict, 500);
  assert.match((await collect(client, conflict, 400)).error, /already linked/);
  assert.notEqual(getProviderSecrets(accountId).openrouter, 'sk-or-stolen');
  assert.equal(getProviderSecrets(user.userId).openrouter, 'sk-or-account-test');
});

test('registration respects one-time signup keys and rolls back a revoked key', async () => {
  process.env.NEOAGENT_ALLOW_SIGNUP = 'false';
  await request(app).post('/api/auth/providers/openrouter/begin').send({ mode: 'register' }).expect(403);
  const { createSignupKeys, revokeSignupKey } = require('../../../server/services/access/signup_keys');
  const [key] = createSignupKeys(accountId, { count: 1 }).keys;
  const client = agent(app);
  const flow = await begin(client, 'register', key.code);
  stubExchange(flow, 'signup-key-identity');
  await callback(client, flow);
  const done = await collect(client, flow);
  assert.equal(ctx.db.prepare('SELECT used_by_user_id FROM signup_keys WHERE id = ?').get(key.id).used_by_user_id, done.user.id);
  await request(app).post('/api/auth/providers/openrouter/begin').send({ mode: 'register', signupKey: key.code }).expect(403);

  const [revoked] = createSignupKeys(accountId, { count: 1 }).keys;
  const revokeFlow = await begin(client, 'register', revoked.code);
  revokeSignupKey(accountId, revoked.id);
  stubExchange(revokeFlow, 'revoked-key-identity');
  const count = ctx.db.prepare('SELECT COUNT(*) AS n FROM users').get().n;
  await callback(client, revokeFlow, 500);
  await collect(client, revokeFlow, 400);
  assert.equal(ctx.db.prepare('SELECT COUNT(*) AS n FROM users').get().n, count);
});

test('the same callback can only claim an account exchange once', async () => {
  const client = agent(app);
  const flow = await begin(client, 'login');
  stubExchange(flow);
  const first = manager.finishAuthorization(flow.state, 'approved');
  assert.equal(manager.consumeAuthorization(flow.state).status, 'pending');
  manager.failAuthorization(flow.state, 'duplicate callback');
  const results = await Promise.allSettled([
    first,
    manager.finishAuthorization(flow.state, 'approved'),
  ]);
  assert.deepEqual(results.map((r) => r.status).sort(), ['fulfilled', 'rejected']);
  assert.equal(exchanges.length, 1);
});

test('two simultaneous registrations of the same identity create only one account', async () => {
  const first = await begin(agent(app), 'register');
  const second = await begin(agent(app), 'register');
  const challenges = new Set([first.challenge, second.challenge]);
  global.fetch = async (_url, options) => {
    const body = JSON.parse(options.body);
    assert.ok(challenges.has(crypto.createHash('sha256').update(body.code_verifier).digest('base64url')));
    return new Response(JSON.stringify({ key: 'sk-or-concurrent', user_id: 'concurrent-account' }));
  };
  const count = ctx.db.prepare('SELECT COUNT(*) AS n FROM users').get().n;
  const results = await Promise.all([
    manager.finishAuthorization(first.state, 'approved'),
    manager.finishAuthorization(second.state, 'approved'),
  ]);
  assert.ok(results.every((r) => r.requiresUsername));
  await Promise.all([
    manager.completeRegistration(first.state, 'concurrent_first'),
    manager.completeRegistration(second.state, 'concurrent_second'),
  ]);
  const accounts = [manager.consumeAuthorization(first.state), manager.consumeAuthorization(second.state)];
  assert.equal(accounts[0].result.userId, accounts[1].result.userId);
  assert.deepEqual(accounts.map((r) => r.result.created).sort(), [false, true]);
  assert.equal(ctx.db.prepare('SELECT COUNT(*) AS n FROM users').get().n, count + 1);
});

test('failure saving credentials rolls back account, provider link, agent, and signup-key use', async () => {
  process.env.NEOAGENT_ALLOW_SIGNUP = 'false';
  const { createSignupKeys } = require('../../../server/services/access/signup_keys');
  const [key] = createSignupKeys(accountId, { count: 1 }).keys;
  const client = agent(app);
  const flow = await begin(client, 'register', key.code);
  stubExchange(flow, 'save-failure-identity');
  const provider = manager.getProvider('openrouter');
  const saveCredentials = provider.saveCredentials;
  const countUsers = ctx.db.prepare('SELECT COUNT(*) AS n FROM users').get().n;
  const countAgents = ctx.db.prepare('SELECT COUNT(*) AS n FROM agents').get().n;
  provider.saveCredentials = (userId, identity) => {
    saveCredentials(userId, identity);
    throw new Error('Credential storage failed');
  };
  try {
    await callback(client, flow, 500);
    await collect(client, flow, 400);
    assert.equal(ctx.db.prepare('SELECT COUNT(*) AS n FROM users').get().n, countUsers);
    assert.equal(ctx.db.prepare('SELECT COUNT(*) AS n FROM agents').get().n, countAgents);
    assert.equal(ctx.db.prepare('SELECT * FROM user_auth_providers WHERE provider_user_id = ?').get('save-failure-identity'), undefined);
    assert.equal(ctx.db.prepare('SELECT used_at FROM signup_keys WHERE id = ?').get(key.id).used_at, null);
  } finally {
    provider.saveCredentials = saveCredentials;
  }
});

test('expired states and denied authorization do not exchange or create credentials', async () => {
  const client = agent(app);
  const flow = await begin(client, 'register');
  stubExchange(flow, 'expired-identity');
  ctx.db.prepare("UPDATE auth_oauth_states SET expires_at = datetime('now', '-1 minute') WHERE state = ?").run(flow.state);
  await callback(client, flow, 500);
  assert.equal(exchanges.length, 0);
  const denied = await begin(client, 'register');
  await client.get('/api/integrations/oauth/callback').query({ state: denied.state, error: 'access_denied' }).expect(400);
  assert.match((await collect(client, denied, 400)).error, /access_denied/);
  assert.equal(exchanges.length, 0);
});

test('an OpenRouter account still needs its second factor when email confirmation is enabled', async () => {
  const bcrypt = require('bcrypt');
  const { encryptValue } = require('../../../server/services/integrations/secrets');
  ctx.db.prepare('INSERT INTO user_two_factor (user_id, secret, enabled) VALUES (?, ?, 1)')
    .run(accountId, encryptValue('JBSWY3DPEHPK3PXP'));
  ctx.db.prepare('INSERT INTO user_recovery_codes (user_id, code_hash) VALUES (?, ?)')
    .run(accountId, await bcrypt.hash('ABCDEF2345', 4));
  const envKeys = ['NEOAGENT_EMAIL_SMTP_HOST', 'NEOAGENT_EMAIL_FROM', 'NEOAGENT_EMAIL_REQUIRE_SIGNUP_CONFIRMATION'];
  const previous = envKeys.map((key) => process.env[key]);
  Object.assign(process.env, {
    NEOAGENT_EMAIL_SMTP_HOST: 'smtp.example.test',
    NEOAGENT_EMAIL_FROM: 'neo@example.test',
    NEOAGENT_EMAIL_REQUIRE_SIGNUP_CONFIRMATION: 'true',
  });
  try {
    const client = agent(app);
    const flow = await begin(client, 'login');
    stubExchange(flow);
    await callback(client, flow);
    const done = await collect(client, flow);
    assert.equal(done.requiresTwoFactor, true);
    await client.get('/api/auth/me').expect(401);
    const verified = await client.post('/api/auth/login/2fa').send({ code: 'ABCDE-F2345' }).expect(200);
    assert.equal(verified.body.user.id, accountId);
    await client.get('/api/auth/me').expect(200);
  } finally {
    envKeys.forEach((key, index) => {
      if (previous[index] === undefined) delete process.env[key];
      else process.env[key] = previous[index];
    });
    ctx.db.prepare('DELETE FROM user_two_factor WHERE user_id = ?').run(accountId);
  }
});

test('Google registration keeps its email identity and existing session flow', async () => {
  const google = manager.getProvider('google');
  const original = { getEnvStatus: google.getEnvStatus, beginOAuth: google.beginOAuth, finishOAuth: google.finishOAuth };
  Object.assign(google, {
    getEnvStatus: () => ({ configured: true }),
    beginOAuth: ({ state }) => ({ url: `https://accounts.google.com/o/oauth2/auth?state=${state}` }),
    finishOAuth: () => ({ providerUserId: 'google-account', email: 'google@example.test', emailVerified: true }),
  });
  try {
    const client = agent(app);
    const begun = await client.post('/api/auth/providers/google/begin').send({ mode: 'register' }).expect(200);
    await callback(client, begun.body);
    const done = await collect(client, begun.body);
    assert.equal(done.user.email, 'google@example.test');
    assert.ok(done.user.emailVerifiedAt);
    await client.get('/api/auth/me').expect(200);
  } finally {
    Object.assign(google, original);
  }
});

test('OpenRouter-only accounts must keep a sign-in method and can set a password for fallback', async () => {
  const link = manager.listUserProviders(accountId).find((p) => p.provider === 'openrouter');
  assert.equal(link.canUnlink, false);
  assert.throws(() => manager.unlinkProvider(accountId, link.id), /Create a password/);
  const client = agent(app);
  const flow = await begin(client, 'login');
  stubExchange(flow);
  await callback(client, flow);
  const user = (await collect(client, flow)).user;
  await client.put('/api/account/password').send({ newPassword: 'Correct-Horse-Battery-9' }).expect(200);
  assert.equal(manager.listUserProviders(accountId)[0].canUnlink, true);
  await client.post('/api/auth/logout').expect(200);
  const loggedIn = await client.post('/api/auth/login')
    .send({ username: user.username, password: 'Correct-Horse-Battery-9' }).expect(200);
  assert.equal(loggedIn.body.user.id, accountId);
});

test('new identities choose an available username before any account or credentials are created', async () => {
  const client = agent(app);
  const flow = await begin(client, 'register');
  stubExchange(flow, 'username-selection-identity');
  const count = ctx.db.prepare('SELECT COUNT(*) AS n FROM users').get().n;
  await client.get('/api/integrations/oauth/callback').query({ state: flow.state, code: 'approved' }).expect(200);
  const pending = await collect(client, flow);
  assert.equal(pending.requiresUsername, true);
  assert.equal(ctx.db.prepare('SELECT COUNT(*) AS n FROM users').get().n, count);
  const stored = ctx.db.prepare('SELECT result_json FROM auth_oauth_states WHERE state = ?').get(flow.state);
  assert.equal(stored.result_json.includes('sk-or-account-test'), false);
  assert.equal(stored.result_json.includes('username-selection-identity'), false);
  await agent(app).post('/api/auth/providers/register').send({ state: flow.state, username: 'chosen_name' }).expect(404);
  const submit = (username) => client.post('/api/auth/providers/register').send({ state: flow.state, username });
  assert.equal((await submit('ab').expect(400)).body.code, 'USERNAME_TOO_SHORT');
  const taken = ctx.db.prepare('SELECT username FROM users WHERE id = ?').get(accountId).username.toUpperCase();
  assert.equal((await submit(taken).expect(409)).body.code, 'USERNAME_TAKEN');
  assert.equal((await collect(client, flow)).requiresUsername, true);
  await submit('chosen_name').expect(200);
  const done = await collect(client, flow);
  assert.equal(done.user.username, 'chosen_name');
  assert.equal(exchanges.length, 1);
  await submit('another_name').expect(404);
  assert.equal(ctx.db.prepare('SELECT COUNT(*) AS n FROM users').get().n, count + 1);
});

test('username selection applies to another provider without provider-specific registration logic', async () => {
  const originalRegistry = manager.registry;
  const provider = {
    key: 'new_provider', label: 'New Provider', getEnvStatus: () => ({ configured: true }),
    beginOAuth: () => ({ url: 'https://identity.example.test/authorize' }),
    finishOAuth: () => ({ providerUserId: 'new-provider-identity', email: null }),
  };
  manager.registry = { get: (key) => key === provider.key ? provider : originalRegistry.get(key), list: () => [...originalRegistry.list(), provider] };
  try {
    const begun = await manager.beginAuthorization({ providerKey: provider.key, mode: 'register' });
    assert.equal((await manager.finishAuthorization(begun.state, 'approved')).requiresUsername, true);
    assert.equal(manager.consumeAuthorization(begun.state).requiresUsername, true);
    await manager.completeRegistration(begun.state, 'new_provider_user');
    const done = manager.consumeAuthorization(begun.state);
    assert.equal(ctx.db.prepare('SELECT username FROM users WHERE id = ?').get(done.result.userId).username, 'new_provider_user');
  } finally {
    manager.registry = originalRegistry;
  }
});
