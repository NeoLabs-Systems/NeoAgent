'use strict';

const assert = require('node:assert/strict');
const { afterEach, test } = require('node:test');

const {
  clearModelFailureCache,
  isModelCoolingDown,
  isPermanentModelFailure,
  isRecoverableModelFailure,
  recordModelFailure,
  recordModelSuccess,
} = require('../../../server/services/ai/model_failure_cache');

afterEach(() => clearModelFailureCache());

test('404 model failures enter a bounded cooldown and successes clear it', () => {
  const error = Object.assign(new Error('NVIDIA NIM request failed: 404 status code'), {
    status: 404,
  });
  assert.equal(isPermanentModelFailure(error), true);
  assert.equal(recordModelFailure(7, 'main', 'nvidia::removed-model', error, 1_000), true);
  assert.equal(isModelCoolingDown(7, 'main', 'nvidia::removed-model', 1_001), true);
  assert.equal(recordModelSuccess(7, 'main', 'nvidia::removed-model'), true);
  assert.equal(isModelCoolingDown(7, 'main', 'nvidia::removed-model', 1_002), false);
});

test('request-shape failures do not quarantine a model', () => {
  const invalidRole = Object.assign(new Error("Role 'function' is not supported"), {
    status: 400,
  });

  assert.equal(recordModelFailure(7, 'main', 'google::gemini', invalidRole), false);
  assert.equal(isModelCoolingDown(7, 'main', 'google::gemini'), false);
});

test('an endpoint-specific unsupported model response quarantines that model', () => {
  const unsupported = Object.assign(new Error('The requested model is not supported.'), {
    status: 400,
  });

  assert.equal(isPermanentModelFailure(unsupported), true);
  assert.equal(recordModelFailure(7, 'main', 'copilot::unsupported', unsupported), true);
  assert.equal(isModelCoolingDown(7, 'main', 'copilot::unsupported'), true);
});

test('exhausted transient and empty-response failures enter a short cooldown', () => {
  const unavailable = Object.assign(new Error('service unavailable'), {
    status: 503,
  });
  const empty = Object.assign(new Error('Model returned an empty response.'), {
    code: 'MODEL_EMPTY_RESPONSE',
  });

  assert.equal(isRecoverableModelFailure(unavailable), true);
  assert.equal(recordModelFailure(7, 'main', 'google::gemini', unavailable, 1_000), true);
  assert.equal(isModelCoolingDown(7, 'main', 'google::gemini', 1_001), true);

  assert.equal(isRecoverableModelFailure(empty), true);
  assert.equal(recordModelFailure(7, 'main', 'openrouter::gemini', empty, 1_000), true);
  assert.equal(isModelCoolingDown(7, 'main', 'openrouter::gemini', 1_001), true);
});

test('provider retry-after extends the recovery cooldown without exceeding its cap', () => {
  const rateLimit = Object.assign(new Error('rate limit exceeded'), {
    status: 429,
    headers: { 'retry-after': '120' },
  });

  assert.equal(recordModelFailure(7, 'main', 'google::gemini', rateLimit, 1_000), true);
  assert.equal(isModelCoolingDown(7, 'main', 'google::gemini', 120_999), true);
  assert.equal(isModelCoolingDown(7, 'main', 'google::gemini', 121_001), false);
});
