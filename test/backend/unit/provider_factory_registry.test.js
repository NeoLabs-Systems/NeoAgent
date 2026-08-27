'use strict';

const assert = require('node:assert/strict');
const { after, before, test } = require('node:test');

const { createTestRuntime, teardownTestRuntime } = require('../../helpers/db');

let ctx;
let AI_PROVIDER_DEFINITIONS;
let PROVIDER_FACTORIES;
let createProviderInstance;
let getProviderCatalog;

before(() => {
  ctx = createTestRuntime();
  ({
    AI_PROVIDER_DEFINITIONS,
    PROVIDER_FACTORIES,
    createProviderInstance,
    getProviderCatalog,
  } = require('../../../server/services/ai/models'));
});

after(() => teardownTestRuntime(ctx));

test('every provider definition has a matching factory and vice versa', () => {
  const definitionIds = Object.keys(AI_PROVIDER_DEFINITIONS).sort();
  const factoryIds = Object.keys(PROVIDER_FACTORIES).sort();
  assert.deepEqual(
    factoryIds,
    definitionIds,
    'PROVIDER_FACTORIES and AI_PROVIDER_DEFINITIONS must cover exactly the same provider ids',
  );
});

test('every factory exposes a constructable Provider class', () => {
  for (const [id, factory] of Object.entries(PROVIDER_FACTORIES)) {
    assert.equal(typeof factory.Provider, 'function', `factory ${id} must expose a Provider constructor`);
  }
});

test('every provider supports live model discovery', () => {
  for (const [id, factory] of Object.entries(PROVIDER_FACTORIES)) {
    assert.equal(
      typeof factory.Provider.prototype.listModels,
      'function',
      `factory ${id} must expose listModels()`,
    );
  }
});

test('createProviderInstance rejects unknown providers before touching runtime config', () => {
  assert.throws(
    () => createProviderInstance('does-not-exist', null, {}),
    /Unknown provider: does-not-exist/,
  );
});

test('custom OpenAI-compatible provider requires both environment values', () => {
  process.env.OPENAI_COMPATIBLE_API_KEY = 'custom-token';
  delete process.env.OPENAI_COMPATIBLE_BASE_URL;
  try {
    const incomplete = getProviderCatalog(null)
      .find((provider) => provider.id === 'openai-compatible');
    assert.equal(incomplete.available, false);
    assert.match(incomplete.availabilityReason, /base URL is required/i);
    assert.throws(
      () => createProviderInstance('openai-compatible'),
      /requires a base URL/i,
    );

    process.env.OPENAI_COMPATIBLE_BASE_URL = 'file:///tmp/models';
    const invalid = getProviderCatalog(null)
      .find((provider) => provider.id === 'openai-compatible');
    assert.equal(invalid.available, false);
    assert.throws(
      () => createProviderInstance('openai-compatible'),
      /valid HTTP or HTTPS base URL/i,
    );

    process.env.OPENAI_COMPATIBLE_BASE_URL = 'https://models.example.test/v1';
    const complete = getProviderCatalog(null)
      .find((provider) => provider.id === 'openai-compatible');
    assert.equal(complete.available, true);
    const instance = createProviderInstance('openai-compatible');
    assert.equal(instance.name, 'openai-compatible');
    assert.equal(instance.baseURL, 'https://models.example.test/v1');
  } finally {
    delete process.env.OPENAI_COMPATIBLE_API_KEY;
    delete process.env.OPENAI_COMPATIBLE_BASE_URL;
  }
});
