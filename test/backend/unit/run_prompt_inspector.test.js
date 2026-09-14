'use strict';

const assert = require('node:assert/strict');
const { after, before, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

let ctx;
let userId;
let journal;
let inspector;
let runEvents;

before(async () => {
  ctx = createTestRuntime();
  userId = (await createTestUser(ctx.db, { username: 'prompt_inspector_user' })).userId;
  journal = require('../../../server/services/ai/runtime/model_request_journal');
  inspector = require('../../../server/services/ai/runtime/prompt_inspector');
  runEvents = require('../../../server/services/ai/runEvents');
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
  return journal.recordModelRequest({
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

test('prompt inspector lists every journaled turn of a run', () => {
  const runId = 'prompt-inspector-list';
  insertRun(runId);
  recordTurn(runId, 1, [{ role: 'user', content: 'first' }]);
  const second = recordTurn(runId, 2, [{ role: 'user', content: 'second' }]);

  const turns = inspector.listRunPromptTurns(runId);
  assert.equal(turns.length, 2);
  assert.equal(turns[0].iteration, 1);
  assert.equal(turns[1].requestId, second.requestId);
  assert.equal(turns[1].messageCount, 1);
  assert.equal(turns[1].toolCount, 1);
  assert.equal(turns[1].characters, 'second'.length);
});

test('prompt sections carry the whole input with derived labels', () => {
  const runId = 'prompt-inspector-sections';
  insertRun(runId);
  const recorded = recordTurn(runId, 1, [
    { role: 'system', content: 'You are NeoAgent.' },
    { role: 'system', content: '[Recalled context]\n- remembers the cat' },
    { role: 'user', content: [{ type: 'text', text: 'what is the cat called?' }] },
  ]);

  const prompt = inspector.getRunPromptTurn(runId, recorded.requestId);
  assert.deepEqual(
    prompt.sections.map((section) => section.label),
    ['System prompt', 'Recalled context', 'User message'],
  );
  assert.equal(prompt.sections[1].text, '[Recalled context]\n- remembers the cat');
  assert.equal(prompt.sections[2].text, 'what is the cat called?');
  assert.deepEqual(prompt.tools, [{ name: 'lookup', description: 'Look things up' }]);
});

test('run detail events omit the journaled request body', () => {
  const runId = 'prompt-inspector-strip';
  insertRun(runId);
  recordTurn(runId, 1, [{ role: 'user', content: 'heavy prompt' }]);

  const events = runEvents.listRunEvents(runId);
  const journaled = events.find((event) => event.eventType === 'model.request_recorded');
  assert.ok(journaled.payload.request_id);
  assert.ok(journaled.payload.digest);
  assert.equal(journaled.payload.request, undefined);
});
