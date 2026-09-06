'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const { after, before, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');
const { createTestApp, loginAs } = require('../../helpers/app');
const { agent, request } = require('../../helpers/supertest');

let ctx;
let app;
let client;
let user;

before(async () => {
  ctx = createTestRuntime();
  process.env.NEOAGENT_SETUP_PROFILE = 'quick';
  process.env.NEOAGENT_SETUP_COMPLETED_SECTIONS = 'core';
  app = createTestApp().app;
  user = await createTestUser(ctx.db, { username: 'provider_ui_user' });
  client = agent(app);
  await loginAs(client, user);
});

after(() => teardownTestRuntime(ctx));

test('desktop users can save an LLM provider key after quick setup', async () => {
  const apiKey = 'sk-test-openai-key';
  const saved = await client
    .put('/api/settings/ai-providers/openai/credentials')
    .send({ apiKey })
    .expect(200);
  assert.equal(saved.body.success, true);
  assert.equal(saved.body.provider.id, 'openai');
  assert.equal(saved.body.provider.credentialConfigured, true);
  assert.equal(saved.body.setup.completedSections.includes('providers'), true);
  assert.equal(saved.body.provider.apiKey, undefined);
  assert.equal(JSON.stringify(saved.body).includes(apiKey), false);

  const catalog = require('../../../server/services/ai/models')
    .getProviderCatalog(user.userId)
    .find((provider) => provider.id === 'openai');
  assert.equal(catalog.credentialConfigured, true);
  assert.equal(catalog.available, true);

  const settings = await client.get('/api/settings').expect(200);
  assert.equal(JSON.stringify(settings.body).includes(apiKey), false);

  assert.match(
    fs.readFileSync(ctx.envFile, 'utf8'),
    /NEOAGENT_SETUP_COMPLETED_SECTIONS=.*providers/,
  );
});

test('custom OpenAI-compatible endpoints require a valid base URL', async () => {
  const missingUrl = await client
    .put('/api/settings/ai-providers/openai-compatible/credentials')
    .send({ apiKey: 'custom-token' })
    .expect(400);
  assert.match(missingUrl.body.error, /base URL/i);

  await client
    .put('/api/settings/ai-providers/openai-compatible/credentials')
    .send({
      apiKey: 'custom-token',
      baseUrl: 'https://models.example.test/v1',
    })
    .expect(200);

  const rejected = await client
    .put('/api/settings/ai-providers/openai-compatible/credentials')
    .send({ baseUrl: 'https://user:pass@models.example.test/v1' })
    .expect(400);
  assert.match(rejected.body.error, /embedded credentials/);
});

test('OAuth providers cannot be configured with an API key field', async () => {
  const response = await client
    .put('/api/settings/ai-providers/claude-code/credentials')
    .send({ apiKey: 'not-a-valid-path' })
    .expect(400);
  assert.match(response.body.error, /account login/i);
});

test('local Ollama can be enabled with a base URL and no API key', async () => {
  const saved = await client
    .put('/api/settings/ai-providers/ollama/credentials')
    .send({ baseUrl: 'http://127.0.0.1:11434' })
    .expect(200);
  assert.equal(saved.body.provider.id, 'ollama');
  assert.equal(saved.body.provider.baseUrl, 'http://127.0.0.1:11434');
  assert.equal(saved.body.setup.completedSections.includes('providers'), true);
});

test('provider credential updates require an authenticated session', async () => {
  await request(app)
    .put('/api/settings/ai-providers/openai/credentials')
    .send({ apiKey: 'sk-should-not-save' })
    .expect(401);
});
