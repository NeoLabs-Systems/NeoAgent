'use strict';

const assert = require('node:assert/strict');
const { after, before, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

let ctx;
let userId;
let capture;
let inspector;

before(async () => {
  ctx = createTestRuntime();
  userId = (await createTestUser(ctx.db, { username: 'prompt_inspector_user' })).userId;
  capture = require('../../../server/services/ai/runtime/run_capture');
  inspector = require('../../../server/services/ai/runtime/prompt_inspector');
});

after(() => teardownTestRuntime(ctx));

function insertRun(runId) {
  ctx.db.prepare(
    `INSERT INTO agent_runs (
      id, user_id, title, status, runtime_state, trigger_type, trigger_source, model
    ) VALUES (?, ?, 'prompt inspector', 'running', 'executing', 'user', 'web', 'test/model')`,
  ).run(runId, userId);
}

function recordTurn(runId, iteration, messages) {
  return capture.captureRequest({ capture: { enabled: true, reason: 'requested', ttlHours: 24 } }, {
    runId,
    userId,
    phase: 'model_turn',
    iteration,
    provider: 'test',
    model: 'test-model',
    messages,
    tools: [{ name: 'lookup', description: 'Look things up\nsecond line' }],
    maxTokens: 800,
  });
}

test('prompt inspector lists every captured turn of a run', () => {
  const runId = 'prompt-inspector-list';
  insertRun(runId);
  recordTurn(runId, 1, [{ role: 'user', content: 'first' }]);
  const second = recordTurn(runId, 2, [{ role: 'user', content: 'second' }]);

  const turns = inspector.listRunPromptTurns(runId);
  assert.equal(turns.length, 2);
  assert.equal(turns[0].iteration, 1);
  assert.equal(turns[1].requestId, second);
  assert.equal(turns[1].messageCount, 1);
  assert.equal(turns[1].toolCount, 1);
  assert.equal(turns[1].characters, 'second'.length);
  assert.equal(turns[1].captureReason, 'requested');
});

test('prompt sections carry the whole input with derived labels', () => {
  const runId = 'prompt-inspector-sections';
  insertRun(runId);
  const requestId = recordTurn(runId, 1, [
    { role: 'system', content: 'You are NeoAgent.' },
    { role: 'system', content: '[Recalled context]\n- remembers the cat' },
    { role: 'user', content: [{ type: 'text', text: 'what is the cat called?' }] },
  ]);

  const prompt = inspector.getRunPromptTurn(runId, requestId);
  assert.deepEqual(
    prompt.sections.map((section) => section.label),
    ['System prompt', 'Recalled context', 'User message'],
  );
  assert.equal(prompt.sections[1].text, '[Recalled context]\n- remembers the cat');
  assert.equal(prompt.sections[2].text, 'what is the cat called?');
  assert.deepEqual(prompt.tools, [{ name: 'lookup', description: 'Look things up' }]);
});

test('private reasoning is never written to a capture', () => {
  const runId = 'prompt-inspector-reasoning';
  insertRun(runId);
  const requestId = recordTurn(runId, 1, [
    {
      role: 'assistant',
      content: '',
      tool_calls: [{ id: 'c1', type: 'function', function: { name: 'lookup', arguments: '{}' } }],
      reasoningState: { reasoning_content: 'SECRET REASONING' },
      providerContentBlocks: [{ type: 'thinking', thinking: 'SECRET THINKING', signature: 'sig' }],
    },
  ]);
  const stored = ctx.db.prepare('SELECT payload_json FROM agent_run_captures WHERE request_id = ?').get(requestId);
  assert.doesNotMatch(stored.payload_json, /SECRET/);
});

test('a run outside the sample keeps nothing, and expired captures are removed', () => {
  const runId = 'prompt-inspector-off';
  insertRun(runId);
  assert.equal(capture.captureRequest({ capture: { enabled: false } }, {
    runId,
    userId,
    messages: [{ role: 'user', content: 'nope' }],
  }), null);
  assert.deepEqual(inspector.listRunPromptTurns(runId), []);

  const expiredRun = 'prompt-inspector-expired';
  insertRun(expiredRun);
  recordTurn(expiredRun, 1, [{ role: 'user', content: 'old' }]);
  ctx.db.prepare("UPDATE agent_run_captures SET expires_at = datetime('now', '-1 hour') WHERE run_id = ?").run(expiredRun);
  assert.deepEqual(inspector.listRunPromptTurns(expiredRun), []);
  assert.ok(capture.pruneExpiredCaptures() >= 1);
  assert.equal(capture.hasCaptures(expiredRun), false);
});

test('capture is decided once: asked for, or marked for the next run', async () => {
  const agentId = require('../../../server/services/agents/manager').resolveAgentId(userId, null);
  assert.equal(capture.decideCapture({ userId, agentId }).enabled, false);
  assert.equal(capture.decideCapture({ userId, agentId, options: { captureContent: true } }).reason, 'requested');

  capture.requestCaptureNextRun(userId, agentId);
  assert.equal(capture.isCaptureNextRunRequested(userId, agentId), true);
  assert.equal(capture.decideCapture({ userId, agentId }).reason, 'capture_next');
  // The mark is used up by the run that took it.
  assert.equal(capture.decideCapture({ userId, agentId }).enabled, false);
});

test('prompts the old journal kept move to captures, and old runs stay inspectable', () => {
  const { moveJournaledPromptsToCaptures } = require('../../../lib/schema_migrations');
  const runId = 'prompt-inspector-journal';
  insertRun(runId);
  const request = {
    header: { phase: 'model_turn', iteration: 3, provider: 'test', model: 'test-model' },
    messages: [{ role: 'user', content: 'from before the upgrade' }],
    tools: [],
  };
  ctx.db.prepare(
    `INSERT INTO agent_run_events (run_id, user_id, event_type, request_id, sequence_index, payload_json)
     VALUES (?, ?, 'model.request_recorded', 'old-request', 1, ?)`,
  ).run(runId, userId, JSON.stringify({ request_id: 'old-request', digest: 'd', request }));

  moveJournaledPromptsToCaptures(ctx.db);
  moveJournaledPromptsToCaptures(ctx.db);

  assert.equal(ctx.db.prepare(
    "SELECT COUNT(*) AS n FROM agent_run_events WHERE run_id = ? AND event_type = 'model.request_recorded'",
  ).get(runId).n, 0);
  const [turn] = inspector.listRunPromptTurns(runId);
  assert.equal(turn.requestId, 'old-request');
  assert.equal(turn.iteration, 3);
  assert.equal(turn.captureReason, 'journal');
  assert.equal(inspector.getRunPromptTurn(runId, 'old-request').sections[0].text, 'from before the upgrade');
});
