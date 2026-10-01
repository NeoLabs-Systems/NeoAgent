'use strict';

const assert = require('node:assert/strict');
const { after, before, describe, test } = require('node:test');

const { createTestRuntime, teardownTestRuntime } = require('../../helpers/db');

const SECONDS_2026_09_27 = Date.parse('2026-09-27T00:00:00Z') / 1000;

function entry(id, prompt, created, parameters = ['tools']) {
  return { id, created, pricing: { prompt, completion: '0' }, supported_parameters: parameters };
}

describe('model reference catalog', () => {
  let ctx;
  let reference;
  let requests;
  let answer;

  before(() => {
    ctx = createTestRuntime();
    requests = [];
    const httpPath = require.resolve('../../../server/services/network/http');
    require(httpPath);
    require.cache[httpPath].exports.fetchResponseText = async (url) => {
      requests.push(url);
      return answer();
    };
    reference = require('../../../server/services/ai/model_reference');
  });

  after(() => teardownTestRuntime(ctx));

  test('keeps serving when the reference cannot be reached', async () => {
    answer = () => {
      throw new Error('offline');
    };

    await reference.refreshReferenceCatalog();
    assert.equal(requests.length, 1);
    assert.equal(reference.lookupModelFacts('gpt-6.1-sol'), null);
    assert.equal(reference.classifyPriceTier('gpt-6.1-sol'), null);
  });

  test('matches provider ids to the reference by name', () => {
    reference.recordReferenceModels([
      entry('openai/gpt-6.1-sol', '0.000002', SECONDS_2026_09_27),
      entry('openai/gpt-6-luna', '0.0000001', SECONDS_2026_09_27),
      entry('openai/gpt-6-luna:batch', '0.00000005', SECONDS_2026_09_27),
      entry('anthropic/claude-sonnet-4.5', '0.000003', SECONDS_2026_09_27),
      entry('vendor/chat-model:free', '0', SECONDS_2026_09_27, ['temperature']),
    ]);

    const sol = reference.lookupModelFacts('gpt-6.1-sol');
    assert.equal(sol.createdAt, SECONDS_2026_09_27 * 1000);
    assert.equal(sol.supportsTools, true);
    assert.equal(reference.classifyPriceTier('gpt-6.1-sol'), 'medium');
    // A dated snapshot is the same model as its alias.
    assert.equal(reference.classifyPriceTier('gpt-6.1-sol-2026-09-27'), 'medium');
    // Anthropic writes versions with dashes and appends a date.
    assert.equal(reference.classifyPriceTier('claude-sonnet-4-5-20250929'), 'medium');
    // The batch variant's discount is not the model's price.
    assert.ok(Math.abs(reference.getInputCostPerM('gpt-6-luna') - 0.1) < 1e-9);
    assert.equal(reference.classifyPriceTier('gpt-6-luna'), 'cheap');
    // OpenRouter's own variants are found by their full id.
    assert.equal(reference.classifyPriceTier('vendor/chat-model:free'), 'free');
    assert.equal(reference.lookupModelFacts('vendor/chat-model:free').supportsTools, false);
    assert.equal(reference.lookupModelFacts('chat-model'), null);
  });
});
