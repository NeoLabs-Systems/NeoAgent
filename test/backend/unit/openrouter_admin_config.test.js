'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const { before, after, afterEach, test } = require('node:test');
const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');
const { createTestApp, loginAs } = require('../../helpers/app');
const { agent, request } = require('../../helpers/supertest');

const ENABLED_ENV = 'NEOAGENT_OPENROUTER_SIGN_IN_ENABLED';
const realFetch = global.fetch;
const previousEnabled = process.env[ENABLED_ENV];
let ctx;
let app;
let admin;
let member;
let manager;

before(async () => {
  ctx = createTestRuntime();
  delete process.env[ENABLED_ENV];
  const { AuthProviderManager } = require('../../../server/services/account/auth_provider_manager');
  manager = new AuthProviderManager();
  app = createTestApp({ locals: { authProviderManager: manager } }).app;
  app.locals.httpRuntimeConfig.publicUrl = 'https://agent.example.test';
  const owner = await createTestUser(ctx.db, { username: 'openrouter_admin' });
  const user = await createTestUser(ctx.db, { username: 'openrouter_member' });
  admin = agent(app);
  member = agent(app);
  await loginAs(admin, owner);
  await loginAs(member, user);
});

afterEach(() => {
  delete process.env[ENABLED_ENV];
  global.fetch = realFetch;
});

after(() => {
  if (previousEnabled === undefined) delete process.env[ENABLED_ENV];
  else process.env[ENABLED_ENV] = previousEnabled;
  global.fetch = realFetch;
  teardownTestRuntime(ctx);
});

async function setEnabled(enabled) {
  return admin.put('/api/admin/config/integrations')
    .send({ integrations: { openrouter: { enabled } } });
}

async function openrouterStatus() {
  const res = await request(app).get('/api/auth/providers').expect(200);
  return res.body.providers.find((p) => p.id === 'openrouter');
}

test('the integration schema exposes a boolean setting alongside Google, enabled by default', async () => {
  const res = await admin.get('/api/admin/config/integrations').expect(200);
  assert.ok(res.body.integrations.find((p) => p.key === 'google'));
  const openrouter = res.body.integrations.find((p) => p.key === 'openrouter');
  assert.equal(openrouter.configured, true);
  assert.deepEqual(openrouter.fields, [{ name: 'enabled', type: 'boolean', value: true }]);
  assert.equal((await openrouterStatus()).configured, true);
});

test('only admins can change the sign-in setting, which persists and takes effect live', async () => {
  await request(app).put('/api/admin/config/integrations')
    .send({ integrations: { openrouter: { enabled: false } } }).expect(401);
  await member.put('/api/admin/config/integrations')
    .send({ integrations: { openrouter: { enabled: false } } }).expect(403);
  assert.equal((await openrouterStatus()).configured, true);
  assert.equal((await setEnabled(false)).status, 200);
  assert.equal((await openrouterStatus()).configured, false);
  assert.match(fs.readFileSync(ctx.envFile, 'utf8'), /^NEOAGENT_OPENROUTER_SIGN_IN_ENABLED=false$/m);
  const res = await admin.get('/api/admin/config/integrations').expect(200);
  assert.equal(res.body.integrations.find((p) => p.key === 'openrouter').fields[0].value, false);
  assert.equal((await setEnabled(true)).status, 200);
  assert.equal((await openrouterStatus()).configured, true);
});

test('non-boolean input is rejected without mutating other submitted fields', async () => {
  const priorGoogleId = process.env.GOOGLE_OAUTH_CLIENT_ID;
  for (const enabled of ['false', 0, null, {}]) {
    await admin.put('/api/admin/config/integrations').send({ integrations: {
      google: { clientId: 'changed-client' }, openrouter: { enabled },
    } }).expect(400);
    assert.equal(process.env.GOOGLE_OAUTH_CLIENT_ID, priorGoogleId);
    assert.equal((await openrouterStatus()).configured, true);
  }
});

test('disabled sign-in rejects registration, login, and linking, while model connection remains available', async () => {
  await setEnabled(false);
  for (const mode of ['register', 'login', 'link']) {
    const res = await member.post('/api/auth/providers/openrouter/begin').send({ mode }).expect(400);
    assert.match(res.body.error, /disabled by the administrator/);
  }
  await member.get('/api/auth/me').expect(200);
  const providers = await member.get('/api/settings/byok').expect(200);
  assert.equal(providers.body.providers.find((p) => p.id === 'openrouter').signInAvailable, true);
  await member.post('/api/provider-sign-in/openrouter').expect(200);
});

test('disabling stops an already pending account callback before minting or storing a key', async () => {
  const begun = await member.post('/api/auth/providers/openrouter/begin').send({ mode: 'link' }).expect(200);
  let exchanges = 0;
  global.fetch = async () => { exchanges += 1; throw new Error('Unexpected exchange'); };
  await setEnabled(false);
  await member.get('/api/integrations/oauth/callback')
    .query({ state: begun.body.state, code: 'approved' }).expect(500);
  const failed = await member.get('/api/auth/providers/complete').query({ state: begun.body.state }).expect(400);
  assert.match(failed.body.error, /disabled by the administrator/);
  assert.equal(exchanges, 0);
  assert.equal(ctx.db.prepare("SELECT COUNT(*) AS n FROM user_auth_providers WHERE provider_key = 'openrouter'").get().n, 0);
});

test('disabling during the exchange prevents storing credentials or linking the account', async () => {
  const begun = await member.post('/api/auth/providers/openrouter/begin').send({ mode: 'link' }).expect(200);
  global.fetch = async () => {
    process.env[ENABLED_ENV] = 'false';
    return new Response(JSON.stringify({ key: 'sk-or-disabled-during-exchange', user_id: 'late-identity' }));
  };
  await member.get('/api/integrations/oauth/callback')
    .query({ state: begun.body.state, code: 'approved' }).expect(500);
  assert.equal(ctx.db.prepare("SELECT COUNT(*) AS n FROM user_auth_providers WHERE provider_key = 'openrouter'").get().n, 0);
});

test('disabling after the callback still prevents collecting a new login session', async () => {
  // Seed an identity link without changing the member's existing password login.
  const userId = (await member.get('/api/auth/me').expect(200)).body.user.id;
  ctx.db.prepare('INSERT INTO user_auth_providers (user_id, provider_key, provider_user_id) VALUES (?, ?, ?)')
    .run(userId, 'openrouter', 'existing-identity');
  const client = agent(app);
  const begun = await client.post('/api/auth/providers/openrouter/begin').send({ mode: 'login' }).expect(200);
  global.fetch = async () => new Response(JSON.stringify({ key: 'sk-or-completed-before-disable', user_id: 'existing-identity' }));
  await client.get('/api/integrations/oauth/callback').query({ state: begun.body.state, code: 'approved' }).expect(200);
  await setEnabled(false);
  const complete = await client.get('/api/auth/providers/complete').query({ state: begun.body.state }).expect(400);
  assert.match(complete.body.error, /disabled by the administrator/);
  await client.get('/api/auth/me').expect(401);
  const { getProviderSecrets } = require('../../../server/services/ai/settings');
  assert.equal(getProviderSecrets(userId).openrouter, 'sk-or-completed-before-disable');
});
