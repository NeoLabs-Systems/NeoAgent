'use strict';

const assert = require('node:assert/strict');
const { EventEmitter } = require('node:events');
const path = require('node:path');
const { test } = require('node:test');
const { pathToFileURL } = require('node:url');

const { ExtensionBrowserProvider } = require('../../../server/services/browser/extension/provider');
const {
  BrowserExtensionRegistry,
  ExtensionBrowserConnection,
} = require('../../../server/services/browser/extension/registry');

class FakeWebSocket extends EventEmitter {
  constructor() {
    super();
    this.readyState = 1;
    this.messages = [];
  }

  send(value) {
    this.messages.push(JSON.parse(value));
  }

  ping() {}

  close() {
    this.readyState = 3;
    this.emit('close');
  }

  terminate() {
    this.close();
  }
}

function connectionFor(ws) {
  return new ExtensionBrowserConnection({
    registry: {
      touchPresence() {},
      unregisterConnection() {},
    },
    ws,
    userId: 'user-1',
    tokenId: 'token-1',
    meta: {},
    timeoutMs: 5000,
    heartbeatIntervalMs: 0,
    heartbeatTimeoutMs: 0,
    presenceTouchIntervalMs: 0,
  });
}

function nextTurn() {
  return new Promise((resolve) => setImmediate(resolve));
}

test('aborting an extension command cancels work in the real browser', async () => {
  const ws = new FakeWebSocket();
  const connection = connectionFor(ws);
  const controller = new AbortController();
  const pending = connection.sendCommand('navigate', { url: 'https://example.com' }, {
    signal: controller.signal,
  });
  const reason = new Error('caller stopped the browser run');
  controller.abort(reason);

  await assert.rejects(pending, (error) => error === reason);
  assert.equal(connection.pending.size, 0);
  assert.equal(ws.messages[0].command, 'navigate');
  assert.equal(ws.messages[1].command, 'cancelCommand');
  assert.equal(ws.messages[1].payload.commandId, ws.messages[0].id);
});

test('extension command results preserve false values', async () => {
  const ws = new FakeWebSocket();
  const connection = connectionFor(ws);
  const pending = connection.sendCommand('getPageInfo');
  const command = ws.messages[0];

  ws.emit('message', JSON.stringify({
    type: 'result',
    id: command.id,
    ok: true,
    result: false,
  }));

  assert.equal(await pending, false);
});

test('extension command completion removes its abort listener', async () => {
  const ws = new FakeWebSocket();
  const connection = connectionFor(ws);
  const controller = new AbortController();
  const pending = connection.sendCommand('getPageInfo', {}, { signal: controller.signal });
  const command = ws.messages[0];

  ws.emit('message', JSON.stringify({
    type: 'result',
    id: command.id,
    ok: true,
    result: { url: 'https://example.com/' },
  }));

  assert.deepEqual(await pending, { url: 'https://example.com/' });
  controller.abort();
  assert.equal(ws.messages.length, 1);
});

test('extension URL validation requests are checked server-side and fail closed', async () => {
  const ws = new FakeWebSocket();
  const checked = [];
  const connection = new ExtensionBrowserConnection({
    registry: {
      urlValidationLimit: 8,
      touchPresence() {},
      unregisterConnection() {},
      async validateBrowserUrl(url) {
        checked.push(url);
        return { allowed: url === 'https://example.com/' };
      },
    },
    ws,
    userId: 'user-1',
    tokenId: 'token-1',
    meta: {},
    timeoutMs: 5000,
    heartbeatIntervalMs: 0,
    heartbeatTimeoutMs: 0,
    presenceTouchIntervalMs: 0,
  });

  ws.emit('message', JSON.stringify({
    type: 'urlValidationRequest',
    version: 1,
    id: 'allow-1',
    url: 'https://example.com/',
  }));
  ws.emit('message', JSON.stringify({
    type: 'urlValidationRequest',
    version: 999,
    id: 'deny-1',
    url: 'https://example.com/',
  }));
  await nextTurn();

  assert.deepEqual(checked, ['https://example.com/']);
  assert.deepEqual(
    ws.messages.map(({ id, allowed }) => ({ id, allowed })).sort((a, b) => a.id.localeCompare(b.id)),
    [
      { id: 'allow-1', allowed: true },
      { id: 'deny-1', allowed: false },
    ],
  );
  connection.close();
});

test('extension provider keeps AbortSignal out of WebSocket payloads', async () => {
  const calls = [];
  const registry = {
    isConnected: () => true,
    async dispatch(_userId, command, payload, options) {
      calls.push({ command, payload, options });
      return { success: true };
    },
  };
  const provider = new ExtensionBrowserProvider({ registry, userId: 'user-1' });
  const controller = new AbortController();
  await provider.navigate('https://example.com/', { signal: controller.signal });

  assert.equal(calls[0].payload.signal, undefined);
  assert.equal(calls[0].options.signal, controller.signal);
});

