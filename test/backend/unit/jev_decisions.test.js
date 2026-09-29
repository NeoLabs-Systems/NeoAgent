'use strict';

const assert = require('node:assert/strict');
const { after, before, test } = require('node:test');

const { createTestRuntime, teardownTestRuntime } = require('../../helpers/db');

let ctx;
let retrieval;
let AgentEngine;

before(() => {
  ctx = createTestRuntime();
  retrieval = require('../../../server/services/memory/retrieval_reasoning');
  ({ AgentEngine } = require('../../../server/services/ai/engine'));
});

after(() => teardownTestRuntime(ctx));

function noul(value) {
  return { type: 'noul', noul: value };
}

test('memory reranking orders candidates by Jev relevance and keeps the rest after them', () => {
  const candidates = [
    { id: 'pasta', content: 'User likes spicy pasta.' },
    { id: 'birthday', content: 'User\'s sister Lena was born on 14 March 1994.' },
    { id: 'party', content: 'User planned a party for Lena in March.' },
  ];
  const judged = candidates.slice(0, 2);
  const { questions } = retrieval.buildRerankDecision('When is my sister\'s birthday?', judged);
  assert.deepEqual(Object.keys(questions), ['candidate_0', 'candidate_1']);

  const reranked = retrieval.rerankFromDecision({
    candidate_0: noul(0.01),
    candidate_1: noul(0.97),
  }, candidates, judged);
  assert.deepEqual(reranked.map((candidate) => candidate.id), ['birthday', 'pasta', 'party']);
});

test('enhanced recall uses Jev for the rerank and the model only for the plan', async () => {
  const INITIAL = [
    { id: 'mem-a', content: 'a', score: 0.6, scoreBreakdown: { semantic: 0.5 } },
    { id: 'mem-b', content: 'b', score: 0.58, scoreBreakdown: { semantic: 0.5 } },
  ];
  const engine = new AgentEngine(null);
  const phases = [];
  engine.requestStructuredJson = async ({ phase, fallback }) => {
    phases.push(phase);
    return { value: fallback, parsed: true };
  };
  engine.decide = async ({ phase }) => {
    phases.push(phase);
    return { candidate_0: noul(0.1), candidate_1: noul(0.9) };
  };

  const message = await engine.buildMemoryRecall({
    memoryManager: {
      recallMemory: async () => INITIAL,
      getPendingExtractionChunks: () => [],
      getMemoryStats: () => ({ total: 2 }),
      recordRetrievalEnhancement: () => {},
      buildRecallMessage: async (_userId, _query, { recalled }) => recalled.map((item) => item.id).join(','),
    },
    userId: 1,
    agentId: null,
    query: 'what did I say about b',
    provider: {},
    providerName: 'test',
    model: 'test-model',
    runId: null,
    options: { signal: new AbortController().signal },
  });

  assert.deepEqual(phases, ['memory_retrieval_plan', 'jev_memory_rerank']);
  assert.equal(message, 'mem-b,mem-a');
});
