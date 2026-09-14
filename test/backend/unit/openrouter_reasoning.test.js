'use strict';

const assert = require('node:assert/strict');
const { before, test } = require('node:test');

let OpenRouterProvider;

before(async () => {
  const httpPath = require.resolve('../../../server/services/network/http');
  require(httpPath);
  require.cache[httpPath].exports.fetchResponseText = async () => ({
    response: { ok: true, status: 200, headers: {} },
    text: JSON.stringify({
      data: [
        {
          id: 'openai/gpt-5.6-luna',
          context_length: 1050000,
          reasoning: { mandatory: false, default_enabled: true, supported_efforts: ['high', 'medium', 'low', 'none'] },
        },
        {
          id: 'anthropic/claude-sonnet',
          context_length: 200000,
          reasoning: { mandatory: false, default_enabled: false, supported_efforts: ['high', 'medium', 'low'] },
        },
        { id: 'openai/gpt-4o-mini', context_length: 128000 },
      ],
    }),
  });
  ({ OpenRouterProvider } = require('../../../server/services/ai/providers/openrouter'));
  await new OpenRouterProvider({ apiKey: 'test-key' }).listModels();
});

function paramsFor(model, reasoningEffort) {
  return new OpenRouterProvider({ apiKey: 'test-key' })
    ._buildParams(model, [{ role: 'user', content: 'hi' }], [], { reasoningEffort });
}

test('reasoning effort is sent to models that reason by default', () => {
  assert.deepEqual(paramsFor('openai/gpt-5.6-luna', 'low').reasoning, { effort: 'low' });
});

test('reasoning effort never switches thinking on for models where it is optional', () => {
  assert.equal(paramsFor('anthropic/claude-sonnet', 'low').reasoning, undefined);
  assert.equal(paramsFor('openai/gpt-4o-mini', 'low').reasoning, undefined);
});

test('unsupported or missing effort levels and uncatalogued models send nothing', () => {
  assert.equal(paramsFor('openai/gpt-5.6-luna', 'minimal').reasoning, undefined);
  assert.equal(paramsFor('openai/gpt-5.6-luna', undefined).reasoning, undefined);
  assert.equal(paramsFor('unknown/model', 'low').reasoning, undefined);
});
