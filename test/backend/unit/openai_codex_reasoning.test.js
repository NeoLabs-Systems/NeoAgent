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
