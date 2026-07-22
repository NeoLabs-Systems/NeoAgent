'use strict';

const assert = require('node:assert/strict');
const { after, before, describe, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../helpers/db');
const { createTestApp, loginAs } = require('../helpers/app');
const { agent, request } = require('../helpers/supertest');

describe('agent profile, agent run, and MCP routes', () => {
  let ctx;
  let app;

  before(() => {
    ctx = createTestRuntime();
    app = createTestApp().app;
  });

  after(() => teardownTestRuntime(ctx));

  test('agent profiles require auth, auto-create main agent, and create custom agents', async () => {
    const user = await createTestUser(ctx.db, { username: 'agent_route_user' });
    await request(app).get('/api/agent-profiles').expect(401);
    const client = agent(app);
    await loginAs(client, user);

    const list = await client.get('/api/agent-profiles').expect(200);
    assert.ok(Array.isArray(list.body.agents));
    assert.equal(list.body.agents.some((item) => item.slug === 'main'), true);
    assert.equal(typeof list.body.defaultAgentId, 'string');

    const created = await client.post('/api/agent-profiles').send({
      displayName: 'Research Agent',
      responsibilities: 'Research safely',
    }).expect(201);
    assert.equal(created.body.slug, 'research-agent');

    const updated = await client.put(`/api/agent-profiles/${created.body.id}`).send({
      displayName: 'Research Lead',
    }).expect(200);
    assert.equal(updated.body.displayName, 'Research Lead');
  });

  test('agent profile data is isolated by user', async () => {
    const userA = await createTestUser(ctx.db, { username: 'agent_iso_a' });
    const userB = await createTestUser(ctx.db, { username: 'agent_iso_b' });
    const clientA = agent(app);
    const clientB = agent(app);
    await loginAs(clientA, userA);
    await loginAs(clientB, userB);
    const created = await clientA.post('/api/agent-profiles').send({ displayName: 'Private Agent' }).expect(201);
    const listB = await clientB.get('/api/agent-profiles').expect(200);
    assert.equal(listB.body.agents.some((item) => item.id === created.body.id), false);
  });

  test('agent run list and creation validate expected route behavior', async () => {
    const user = await createTestUser(ctx.db, { username: 'run_user' });
    const client = agent(app);
    await loginAs(client, user);
    const runs = await client.get('/api/agents').expect(200);
    assert.deepEqual(runs.body.runs, []);
    assert.equal(runs.body.total, 0);
    await client.post('/api/agents').send({ task: '' }).expect(400);
    const created = await client.post('/api/agents').send({ task: 'Say hello' }).expect(200);
    assert.equal(created.body.status, 'completed');
  });

  test('agent pause and resume routes preserve the active execution and enforce ownership', async () => {
    const owner = await createTestUser(ctx.db, { username: 'run_pause_owner' });
    const outsider = await createTestUser(ctx.db, { username: 'run_pause_outsider' });
    const ownerClient = agent(app);
    const outsiderClient = agent(app);
    await loginAs(ownerClient, owner);
    await loginAs(outsiderClient, outsider);

    const { AgentEngine } = require('../../server/services/ai/engine');
    const engine = new AgentEngine(null);
    engine.emit = () => {};
    engine.recordRunEvent = () => {};
    engine.startMessagingProgressSupervisor = () => {};
    engine.stopMessagingProgressSupervisor = () => {};
    const originalEngine = app.locals.agentEngine;
    app.locals.agentEngine = engine;
    const runId = 'pause-route-run';

    try {
      ctx.db.prepare(
        'INSERT INTO agent_runs (id, user_id, title, status) VALUES (?, ?, ?, ?)'
      ).run(runId, owner.userId, 'Pause route run', 'running');
      engine.activeRuns.set(runId, {
        userId: owner.userId,
        agentId: null,
        status: 'running',
        pauseAvailable: true,
        abortController: new AbortController(),
        toolPids: new Set(),
        activeTools: [],
        progressLedger: { currentPhase: 'model' },
      });

      await request(app).post(`/api/agents/${runId}/pause`).send({}).expect(401);
      await outsiderClient.post(`/api/agents/${runId}/pause`).send({}).expect(409);
      await ownerClient.post(`/api/agents/${runId}/pause`)
        .send({ reason: 'operator pause' })
        .expect(200, { success: true, status: 'pausing' });

      const boundary = engine.checkpointLifecycle(runId, 'model_boundary', { iteration: 4 });
      await new Promise((resolve) => setImmediate(resolve));
      const detail = await ownerClient.get(`/api/agents/${runId}/steps`).expect(200);
      assert.equal(detail.body.run.status, 'paused');
      assert.equal(detail.body.lifecycle.action, 'pause');
      assert.equal(detail.body.lifecycle.reason, 'operator pause');
      assert.equal(detail.body.lifecycle.checkpoint_phase, 'model_boundary');

      await ownerClient.post(`/api/agents/${runId}/resume`)
        .expect(200, { success: true, status: 'running' });
      await boundary;
      assert.equal(ctx.db.prepare('SELECT status FROM agent_runs WHERE id = ?').get(runId).status, 'running');
      assert.equal(engine.getRunMeta(runId).abortController.signal.aborted, false);
      await ownerClient.post(`/api/agents/${runId}/resume`).expect(409);
    } finally {
      if (engine.activeRuns.has(runId)) {
        engine.stopRun(runId);
        engine.activeRuns.delete(runId);
      }
      app.locals.agentEngine = originalEngine;
    }
  });

  test('MCP CRUD works with real DB and fake runtime client', async () => {
    const user = await createTestUser(ctx.db, { username: 'mcp_user' });
    const client = agent(app);
    await loginAs(client, user);
    await client.get('/api/mcp').expect(200).expect((res) => assert.deepEqual(res.body, []));

    const created = await client.post('/api/mcp').send({
      name: 'Docs',
      command: 'https://mcp.example.test/sse',
      config: { token: 'abc' },
    }).expect(201);
    assert.equal(created.body.command, 'https://mcp.example.test/sse');

    const list = await client.get('/api/mcp').expect(200);
    assert.equal(list.body.length, 1);
    assert.equal(list.body[0].name, 'Docs');
    await client.get('/api/mcp/oauth/callback').query({
      state: `${created.body.id}::${'0'.repeat(32)}`,
      code: 'unissued-code',
    }).expect(400).expect(/Invalid or expired OAuth state/);

    await client.put(`/api/mcp/${created.body.id}`).send({ name: 'Docs Updated' }).expect(200);
    await client.post(`/api/mcp/${created.body.id}/start`).expect(200);
    await client.get(`/api/mcp/${created.body.id}/tools`).expect(200);
    const liveUpdate = await client.put(`/api/mcp/${created.body.id}`).send({
      name: 'Docs Final',
      command: 'https://mcp-final.example.test/sse',
    }).expect(200);
    assert.equal(liveUpdate.body.status, 'stopped');
    const afterUpdate = await client.get('/api/mcp').expect(200);
    assert.equal(afterUpdate.body[0].status, 'stopped');
    assert.equal(afterUpdate.body[0].command, 'https://mcp-final.example.test/sse');
    await client.delete(`/api/mcp/${created.body.id}`).expect(200);
    await client.get('/api/mcp').expect(200).expect((res) => assert.equal(res.body.length, 0));
  });

  test('MCP servers are scoped to creating user', async () => {
    const userA = await createTestUser(ctx.db, { username: 'mcp_iso_a' });
    const userB = await createTestUser(ctx.db, { username: 'mcp_iso_b' });
    const clientA = agent(app);
    const clientB = agent(app);
    await loginAs(clientA, userA);
    await loginAs(clientB, userB);
    const created = await clientA.post('/api/mcp').send({
      name: 'Private',
      command: 'https://private.example.test/sse',
    }).expect(201);
    const listB = await clientB.get('/api/mcp').expect(200);
    assert.equal(listB.body.some((item) => Number(item.id) === Number(created.body.id)), false);
  });
});
