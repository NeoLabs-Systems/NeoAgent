'use strict';

const assert = require('node:assert/strict');
const { after, before, test } = require('node:test');

const { createTestRuntime, teardownTestRuntime } = require('../../helpers/db');

let ctx;
let AgentEngine;

before(() => {
  ctx = createTestRuntime();
  ({ AgentEngine } = require('../../../server/services/ai/engine'));
});

after(() => teardownTestRuntime(ctx));

// Two close, weak leaders make the direct retrieval ambiguous, which is what
// sends a query into enhanced recall.
const INITIAL = [
  { id: 'mem-a', content: 'a', score: 0.6, scoreBreakdown: { semantic: 0.5 } },
  { id: 'mem-b', content: 'b', score: 0.58, scoreBreakdown: { semantic: 0.5 } },
];

function memoryManager(recorded) {
  return {
    recallMemory: async () => INITIAL,
    getPendingExtractionChunks: () => [],
    getMemoryStats: () => ({ total: INITIAL.length }),
    recordRetrievalEnhancement: (_userId, entry) => recorded.push(entry),
    buildRecallMessage: async (_userId, _query, { recalled }) => `recall:${recalled.map((item) => item.id).join(',')}`,
  };
}

// A helper model call that never answers until its signal aborts.
function hangingEngine(onStarted) {
  const engine = new AgentEngine(null);
  engine.requestStructuredJson = ({ telemetry }) => new Promise((_, reject) => {
    onStarted();
    telemetry.signal.addEventListener('abort', () => {
      const error = new Error('aborted');
      error.name = 'AbortError';
      reject(error);
    }, { once: true });
  });
  return engine;
}

test('a stuck recall enhancement falls back to the direct results once its budget runs out', async (t) => {
  t.mock.timers.enable({ apis: ['setTimeout'] });
  const recorded = [];
  let started;
  const helperStarted = new Promise((resolve) => { started = resolve; });
  const engine = hangingEngine(() => started());

  const pending = engine.buildMemoryRecall({
    memoryManager: memoryManager(recorded),
    userId: 1,
    agentId: null,
    query: 'what did I say about the server',
    provider: {},
    providerName: 'test',
    model: 'test-model',
    runId: null,
    options: { signal: new AbortController().signal },
  });
  await helperStarted;
  t.mock.timers.tick(15_000);

  assert.equal(await pending, 'recall:mem-a,mem-b');
  assert.equal(recorded[0].plan, null);
});

test('a cancelled run still stops enhanced recall', async () => {
  const run = new AbortController();
  let started;
  const helperStarted = new Promise((resolve) => { started = resolve; });
  const engine = hangingEngine(() => started());

  const pending = engine.buildMemoryRecall({
    memoryManager: memoryManager([]),
    userId: 1,
    agentId: null,
    query: 'what did I say about the server',
    provider: {},
    providerName: 'test',
    model: 'test-model',
    runId: null,
    options: { signal: run.signal },
  });
  await helperStarted;
  run.abort();

  await assert.rejects(pending);
});
