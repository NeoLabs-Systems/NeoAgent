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

test('requestModelResponse rejects a terminal response with no text or tool calls', async () => {
  const engine = new AgentEngine(null);
  const provider = {
    async chat() {
      return {
        content: '',
        toolCalls: [],
        finishReason: 'stop',
        usage: { totalTokens: 100 },
      };
    },
  };

  await assert.rejects(
    engine.requestModelResponse({
      provider,
      providerName: 'test',
      model: 'test-model',
      messages: [{ role: 'user', content: 'Run the task.' }],
      tools: [],
      options: { stream: false, userId: 1 },
      runId: 'run-id',
      iteration: 1,
    }),
    (error) => error.code === 'MODEL_EMPTY_RESPONSE'
      && error.message === 'Model test-model returned an empty response.',
  );
});

test('requestModelResponse accepts text and tool-call responses', async () => {
  const engine = new AgentEngine(null);
  const textResult = await engine.requestModelResponse({
    provider: {
      async chat() {
        return { content: 'Done.', toolCalls: [], finishReason: 'stop' };
      },
    },
    providerName: 'test',
    model: 'test-model',
    messages: [{ role: 'user', content: 'Run the task.' }],
    tools: [],
    options: { stream: false, userId: 1 },
    runId: 'text-run',
    iteration: 1,
  });
  assert.equal(textResult.response.content, 'Done.');

  const toolResult = await engine.requestModelResponse({
    provider: {
      async chat() {
        return {
          content: '',
          toolCalls: [{
            id: 'call-id',
            type: 'function',
            function: { name: 'test_tool', arguments: '{}' },
          }],
          finishReason: 'tool_calls',
        };
      },
    },
    providerName: 'test',
    model: 'test-model',
    messages: [{ role: 'user', content: 'Run the task.' }],
    tools: [],
    options: { stream: false, userId: 1 },
    runId: 'tool-run',
    iteration: 1,
  });
  assert.equal(toolResult.response.toolCalls.length, 1);
});

test('requestModelResponse retries the same model on a transient failure', async () => {
  const engine = new AgentEngine(null);
  let calls = 0;
  const result = await engine.requestModelResponse({
    provider: {
      async chat() {
        calls += 1;
        if (calls === 1) {
          const err = new Error('overloaded');
          err.status = 529;
          throw err;
        }
        return { content: 'Recovered.', toolCalls: [], finishReason: 'stop' };
      },
    },
    providerName: 'test',
    model: 'test-model',
    messages: [{ role: 'user', content: 'Run the task.' }],
    tools: [],
    options: { stream: false, userId: 1, retry: { baseDelayMs: 0, maxDelayMs: 0 } },
    runId: 'retry-run',
    iteration: 1,
  });
  assert.equal(calls, 2);
  assert.equal(result.response.content, 'Recovered.');
});

test('requestModelResponse does not retry a non-transient failure', async () => {
  const engine = new AgentEngine(null);
  let calls = 0;
  await assert.rejects(
    engine.requestModelResponse({
      provider: {
        async chat() {
          calls += 1;
          const err = new Error('invalid request');
          err.status = 400;
          throw err;
        },
      },
      providerName: 'test',
      model: 'test-model',
      messages: [{ role: 'user', content: 'Run the task.' }],
      tools: [],
      options: { stream: false, userId: 1 },
      runId: 'no-retry-run',
      iteration: 1,
    }),
    /invalid request/,
  );
  assert.equal(calls, 1);
});

test('requestModelResponse does not retry once stream content has been emitted', async () => {
  const engine = new AgentEngine(null);
  let calls = 0;
  await assert.rejects(
    engine.requestModelResponse({
      provider: {
        async *stream() {
          calls += 1;
          yield { type: 'content', content: 'partial ' };
          const err = new Error('overloaded');
          err.status = 529;
          throw err;
        },
      },
      providerName: 'test',
      model: 'test-model',
      messages: [{ role: 'user', content: 'Run the task.' }],
      tools: [],
      options: { stream: true, userId: 1 },
      runId: 'stream-unsafe-run',
      iteration: 1,
    }),
    /overloaded/,
  );
  assert.equal(calls, 1);
});
