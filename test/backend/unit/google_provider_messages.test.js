'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { GoogleProvider } = require('../../../server/services/ai/providers/google');

test('Google tool responses use supported user/model roles and preserve call ids', () => {
  const provider = new GoogleProvider({ apiKey: 'test-key' });
  const converted = provider.convertMessages([
    { role: 'user', content: 'Check the weather.' },
    {
      role: 'assistant',
      content: '',
      tool_calls: [{
        id: 'call-weather-1',
        function: {
          name: 'weather',
          arguments: '{"city":"Berlin"}',
        },
      }],
    },
    {
      role: 'tool',
      name: 'weather',
      tool_call_id: 'call-weather-1',
      content: '{"temperature":22}',
    },
  ]);

  assert.deepEqual(
    converted.history.map((message) => message.role),
    ['user', 'model', 'user'],
  );
  assert.equal(
    converted.history[2].parts[0].functionResponse.name,
    'weather',
  );
  assert.equal(
    converted.history[2].parts[0].functionResponse.id,
    'call-weather-1',
  );
  assert.equal(
    converted.history.some((message) => message.role === 'function'),
    false,
  );
});

test('Google chat sends full tool history through the current generateContent API', async () => {
  const provider = new GoogleProvider({ apiKey: 'test-key' });
  let request = null;
  provider.genAI = {
    models: {
      async generateContent(nextRequest) {
        request = nextRequest;
        return {
          candidates: [{
            content: { parts: [{ text: 'It is 22°C.' }] },
          }],
          usageMetadata: {
            promptTokenCount: 12,
            candidatesTokenCount: 5,
            totalTokenCount: 17,
          },
        };
      },
    },
  };

  const result = await provider.chat([
    { role: 'system', content: 'Be concise.' },
    { role: 'user', content: 'Check the weather.' },
    {
      role: 'assistant',
      content: '',
      tool_calls: [{
        id: 'call-weather-1',
        function: {
          name: 'weather',
          arguments: '{"city":"Berlin"}',
        },
      }],
    },
    {
      role: 'tool',
      name: 'weather',
      tool_call_id: 'call-weather-1',
      content: '{"temperature":22}',
    },
  ], [{
    name: 'weather',
    description: 'Read weather.',
    parameters: {
      type: 'object',
      properties: { city: { type: 'string' } },
    },
  }], {
    model: 'gemini-test',
    maxTokens: 123,
  });

  assert.equal(request.model, 'gemini-test');
  assert.equal(request.config.systemInstruction, 'Be concise.');
  assert.equal(request.config.maxOutputTokens, 123);
  assert.deepEqual(
    request.contents.map((message) => message.role),
    ['user', 'model', 'user'],
  );
  assert.equal(
    request.contents[2].parts[0].functionResponse.id,
    'call-weather-1',
  );
  assert.equal(
    request.config.tools[0].functionDeclarations[0].parametersJsonSchema.type,
    'object',
  );
  assert.equal(result.content, 'It is 22°C.');
  assert.equal(result.usage.totalTokens, 17);
});

test('Google system-only structured requests receive a user generation turn', async () => {
  const provider = new GoogleProvider({ apiKey: 'test-key' });
  let request = null;
  provider.genAI = {
    models: {
      async generateContent(nextRequest) {
        request = nextRequest;
        return {
          candidates: [{
            content: { parts: [{ text: '{"ok":true}' }] },
          }],
        };
      },
    },
  };

  const result = await provider.chat([
    { role: 'system', content: 'Return JSON only.' },
  ], [], { model: 'catalog-model' });

  assert.match(request.contents[0].parts[0].text, /requested response/i);
  assert.equal(request.config.systemInstruction, 'Return JSON only.');
  assert.equal(result.content, '{"ok":true}');
});

test('Google streaming ignores thought text and deduplicates repeated tool calls', async () => {
  const provider = new GoogleProvider({ apiKey: 'test-key' });
  provider.genAI = {
    models: {
      async generateContentStream() {
        return (async function* stream() {
          yield {
            candidates: [{
              content: {
                parts: [
                  { text: 'private reasoning', thought: true },
                  { text: 'Checking.' },
                  {
                    functionCall: {
                      id: 'call-weather-1',
                      name: 'weather',
                      args: { city: 'Berlin' },
                    },
                  },
                ],
              },
            }],
          };
          yield {
            candidates: [{
              content: {
                parts: [{
                  functionCall: {
                    id: 'call-weather-1',
                    name: 'weather',
                    args: { city: 'Berlin' },
                  },
                }],
              },
            }],
            usageMetadata: { totalTokenCount: 9 },
          };
        }());
      },
    },
  };

  const chunks = [];
  for await (const chunk of provider.stream([
    { role: 'user', content: 'Weather?' },
  ], [], { model: 'catalog-model' })) {
    chunks.push(chunk);
  }

  assert.deepEqual(
    chunks.filter((chunk) => chunk.type === 'content').map((chunk) => chunk.content),
    ['Checking.'],
  );
  const done = chunks.at(-1);
  assert.equal(done.toolCalls.length, 1);
  assert.equal(done.toolCalls[0].id, 'call-weather-1');
  assert.equal(done.usage.totalTokens, 9);
});
