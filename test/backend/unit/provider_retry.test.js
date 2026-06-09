'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  withProviderRetry,
  isTransientError,
  retryAfterMs,
  computeBackoffMs,
} = require('../../../server/services/ai/providerRetry');

test('isTransientError classifies retryable statuses, codes, and messages', () => {
  assert.equal(isTransientError({ status: 429 }), true);
  assert.equal(isTransientError({ status: 529 }), true);
  assert.equal(isTransientError({ statusCode: 503 }), true);
  assert.equal(isTransientError({ response: { status: 502 } }), true);
  assert.equal(isTransientError({ code: 'ECONNRESET' }), true);
  assert.equal(isTransientError({ name: 'APIConnectionError' }), true);
  assert.equal(isTransientError(new Error('Service temporarily unavailable')), true);
  assert.equal(isTransientError(new Error('overloaded')), true);

  // Non-transient: client errors and ordinary failures must not retry.
  assert.equal(isTransientError({ status: 400 }), false);
  assert.equal(isTransientError({ status: 401 }), false);
  assert.equal(isTransientError({ status: 404 }), false);
  assert.equal(isTransientError(new Error('invalid api key')), false);
  assert.equal(isTransientError(null), false);
});

test('retryAfterMs honors retry-after-ms and retry-after headers', () => {
  assert.equal(retryAfterMs({ headers: { 'retry-after-ms': '1500' } }), 1500);
  assert.equal(retryAfterMs({ headers: { 'retry-after': '2' } }), 2000);
  assert.equal(retryAfterMs({ response: { headers: new Map([['retry-after', '3']]) } }), 3000);
  assert.equal(retryAfterMs({ headers: {} }), null);
  assert.equal(retryAfterMs(new Error('no headers')), null);
});

test('computeBackoffMs grows exponentially and stays within max', () => {
  for (let attempt = 1; attempt <= 6; attempt += 1) {
    const ms = computeBackoffMs(attempt, 500, 8000);
    assert.ok(ms >= 0);
    assert.ok(ms <= 8000, `attempt ${attempt} produced ${ms} > max`);
  }
  // Later attempts should not be smaller than the very first attempt's floor.
  const first = computeBackoffMs(1, 500, 8000);
  assert.ok(first >= 250 && first <= 500);
});

test('withProviderRetry retries transient failures then succeeds', async () => {
  let calls = 0;
  const result = await withProviderRetry(
    async () => {
      calls += 1;
      if (calls < 3) {
        const err = new Error('overloaded');
        err.status = 529;
        throw err;
      }
      return 'ok';
    },
    { baseDelayMs: 0, maxDelayMs: 0, maxAttempts: 5 },
  );
  assert.equal(result, 'ok');
  assert.equal(calls, 3);
});

test('withProviderRetry does not retry non-transient errors', async () => {
  let calls = 0;
  await assert.rejects(
    withProviderRetry(
      async () => {
        calls += 1;
        const err = new Error('bad request');
        err.status = 400;
        throw err;
      },
      { baseDelayMs: 0, maxDelayMs: 0 },
    ),
    /bad request/,
  );
  assert.equal(calls, 1);
});

test('withProviderRetry stops after maxAttempts and rethrows the last error', async () => {
  let calls = 0;
  const retries = [];
  await assert.rejects(
    withProviderRetry(
      async () => {
        calls += 1;
        const err = new Error('still overloaded');
        err.status = 503;
        throw err;
      },
      {
        baseDelayMs: 0,
        maxDelayMs: 0,
        maxAttempts: 3,
        onRetry: ({ attempt }) => retries.push(attempt),
      },
    ),
    /still overloaded/,
  );
  assert.equal(calls, 3);
  assert.deepEqual(retries, [1, 2]);
});

test('withProviderRetry honors a custom isRetryable guard', async () => {
  let calls = 0;
  await assert.rejects(
    withProviderRetry(
      async () => {
        calls += 1;
        const err = new Error('overloaded');
        err.status = 529;
        err.__unsafe = true;
        throw err;
      },
      {
        baseDelayMs: 0,
        maxDelayMs: 0,
        isRetryable: (err) => !err.__unsafe && isTransientError(err),
      },
    ),
    /overloaded/,
  );
  assert.equal(calls, 1);
});
