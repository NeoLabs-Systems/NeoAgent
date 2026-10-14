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

test('pre-run recall hands over the direct search results without a model call', async () => {
  const engine = new AgentEngine(null);
  engine.requestStructuredJson = async () => {
    throw new Error('pre-run recall must not call a model');
  };
  engine.decide = async () => {
    throw new Error('pre-run recall must not call a model');
  };
  const searches = [];
  // Weak, close leaders: the kind of result that used to trigger an LLM
  // planning and rerank pass before the agent's first turn.
  const memoryManager = {
    recallMemory: async (_userId, query, limit) => {
      searches.push({ query, limit });
      return [
        { id: 'mem-a', content: 'a', score: 0.31 },
        { id: 'mem-b', content: 'b', score: 0.3 },
      ];
    },
    getPendingExtractionChunks: () => [],
    buildRecallMessage: async (_userId, _query, { recalled }) => `recall:${recalled.map((item) => item.id).join(',')}`,
  };

  const message = await engine.buildMemoryRecall({
    memoryManager,
    userId: 1,
    agentId: null,
    query: 'hey, alles gut bei dir?',
    provider: {},
    providerName: 'test',
    model: 'test-model',
    runId: null,
    options: { signal: new AbortController().signal },
  });

  assert.equal(message, 'recall:mem-a,mem-b');
  assert.deepEqual(searches, [{ query: 'hey, alles gut bei dir?', limit: 5 }]);
});
