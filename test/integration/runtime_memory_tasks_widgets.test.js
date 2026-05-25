'use strict';

const assert = require('node:assert/strict');
const { after, before, describe, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../helpers/db');
const { createTestApp, loginAs } = require('../helpers/app');
const { agent } = require('../helpers/supertest');

describe('runtime, settings, memory, tasks, widgets, and messaging routes', () => {
  let ctx;
  let app;
  let client;
  let user;

  before(async () => {
    ctx = createTestRuntime();
    app = createTestApp().app;
    user = await createTestUser(ctx.db, { username: 'misc_user' });
    client = agent(app);
    await loginAs(client, user);
  });

  after(() => teardownTestRuntime(ctx));

  test('runtime and health routes return autonomous status shapes', async () => {
    const runtime = await client.get('/api/runtime/config').expect(200);
    assert.equal(typeof runtime.body.analytics, 'object');
    const health = await client.get('/api/health').expect(200);
    assert.match(health.body.status, /^(ok|degraded)$/);
    assert.equal(typeof health.body.runtime.ready, 'boolean');
    await client.get('/api/system/test/cli').expect(200);
    await client.get('/api/version').expect(200);
  });

  test('settings routes read and write agent-scoped settings', async () => {
    const settings = await client.get('/api/settings').expect(200);
    assert.equal(typeof settings.body, 'object');
    await client.put('/api/settings/default_chat_model').send({ value: 'gpt-test' }).expect(200);
    const one = await client.get('/api/settings/default_chat_model').expect(200);
    assert.equal(one.body.value, 'gpt-test');
    await client.get('/api/settings/meta/models').expect(200);
    await client.get('/api/settings/meta/ai-providers').expect(200);
  });

  test('memory overview, CRUD, recall, and core routes run without external services', async () => {
    const overview = await client.get('/api/memory').expect(200);
    assert.equal(typeof overview.body.agentId, 'string');
    const created = await client.post('/api/memory/memories').send({
      content: 'Autonomous tests should cover memory.',
      category: 'semantic',
      importance: 7,
    }).expect(200);
    assert.equal(created.body.success, true);
    const memories = await client.get('/api/memory/memories').expect(200);
    assert.ok(memories.body.length >= 1);
    await client.post('/api/memory/memories/recall').send({ query: 'memory', limit: 3 }).expect(200);
    await client.put('/api/memory/core/project').send({ value: 'NeoAgent' }).expect(200);
    const core = await client.get('/api/memory/core').expect(200);
    assert.equal(core.body.project, 'NeoAgent');
    await client.delete('/api/memory/memories/999999').expect(404);
  });

  test('tasks and widgets use fake services but real auth/routing', async () => {
    const task = await client.post('/api/tasks').send({ name: 'Daily review' }).expect(201);
    assert.equal(task.body.name, 'Daily review');
    const tasks = await client.get('/api/tasks').expect(200);
    assert.equal(tasks.body.some((item) => item.id === task.body.id), true);
    await client.post(`/api/tasks/${task.body.id}/run`).expect(200);

    const widget = await client.post('/api/widgets').send({ name: 'Focus' }).expect(201);
    assert.equal(widget.body.name, 'Focus');
    const widgets = await client.get('/api/widgets').expect(200);
    assert.equal(widgets.body.some((item) => item.id === widget.body.id), true);
    await client.post(`/api/widgets/${widget.body.id}/refresh`).expect(200);
  });

  test('messaging, desktop, browser, android, and social routes are reachable with fakes', async () => {
    await client.get('/api/messaging/status').expect(200);
    await client.get('/api/desktop/status').expect(200);
    await client.get('/api/browser/status').expect(200);
    await client.get('/api/android/status').expect(200);
    await client.get('/api/social-video/health').expect(200);
  });
});
