'use strict';

const assert = require('node:assert/strict');
const { after, before, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

let ctx;
let AgentEngine;
let announceBackgroundRunEnded;
let buildBackgroundRunsNote;
let isBackgroundEligible;
let listBackgroundRuns;
let moveRunToBackground;

before(() => {
  ctx = createTestRuntime();
  ({ AgentEngine } = require('../../../server/services/ai/loop/agent_engine_core'));
  ({
    announceBackgroundRunEnded,
    buildBackgroundRunsNote,
    isBackgroundEligible,
    listBackgroundRuns,
    moveRunToBackground,
  } = require('../../../server/services/ai/loop/background_runs'));
});

after(() => teardownTestRuntime(ctx));

function createEngine() {
  const engine = new AgentEngine(null, {});
  engine.events = [];
  engine.emit = (userId, event, data) => engine.events.push({ userId, event, data });
  engine.persistRunMetadata = () => {};
  engine.recordRunEvent = () => {};
  engine.aborted = [];
  engine.abort = (runId, options) => {
    engine.aborted.push({ runId, options });
    return true;
  };
  return engine;
}

function addRun(engine, runId, overrides = {}) {
  engine.activeRuns.set(runId, {
    userId: 1,
    agentId: 'agent-1',
    status: 'running',
    aborted: false,
    triggerType: 'user',
    triggerSource: 'web',
    conversationId: 'conversation-1',
    request: `request for ${runId}`,
    startedAtIso: '2026-09-29T10:00:00.000Z',
    backgroundEligible: true,
    background: null,
    onBackground: null,
    steeringQueue: [],
    systemSteeringQueue: [],
    ...overrides,
  });
  return engine.activeRuns.get(runId);
}

test('only owner chat runs started by the user can move to the background', () => {
  assert.equal(isBackgroundEligible({ triggerType: 'user', triggerSource: 'web' }), true);
  assert.equal(isBackgroundEligible({ triggerType: 'user', triggerSource: 'messaging', memoryAudience: 'owner' }), true);
  assert.equal(isBackgroundEligible({ triggerType: 'user', triggerSource: 'messaging', memoryAudience: 'shared' }), false);
  assert.equal(isBackgroundEligible({ triggerType: 'user', triggerSource: 'voice_live' }), false);
  assert.equal(isBackgroundEligible({ triggerType: 'subagent', triggerSource: 'web' }), false);
});

test('a run moves to the background once and stops taking steering', () => {
  const engine = createEngine();
  let released = 0;
  const runMeta = addRun(engine, 'long-run', { onBackground: () => { released += 1; } });

  assert.equal(engine.findSteerableRunForUser(1, 'web')?.runId, 'long-run');
  assert.equal(moveRunToBackground(engine, 'long-run'), true);
  assert.equal(moveRunToBackground(engine, 'long-run'), false);

  assert.ok(runMeta.background.since);
  assert.equal(released, 1);
  assert.deepEqual(engine.events.map((entry) => entry.event), ['run:background']);
  assert.equal(engine.findSteerableRunForUser(1, 'web'), null);
});

test('visible progress moves an eligible run to the background', () => {
  const engine = createEngine();
  addRun(engine, 'long-run');
  addRun(engine, 'foreground-run', { backgroundEligible: false });

  engine.markRunVisibleProgress('long-run');
  engine.markRunVisibleProgress('foreground-run');

  assert.ok(engine.getRunMeta('long-run').background);
  assert.equal(engine.getRunMeta('foreground-run').background, null);
});

test('a run that already delivered its final answer stays in the foreground', () => {
  const engine = createEngine();
  addRun(engine, 'done-run', { finalDeliverySent: true });

  assert.equal(moveRunToBackground(engine, 'done-run'), false);
  assert.deepEqual(engine.events, []);
});

test('foreground runs see background work of the same agent only', async () => {
  const { userId } = await createTestUser(ctx.db, { username: 'background_steps_user' });
  ctx.db.prepare('INSERT INTO agent_runs (id, user_id, title, status) VALUES (?, ?, ?, ?)')
    .run('research', userId, 'research', 'running');
  ctx.db.prepare(
    `INSERT INTO agent_steps (id, run_id, step_index, type, description, status, tool_name, started_at)
     VALUES (?, ?, ?, 'tool', ?, ?, ?, datetime('now'))`,
  ).run('step-1', 'research', 1, 'web_search: {"query":"laptops"}', 'completed', 'web_search');
  ctx.db.prepare(
    `INSERT INTO agent_steps (id, run_id, step_index, type, description, status, tool_name, started_at)
     VALUES (?, ?, ?, 'tool', ?, ?, ?, datetime('now'))`,
  ).run('step-2', 'research', 2, 'browser_navigate: {"url":"https://example.com"}', 'running', 'browser_navigate');
  const engine = createEngine();
  addRun(engine, 'research', { background: { since: 'now' } });
  addRun(engine, 'other-agent', { agentId: 'agent-2', background: { since: 'now' } });
  addRun(engine, 'foreground');

  const runs = listBackgroundRuns(engine, { userId: 1, agentId: 'agent-1', excludeRunId: 'foreground' });
  assert.deepEqual(runs.map((run) => run.run_id), ['research']);
  assert.deepEqual(runs[0].recent_steps.map((step) => step.status), ['completed', 'running']);

  const note = buildBackgroundRunsNote(runs);
  assert.match(note, /run_id research/);
  assert.match(note, /request for research/);
  assert.match(note, /Latest step \(running\): browser_navigate/);
  assert.equal(buildBackgroundRunsNote([]), '');
});

test('background_task instructs and cancels background runs from the owner chat', () => {
  const engine = createEngine();
  addRun(engine, 'research', { background: { since: 'now' } });
  addRun(engine, 'foreground');
  addRun(engine, 'group-run', { backgroundEligible: false });

  const listed = engine.manageBackgroundRun('foreground', { action: 'status' });
  assert.deepEqual(listed.background_tasks.map((run) => run.run_id), ['research']);

  const instructed = engine.manageBackgroundRun('foreground', {
    action: 'instruct',
    run_id: 'research',
    instruction: 'Also compare prices in Austria.',
  });
  assert.equal(instructed.instructed, true);
  assert.match(engine.getRunMeta('research').systemSteeringQueue[0].content, /compare prices in Austria/);

  const cancelled = engine.manageBackgroundRun('foreground', { action: 'cancel', run_id: 'research' });
  assert.equal(cancelled.cancelled, true);
  assert.equal(engine.aborted[0].runId, 'research');
  assert.equal(engine.aborted[0].options.userId, 1);

  assert.match(engine.manageBackgroundRun('foreground', { action: 'cancel', run_id: 'missing' }).error, /No background task/);
  assert.match(engine.manageBackgroundRun('group-run', { action: 'status' }).error, /owner's own chat/);
});

test('an ended background run is announced to the running foreground runs', () => {
  const engine = createEngine();
  const ended = addRun(engine, 'research', {
    background: { since: 'now' },
    finalDeliverySent: true,
    lastSentMessage: 'Here is the comparison.',
  });
  addRun(engine, 'foreground');
  addRun(engine, 'other-background', { background: { since: 'now' } });
  engine.activeRuns.delete('research');

  announceBackgroundRunEnded(engine, 'research', ended);

  const foregroundQueue = engine.getRunMeta('foreground').systemSteeringQueue;
  assert.equal(foregroundQueue.length, 1);
  assert.match(foregroundQueue[0].content, /finished/);
  assert.match(foregroundQueue[0].content, /Here is the comparison\./);
  assert.equal(engine.getRunMeta('other-background').systemSteeringQueue.length, 0);
});
