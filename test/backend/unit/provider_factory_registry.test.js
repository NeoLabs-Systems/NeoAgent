'use strict';

const assert = require('node:assert/strict');
const { after, before, test } = require('node:test');

const { createTestRuntime, teardownTestRuntime } = require('../../helpers/db');

let ctx;
let AI_PROVIDER_DEFINITIONS;
let PROVIDER_FACTORIES;
let createProviderInstance;

before(() => {
  ctx = createTestRuntime();
  ({ AI_PROVIDER_DEFINITIONS, PROVIDER_FACTORIES, createProviderInstance } = require('../../../server/services/ai/models'));
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

test('createProviderInstance rejects unknown providers before touching runtime config', () => {
  assert.throws(
    () => createProviderInstance('does-not-exist', null, {}),
    /Unknown provider: does-not-exist/,
  );
});
