'use strict';

const assert = require('node:assert/strict');
const { after, before, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../helpers/db');
const { loginAs } = require('../helpers/app');
const { agent } = require('../helpers/supertest');
const { connectSocket, createSocketFixture } = require('../helpers/socket');

let ctx;
let fixture;

before(async () => {
  ctx = createTestRuntime();
  fixture = await createSocketFixture();
});

after(async () => {
  await fixture.close();
  teardownTestRuntime(ctx);
});

async function connectAs(user) {
  const http = agent(fixture.app);
  const login = await loginAs(http, user);
  const cookie = login.headers['set-cookie'].map((item) => item.split(';')[0]).join('; ');
  const socket = connectSocket(fixture.url, cookie);
  await new Promise((resolve, reject) => {
    socket.on('connect', resolve);
    socket.on('connect_error', reject);
  });
  return socket;
}

// Regression: agent:run_detail used to fetch agent_steps, conversation_history,
// and run events by run_id alone. The run row was user-scoped, but the other
// three were not — so any user could read another user's run internals by id.
test('agent:run_detail does not leak another user\'s run steps/history', async () => {
  const victim = await createTestUser(ctx.db, { username: 'idor_victim' });
  const attacker = await createTestUser(ctx.db, { username: 'idor_attacker' });

  const runId = 'run_victim_secret_1';
  ctx.db.prepare(
    'INSERT INTO agent_runs (id, user_id, agent_id, status) VALUES (?, ?, ?, ?)'
  ).run(runId, victim.userId, null, 'completed');
  ctx.db.prepare(
    'INSERT INTO agent_steps (id, run_id, step_index, type, description) VALUES (?, ?, ?, ?, ?)'
  ).run('step_secret_1', runId, 0, 'tool_call', 'victim private step');
  ctx.db.prepare(
    'INSERT INTO conversation_history (user_id, agent_id, agent_run_id, role, content) VALUES (?, ?, ?, ?, ?)'
  ).run(victim.userId, null, runId, 'assistant', 'victim private content');

  const socket = await connectAs(attacker);
  const detail = await new Promise((resolve) => {
    socket.on('agent:run_detail', resolve);
    socket.emit('agent:run_detail', { runId });
  });
  socket.close();

  assert.equal(detail.run, null);
  assert.deepEqual(detail.steps, []);
  assert.deepEqual(detail.history, []);
});

// The owner still gets full detail back.
test('agent:run_detail returns full detail to the run owner', async () => {
  const owner = await createTestUser(ctx.db, { username: 'idor_owner' });
  const runId = 'run_owner_1';
  ctx.db.prepare(
    'INSERT INTO agent_runs (id, user_id, agent_id, status) VALUES (?, ?, ?, ?)'
  ).run(runId, owner.userId, null, 'completed');
  ctx.db.prepare(
    'INSERT INTO agent_steps (id, run_id, step_index, type, description) VALUES (?, ?, ?, ?, ?)'
  ).run('step_owner_1', runId, 0, 'tool_call', 'owner step');

  const socket = await connectAs(owner);
  const detail = await new Promise((resolve) => {
    socket.on('agent:run_detail', resolve);
    socket.emit('agent:run_detail', { runId });
  });
  socket.close();

  assert.ok(detail.run);
  assert.equal(detail.run.id, runId);
  assert.equal(detail.steps.length, 1);
});
