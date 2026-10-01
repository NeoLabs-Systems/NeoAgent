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

test('a model outside the provider plan is treated as unavailable, not fatal', () => {
  const error = Object.assign(new Error('400 The requested model is not supported.'), {
    status: 400,
    code: 'model_not_supported',
  });
  assert.equal(modelHealth.isPermanentModelFailure(error), true);
  assert.equal(modelHealth.shouldSwitchModel(error), true);
});

test('JSON-wrapped provider errors preserve their structured model status', () => {
  const error = new Error(JSON.stringify({
    error: {
      code: 404,
      status: 'NOT_FOUND',
      message: 'Unavailable selection.',
    },
  }));

  assert.equal(modelHealth.isPermanentModelFailure(error), true);
  assert.equal(
    modelHealth.recordModelFailure(userId, 'main', 'google::catalog-entry', error),
    true,
  );
  assert.equal(
    modelHealth.isModelCoolingDown(userId, 'main', 'google::catalog-entry'),
    true,
  );
});

test('a prefixed JSON provider error still preserves its structured status', () => {
  const error = new Error(`Google provider error: ${JSON.stringify({
    error: {
      code: 404,
      status: 'NOT_FOUND',
      message: 'This model is no longer available to new users.',
    },
  })}`);

  assert.equal(modelHealth.isPermanentModelFailure(error), true);
  assert.equal(
    modelHealth.recordModelFailure(userId, 'main', 'google::retired-entry', error),
    true,
  );
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

function httpError(status, message) {
  return Object.assign(new Error(message), { status });
}

test('a rate limit on an aggregator cools down only the model it hit', () => {
  const error = httpError(429, 'OpenRouter request failed: 429 Provider returned error');
  modelHealth.recordModelFailure(userId, 'main', 'openrouter::vendor/model:free', error);
  modelHealth.recordModelFailure(userId, 'main', 'openai::gpt-6.1-sol', httpError(429, 'Rate limit reached'));

  const health = modelHealth.getModelHealthSnapshot(userId, 'main');
  assert.equal(health.modelIds.has('openrouter::vendor/model:free'), true);
  assert.equal(health.providerIds.has('openrouter'), false);
  // A first-party provider's rate limit still covers the whole account.
  assert.equal(health.providerIds.has('openai'), true);
});

test('running out of credit pauses an aggregator\'s paid models and keeps its free ones', () => {
  const error = httpError(402, 'OpenRouter request failed: 402 Insufficient credits');
  assert.equal(modelHealth.shouldSwitchModel(error), true);
  modelHealth.recordModelFailure(userId, 'main', 'openrouter::vendor/paid-model', error);
  modelHealth.recordModelFailure(userId, 'main', 'openai::gpt-6.1-sol', httpError(402, 'Payment required'));
  // The cooldown is stored, not only held in memory.
  modelHealth.clearModelFailureCache();

  const health = modelHealth.getModelHealthSnapshot(userId, 'main');
  const openRouterModel = (modelId, priceTier) => ({
    id: `openrouter::${modelId}`,
    provider: 'openrouter',
    priceTier,
  });
  assert.equal(health.providerIds.has('openrouter'), false);
  assert.equal(modelHealth.isHealthBlocked(health, openRouterModel('vendor/other-paid', 'medium')), true);
  assert.equal(modelHealth.isHealthBlocked(health, openRouterModel('vendor/unpriced', null)), true);
  assert.equal(modelHealth.isHealthBlocked(health, openRouterModel('vendor/model:free', 'free')), false);
  assert.equal(health.providerIds.has('openai'), true);
  assert.match(
    modelHealth.describeModelCooldowns(userId, 'main', 'openrouter::vendor/other-paid')[0],
    /^paid models of provider openrouter provider_billing HTTP 402/,
  );
});
