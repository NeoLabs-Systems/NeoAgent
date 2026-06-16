'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { selectDeliverableWorkflow } = require('../../../server/services/ai/deliverables/selector');

test('deliverable selector falls back to standard when structured engine is unavailable', async () => {
  const result = await selectDeliverableWorkflow({
    engine: undefined,
    provider: {},
    providerName: 'test-provider',
    model: 'test-model',
    messages: [],
    tools: [],
  });

  assert.equal(result.selection.status, 'standard');
  assert.equal(result.selection.type, null);
  assert.equal(result.usage, 0);
  assert.equal(result.skipped, true);
  assert.equal(result.reason, 'structured selector unavailable');
});

test('deliverable selector falls back to standard when requestStructuredJson is missing', async () => {
  const result = await selectDeliverableWorkflow({
    engine: {},
    provider: {},
    providerName: 'test-provider',
    model: 'test-model',
    messages: [],
    tools: [],
  });

  assert.equal(result.selection.status, 'standard');
  assert.equal(result.selection.type, null);
  assert.equal(result.skipped, true);
});
