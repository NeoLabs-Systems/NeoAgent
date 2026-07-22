'use strict';

const assert = require('node:assert/strict');
const http = require('node:http');
const { afterEach, test } = require('node:test');

const {
  executeHttpRequest,
  resolveHttpTarget,
} = require('../../../server/services/ai/integrated_tools/http_request');
const { executeSafeHttpRequest } = require('../../../server/services/network/safe_request');

const servers = [];

async function listen(handler) {
  const server = http.createServer(handler);
  servers.push(server);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  return server.address().port;
}

const localLookup = async () => [{ address: '127.0.0.1', family: 4 }];

afterEach(async () => {
  await Promise.all(servers.splice(0).map((server) => new Promise((resolve) => {
    server.closeAllConnections?.();
    server.close(resolve);
  })));
});

test('HTTP tool rejects DNS names resolving to private addresses by default', async () => {
  await assert.rejects(
    resolveHttpTarget('https://apparently-public.example/resource', {
      lookup: localLookup,
    }),
    /resolves to a private, loopback, or reserved address/,
  );
});

test('HTTP tool validates redirects and strips credentials across origins', async () => {
  let firstAuthorization = null;
  let redirectedAuthorization = null;
  let redirectedMethod = null;
  let redirectedContentType = null;
  const secondPort = await listen((request, response) => {
    redirectedAuthorization = request.headers.authorization || null;
    redirectedMethod = request.method;
    redirectedContentType = request.headers['content-type'] || null;
    response.writeHead(200, {
      'content-type': 'text/plain',
      'set-cookie': 'session=secret',
    });
    response.end('redirect complete');
  });
  const firstPort = await listen((request, response) => {
    firstAuthorization = request.headers.authorization || null;
    response.writeHead(302, {
      location: `http://second.example:${secondPort}/finish`,
    });
    response.end();
  });

  const result = await executeHttpRequest({
    url: `http://first.example:${firstPort}/start`,
    method: 'POST',
    headers: { Authorization: 'Bearer private-token' },
    body: '{"run":true}',
  }, {
    allowPrivate: true,
    lookup: localLookup,
  });

  assert.equal(firstAuthorization, 'Bearer private-token');
  assert.equal(redirectedAuthorization, null);
  assert.equal(redirectedMethod, 'GET');
  assert.equal(redirectedContentType, null);
  assert.equal(result.status, 200);
  assert.equal(result.body, 'redirect complete');
  assert.equal(result.headers['set-cookie'], undefined);
  assert.deepEqual(result.redirects, [`http://second.example:${secondPort}/finish`]);
});

test('HTTP tool cancels a live request with the caller reason', async () => {
  let markRequestArrived;
  const requestArrived = new Promise((resolve) => {
    markRequestArrived = resolve;
  });
  const port = await listen((_request, _response) => markRequestArrived());
  const controller = new AbortController();
  const pending = executeHttpRequest({
    url: `http://cancel.example:${port}/wait`,
  }, {
    allowPrivate: true,
    lookup: localLookup,
    signal: controller.signal,
  });
  await requestArrived;

  const reason = new Error('agent run stopped');
  controller.abort(reason);
  await assert.rejects(pending, (error) => error === reason);
});

test('HTTP tool bounds and actively truncates oversized response bodies', async () => {
  const port = await listen((_request, response) => {
    response.writeHead(200, { 'content-type': 'text/plain' });
    response.end('1234567890abcdef');
  });

  const result = await executeHttpRequest({
    url: `http://large.example:${port}/large`,
  }, {
    allowPrivate: true,
    lookup: localLookup,
    maxResponseBytes: 8,
  });

  assert.equal(result.truncated, true);
  assert.equal(result.body, '12345678\n...[truncated at response safety limit]');
});

test('HTTP tool timeout is distinct from caller cancellation', async () => {
  let markRequestArrived;
  const requestArrived = new Promise((resolve) => {
    markRequestArrived = resolve;
  });
  const port = await listen((_request, _response) => markRequestArrived());

  const pending = executeHttpRequest({
      url: `http://timeout.example:${port}/wait`,
      timeout_ms: 100,
  }, {
    allowPrivate: true,
    lookup: localLookup,
  });
  await requestArrived;
  await assert.rejects(
    pending,
    (error) => error.code === 'HTTP_REQUEST_TIMEOUT',
  );
});

test('shared safe requester can preserve binary response bodies', async () => {
  const payload = Buffer.from([0, 255, 16, 128, 42]);
  const port = await listen((_request, response) => {
    response.writeHead(200, { 'content-type': 'application/octet-stream' });
    response.end(payload);
  });

  const result = await executeSafeHttpRequest({
    url: `http://binary.example:${port}/asset`,
  }, {
    allowPrivate: true,
    lookup: localLookup,
    responseType: 'buffer',
  });

  assert.ok(Buffer.isBuffer(result.body));
  assert.deepEqual(result.body, payload);
});
