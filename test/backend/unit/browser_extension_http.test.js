'use strict';

const assert = require('node:assert/strict');
const path = require('node:path');
const { test } = require('node:test');
const { pathToFileURL } = require('node:url');

async function extensionHttp() {
  return import(pathToFileURL(path.resolve(
    __dirname,
    '../../../extensions/chrome-browser/http.mjs',
  )).href);
}

test('extension HTTP helper parses bounded JSON responses', async () => {
  const { fetchJsonWithTimeout } = await extensionHttp();
  const result = await fetchJsonWithTimeout('https://neoagent.example.test/status', {}, {
    fetchImpl: async () => new Response(JSON.stringify({ ready: true }), { status: 200 }),
  });

  assert.equal(result.response.status, 200);
  assert.deepEqual(result.payload, { ready: true });
});

test('extension HTTP helper cancels oversized response streams', async () => {
  const { readJsonResponse } = await extensionHttp();
  let cancelled = false;
  const chunks = [new Uint8Array(5), new Uint8Array(5)];
  const response = {
    headers: { get: () => null },
    body: {
      getReader() {
        return {
          async read() {
            if (chunks.length === 0) return { done: true };
            return { done: false, value: chunks.shift() };
          },
          async cancel() { cancelled = true; },
          releaseLock() {},
        };
      },
    },
  };

  await assert.rejects(
    readJsonResponse(response, { maxResponseBytes: 8 }),
    (error) => error.code === 'EXTENSION_RESPONSE_TOO_LARGE',
  );
  assert.equal(cancelled, true);
});

test('extension HTTP timeout covers a stalled response body', async () => {
  const { fetchJsonWithTimeout } = await extensionHttp();
  let cancelled = false;
  const fetchImpl = async () => ({
    headers: { get: () => null },
    body: {
      getReader() {
        return {
          read: () => new Promise(() => {}),
          async cancel() { cancelled = true; },
          releaseLock() {},
        };
      },
    },
  });

  await assert.rejects(
    fetchJsonWithTimeout('https://neoagent.example.test/stalled', {}, {
      fetchImpl,
      timeoutMs: 10,
    }),
    (error) => error.code === 'EXTENSION_HTTP_TIMEOUT',
  );
  assert.equal(cancelled, true);
});

test('extension HTTP helper preserves caller cancellation reasons', async () => {
  const { fetchJsonWithTimeout } = await extensionHttp();
  const controller = new AbortController();
  const reason = new Error('extension operation stopped');
  let capturedSignal = null;
  const fetchImpl = (_url, options) => {
    capturedSignal = options.signal;
    return new Promise(() => {});
  };
  const pending = fetchJsonWithTimeout(
    'https://neoagent.example.test/status',
    { signal: controller.signal },
    { fetchImpl },
  );
  await new Promise((resolve) => setImmediate(resolve));
  controller.abort(reason);

  await assert.rejects(pending, (error) => error === reason);
  assert.ok(capturedSignal);
  assert.notEqual(capturedSignal, controller.signal);
  assert.equal(capturedSignal.aborted, true);
});
