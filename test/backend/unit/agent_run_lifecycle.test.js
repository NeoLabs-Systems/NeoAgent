'use strict';

const assert = require('node:assert/strict');
const { after, before, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

let ctx;
let lifecycle;
let AgentEngine;
let userId;
let otherUserId;

before(async () => {
  ctx = createTestRuntime();
  userId = (await createTestUser(ctx.db, { username: 'run_lifecycle_user' })).userId;
  otherUserId = (await createTestUser(ctx.db, { username: 'run_lifecycle_other' })).userId;
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

test('stopping a paused run releases its suspended execution', async () => {
  insertRun('pause-stop-run');
  const engine = new AgentEngine(null);
  engine.emit = () => {};
  engine.recordRunEvent = () => {};
  engine.startMessagingProgressSupervisor = () => {};
  engine.stopMessagingProgressSupervisor = () => {};
  engine.activeRuns.set('pause-stop-run', {
    userId,
    agentId: null,
    status: 'running',
    pauseAvailable: true,
    abortController: new AbortController(),
    toolPids: new Set(),
    activeTools: [],
    progressLedger: { currentPhase: 'model' },
  });

  assert.equal(engine.pauseRun('pause-stop-run', { userId }), true);
  const boundary = engine.checkpointLifecycle('pause-stop-run', 'model_boundary', { iteration: 1 });
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(engine.getRunMeta('pause-stop-run').status, 'paused');

  engine.stopRun('pause-stop-run');
  assert.deepEqual(await boundary, { action: 'stop' });
  assert.equal(engine.getRunMeta('pause-stop-run').status, 'stopped');
  assert.equal(ctx.db.prepare('SELECT status FROM agent_runs WHERE id = ?').get('pause-stop-run').status, 'stopped');
  engine.activeRuns.delete('pause-stop-run');
});

test('abort enforces ownership for persisted runs that are not active in memory', () => {
  insertRun('persisted-owner-run');
  const engine = new AgentEngine(null);

  assert.equal(engine.abort('persisted-owner-run', { userId: otherUserId }), false);
  assert.equal(
    ctx.db.prepare('SELECT status FROM agent_runs WHERE id = ?').get('persisted-owner-run').status,
    'running',
  );

  assert.equal(engine.abort('persisted-owner-run', {
    userId,
    reason: 'Owner requested stop.',
  }), true);
  assert.deepEqual(
    ctx.db.prepare('SELECT status, error FROM agent_runs WHERE id = ?').get('persisted-owner-run'),
    { status: 'stopped', error: 'Owner requested stop.' },
  );
});

test('abort rejects unknown and already-terminal runs', () => {
  insertRun('already-complete-run', 'completed');
  const engine = new AgentEngine(null);

  assert.equal(engine.abort('missing-run', { userId }), false);
  assert.equal(engine.abort('already-complete-run', { userId }), false);
});

test('engine shutdown aborts and awaits owned background work', async () => {
  const engine = new AgentEngine(null);
  let observedReason = null;
  const backgroundTask = engine.trackBackgroundTask((signal) => new Promise((resolve) => {
    signal.addEventListener('abort', () => {
      observedReason = signal.reason;
      resolve('cancelled');
    }, { once: true });
  }));
  await new Promise((resolve) => setImmediate(resolve));

  const status = await engine.shutdown({ reason: 'test engine shutdown', timeoutMs: 1000 });

  assert.deepEqual(status, { state: 'stopped', timedOut: false, pendingCount: 0 });
  assert.equal(await backgroundTask, 'cancelled');
  assert.equal(observedReason, 'test engine shutdown');
  assert.equal(engine.backgroundTasks.size, 0);
});

test('engine rejects new foreground and background work after shutdown starts', async () => {
  const engine = new AgentEngine(null);
  await engine.shutdown({ reason: 'engine no longer accepting work' });

  await assert.rejects(
    engine.trackBackgroundTask(async () => 'too late'),
    (error) => error.name === 'AbortError'
      && error.message === 'engine no longer accepting work',
  );
  await assert.rejects(
    engine.runWithModel(userId, 'Do not start this run.'),
    (error) => error.name === 'AbortError'
      && error.message === 'engine no longer accepting work',
  );
});

test('engine shutdown fences and drains a sub-agent startup waiting on memory', async () => {
  insertRun('subagent-startup-parent');
  let markRecallStarted;
  let releaseRecall;
  const recallStarted = new Promise((resolve) => {
    markRecallStarted = resolve;
  });
  const recallBarrier = new Promise((resolve) => {
    releaseRecall = resolve;
  });
  const engine = new AgentEngine(null, {
    memoryManager: {
      recallMemory: async () => {
        markRecallStarted();
        await recallBarrier;
        return [];
      },
    },
  });
  engine.emit = () => {};
  engine.activeRuns.set('subagent-startup-parent', {
    userId,
    agentId: null,
    status: 'running',
    aborted: false,
    subagentDepth: 0,
    abortController: new AbortController(),
    toolPids: new Set(),
  });
  const spawn = engine.spawnSubagent(
    userId,
    'subagent-startup-parent',
    'Inspect the pending task.',
  );

  await recallStarted;
  const stopping = engine.shutdown({
    reason: 'shutdown while child startup was pending',
    timeoutMs: 1000,
  });
  releaseRecall();

  await assert.rejects(
    spawn,
    (error) => error.name === 'AbortError'
      && error.message === 'shutdown while child startup was pending',
  );
  assert.deepEqual(
    await stopping,
    { state: 'stopped', timedOut: false, pendingCount: 0 },
  );
  assert.equal(engine.subagentStartupTasks.size, 0);
  assert.equal(engine.subagents.size, 0);
  engine.activeRuns.delete('subagent-startup-parent');
});

test('parent cleanup waits for child shutdown and suppresses orphan rejection', async () => {
  const engine = new AgentEngine(null);
  let finishShutdown;
  const childShutdown = new Promise((resolve) => {
    finishShutdown = resolve;
  });
  const record = {
    handle: 'child-handle',
    parentRunId: 'parent-run',
    childRunId: 'child-run',
    userId,
    status: 'running',
    settled: false,
    promise: Promise.resolve(),
    engine: {
      shutdown: () => childShutdown,
    },
  };
  engine.emit = () => {};
  engine.subagents.set(record.handle, record);

  let cleanupSettled = false;
  const cleanup = engine.cleanupSubagentsForRun('parent-run').then((result) => {
    cleanupSettled = true;
    return result;
  });
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(cleanupSettled, false);
  assert.equal(record.status, 'cancelled');
  finishShutdown({ state: 'stopped', timedOut: false });

  assert.deepEqual(await cleanup, { cancelled: 1, timedOut: 0 });
});
