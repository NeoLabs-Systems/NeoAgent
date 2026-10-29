'use strict';

const assert = require('node:assert/strict');
const http = require('node:http');
const { after, before, test } = require('node:test');
const express = require('express');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

const ctx = createTestRuntime();
let fake;
let address;
let approved = false;

// A NeoRouter as NeoAgent sees it: device sign-in and the /v1 model lists.
function fakeNeoRouter() {
  const app = express();
  app.use(express.urlencoded({ extended: false }), express.json());
  app.post('/oauth/device/code', (req, res) => res.json({
    device_code: 'dev-code', user_code: 'ABCD-EFGH', interval: 1, expires_in: 600,
    verification_uri_complete: `${address}/app/?connect=req1`,
  }));
  app.post('/oauth/token', (req, res) => {
    if (req.body.device_code !== 'dev-code' || req.body.client_id !== 'neoagent') return res.status(400).json({ error: 'invalid_grant' });
    if (!approved) return res.status(400).json({ error: 'authorization_pending' });
    return res.json({ access_token: 'nrt_fake_key', token_type: 'Bearer' });
  });
  const auth = (req, res, next) => (req.get('authorization') === 'Bearer nrt_fake_key' ? next() : res.status(401).json({ error: { message: 'bad key' } }));
  const lists = {
    chat: [{ id: 'auto', object: 'model' }, { id: 'groq/llama-4', pricing: { prompt: '0', completion: '0' }, neorouter: { free: true, tools: true } }],
    moderation: [{ id: 'openrouter/liquid-d1', neorouter: { decision: true } }, { id: 'groq/llama-guard-4', neorouter: { decision: false } }],
    live: [{ id: 'google/gemini-3.8-flash-live', neorouter: { protocols: ['gemini_live'] } }],
    embedding: [{ id: 'nvidia/embed' }],
    transcription: [], image: [], search: [{ id: 'brave-search/web' }],
  };
  app.get('/v1/models', auth, (req, res) => res.json({
    object: 'list',
    data: lists[req.query.type || 'chat'] || [],
    // Paid image models the free-only key may not use.
    neorouter: { not_allowed_for_key: req.query.type === 'image' ? { free: 0, plan: 0, paid: 30 } : { free: 0, plan: 0, paid: 0 } },
  }));
  app.post('/v1/embeddings', auth, (req, res) => res.json({ model: 'nvidia/embed', data: [{ index: 0, embedding: [0.1, 0.2, 0.3] }] }));
  app.post('/v1/search', auth, (req, res) => res.json({ results: [{ title: 'NeoRouter', url: 'https://example.com', content: `about ${req.body.query}` }] }));
  app.post('/v1/systemone', auth, (req, res) => res.json({ model: req.body.model, answers: { ok: true } }));
  return new Promise((resolve) => {
    const server = http.createServer(app).listen(0, '127.0.0.1', () => resolve(server));
  });
}

