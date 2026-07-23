'use strict';

const assert = require('node:assert/strict');
const { afterEach, test } = require('node:test');

const {
  clearModelFailureCache,
  isModelCoolingDown,
  isPermanentModelFailure,
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

test('request-shape and transient failures do not quarantine a model', () => {
  const invalidRole = Object.assign(new Error("Role 'function' is not supported"), {
    status: 400,
  });
  const timeout = Object.assign(new Error('request timed out'), {
    status: 503,
  });

  assert.equal(recordModelFailure(7, 'main', 'google::gemini', invalidRole), false);
  assert.equal(recordModelFailure(7, 'main', 'google::gemini', timeout), false);
  assert.equal(isModelCoolingDown(7, 'main', 'google::gemini'), false);
});
