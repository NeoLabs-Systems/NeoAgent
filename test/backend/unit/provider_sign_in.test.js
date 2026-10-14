'use strict';

const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const { after, afterEach, before, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');
const { createTestApp, loginAs } = require('../../helpers/app');
const { agent } = require('../../helpers/supertest');

const KEY_EXCHANGE_URL = 'https://openrouter.ai/api/v1/auth/keys';

let ctx;
let app;
let owner;
let ownerClient;
let other;
let otherClient;
const realFetch = global.fetch;
let exchanges;

function challengeFor(verifier) {
  return crypto.createHash('sha256').update(verifier).digest('base64url');
}

// Stands in for OpenRouter's key exchange: accepts only `goodCode` together
// with the verifier that matches the challenge sent in the authorization URL.
function stubKeyExchange({ goodCode, challenge, key }) {
  global.fetch = async (url, options) => {
    assert.equal(url, KEY_EXCHANGE_URL);
    const body = JSON.parse(options.body);
    exchanges.push(body);
    const valid = body.code === goodCode
      && body.code_challenge_method === 'S256'
      && challengeFor(body.code_verifier) === challenge;
    return new Response(
      JSON.stringify(valid ? { key } : { error: { message: 'Invalid code or code_verifier' } }),
      { status: valid ? 200 : 403, headers: { 'Content-Type': 'application/json' } },
    );
  };
}

async function byokEntry(client, providerId) {
  const res = await client.get('/api/settings/byok').expect(200);
  return res.body.providers.find((provider) => provider.id === providerId);
}

before(async () => {
  ctx = createTestRuntime();
  process.env.NEOAGENT_SETUP_PROFILE = 'quick';
  process.env.NEOAGENT_SETUP_COMPLETED_SECTIONS = 'core';
  app = createTestApp().app;
  owner = await createTestUser(ctx.db, { username: 'sign_in_owner' });
  other = await createTestUser(ctx.db, { username: 'sign_in_other' });
  ownerClient = agent(app);
  otherClient = agent(app);
  await loginAs(ownerClient, owner);
  await loginAs(otherClient, other);
});

afterEach(() => {
  global.fetch = realFetch;
  exchanges = [];
  app.locals.httpRuntimeConfig.publicUrl = null;
});

after(() => {
  global.fetch = realFetch;
  teardownTestRuntime(ctx);
});

test('lists OpenRouter as a provider with sign-in', async () => {
  const openrouter = await byokEntry(ownerClient, 'openrouter');
  assert.equal(openrouter.signInAvailable, true);
  assert.equal(openrouter.configured, false);
  const openai = await byokEntry(ownerClient, 'openai');
  assert.equal(openai.signInAvailable, false);
});

test('rejects providers without a sign-in method', async () => {
  await ownerClient.post('/api/provider-sign-in/openai').expect(400);
});

test('https servers get a redirect flow that finishes in the starting browser', async () => {
  app.locals.httpRuntimeConfig.publicUrl = 'https://agent.example.test';
  const begin = await ownerClient.post('/api/provider-sign-in/openrouter').expect(200);
  assert.equal(begin.body.mode, 'redirect');
  assert.match(begin.body.state, /^model_[a-f0-9]{48}$/);

  const url = new URL(begin.body.url);
  assert.equal(url.origin + url.pathname, 'https://openrouter.ai/auth');
  assert.equal(url.searchParams.get('callback_url'), 'https://agent.example.test/api/integrations/oauth/callback');
  assert.equal(url.searchParams.get('state'), begin.body.state);
  assert.equal(url.searchParams.get('code_challenge_method'), 'S256');

  stubKeyExchange({
    goodCode: 'code-123',
    challenge: url.searchParams.get('code_challenge'),
    key: 'sk-or-v1-signed-in',
  });
  const pending = await ownerClient.get(`/api/provider-sign-in/${begin.body.state}`).expect(200);
  assert.equal(pending.body.status, 'pending');

  const callback = await ownerClient
    .get('/api/integrations/oauth/callback')
    .query({ state: begin.body.state, code: 'code-123' })
    .expect(200);
  assert.match(callback.text, /model_sign_in_success/);
  assert.equal(callback.text.includes('sk-or-v1-signed-in'), false);

  const done = await ownerClient.get(`/api/provider-sign-in/${begin.body.state}`).expect(200);
  assert.equal(done.body.status, 'completed');
  await ownerClient.get(`/api/provider-sign-in/${begin.body.state}`).expect(404);

  assert.equal((await byokEntry(ownerClient, 'openrouter')).configured, true);
  assert.equal((await byokEntry(otherClient, 'openrouter')).configured, false);
  await ownerClient.delete('/api/settings/byok/openrouter').expect(200);
});

test('a callback in a browser that did not start the flow must be confirmed', async () => {
  app.locals.httpRuntimeConfig.publicUrl = 'https://agent.example.test';
  const begin = await ownerClient.post('/api/provider-sign-in/openrouter').expect(200);
  const url = new URL(begin.body.url);
  stubKeyExchange({
    goodCode: 'code-456',
    challenge: url.searchParams.get('code_challenge'),
    key: 'sk-or-v1-confirmed',
  });

  const held = await agent(app)
    .get('/api/integrations/oauth/callback')
    .query({ state: begin.body.state, code: 'code-456' })
    .expect(200);
  assert.match(held.text, /connect your OpenRouter account to the NeoAgent account <strong>sign_in_owner<\/strong>/);
  assert.equal(exchanges.length, 0);
  assert.equal((await byokEntry(ownerClient, 'openrouter')).configured, false);

  const token = held.text.match(/callback\/confirm\?token=([^"&]+)/)[1];
  await agent(app).get('/api/integrations/oauth/callback/confirm').query({ token }).expect(200);
  assert.equal((await byokEntry(ownerClient, 'openrouter')).configured, true);
  await ownerClient.delete('/api/settings/byok/openrouter').expect(200);
});

test('plain-http LAN servers get the paste-a-code flow', async () => {
  app.locals.httpRuntimeConfig.publicUrl = 'http://192.168.1.50:3333';
  const begin = await ownerClient.post('/api/provider-sign-in/openrouter').expect(200);
  assert.equal(begin.body.mode, 'code');
  const url = new URL(begin.body.url);
  assert.equal(url.searchParams.has('callback_url'), false);
  assert.equal(url.searchParams.has('state'), false);

  stubKeyExchange({
    goodCode: 'pasted-code',
    challenge: url.searchParams.get('code_challenge'),
    key: 'sk-or-v1-pasted',
  });

  await otherClient
    .post(`/api/provider-sign-in/${begin.body.state}/code`)
    .send({ code: 'pasted-code' })
    .expect(400);
  await otherClient.get(`/api/provider-sign-in/${begin.body.state}`).expect(404);

  const wrong = await ownerClient
    .post(`/api/provider-sign-in/${begin.body.state}/code`)
    .send({ code: 'typo' })
    .expect(400);
  assert.match(wrong.body.error, /Invalid code/);

  const done = await ownerClient
    .post(`/api/provider-sign-in/${begin.body.state}/code`)
    .send({ code: 'pasted-code' })
    .expect(200);
  assert.deepEqual(done.body, { status: 'completed', providerId: 'openrouter' });
  assert.equal((await byokEntry(ownerClient, 'openrouter')).configured, true);
  assert.equal((await byokEntry(otherClient, 'openrouter')).configured, false);
});

test('a second completion of the same sign-in cannot race the first', async () => {
  const providerSignIn = require('../../../server/services/ai/provider_sign_in');
  const flow = providerSignIn.begin({
    providerId: 'openrouter',
    userId: owner.userId,
    agentId: null,
    baseUrl: 'https://agent.example.test',
  });
  const url = new URL(flow.url);
  stubKeyExchange({
    goodCode: 'once-only',
    challenge: url.searchParams.get('code_challenge'),
    key: 'sk-or-v1-raced',
  });

  const results = await Promise.allSettled([
    providerSignIn.complete(flow.state, 'once-only'),
    providerSignIn.complete(flow.state, 'once-only'),
  ]);

  assert.deepEqual(results.map((result) => result.status).sort(), ['fulfilled', 'rejected']);
  assert.equal(exchanges.length, 1);
  assert.equal(providerSignIn.status(flow.state, owner.userId).status, 'completed');
  await ownerClient.delete('/api/settings/byok/openrouter').expect(200);
});

test('a denied sign-in without state still gets a readable page', async () => {
  const res = await agent(app)
    .get('/api/integrations/oauth/callback')
    .query({ error: 'access_denied' })
    .expect(400);
  assert.match(res.text, /Sign-in was canceled/);
});