test('extension credential operations return opaque protected state', async () => {
  const calls = [];
  const registry = {
    isConnected: () => true,
    async dispatch(_userId, command, payload) {
      calls.push({ command, payload });
      if (command === 'fillCredential') {
        return { success: true, protectedFillId: 'protected-extension-1' };
      }
      return { success: true, protected: false };
    },
  };
  const provider = new ExtensionBrowserProvider({ registry, userId: 'user-1' });
  const result = await provider.fillCredential({
    usernameSelector: '#email',
    passwordSelector: '#password',
    username: 'private@example.test',
    password: 'never-return-this',
    allowedOrigin: 'https://accounts.example.test',
  });
  assert.equal(JSON.stringify(result).includes('never-return-this'), false);
  await provider.submitProtectedCredential(result.protectedFillId);
  assert.deepEqual(calls.map((call) => call.command), ['fillCredential', 'submitCredential']);
});

test('extension provider validates screenshot bytes before creating an artifact', async () => {
  const png = Buffer.from(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    'base64',
  );
  let artifactOptions = null;
  const provider = new ExtensionBrowserProvider({
    userId: 'user-1',
    registry: {
      async dispatch() {
        return { screenshotData: png.toString('base64'), success: true };
      },
    },
    artifactStore: {
      async createBufferArtifact(_userId, options) {
        artifactOptions = options;
        return {
          artifactId: 'artifact-1',
          storagePath: '/tmp/browser.png',
          url: '/api/artifacts/artifact-1/content',
        };
      },
    },
  });

  const result = await provider.screenshot();

  assert.equal(result.screenshotData, undefined);
  assert.equal(result.screenshotPath, '/api/artifacts/artifact-1/content');
  assert.equal(artifactOptions.contentType, 'image/png');
  assert.deepEqual(artifactOptions.content, png);
});

test('extension provider rejects corrupt screenshot payloads', async () => {
  const provider = new ExtensionBrowserProvider({
    userId: 'user-1',
    registry: {
      async dispatch() {
        return { screenshotData: Buffer.from('not a png').toString('base64') };
      },
    },
    artifactStore: {
      async createBufferArtifact() {
        throw new Error('artifact creation should not run');
      },
    },
  });

  await assert.rejects(provider.screenshot(), /not a valid PNG or JPEG/i);
});

test('revoking all browser tokens closes every live extension connection', () => {
  const fakeDb = {
    prepare() {
      return {
        run() {},
        get() { return null; },
        all() { return []; },
      };
    },
  };
  const registry = new BrowserExtensionRegistry({ db: fakeDb });
  const first = new FakeWebSocket();
  const second = new FakeWebSocket();
  registry.registerConnection({
    id: 'token-1',
    user_id: 'user-1',
    metadata: {},
  }, first);
  registry.registerConnection({
    id: 'token-2',
    user_id: 'user-1',
    metadata: {},
  }, second);

  registry.revoke('user-1');

  assert.equal(first.readyState, 3);
  assert.equal(second.readyState, 3);
  assert.equal(registry.isConnected('user-1', 'token-1'), false);
  assert.equal(registry.isConnected('user-1', 'token-2'), false);
});

test('extension protocol cancellation settles a hanging Chrome callback', async () => {
  const protocolUrl = pathToFileURL(path.resolve(
    __dirname,
    '../../../extensions/chrome-browser/protocol.mjs',
  )).href;
  const { COMMANDS, createBrowserProtocol } = await import(protocolUrl);
  let notifyNavigateStarted;
  const navigateStarted = new Promise((resolve) => { notifyNavigateStarted = resolve; });
  const noopEvent = { addListener() {} };
  const chromeApi = {
    runtime: { lastError: null },
    tabs: {
      onRemoved: noopEvent,
      query(_options, callback) {
        callback([{ id: 7, url: 'about:blank', title: '' }]);
      },
      get(_tabId, callback) {
        callback({ id: 7, url: 'about:blank', title: '' });
      },
      create(_options, callback) {
        callback({ id: 7, url: 'about:blank', title: '' });
      },
    },
    debugger: {
      onDetach: noopEvent,
      attach(_debuggee, _version, callback) { callback(); },
      detach(_debuggee, callback) { callback(); },
      sendCommand(_debuggee, method, _params, callback) {
        if (method === 'Page.navigate') {
          notifyNavigateStarted();
          return;
        }
        callback({});
      },
    },
    cookies: {
      getAll(_options, callback) { callback([]); },
    },
  };
  const protocol = createBrowserProtocol(chromeApi, {
    validateUrl: async () => true,
  });
  const controller = new AbortController();
  const pending = protocol.run(COMMANDS.NAVIGATE, {
    url: 'https://example.com/',
    screenshot: false,
  }, { signal: controller.signal });
  await navigateStarted;
  const reason = new Error('stop the hanging navigation');
  controller.abort(reason);

  await assert.rejects(pending, (error) => error === reason);
});

