'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { OpenAICodexProvider } = require('../../../server/services/ai/providers/openaiCodex');

// api.openai.com is normalized to the ChatGPT Codex backend; the plain
// Responses API path is taken for any other base URL, such as a proxy.
function reasoningFor(model, reasoningEffort) {
  const provider = new OpenAICodexProvider({ apiKey: 'test-key', baseUrl: 'https://responses-proxy.example/v1' });
  const request = provider._buildRequest([{ role: 'user', content: 'hi' }], [], { reasoningEffort }, model);
  return request.reasoning;
}

test('Responses API requests carry reasoning effort only for reasoning models', () => {
  assert.deepEqual(reasoningFor('gpt-5', 'low'), { effort: 'low' });
  assert.equal(reasoningFor('gpt-4o', 'low'), undefined);
});

test('Codex reasoning survives the actual engine preparation path in chat and stream', async () => {
  const { requestModelResponse } = require('../../../server/services/ai/loop/model_io');
  const provider = new OpenAICodexProvider({ apiKey: 'dummy-key', baseUrl: 'https://responses-proxy.example/v1' });
  const reasoning = { type: 'reasoning', encrypted_content: 'dummy-encrypted-state', summary: [] };
  const messages = [
    { role: 'user', content: 'inspect fixture' },
    { role: 'assistant', content: '', reasoningState: { reasoningItems: [reasoning] }, tool_calls: [{ id: 'c1', type: 'function', function: { name: 'read_file', arguments: '{}' } }] },
    { role: 'tool', tool_call_id: 'c1', content: 'fixture' },
  ];
  const requests = [];
  const response = { output: [reasoning, { type: 'function_call', call_id: 'c2', name: 'read_file', arguments: '{}' }] };
  provider.client = { responses: { async create(request) {
    requests.push(request);
    return request.stream ? (async function* () { yield { type: 'response.completed', response }; })() : response;
  } } };
  const engine = { emit() {}, getReasoningEffort: () => undefined };
  for (const stream of [false, true]) {
    const result = await requestModelResponse(engine, { provider, providerName: 'openai_codex', model: 'gpt-5', messages, tools: [], options: { stream }, iteration: 1 });
    assert.ok(requests.at(-1).input.some((item) => item.encrypted_content === reasoning.encrypted_content));
    assert.equal(result.response.reasoningState.reasoningItems[0].encrypted_content, reasoning.encrypted_content);
  }
});
