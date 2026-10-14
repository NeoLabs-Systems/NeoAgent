'use strict';

const assert = require('node:assert/strict');
const { after, before, describe, test } = require('node:test');

const { createTestRuntime, teardownTestRuntime } = require('../../helpers/db');

function released(isoDate) {
  return Date.parse(`${isoDate}T00:00:00Z`);
}

function model(modelId, priceTier, createdAt, extra = {}) {
  return {
    id: `openai::${modelId}`,
    modelId,
    provider: 'openai',
    priceTier,
    createdAt,
    available: true,
    ...extra,
  };
}

// Shaped like a live catalog: the current generation names its small model
// without any "mini"/"nano" marker, while older generations still carry one.
const CATALOG = [
  model('gpt-4o', 'medium', released('2024-05-10')),
  model('o3', 'medium', released('2025-04-16')),
  model('gpt-5.4-mini', 'cheap', released('2026-03-14')),
  model('gpt-5.4-nano', 'cheap', released('2026-03-14')),
  model('gpt-6-astra', 'expensive', released('2026-08-27')),
  model('gpt-6-luna', 'cheap', released('2026-09-14')),
  model('gpt-6.1-sol', 'medium', released('2026-09-27')),
];

describe('model router ranking', () => {
  let ctx;
  let rankModels;

  before(() => {
    ctx = createTestRuntime();
    ({ rankModels } = require('../../../server/services/ai/model_router'));
  });

  after(() => teardownTestRuntime(ctx));

  function pick(models, options = {}) {
    return rankModels(models, { settings: {}, ...options })[0]?.modelId;
  }

  test('main runs take the newest mid-priced model', () => {
    assert.equal(pick(CATALOG), 'gpt-6.1-sol');
    assert.equal(pick(CATALOG, { selectionHint: { purpose: 'planning' } }), 'gpt-6.1-sol');
  });

  test('sub-agents take the newest cheap model, whatever it is called', () => {
    assert.equal(pick(CATALOG, { isSubagent: true }), 'gpt-6-luna');
    assert.equal(pick(CATALOG, { selectionHint: { purpose: 'fast' } }), 'gpt-6-luna');
  });

  test('cost modes pick their class and still the newest within it', () => {
    assert.equal(pick(CATALOG, { selectionHint: { costMode: 'quality' } }), 'gpt-6-astra');
    assert.equal(pick(CATALOG, { settings: { cost_mode: 'economy' } }), 'gpt-6-luna');
  });

  test('older models of the class follow the current one as fallbacks', () => {
    const ranked = rankModels(CATALOG, { settings: {} }).map((entry) => entry.modelId);
    assert.deepEqual(ranked.slice(0, 3), ['gpt-6.1-sol', 'o3', 'gpt-4o']);
  });

  test('ranks models whose catalog rules out tool calls last', () => {
    const catalog = [
      ...CATALOG,
      model('chat-only-preview', 'medium', released('2026-09-30'), { supportsTools: false }),
    ];

    assert.equal(pick(catalog), 'gpt-6.1-sol');
    assert.equal(rankModels(catalog, { settings: {} }).at(-1).modelId, 'chat-only-preview');
  });

  test('without known prices the newest model wins', () => {
    const unpriced = CATALOG.map((entry) => ({ ...entry, priceTier: null }));

    assert.equal(pick(unpriced), 'gpt-6.1-sol');
    assert.equal(pick(unpriced, { isSubagent: true }), 'gpt-6.1-sol');
  });

  test('free and rate-limited models serve main runs only when nothing else is left', () => {
    const catalog = [
      model('vendor/newest:free', 'free', released('2026-09-30')),
      model('gpt-6.1-sol', 'medium', released('2026-09-27')),
    ];

    assert.equal(pick(catalog), 'gpt-6.1-sol');
    assert.equal(pick(catalog.slice(0, 1)), 'vendor/newest:free');
  });
});