async function waitFor(check) {
  for (let i = 0; i < 50; i += 1) {
    const value = check();
    if (value) return value;
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error('timed out');
}

before(async () => {
  fake = await fakeNeoRouter();
  address = `http://127.0.0.1:${fake.address().port}`;
});

after(async () => {
  await new Promise((resolve) => fake.close(resolve));
  teardownTestRuntime(ctx);
});

test('connecting for the server stores the key and sets up live voice', async () => {
  const signIn = require('../../../server/services/ai/neorouter/sign_in');
  const { serverConnection, forRole } = require('../../../server/services/ai/neorouter/connection');
  const admin = await createTestUser(ctx.db, { username: 'nr_admin' });
  const started = await signIn.begin({ scope: 'server', userId: admin.userId, address });
  assert.match(started.url, /connect=req1/);
  assert.equal(started.userCode, 'ABCD-EFGH');
  assert.equal(signIn.status(started.id, admin.userId + 1), null, 'only the person who started it may read it');
  approved = true;
  const result = await waitFor(() => {
    const state = signIn.status(started.id, admin.userId);
    return state?.status !== 'pending' ? state : null;
  });
  assert.equal(result.status, 'completed', JSON.stringify(result));
  assert.equal(process.env.NEOROUTER_BASE_URL, `${address}/v1`);
  assert.equal(process.env.NEOROUTER_API_KEY, 'nrt_fake_key');
  assert.equal(process.env.VOICE_LIVE_PROVIDER, 'neorouter_google', 'the router only has Gemini Live models');
  assert.equal(serverConnection().roles.size, 7);

  const other = await createTestUser(ctx.db, { username: 'nr_user' });
  assert.equal(forRole(other.userId, null, 'search').scope, 'server', 'everyone uses the server connection');
});

test('every kind of work goes through the connected router', async () => {
  const user = await createTestUser(ctx.db, { username: 'nr_work' });
  const { getEmbeddingWithMetadata } = require('../../../server/services/memory/embeddings');
  const embedded = await getEmbeddingWithMetadata('hello', 'openai', { userId: user.userId });
  assert.equal(embedded.provider, 'neorouter');
  assert.equal(embedded.dimensions, 3);

  const { createProviderInstance } = require('../../../server/services/ai/models');
  const provider = createProviderInstance('neorouter', user.userId);
  const models = await provider.listModels();
  assert.ok(models.some((model) => model.id === 'auto:balanced'), 'routing profiles are offered as models');
  assert.equal(models.find((model) => model.id === 'groq/llama-4').priceTier, 'free');
  assert.deepEqual((await provider.listDecisionModels()).map((model) => model.id), ['openrouter/liquid-d1'], 'only decision models, no classifiers');
  const { describeOffer } = require('../../../server/services/ai/neorouter/offer');
  const { serverConnection } = require('../../../server/services/ai/neorouter/connection');
  const offer = await describeOffer(serverConnection(), { fresh: true });
  assert.equal(offer.roles.system_one, 1);
  assert.equal(offer.roles.images, 0);
  assert.equal(offer.notAllowed.images, 30, 'paid image models the key may not use are reported');
  assert.deepEqual((await provider.decide({ model: 'auto', state: {}, questions: { ok: {} } })).answers, { ok: true });

  const { resolveSttTarget } = require('../../../server/services/voice/transcription');
  const target = resolveSttTarget(user.userId, null, { sttProvider: 'auto', sttModel: '' });
  assert.deepEqual(target, { provider: 'openai', model: 'auto', apiKey: 'nrt_fake_key', baseUrl: `${address}/v1` });
});

test('automatic chat picks the router profile that fits the request', () => {
  const { selectInitialModel } = require('../../../server/services/ai/model_router');
  const models = [
    { id: 'openai::gpt-5', provider: 'openai', modelId: 'gpt-5', priceTier: 'expensive' },
    { id: 'neorouter::auto:balanced', provider: 'neorouter', modelId: 'auto:balanced' },
    { id: 'neorouter::auto:fast', provider: 'neorouter', modelId: 'auto:fast' },
  ];
  const settings = { default_chat_model: 'auto', enabled_models: [], cost_mode: 'balanced_auto' };
  assert.equal(selectInitialModel({ models, settings, userId: 1 }).model.id, 'neorouter::auto:balanced');
  assert.equal(selectInitialModel({ models, settings, userId: 1, selectionHint: { purpose: 'fast' } }).model.id, 'neorouter::auto:fast');
  const more = [...models, ...['cheap', 'best', 'smart'].map((profile) => ({ id: `neorouter::auto:${profile}`, provider: 'neorouter', modelId: `auto:${profile}` }))];
  assert.equal(selectInitialModel({ models: more, settings: { ...settings, cost_mode: 'economy' }, userId: 1 }).model.id, 'neorouter::auto:cheap');
  assert.equal(selectInitialModel({ models: more, settings, userId: 1, selectionHint: { complexity: 'complex' } }).model.id, 'neorouter::auto:smart');
  assert.equal(selectInitialModel({ models: more, settings, userId: 1, selectionHint: { requiredConfidence: 'high' } }).model.id, 'neorouter::auto:best');
  // NeoRouter's routing replaces the Smart Selector pool.
  const pooled = { ...settings, enabled_models: ['openai::gpt-5'] };
  assert.equal(selectInitialModel({ models: more, settings: pooled, userId: 1 }).model.id, 'neorouter::auto:balanced');
  // A model the user picked still wins.
  assert.equal(selectInitialModel({ models: more, settings: { ...settings, default_chat_model: 'openai::gpt-5' }, userId: 1 }).model.id, 'openai::gpt-5');
});

test('tool turns move a NeoRouter run to the profile for that work', async () => {
  const { neoRouterTaskSelection } = require('../../../server/services/ai/model_router');
  assert.equal(neoRouterTaskSelection('coding'), 'neorouter::auto:best');
  assert.equal(neoRouterTaskSelection('research'), 'neorouter::auto:smart');
  assert.equal(neoRouterTaskSelection('unknown'), null);
});

test('turning a role off hands it back to the usual provider', async () => {
  const signIn = require('../../../server/services/ai/neorouter/sign_in');
  const { forRole } = require('../../../server/services/ai/neorouter/connection');
  const admin = await createTestUser(ctx.db, { username: 'nr_roles' });
  await signIn.updateRoles({ scope: 'server', userId: admin.userId, roles: ['chat', 'search'] });
  assert.equal(forRole(admin.userId, null, 'live'), null);
  assert.equal(process.env.VOICE_LIVE_PROVIDER || '', '', 'live voice is no longer pointed at the router');
  assert.ok(forRole(admin.userId, null, 'search'));
  await signIn.disconnect({ scope: 'server', userId: admin.userId });
  assert.equal(forRole(admin.userId, null, 'search'), null);
});

test('only admins learn where the server NeoRouter lives', async () => {
  const { createTestApp, loginAs } = require('../../helpers/app');
  const { agent } = require('../../helpers/supertest');
  process.env.NEOROUTER_BASE_URL = `${address}/v1`;
  process.env.NEOROUTER_API_KEY = 'nrt_fake_key';
  process.env.NEOROUTER_ROLES = 'chat';
  try {
    const { app } = createTestApp();
    const owner = await createTestUser(ctx.db, { username: 'nr_view_admin' });
    const member = await createTestUser(ctx.db, { username: 'nr_view_member' });
    ctx.db.prepare('UPDATE users SET is_admin = CASE WHEN id = ? THEN 1 ELSE 0 END WHERE id IN (?, ?)').run(owner.userId, owner.userId, member.userId);
    const asAdmin = agent(app);
    const asMember = agent(app);
    await loginAs(asAdmin, owner);
    await loginAs(asMember, member);

    const adminView = (await asAdmin.get('/api/neorouter').expect(200)).body;
    assert.equal(adminView.server.address, address);
    const memberView = (await asMember.get('/api/neorouter').expect(200)).body;
    assert.deepEqual(memberView.server, { connected: true });
    assert.ok(!JSON.stringify(memberView).includes(address), 'the address is nowhere in the answer');

    const providers = (await asMember.get('/api/settings/meta/ai-providers').expect(200)).body.providers;
    assert.ok(!JSON.stringify(providers).includes(address), 'nor in the provider list');
    const adminProviders = (await asAdmin.get('/api/settings/meta/ai-providers').expect(200)).body.providers;
    assert.equal(adminProviders.find((provider) => provider.id === 'neorouter').baseUrl, `${address}/v1`);
  } finally {
    delete process.env.NEOROUTER_BASE_URL;
    delete process.env.NEOROUTER_API_KEY;
    delete process.env.NEOROUTER_ROLES;
  }
});
