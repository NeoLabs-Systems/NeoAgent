'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { isTransientError } = require('../../../server/services/ai/providerRetry');
const {
  sanitizeProviderErrorDetail,
  wrapProviderError,
} = require('../../../server/services/ai/providers/provider_error');

test('provider error wrapping preserves retry metadata and cause', () => {
  const original = new Error('overloaded');
  original.status = 529;
  original.code = 'provider_overloaded';
  original.headers = { 'retry-after': '2' };

  const wrapped = wrapProviderError(original, 'Remote model failed');

  assert.equal(wrapped.cause, original);
  assert.equal(wrapped.status, 529);
  assert.equal(wrapped.code, 'provider_overloaded');
  assert.equal(wrapped.headers, original.headers);
  assert.equal(isTransientError(wrapped), true);
});

test('provider error wrapping preserves caller cancellation identity', () => {
  const controller = new AbortController();
  const reason = new Error('run interrupted');
  controller.abort(reason);

  assert.equal(
    wrapProviderError(new Error('SDK abort wrapper'), 'Provider failed', {
      signal: controller.signal,
    }),
    reason,
  );
});

test('provider error details redact credentials and query keys', () => {
  const sanitized = sanitizeProviderErrorDetail(
    'Bearer secret-token https://api.example.test/models?key=private-key access_token=abc',
  );

  assert.doesNotMatch(sanitized, /secret-token|private-key|access_token=abc/);
  assert.match(sanitized, /Bearer \[redacted\]/);
});