test('extension protocol intercepts redirects and subresources before network access', async () => {
  const protocolUrl = pathToFileURL(path.resolve(
    __dirname,
    '../../../extensions/chrome-browser/protocol.mjs',
  )).href;
  const {
    createBrowserProtocol,
    normalizeNetworkValidationUrl,
  } = await import(protocolUrl);
  const commands = [];
  let onDebuggerEvent = null;
  const noopEvent = { addListener() {} };
  const chromeApi = {
    runtime: { lastError: null },
    tabs: {
      onRemoved: noopEvent,
      query(_options, callback) {
        callback([{ id: 7, url: 'about:blank', title: '' }]);
      },
      get(_tabId, callback) {
        callback({ id: 7, url: 'about:blank', title: '' });
      },
      create(_options, callback) {
        callback({ id: 7, url: 'about:blank', title: '' });
      },
    },
    debugger: {
      onDetach: noopEvent,
      onEvent: {
        addListener(listener) { onDebuggerEvent = listener; },
      },
      attach(_debuggee, _version, callback) { callback(); },
      detach(_debuggee, callback) { callback(); },
      sendCommand(debuggee, method, params, callback) {
        commands.push({ debuggee, method, params });
        callback({});
      },
    },
    cookies: {
      getAll(_options, callback) { callback([]); },
    },
  };
  const validated = [];
  const protocol = createBrowserProtocol(chromeApi, {
    async validateUrl(url) {
      validated.push(url);
      return { allowed: url === 'https://cdn.example.com/' };
    },
  });
  await protocol._test.attach();

  onDebuggerEvent({ tabId: 7 }, 'Fetch.requestPaused', {
    requestId: 'public-subresource',
    request: { url: 'https://cdn.example.com/app.js?secret=not-forwarded' },
    resourceType: 'Script',
  });
  onDebuggerEvent({ tabId: 7 }, 'Fetch.requestPaused', {
    requestId: 'private-redirect',
    request: { url: 'http://127.0.0.1/admin' },
    resourceType: 'Document',
    redirectedRequestId: 'public-navigation',
  });
  await nextTurn();

  assert.equal(normalizeNetworkValidationUrl('wss://socket.example.com/live?token=x'), 'https://socket.example.com/');
  assert.equal(normalizeNetworkValidationUrl('http://[fe90::1]/'), null);
  assert.deepEqual(validated, ['https://cdn.example.com/']);
  assert.ok(commands.some(({ method }) => method === 'Fetch.enable'));
  assert.ok(commands.some(({ method, params }) => (
    method === 'Fetch.continueRequest' && params.requestId === 'public-subresource'
  )));
  assert.ok(commands.some(({ method, params }) => (
    method === 'Fetch.failRequest'
    && params.requestId === 'private-redirect'
    && params.errorReason === 'BlockedByClient'
  )));
});

test('extension protocol refuses page access when URL validation is unavailable', async () => {
  const protocolUrl = pathToFileURL(path.resolve(
    __dirname,
    '../../../extensions/chrome-browser/protocol.mjs',
  )).href;
  const { COMMANDS, createBrowserProtocol } = await import(protocolUrl);
  const noopEvent = { addListener() {} };
  let debuggerAttached = false;
  const chromeApi = {
    runtime: { lastError: null },
    tabs: {
      onRemoved: noopEvent,
      query(_options, callback) {
        callback([{ id: 7, url: 'https://example.com/', title: '' }]);
      },
      get(_tabId, callback) {
        callback({ id: 7, url: 'https://example.com/', title: '' });
      },
      create(_options, callback) { callback({ id: 7, url: 'about:blank' }); },
    },
    debugger: {
      onDetach: noopEvent,
      onEvent: noopEvent,
      attach(_debuggee, _version, callback) {
        debuggerAttached = true;
        callback();
      },
      detach(_debuggee, callback) { callback(); },
      sendCommand(_debuggee, _method, _params, callback) { callback({}); },
    },
    cookies: { getAll(_options, callback) { callback([]); } },
  };
  const protocol = createBrowserProtocol(chromeApi, {
    async validateUrl() {
      throw new Error('server disconnected');
    },
  });

  await assert.rejects(
    protocol.run(COMMANDS.SCREENSHOT),
    /server disconnected/,
  );
  assert.equal(debuggerAttached, false);
});
