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

test('a thinking model gets another model\'s tool calls as text, its own signed calls as parts', async () => {
  const http = require('../../../server/services/network/http');
  const originalFetchResponseText = http.fetchResponseText;
  const googlePath = require.resolve('../../../server/services/ai/providers/google');
  http.fetchResponseText = async () => ({
    response: { ok: true, status: 200, headers: {} },
    text: JSON.stringify({
      models: [{ name: 'models/gemini-3.5-flash-lite', supportedGenerationMethods: ['generateContent'], thinking: true }],
    }),
  });
  delete require.cache[googlePath];

  try {
    const { GoogleProvider: CatalogProvider } = require(googlePath);
    const provider = new CatalogProvider({ apiKey: 'test-key' });
    await provider.listModels();
    const messages = [
      { role: 'user', content: 'Bist du noch dabei?' },
      {
        role: 'assistant',
        content: '',
        tool_calls: [{ id: 'foreign-1', function: { name: 'background_task', arguments: '{"action":"status"}' } }],
      },
      { role: 'tool', name: 'background_task', tool_call_id: 'foreign-1', content: '{"background_tasks":[]}' },
      {
        role: 'assistant',
        content: '',
        tool_calls: [
          { id: 'own-1', function: { name: 'web_search', arguments: '{"q":"a"}', thought_signature: 'sig' } },
          { id: 'own-2', function: { name: 'web_search', arguments: '{"q":"b"}' } },
        ],
      },
      { role: 'tool', name: 'web_search', tool_call_id: 'own-1', content: 'a' },
      { role: 'tool', name: 'web_search', tool_call_id: 'own-2', content: 'b' },
    ];

    const { history } = provider.convertMessages(messages, 'gemini-3.5-flash-lite');
    const parts = history.flatMap((message) => message.parts);
    assert.equal(parts.some((part) => part.functionCall?.name === 'background_task'), false);
    assert.ok(parts.some((part) => part.text === '[Called background_task with {"action":"status"}]'));
    assert.ok(parts.some((part) => part.text === '[Result of background_task]\n{"background_tasks":[]}'));
    assert.deepEqual(
      parts.filter((part) => part.functionCall).map((part) => part.functionCall.id),
      ['own-1', 'own-2'],
    );
    assert.deepEqual(
      parts.filter((part) => part.functionResponse).map((part) => part.functionResponse.id),
      ['own-1', 'own-2'],
    );

    // A model that does not think keeps every call structured.
    const plain = provider.convertMessages(messages, 'gemini-test').history.flatMap((message) => message.parts);
    assert.ok(plain.some((part) => part.functionCall?.name === 'background_task'));
  } finally {
    http.fetchResponseText = originalFetchResponseText;
    delete require.cache[googlePath];
  }
});
