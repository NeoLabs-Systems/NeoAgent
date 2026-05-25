'use strict';

const assert = require('node:assert/strict');
const { after, before, test } = require('node:test');

const { createTestRuntime, teardownTestRuntime } = require('../helpers/db');
const { createTestApp } = require('../helpers/app');
const { agent } = require('../helpers/supertest');

let ctx;
let app;

before(() => {
  ctx = createTestRuntime();
  app = createTestApp().app;
});

after(() => teardownTestRuntime(ctx));

test('full register, authenticated app flow, logout, and login again', async () => {
  const client = agent(app);
  const initial = await client.get('/api/auth/status').expect(200);
  assert.equal(initial.body.authenticated, false);

  await client.post('/api/auth/register').send({
    username: 'e2e_user',
    email: 'e2e@example.com',
    password: 'CorrectHorse9!Battery',
  }).expect(200);

  await client.get('/api/auth/me').expect(200);
  const profiles = await client.get('/api/agent-profiles').expect(200);
  assert.equal(profiles.body.agents.some((agentProfile) => agentProfile.slug === 'main'), true);
  const runs = await client.get('/api/agents').expect(200);
  assert.equal(runs.body.total, 0);

  await client.post('/api/auth/logout').expect(200);
  await client.get('/api/auth/me').expect(401);

  await client.post('/api/auth/login').send({
    username: 'e2e_user',
    password: 'CorrectHorse9!Battery',
  }).expect(200);
  await client.get('/api/auth/me').expect(200);
});
