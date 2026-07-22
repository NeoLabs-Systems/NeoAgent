'use strict';

const assert = require('node:assert/strict');
const { after, before, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

let ctx;
let lifecycle;
let AgentEngine;
let userId;

before(async () => {
  ctx = createTestRuntime();
  userId = (await createTestUser(ctx.db, { username: 'run_lifecycle_user' })).userId;
  lifecycle = require('../../../server/services/ai/loop/lifecycle');
  ({ AgentEngine } = require('../../../server/services/ai/engine'));
});

after(() => teardownTestRuntime(ctx));

function insertRun(id, status = 'running') {
  ctx.db.prepare(
    'INSERT INTO agent_runs (id, user_id, title, status) VALUES (?, ?, ?, ?)',
  ).run(id, userId, id, status);
}

test('terminal run transitions are first-writer-wins', () => {
  insertRun('fenced-run');
  assert.equal(lifecycle.closeRun('fenced-run', 'stopped'), true);
  assert.equal(lifecycle.closeRun('fenced-run', 'completed', { finalResponse: 'late' }), false);
  const row = ctx.db.prepare(
    'SELECT status, final_response, completed_at FROM agent_runs WHERE id = ?',
  ).get('fenced-run');
  assert.equal(row.status, 'stopped');
  assert.equal(row.final_response, null);
  assert.ok(row.completed_at);
});

test('closing a run atomically settles its active step', () => {
  insertRun('cascade-run');
  ctx.db.prepare(
    `INSERT INTO agent_steps (id, run_id, step_index, type, description, status, started_at)
     VALUES (?, ?, 1, 'tool', 'active step', 'running', datetime('now'))`,
  ).run('cascade-step', 'cascade-run');

  assert.equal(lifecycle.closeRun('cascade-run', 'interrupted', { error: 'restart' }), true);
  const step = ctx.db.prepare('SELECT status, error, completed_at FROM agent_steps WHERE id = ?')
    .get('cascade-step');
  assert.equal(step.status, 'interrupted');
  assert.equal(step.error, 'restart');
  assert.ok(step.completed_at);
});

test('a stronger pending control signal is not downgraded', () => {
  insertRun('control-run');
  assert.equal(lifecycle.requestRunControl('control-run', userId, 'stop', 'operator stop').accepted, true);
  const pause = lifecycle.requestRunControl('control-run', userId, 'pause', 'late pause');
  assert.equal(pause.accepted, false);
  assert.equal(pause.reason, 'stronger_signal_pending');
  assert.equal(lifecycle.getRunControl('control-run').action, 'stop');
});

test('checkpoints update in place and remain attached to an open paused run', () => {
  insertRun('checkpoint-run', 'paused');
  lifecycle.checkpointRun('checkpoint-run', 'tool_boundary', { iteration: 2 });
  lifecycle.checkpointRun('checkpoint-run', 'model_boundary', { iteration: 3 });
  const row = ctx.db.prepare(
    'SELECT version, phase, state_json FROM agent_run_checkpoints WHERE run_id = ?',
  ).get('checkpoint-run');
  assert.equal(row.version, 1);
  assert.equal(row.phase, 'model_boundary');
  assert.deepEqual(JSON.parse(row.state_json), { iteration: 3 });
});

test('an active run pauses at a boundary and resumes the same execution', async () => {
  insertRun('pause-run');
  const engine = new AgentEngine(null);
  engine.emit = () => {};
  engine.recordRunEvent = () => {};
  engine.startMessagingProgressSupervisor = () => {};
  engine.stopMessagingProgressSupervisor = () => {};
  engine.activeRuns.set('pause-run', {
    userId,
    agentId: null,
    status: 'running',
    pauseAvailable: true,
    abortController: new AbortController(),
    toolPids: new Set(),
    activeTools: [],
    progressLedger: { currentPhase: 'model' },
  });

  assert.equal(engine.pauseRun('pause-run', { userId, reason: 'test pause' }), true);
  const boundary = engine.checkpointLifecycle('pause-run', 'model_boundary', { iteration: 2 });
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(ctx.db.prepare('SELECT status FROM agent_runs WHERE id = ?').get('pause-run').status, 'paused');
  assert.equal(engine.resumeRun('pause-run', { userId }), true);
  await boundary;
  assert.equal(ctx.db.prepare('SELECT status FROM agent_runs WHERE id = ?').get('pause-run').status, 'running');
  assert.equal(engine.getRunMeta('pause-run').abortController.signal.aborted, false);
  engine.activeRuns.delete('pause-run');
});
