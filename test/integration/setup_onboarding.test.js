'use strict';

const assert = require('node:assert/strict');
const { after, before, test } = require('node:test');

const { createTestRuntime, teardownTestRuntime } = require('../helpers/db');
const { createTestApp } = require('../helpers/app');
const { agent, request } = require('../helpers/supertest');

let ctx;
let app;

before(() => {
  ctx = createTestRuntime();
  process.env.NEOAGENT_SETUP_PROFILE = 'quick';
  process.env.NEOAGENT_SETUP_COMPLETED_SECTIONS = 'core,providers';
  process.env.NEOAGENT_INSTANCE_NAME = 'Setup Test';
  app = createTestApp().app;
});

after(() => teardownTestRuntime(ctx));

test('setup handshake exposes discovery metadata without secrets', async () => {
  const response = await request(app).get('/api/setup/handshake').expect(200);
  assert.equal(response.body.product, 'NeoAgent');
  assert.equal(response.body.protocolVersion, 1);
  assert.equal(response.body.displayName, 'Setup Test');
  assert.equal(response.body.claimed, false);
  assert.equal(typeof response.body.instanceId, 'string');
  assert.equal(Object.hasOwn(response.body, 'token'), false);
});

test('first account can register without a setup claim', async () => {
  const payload = {
    username: 'setup_owner',
    email: 'setup-owner@example.com',
    password: 'CorrectHorse9!Battery',
  };
  const client = agent(app);
  await client.post('/api/auth/register').send(payload).expect(200);

  const finalStatus = await client.get('/api/auth/status').expect(200);
  assert.equal(finalStatus.body.hasUser, true);

  const setupStatus = await client.get('/api/setup/status').expect(200);
  assert.equal(setupStatus.body.profile, 'quick');
  assert.deepEqual(setupStatus.body.completedSections, ['core', 'providers']);
  assert.ok(setupStatus.body.openSections.includes('integrations'));
  assert.equal(setupStatus.body.complete, false);
});
