'use strict';

const assert = require('node:assert/strict');
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

test('account settings cannot store AI provider keys', async () => {
  const apiKey = 'sk-test-openai-key';
  await client
    .put('/api/settings/ai-providers/openai/credentials')
    .send({ apiKey })
    .expect(404);

  await client
    .put('/api/settings')
    .send({
      ai_provider_configs: {
        openai: { enabled: true, baseUrl: 'https://user.example.test/v1' },
      },
    })
    .expect(200);

  const rejected = await client
    .put('/api/settings/ai_provider_configs')
    .send({
      value: {
        openai: { enabled: true, baseUrl: 'https://user.example.test/v1' },
      },
    })
    .expect(403);
  assert.match(rejected.body.error, /server, not per account/i);

  const settings = await client.get('/api/settings').expect(200);
  assert.equal(JSON.stringify(settings.body).includes(apiKey), false);
  assert.equal(settings.body.ai_provider_api_keys, undefined);
  assert.notEqual(
    settings.body.ai_provider_configs?.openai?.baseUrl,
    'https://user.example.test/v1',
  );

  const catalog = require('../../../server/services/ai/models')
    .getProviderCatalog(user.userId)
    .find((provider) => provider.id === 'openai');
  assert.equal(catalog.credentialConfigured, false);
  assert.notEqual(catalog.baseUrl, 'https://user.example.test/v1');
});

test('provider credential updates require an authenticated session', async () => {
  await request(app)
    .put('/api/settings/ai-providers/openai/credentials')
    .send({ apiKey: 'sk-should-not-save' })
    .expect(401);
});
