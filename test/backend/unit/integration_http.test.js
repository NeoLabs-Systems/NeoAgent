'use strict';

const assert = require('node:assert/strict');
const { afterEach, test } = require('node:test');

const {
  fetchResponseText,
  waitForBoundedResult,
} = require('../../../server/services/integrations/http');
const {
  fetchJson,
} = require('../../../server/services/integrations/oauth_provider');

const originalFetch = global.fetch;

afterEach(() => {
  global.fetch = originalFetch;
});

test('integration HTTP requests forward caller cancellation and preserve its reason', async () => {
  const controller = new AbortController();
  let capturedSignal = null;
  global.fetch = (_url, options) => {
    capturedSignal = options.signal;
    return new Promise((resolve, reject) => {
      options.signal.addEventListener('abort', () => reject(options.signal.reason), {
        once: true,
      });
    });
  };

  const pending = fetchJson(
    'https://integration.example.test/resource',
    { signal: controller.signal },
    { serviceName: 'Example' },
  );
  await new Promise((resolve) => setImmediate(resolve));
  assert.ok(capturedSignal);
  assert.notEqual(capturedSignal, controller.signal);

  const reason = new Error('run stopped');
  controller.abort(reason);
  await assert.rejects(pending, (error) => error === reason);
  assert.equal(capturedSignal.aborted, true);
});

test('integration HTTP timeout settles even when fetch ignores AbortSignal', async () => {
  global.fetch = () => new Promise(() => {});

  await assert.rejects(
    fetchResponseText(
      'https://integration.example.test/resource',
      { timeoutMs: 10 },
      { serviceName: 'Example' },
    ),
    (error) => {
      assert.equal(error.code, 'INTEGRATION_HTTP_TIMEOUT');
      assert.match(error.message, /Example request timed out after 10ms/);
      return true;
    },
  );
});

test('integration HTTP cancellation closes a non-cooperative response reader', async () => {
  const controller = new AbortController();
  const reason = new Error('response no longer needed');
  let cancelCalled = false;
  global.fetch = async () => ({
    headers: { get: () => null },
    body: {
      getReader() {
        return {
          read: () => new Promise(() => {}),
          cancel: async () => {
            cancelCalled = true;
          },
          releaseLock() {},
        };
      },
    },
  });

  const pending = fetchResponseText(
    'https://integration.example.test/stream',
    { signal: controller.signal },
    { serviceName: 'Example' },
  );
  await new Promise((resolve) => setImmediate(resolve));
  controller.abort(reason);

  await assert.rejects(pending, (error) => error === reason);
  assert.equal(cancelCalled, true);
});

test('bounded integration waits settle even when a third-party SDK never does', async () => {
  await assert.rejects(
    waitForBoundedResult(new Promise(() => {}), {
      timeoutMs: 10,
      serviceName: 'SDK operation',
    }),
    (error) => {
      assert.equal(error.code, 'INTEGRATION_HTTP_TIMEOUT');
      assert.match(error.message, /SDK operation request timed out after 10ms/);
      return true;
    },
  );
});

test('integration HTTP responses are bounded before JSON parsing', async () => {
  global.fetch = async () => ({
    headers: { get: () => null },
    text: async () => 'response-body-too-large',
  });

  await assert.rejects(
    fetchResponseText(
      'https://integration.example.test/resource',
      { maxResponseBytes: 8 },
      { serviceName: 'Example' },
    ),
    (error) => {
      assert.equal(error.code, 'INTEGRATION_RESPONSE_TOO_LARGE');
      return true;
    },
  );
});

test('fetchJson keeps Slack-style ok=false responses as failures', async () => {
  global.fetch = async () => ({
    ok: true,
    status: 200,
    statusText: 'OK',
    headers: { get: () => null },
    text: async () => JSON.stringify({ ok: false, error: 'invalid_auth' }),
  });

  await assert.rejects(
    fetchJson(
      'https://slack.example.test/api',
      {},
      { serviceName: 'Slack' },
    ),
    /Slack request failed: invalid_auth/,
  );
});

test('fetchJson retries a throttled read after Retry-After and then succeeds', async () => {
  let calls = 0;
  global.fetch = async () => {
    calls += 1;
    if (calls === 1) {
      return {
        ok: false,
        status: 429,
        statusText: 'Too Many Requests',
        headers: { get: (name) => name.toLowerCase() === 'retry-after' ? '0' : null },
        text: async () => JSON.stringify({ error: 'rate_limited' }),
      };
    }
    return {
      ok: true,
      status: 200,
      statusText: 'OK',
      headers: { get: () => null },
      text: async () => JSON.stringify({ value: 'ready' }),
    };
  };

  assert.deepEqual(
    await fetchJson(
      'https://integration.example.test/resource',
      {},
      { serviceName: 'Example' },
    ),
    { value: 'ready' },
  );
  assert.equal(calls, 2);
});

test('fetchJson never automatically retries a failed write', async () => {
  let calls = 0;
  global.fetch = async () => {
    calls += 1;
    return {
      ok: false,
      status: 503,
      statusText: 'Service Unavailable',
      headers: { get: () => null },
      text: async () => JSON.stringify({ error: 'unavailable' }),
    };
  };

  await assert.rejects(
    fetchJson(
      'https://integration.example.test/resource',
      { method: 'POST', json: { value: 1 } },
      { serviceName: 'Example' },
    ),
    /unavailable/,
  );
  assert.equal(calls, 1);
});

test('fetchJson aborts during a server-requested retry delay', async () => {
  let calls = 0;
  global.fetch = async () => {
    calls += 1;
    return {
      ok: false,
      status: 429,
      statusText: 'Too Many Requests',
      headers: { get: (name) => name.toLowerCase() === 'retry-after' ? '5' : null },
      text: async () => JSON.stringify({ error: 'rate_limited' }),
    };
  };
  const controller = new AbortController();
  const pending = fetchJson(
    'https://integration.example.test/resource',
    { signal: controller.signal },
    { serviceName: 'Example' },
  );
  await new Promise((resolve) => setImmediate(resolve));

  const reason = new Error('tool stopped');
  controller.abort(reason);
  await assert.rejects(pending, (error) => error === reason);
  assert.equal(calls, 1);
});
