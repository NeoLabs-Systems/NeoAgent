'use strict';

const assert = require('node:assert/strict');
const { afterEach, test } = require('node:test');

const { resolveModelCallTimeoutMs } = require('../../../server/services/ai/loop/model_call_guard');

const original = process.env.NEOAGENT_MODEL_CALL_TIMEOUT_MS;

afterEach(() => {
  if (original === undefined) delete process.env.NEOAGENT_MODEL_CALL_TIMEOUT_MS;
  else process.env.NEOAGENT_MODEL_CALL_TIMEOUT_MS = original;
});

test('resolveModelCallTimeoutMs prefers an explicit option over the env default', () => {
  process.env.NEOAGENT_MODEL_CALL_TIMEOUT_MS = '900000';
  assert.equal(resolveModelCallTimeoutMs({ modelCallTimeoutMs: 15000 }), 15000);
  assert.equal(resolveModelCallTimeoutMs({}), 900000);
});
