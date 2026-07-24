'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');
const supertest = require('supertest');

const { createTestApp } = require('../../helpers/app');
const { createTestRuntime, teardownTestRuntime } = require('../../helpers/db');

test('disabled billing probe returns an explicit non-error state', async () => {
  const ctx = createTestRuntime();
  const previous = process.env.NEOAGENT_BILLING_ENABLED;
  delete process.env.NEOAGENT_BILLING_ENABLED;

  try {
    const { app } = createTestApp();
    const response = await supertest(app).get('/api/billing/plans');

    assert.equal(response.statusCode, 200);
    assert.deepEqual(response.body, {
      enabled: false,
      plans: null,
    });
  } finally {
    if (previous === undefined) delete process.env.NEOAGENT_BILLING_ENABLED;
    else process.env.NEOAGENT_BILLING_ENABLED = previous;
    teardownTestRuntime(ctx);
  }
});
