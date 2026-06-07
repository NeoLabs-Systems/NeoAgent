'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  normalizeCompletionConfidence,
  completionConfidenceRank,
  shouldAcceptTaskComplete,
} = require('../../../server/services/ai/completion');

test('normalizeCompletionConfidence clamps to known levels and defaults to medium', () => {
  assert.equal(normalizeCompletionConfidence('HIGH'), 'high');
  assert.equal(normalizeCompletionConfidence(' Low '), 'low');
  assert.equal(normalizeCompletionConfidence('medium'), 'medium');
  assert.equal(normalizeCompletionConfidence('nonsense'), 'medium');
  assert.equal(normalizeCompletionConfidence(null), 'medium');
});

test('completionConfidenceRank orders the levels', () => {
  assert.ok(completionConfidenceRank('high') > completionConfidenceRank('medium'));
  assert.ok(completionConfidenceRank('medium') > completionConfidenceRank('low'));
});

test('shouldAcceptTaskComplete accepts when confidence meets the requirement', () => {
  const decision = shouldAcceptTaskComplete({
    confidence: 'high',
    requiredConfidence: 'medium',
    iteration: 1,
    maxIterations: 10,
  });
  assert.equal(decision.accept, true);
  assert.equal(decision.reason, '');
});

test('shouldAcceptTaskComplete rejects low confidence early with guidance', () => {
  const decision = shouldAcceptTaskComplete({
    confidence: 'low',
    requiredConfidence: 'high',
    iteration: 1,
    maxIterations: 10,
  });
  assert.equal(decision.accept, false);
  assert.match(decision.reason, /below required/);
});

test('shouldAcceptTaskComplete accepts under-confidence at the iteration limit', () => {
  const decision = shouldAcceptTaskComplete({
    confidence: 'low',
    requiredConfidence: 'high',
    iteration: 10,
    maxIterations: 10,
  });
  assert.equal(decision.accept, true);
  assert.match(decision.reason, /iteration limit/);
});
