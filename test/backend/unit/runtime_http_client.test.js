'use strict';

const assert = require('node:assert/strict');
const http = require('node:http');
const { afterEach, test } = require('node:test');

const {
  RuntimeHttpClient,
  VmBrowserProvider,
} = require('../../../server/services/runtime/backends/local-vm');

const servers = new Set();

afterEach(async () => {
  await Promise.allSettled(Array.from(servers, (server) => new Promise((resolve) => {
    server.closeAllConnections?.();
    server.close(resolve);
  })));
  servers.clear();
});

async function listen(handler) {
  const server = http.createServer(handler);
  servers.add(server);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const address = server.address();
  return { server, url: `http://127.0.0.1:${address.port}` };
}

test('runtime HTTP requests abort immediately when a run is stopped', async () => {
  const { url } = await listen(() => {});
  const client = new RuntimeHttpClient(url);
  const controller = new AbortController();
  const request = client.request('GET', '/hang', undefined, {
    retryCount: 0,
    signal: controller.signal,
  });
  controller.abort('run stopped');

  await assert.rejects(
    request,
    (error) => error.name === 'AbortError' && error.code === 'ABORT_ERR',
  );
});

test('runtime retry backoff is cancellable', async () => {
  const { url } = await listen((request) => request.socket.destroy());
  const client = new RuntimeHttpClient(url);
  const controller = new AbortController();
  const startedAt = Date.now();
  const request = client.request('GET', '/disconnect', undefined, {
    retryCount: 5,
    retryDelayMs: 5000,
    signal: controller.signal,
  });
  setTimeout(() => controller.abort('run stopped'), 50);

  await assert.rejects(request, (error) => error.name === 'AbortError');
  assert.ok(Date.now() - startedAt < 1000);
});

test('runtime HTTP client never automatically replays side-effecting requests', async () => {
  let requests = 0;
  const { url } = await listen((request, response) => {
    requests += 1;
    if (requests === 1) {
      request.socket.destroy();
      return;
    }
    response.writeHead(200, { 'content-type': 'application/json' });
    response.end('{"ok":true}');
  });
  const client = new RuntimeHttpClient(url);

  await assert.rejects(
    client.request('POST', '/click', { selector: '#submit' }),
  );
  assert.equal(requests, 1);
});

test('VM browser transports cancellation out of the serialized request body', async () => {
  const calls = [];
  const client = {
    async request(method, pathname, body, options) {
      calls.push({ method, pathname, body, options });
      return { url: body.url };
    },
  };
  const provider = new VmBrowserProvider(client);
  const controller = new AbortController();

  await provider.navigate('https://example.com', { signal: controller.signal });

  assert.equal(calls.length, 1);
  assert.equal(calls[0].body.signal, undefined);
  assert.equal(calls[0].options.signal, controller.signal);
});

test('VM browser status and cookie reads forward cancellation', async () => {
  const calls = [];
  const client = {
    async request(method, pathname, body, options) {
      calls.push({ method, pathname, body, options });
      if (pathname === '/browser/status') return { launched: true, pages: 1 };
      return { cookies: [] };
    },
  };
  const provider = new VmBrowserProvider(client);
  const controller = new AbortController();

  await provider.getPageInfo({ signal: controller.signal });
  await provider.getCookies({ signal: controller.signal });

  assert.equal(calls.length, 2);
  assert.ok(calls.every((call) => call.options.signal === controller.signal));
});
