'use strict';

const assert = require('node:assert/strict');
const { after, before, describe, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../helpers/db');
const { createTestApp, loginAs } = require('../helpers/app');
const { agent, request } = require('../helpers/supertest');

function assertUserPayload(user) {
  assert.equal(typeof user.id, 'number');
  assert.equal(typeof user.username, 'string');
  assert.equal(Object.hasOwn(user, 'password'), false);
  assert.equal(Object.hasOwn(user, 'password_hash'), false);
}

describe('API response contracts', () => {
  let ctx;
  let app;
  let client;
  let user;

  before(async () => {
    ctx = createTestRuntime();
    app = createTestApp().app;
    user = await createTestUser(ctx.db, { username: 'contract_user' });
    client = agent(app);
    await loginAs(client, user);
  });

  after(() => teardownTestRuntime(ctx));

  test('auth contract shapes are stable and never expose passwords', async () => {
    const statusPublic = await request(app).get('/api/auth/status').expect(200);
    assert.equal(statusPublic.body.authenticated, false);
    assert.equal(statusPublic.body.user, null);

    const status = await client.get('/api/auth/status').expect(200);
    assert.equal(status.body.authenticated, true);
    assertUserPayload(status.body.user);

    const me = await client.get('/api/auth/me').expect(200);
    assertUserPayload(me.body.user);

    const logoutClient = agent(app);
    await loginAs(logoutClient, user);
    const logout = await logoutClient.post('/api/auth/logout').expect(200);
    assert.equal(logout.body.success, true);
  });

  test('account contract shape includes user, 2FA, sessions, and providers', async () => {
    const account = await client.get('/api/account').expect(200);
    assertUserPayload(account.body.user);
    assert.equal(typeof account.body.twoFactor.enabled, 'boolean');
    assert.ok(Array.isArray(account.body.authProviders));
    const sessions = await client.get('/api/account/sessions').expect(200);
    assert.ok(Array.isArray(sessions.body.sessions));
  });

  test('agent contracts expose profiles, run summaries, and run details', async () => {
    const profiles = await client.get('/api/agent-profiles').expect(200);
    assert.ok(Array.isArray(profiles.body.agents));
    assert.equal(typeof profiles.body.defaultAgentId, 'string');
    const profile = await client.post('/api/agent-profiles').send({ displayName: 'Contract Agent' }).expect(201);
    for (const key of ['id', 'slug', 'displayName', 'status', 'createdAt', 'updatedAt', 'isDefault']) {
      assert.equal(Object.hasOwn(profile.body, key), true, key);
    }
    const runs = await client.get('/api/agents?limit=20').expect(200);
    assert.ok(Array.isArray(runs.body.runs));
    assert.equal(typeof runs.body.total, 'number');
    assert.equal(typeof runs.body.limit, 'number');
    assert.equal(typeof runs.body.offset, 'number');
  });

  test('runtime, settings, memory, MCP, tasks, widgets, and integrations contracts are stable', async () => {
    const runtime = await request(app).get('/api/runtime/config').expect(200);
    assert.equal(typeof runtime.body.analytics, 'object');
    const health = await client.get('/api/health').expect(200);
    assert.match(health.body.status, /^(ok|degraded)$/);
    assert.equal(typeof health.body.timestamp, 'string');
    assert.equal(typeof health.body.runtime.ready, 'boolean');

    assert.equal(typeof (await client.get('/api/settings').expect(200)).body, 'object');
    assert.equal(typeof (await client.get('/api/memory').expect(200)).body.agentId, 'string');
    assert.ok(Array.isArray((await client.get('/api/mcp').expect(200)).body));
    assert.ok(Array.isArray((await client.get('/api/tasks').expect(200)).body));
    assert.ok(Array.isArray((await client.get('/api/widgets').expect(200)).body));
    assert.ok(Array.isArray((await client.get('/api/integrations').expect(200)).body));
  });
});
