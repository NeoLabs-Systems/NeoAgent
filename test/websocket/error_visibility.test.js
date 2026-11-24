'use strict';

const assert = require('node:assert/strict');
const { after, before, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../helpers/db');
const { loginAs } = require('../helpers/app');
const { agent } = require('../helpers/supertest');
const { connectSocket, createSocketFixture } = require('../helpers/socket');

const RAW = 'SqliteError: no such table: secrets at /Users/x/db.js:3';
const GENERIC = 'Something went wrong. Please try again.';

let ctx;
let fixture;
let admin;
let member;

before(async () => {
  ctx = createTestRuntime();
  admin = await createTestUser(ctx.db, { username: 'stream_admin' });
  member = await createTestUser(ctx.db, { username: 'stream_member' });
  fixture = await createSocketFixture();
});

after(async () => {
  await fixture.close();
  teardownTestRuntime(ctx);
});

async function connectAs(user) {
  const login = await loginAs(agent(fixture.app), user);
  const cookie = login.headers['set-cookie'].map((item) => item.split(';')[0]).join('; ');
  const socket = connectSocket(fixture.url, cookie);
  await new Promise((resolve, reject) => {
    socket.on('connect', resolve);
    socket.on('connect_error', reject);
  });
  return socket;
}

async function runDetailAs(user, runId) {
  ctx.db.prepare(
    "INSERT INTO agent_runs (id, user_id, agent_id, status, error) VALUES (?, ?, NULL, 'failed', ?)",
  ).run(runId, user.userId, RAW);
  ctx.db.prepare(
    "INSERT INTO agent_steps (id, run_id, step_index, type, description, status, error, result) VALUES (?, ?, 0, 'tool_call', 'Step', 'failed', ?, ?)",
  ).run(`${runId}_step`, runId, RAW, RAW);
  const socket = await connectAs(user);
  const detail = await new Promise((resolve) => {
    socket.on('agent:run_detail', resolve);
    socket.emit('agent:run_detail', { runId });
  });
  socket.close();
  return detail;
}

test('agent:run_detail hides a failure from non-admins only', async () => {
  const seenByMember = await runDetailAs(member, 'run_visibility_member');
  assert.equal(seenByMember.run.error, GENERIC);
  assert.equal(seenByMember.steps[0].error, GENERIC);
  assert.equal(seenByMember.steps[0].result, null);
  assert.doesNotMatch(JSON.stringify(seenByMember), /SqliteError/);

  const seenByAdmin = await runDetailAs(admin, 'run_visibility_admin');
  assert.equal(seenByAdmin.run.error, RAW);
  assert.equal(seenByAdmin.steps[0].error, RAW);
});

function emitted(user, event, payload) {
  const { AgentEngine } = require('../../server/services/ai/loop/agent_engine_core');
  const sent = [];
  const engine = {
    activeRuns: new Map(),
    io: { to: () => ({ emit: (_, data) => sent.push(data) }) },
  };
  AgentEngine.prototype.emit.call(engine, user.userId, event, payload);
  return sent[0];
}

test('streamed run failures follow the same rule', () => {
  assert.equal(emitted(member, 'run:error', { error: RAW }).error, GENERIC);
  assert.equal(emitted(member, 'run:error', { error: 'Add a model first.' }).error, 'Add a model first.');
  assert.equal(emitted(admin, 'run:error', { error: RAW }).error, RAW);

  const tool = emitted(member, 'run:tool_end', { error: 'Could not open it.', result: RAW });
  assert.equal(tool.error, GENERIC);
  assert.equal(tool.result, null);
  assert.equal(emitted(admin, 'run:tool_end', { error: RAW, result: RAW }).result, RAW);
  assert.equal(emitted(member, 'run:complete', { content: 'Done' }).content, 'Done');
});
