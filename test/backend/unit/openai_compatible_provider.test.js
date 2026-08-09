'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { OpenAICompatibleProvider } = require('../../../server/services/ai/providers/openaiCompatible');
const { GrokProvider } = require('../../../server/services/ai/providers/grok');
const { NvidiaProvider } = require('../../../server/services/ai/providers/nvidia');
const { OpenAIProvider } = require('../../../server/services/ai/providers/openai');
const { CustomOpenAIProvider } = require('../../../server/services/ai/providers/openai_compatible_custom');

test('normalizeUsage maps snake_case and camelCase token fields and handles null', () => {
  const p = new OpenAICompatibleProvider();
  assert.equal(p.normalizeUsage(null), null);
  assert.deepEqual(
    p.normalizeUsage({ prompt_tokens: 10, completion_tokens: 5, total_tokens: 15 }),
    {
      inputTokens: 10,
      outputTokens: 5,
      reasoningTokens: 0,
      cachedReadTokens: 0,
      cacheWriteTokens: 0,
      promptTokens: 10,
      completionTokens: 5,
      totalTokens: 15,
    },
  );
  assert.deepEqual(
    p.normalizeUsage({ promptTokens: 3, completionTokens: 2, totalTokens: 5 }),
    {
      inputTokens: 3,
      outputTokens: 2,
      reasoningTokens: 0,
      cachedReadTokens: 0,
      cacheWriteTokens: 0,
      promptTokens: 3,
      completionTokens: 2,
      totalTokens: 5,
    },
  );
  assert.deepEqual(
    p.normalizeUsage({}),
    {
      inputTokens: 0,
      outputTokens: 0,
      reasoningTokens: 0,
      cachedReadTokens: 0,
      cacheWriteTokens: 0,
      promptTokens: 0,
      completionTokens: 0,
      totalTokens: 0,
    },
  );
});

test('normalizeResponse extracts content, tool calls, finish reason, and usage', () => {
  const p = new OpenAICompatibleProvider();
  const result = p.normalizeResponse({
    choices: [{
      message: {
        content: 'hi',
        tool_calls: [{ id: 'c1', function: { name: 'do_thing', arguments: '{"a":1}' } }],
      },
      finish_reason: 'tool_calls',
    }],
    usage: { prompt_tokens: 4, completion_tokens: 1, total_tokens: 5 },
  });
  assert.equal(result.content, 'hi');
  assert.equal(result.finishReason, 'tool_calls');
  assert.deepEqual(result.toolCalls, [{
    id: 'c1', type: 'function', function: { name: 'do_thing', arguments: '{"a":1}' },
  }]);
  assert.deepEqual(result.usage, {
    inputTokens: 4,
    outputTokens: 1,
    reasoningTokens: 0,
    cachedReadTokens: 0,
    cacheWriteTokens: 0,
    promptTokens: 4,
    completionTokens: 1,
    totalTokens: 5,
  });
});

test('analyzeImage refuses providers without vision support', async () => {
  const p = new OpenAICompatibleProvider();
  p.name = 'test';
  await assert.rejects(p.analyzeImage({ imagePath: '/tmp/none.png' }), /does not support image analysis/);
});

test('real OpenAI-compatible providers inherit the shared helpers', () => {
  const grok = new GrokProvider({ apiKey: 'test' });
  const nvidia = new NvidiaProvider({ apiKey: 'test' });
  const openai = new OpenAIProvider({ apiKey: 'test' });
  const custom = new CustomOpenAIProvider({
    apiKey: 'test',
    baseUrl: 'https://models.example.test/v1',
  });

  // Shared methods are present on every subclass.
  for (const provider of [grok, nvidia, openai, custom]) {
    assert.equal(typeof provider.normalizeUsage, 'function');
    assert.equal(typeof provider.normalizeResponse, 'function');
    assert.equal(typeof provider.analyzeImage, 'function');
  }

  // Vision capability is preserved per provider: grok/openai support it, nvidia does not.
  assert.equal(grok.supportsVision(), true);
  assert.equal(openai.supportsVision(), true);
  assert.equal(nvidia.supportsVision(), false);
});

test('custom provider uses standard Chat Completions parameters', () => {
  const provider = new CustomOpenAIProvider({
    apiKey: 'test',
    baseUrl: 'https://models.example.test/v1',
  });
  const params = provider._buildParams(
    'model-a',
    [{ role: 'user', content: 'hello' }],
    [{
      name: 'lookup',
      description: 'Look something up',
      parameters: { type: 'object', properties: {} },
    }],
    { maxTokens: 2048, temperature: 0.2 },
  );

  assert.equal(params.model, 'model-a');
  assert.equal(params.max_tokens, 2048);
  assert.equal(params.temperature, 0.2);
  assert.equal(params.tool_choice, 'auto');
  assert.equal(params.tools[0].function.name, 'lookup');
});

test('custom provider exposes every model reported by the endpoint', async () => {
  const provider = new CustomOpenAIProvider({
    apiKey: 'test',
    baseUrl: 'https://models.example.test/v1',
  });
  provider.client.models.list = async () => ({
    data: [{ id: 'chat-model' }, { id: 'vendor/special-model' }],
  });

  assert.deepEqual(await provider.listModels(), [
    { id: 'chat-model', name: 'chat-model' },
    { id: 'vendor/special-model', name: 'vendor/special-model' },
  ]);
});

test('custom provider assembles streamed tool calls', async () => {
  const provider = new CustomOpenAIProvider({
    apiKey: 'test',
    baseUrl: 'https://models.example.test/v1',
  });
  provider.client.chat.completions.create = async () => (async function* chunks() {
    yield {
      choices: [{
        delta: {
          tool_calls: [{
            index: 0,
            id: 'call-1',
            function: { name: 'look', arguments: '{"q":' },
          }],
        },
        finish_reason: null,
      }],
    };
    yield {
      choices: [{
        delta: {
          tool_calls: [{
            index: 0,
            function: { name: 'up', arguments: '"value"}' },
          }],
        },
        finish_reason: 'tool_calls',
      }],
    };
  }());

  const events = [];
  for await (const event of provider.stream([], [], { model: 'model-a' })) {
    events.push(event);
  }

  assert.deepEqual(events, [{
    type: 'tool_calls',
    toolCalls: [{
      id: 'call-1',
      type: 'function',
      function: { name: 'lookup', arguments: '{"q":"value"}' },
    }],
    content: '',
    usage: null,
  }]);
});

test('nvidia analyzeImage throws because it is not vision-capable', async () => {
  const nvidia = new NvidiaProvider({ apiKey: 'test' });
  await assert.rejects(nvidia.analyzeImage({ imagePath: '/tmp/none.png' }), /does not support image analysis/);
});
