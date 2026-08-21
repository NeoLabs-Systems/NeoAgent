'use strict';

const assert = require('node:assert/strict');
const { after, before, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

let ctx;
let userId;
let journal;

before(async () => {
  ctx = createTestRuntime();
  userId = (await createTestUser(ctx.db, { username: 'request_journal_user' })).userId;
  journal = require('../../../server/services/ai/runtime/model_request_journal');
});

after(() => teardownTestRuntime(ctx));

function insertRun(runId) {
  ctx.db.prepare(
    `INSERT INTO agent_runs (
      id, user_id, title, status, runtime_state, trigger_type, trigger_source, model
    ) VALUES (?, ?, 'request journal', 'running', 'executing', 'user', 'web', 'test/model')`,
  ).run(runId, userId);
}

test('model requests reconstruct exactly from the durable event log', () => {
  const runId = 'request-journal-ok';
  insertRun(runId);
  const recorded = journal.recordModelRequest({
    runId,
    userId,
    phase: 'model_turn',
    iteration: 3,
    provider: 'test',
    model: 'test-model',
    messages: [{ role: 'user', content: 'hello' }],
    tools: [{ name: 'lookup', parameters: { type: 'object', properties: {} } }],
    maxTokens: 900,
  });

  const reconstructed = journal.reconstructModelRequest(runId, recorded.requestId);
  assert.equal(reconstructed.header.iteration, 3);
  assert.deepEqual(reconstructed.messages, [{ content: 'hello', role: 'user' }]);
  assert.equal(reconstructed.tools[0].name, 'lookup');
  assert.equal(Object.isFrozen(reconstructed), true);
  assert.equal(Object.isFrozen(reconstructed.messages), true);
});

test('request reconstruction fails loudly when durable request data changes', () => {
  const runId = 'request-journal-tamper';
  insertRun(runId);
  const recorded = journal.recordModelRequest({
    runId,
    userId,
    model: 'original-model',
    messages: [{ role: 'user', content: 'hello' }],
  });
  const row = ctx.db.prepare(
    `SELECT id, payload_json FROM agent_run_events
     WHERE run_id = ? AND request_id = ?`,
  ).get(runId, recorded.requestId);
  const payload = JSON.parse(row.payload_json);
  payload.request.header.model = 'changed-model';
  ctx.db.prepare('UPDATE agent_run_events SET payload_json = ? WHERE id = ?')
    .run(JSON.stringify(payload), row.id);

  assert.throws(
    () => journal.reconstructModelRequest(runId, recorded.requestId),
    (error) => error.code === 'MODEL_REQUEST_RECONSTRUCTION_MISMATCH',
  );
});

test('model I/O dispatches the request reconstructed from the durable log', async () => {
  const runId = 'request-journal-dispatch';
  insertRun(runId);
  const { requestModelResponse } = require('../../../server/services/ai/loop/model_io');
  let observed = null;
  const engine = {
    emit() {},
    getReasoningEffort: () => 'medium',
    getRunMeta: (candidateRunId) => candidateRunId === runId ? {} : null,
  };
  const result = await requestModelResponse(engine, {
    provider: {
      async chat(messages, tools, options) {
        observed = { messages, tools, options };
        return { content: 'done', toolCalls: [], usage: { total_tokens: 2 } };
      },
    },
    providerName: 'test',
    model: 'test-model',
    messages: [{ role: 'user', content: 'dispatch me' }],
    tools: [{ name: 'lookup', parameters: { type: 'object', properties: {} } }],
    options: { stream: false, runId, userId, maxTokens: 700 },
    runId,
    iteration: 1,
  });

  assert.equal(result.response.content, 'done');
  assert.equal(Object.isFrozen(observed.messages), true);
  assert.equal(Object.isFrozen(observed.tools), true);
  assert.equal(observed.options.model, 'test-model');
  const event = ctx.db.prepare(
    `SELECT request_id, payload_json FROM agent_run_events
     WHERE run_id = ? AND event_type = 'model.request_recorded'`,
  ).get(runId);
  assert.ok(event.request_id);
  const payload = JSON.parse(event.payload_json);
  assert.equal(payload.request.messages[0].content, 'dispatch me');
  assert.equal(payload.request.header.maxTokens, 700);
});
