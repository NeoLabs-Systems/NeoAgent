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
