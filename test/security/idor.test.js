'use strict';

const assert = require('node:assert/strict');
const { after, before, describe, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../helpers/db');
const { createTestApp, loginAs } = require('../helpers/app');
const { agent } = require('../helpers/supertest');

describe('IDOR protections', () => {
  let ctx;
  let app;

  before(() => {
    ctx = createTestRuntime();
    app = createTestApp().app;
  });

  after(() => teardownTestRuntime(ctx));

  test('user cannot update or delete another user agent profile', async () => {
    const userA = await createTestUser(ctx.db, { username: 'idor_agent_a' });
    const userB = await createTestUser(ctx.db, { username: 'idor_agent_b' });
    const a = agent(app);
    const b = agent(app);
    await loginAs(a, userA);
    await loginAs(b, userB);
    const created = await a.post('/api/agent-profiles').send({ displayName: 'Owned Agent' }).expect(201);

    await b.put(`/api/agent-profiles/${created.body.id}`).send({ displayName: 'Tampered' }).expect(404);
    const row = ctx.db.prepare('SELECT display_name, status FROM agents WHERE id = ?').get(created.body.id);
    assert.equal(row.display_name, 'Owned Agent');

    await b.delete(`/api/agent-profiles/${created.body.id}`).expect(404);
    assert.equal(ctx.db.prepare('SELECT status FROM agents WHERE id = ?').get(created.body.id).status, 'active');
  });

  test('user cannot see or delete another user agent run', async () => {
    const userA = await createTestUser(ctx.db, { username: 'idor_run_a' });
    const userB = await createTestUser(ctx.db, { username: 'idor_run_b' });
    const { resolveAgentId } = require('../../server/services/agents/manager');
    const agentId = resolveAgentId(userA.userId, null);
    ctx.db.prepare(
      `INSERT INTO agent_runs (id, user_id, agent_id, title, status) VALUES (?, ?, ?, ?, ?)`
    ).run('run-owned-by-a', userA.userId, agentId, 'Secret run', 'completed');
    const b = agent(app);
    await loginAs(b, userB);
    await b.get('/api/agents/run-owned-by-a').expect(404);
    await b.get('/api/agents/run-owned-by-a/steps').expect(404);
    await b.delete('/api/agents/run-owned-by-a').expect(404);
    assert.equal(ctx.db.prepare('SELECT COUNT(*) AS count FROM agent_runs WHERE id = ?').get('run-owned-by-a').count, 1);
  });

  test('user cannot read or mutate another user MCP server', async () => {
    const userA = await createTestUser(ctx.db, { username: 'idor_mcp_a' });
    const userB = await createTestUser(ctx.db, { username: 'idor_mcp_b' });
    const a = agent(app);
    const b = agent(app);
    await loginAs(a, userA);
    await loginAs(b, userB);
    const created = await a.post('/api/mcp').send({
      name: 'Owned MCP',
      command: 'https://owned.example.test/sse',
    }).expect(201);
    await b.put(`/api/mcp/${created.body.id}`).send({ name: 'Tampered' }).expect(404);
    await b.delete(`/api/mcp/${created.body.id}`).expect(404);
    assert.equal(ctx.db.prepare('SELECT name FROM mcp_servers WHERE id = ?').get(created.body.id).name, 'Owned MCP');
  });
});
