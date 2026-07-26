'use strict';

const assert = require('node:assert/strict');
const { describe, test } = require('node:test');

const {
  createModelSelectionId,
  modelMatchesConfiguredId,
  normalizeModelSelections,
  resolveModelSelection,
  toSelectableModel,
} = require('../../../server/services/ai/model_identity');

describe('model identity', () => {
  const models = [
    toSelectableModel({ id: 'gpt-5.3', provider: 'github-copilot' }),
    toSelectableModel({ id: 'gpt-5.3', provider: 'openai' }),
    toSelectableModel({ id: 'openai/gpt-5.3', provider: 'openrouter' }),
  ];

  test('creates provider-scoped ids without altering provider model slugs', () => {
    assert.equal(createModelSelectionId('OpenRouter', 'openai/gpt-5.3'), 'openrouter::openai/gpt-5.3');
    assert.deepEqual(models[2], {
      id: 'openrouter::openai/gpt-5.3',
      modelId: 'openai/gpt-5.3',
      provider: 'openrouter',
    });
  });

  test('resolves exact scoped selections before legacy raw ids', () => {
    assert.equal(resolveModelSelection(models, 'openai::gpt-5.3'), models[1]);
    assert.equal(resolveModelSelection(models, 'gpt-5.3'), models[0]);
    assert.equal(
      resolveModelSelection(models, 'gpt-5.3', { preferredProvider: 'openai' }),
      models[1],
    );
  });

  test('normalizes and deduplicates persisted legacy selections', () => {
    assert.deepEqual(
      normalizeModelSelections(models, ['gpt-5.3', 'github-copilot::gpt-5.3', 'missing']),
      ['github-copilot::gpt-5.3'],
    );
  });

  test('supports raw and scoped deployment allowlists during migration', () => {
    assert.equal(modelMatchesConfiguredId(models[1], new Set(['gpt-5.3'])), true);
    assert.equal(modelMatchesConfiguredId(models[1], new Set(['openai::gpt-5.3'])), true);
    assert.equal(modelMatchesConfiguredId(models[0], new Set(['openai::gpt-5.3'])), false);
  });
});
