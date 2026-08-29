'use strict';

const assert = require('node:assert/strict');
const { afterEach, beforeEach, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

let ctx;
let userId;
let modelHealth;

beforeEach(async () => {
  ctx = createTestRuntime();
  ({ userId } = await createTestUser(ctx.db));
  modelHealth = require('../../../server/services/ai/model_failure_cache');
});

afterEach(() => {
  modelHealth.clearModelFailureCache();
  teardownTestRuntime(ctx);
});

test('404 model failures enter a bounded cooldown and successes clear it', () => {
  const error = Object.assign(new Error('NVIDIA NIM request failed: 404 status code'), {
    status: 404,
  });
  assert.equal(modelHealth.isPermanentModelFailure(error), true);
  assert.equal(modelHealth.recordModelFailure(userId, 'main', 'nvidia::removed-model', error, 1_000), true);
  assert.equal(modelHealth.isModelCoolingDown(userId, 'main', 'nvidia::removed-model', 1_001), true);
  assert.equal(modelHealth.recordModelSuccess(userId, 'main', 'nvidia::removed-model'), true);
  assert.equal(modelHealth.isModelCoolingDown(userId, 'main', 'nvidia::removed-model', 1_002), false);
});

test('request-shape failures do not quarantine a model', () => {
  const invalidRole = Object.assign(new Error("Role 'function' is not supported"), {
    status: 400,
  });

  assert.equal(modelHealth.recordModelFailure(userId, 'main', 'google::gemini', invalidRole), false);
  assert.equal(modelHealth.isModelCoolingDown(userId, 'main', 'google::gemini'), false);
});

test('an endpoint-specific unsupported model response quarantines that model', () => {
  const unsupported = Object.assign(new Error('Provider rejected the selection.'), {
    status: 400,
    code: 'MODEL_UNSUPPORTED',
  });

  assert.equal(modelHealth.isPermanentModelFailure(unsupported), true);
  assert.equal(modelHealth.recordModelFailure(userId, 'main', 'copilot::unsupported', unsupported), true);
  assert.equal(modelHealth.isModelCoolingDown(userId, 'main', 'copilot::unsupported'), true);
});

test('message wording alone never decides model health', () => {
  const unstructured = Object.assign(new Error('The requested model is not supported.'), {
    status: 400,
  });

  assert.equal(modelHealth.recordModelFailure(userId, 'main', 'copilot::unsupported', unstructured), false);
  assert.equal(modelHealth.isModelCoolingDown(userId, 'main', 'copilot::unsupported'), false);
});

test('exhausted transient and empty-response failures enter a short cooldown', () => {
  const unavailable = Object.assign(new Error('service unavailable'), {
    status: 503,
  });
  const empty = Object.assign(new Error('Model returned an empty response.'), {
    code: 'MODEL_EMPTY_RESPONSE',
  });

  assert.equal(modelHealth.isRecoverableModelFailure(unavailable), true);
  assert.equal(modelHealth.recordModelFailure(userId, 'main', 'google::gemini', unavailable, 1_000), true);
  assert.equal(modelHealth.isModelCoolingDown(userId, 'main', 'google::gemini', 1_001), true);

  assert.equal(modelHealth.isRecoverableModelFailure(empty), true);
  assert.equal(modelHealth.recordModelFailure(userId, 'main', 'openrouter::gemini', empty, 1_000), true);
  assert.equal(modelHealth.isModelCoolingDown(userId, 'main', 'openrouter::gemini', 1_001), true);
});

test('provider retry-after extends the recovery cooldown without exceeding its cap', () => {
  const rateLimit = Object.assign(new Error('rate limit exceeded'), {
    status: 429,
    headers: { 'retry-after': '120' },
  });

  assert.equal(modelHealth.recordModelFailure(userId, 'main', 'google::gemini', rateLimit, 1_000), true);
  assert.equal(modelHealth.isModelCoolingDown(userId, 'main', 'google::gemini', 120_999), true);
  assert.equal(modelHealth.isModelCoolingDown(userId, 'main', 'google::gemini', 121_001), false);
});
