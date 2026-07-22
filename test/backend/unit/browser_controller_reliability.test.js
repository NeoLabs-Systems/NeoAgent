'use strict';

const assert = require('node:assert/strict');
const { EventEmitter } = require('node:events');
const { test } = require('node:test');

const { BrowserController } = require('../../../server/services/browser/controller');

function controllerWithValidator(validator) {
  return new BrowserController({
    userId: `browser-test-${process.pid}`,
    urlValidator: validator,
  });
}

test('browser network guard validates requests and WebSockets before connecting', async () => {
  const handlers = {};
  const controller = controllerWithValidator(async (url) => ({
    allowed: !url.includes('blocked.example'),
  }));
  const context = {
    async route(_pattern, handler) { handlers.request = handler; },
    async routeWebSocket(_pattern, handler) { handlers.webSocket = handler; },
  };
  await controller._installNetworkGuard(context);

  const allowedRoute = {
    request: () => ({ url: () => 'https://public.example/app.js' }),
    continued: 0,
    aborted: 0,
    async continue() { this.continued += 1; },
    async abort() { this.aborted += 1; },
  };
  const blockedRoute = {
    request: () => ({ url: () => 'https://blocked.example/secret' }),
    continued: 0,
    aborted: 0,
    async continue() { this.continued += 1; },
    async abort() { this.aborted += 1; },
  };
  await handlers.request(allowedRoute);
  await handlers.request(blockedRoute);
  assert.equal(allowedRoute.continued, 1);
  assert.equal(allowedRoute.aborted, 0);
  assert.equal(blockedRoute.continued, 0);
  assert.equal(blockedRoute.aborted, 1);

  const allowedSocket = {
    url: () => 'wss://public.example/socket',
    connected: 0,
    closed: 0,
    connectToServer() { this.connected += 1; },
    async close() { this.closed += 1; },
  };
  const blockedSocket = {
    url: () => 'ws://blocked.example/socket',
    connected: 0,
    closed: 0,
    connectToServer() { this.connected += 1; },
    async close() { this.closed += 1; },
  };
  await handlers.webSocket(allowedSocket);
  await handlers.webSocket(blockedSocket);
  assert.equal(allowedSocket.connected, 1);
  assert.equal(allowedSocket.closed, 0);
  assert.equal(blockedSocket.connected, 0);
  assert.equal(blockedSocket.closed, 1);
});

test('browser navigation only accepts validator-approved top-level URLs', async () => {
  const controller = controllerWithValidator(async (url) => ({
    allowed: url === 'https://public.example/',
  }));

  await controller._assertNavigationAllowed('https://public.example/');
  await assert.rejects(
    controller._assertNavigationAllowed('data:text/html,private'),
    (error) => error.code === 'URL_BLOCKED',
  );
});

test('aborting a browser action closes the page and rejects promptly', async () => {
  const controller = controllerWithValidator(async () => ({ allowed: true }));
  const abortController = new AbortController();
  let closed = false;
  const page = {
    isClosed: () => closed,
    async close() { closed = true; },
  };
  const operation = controller._withPageCancellation(
    page,
    abortController.signal,
    () => new Promise(() => {}),
  );
  abortController.abort();

  await assert.rejects(operation, (error) => error.name === 'AbortError');
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(closed, true);
});

test('browser lifecycle events discard crashed pages and disconnected contexts', () => {
  const controller = controllerWithValidator(async () => ({ allowed: true }));
  const context = new EventEmitter();
  context.pages = () => [];
  context.isClosed = () => false;
  const browser = new EventEmitter();
  browser.isConnected = () => true;
  const page = new EventEmitter();
  page.isClosed = () => false;

  controller.context = context;
  controller.browser = browser;
  controller._bindContextLifecycle(context, browser);
  controller._bindPage(page);
  assert.equal(controller.isLaunched(), true);

  page.emit('crash');
  assert.equal(controller.page, null);

  browser.emit('disconnected');
  assert.equal(controller.context, null);
  assert.equal(controller.browser, null);
});

test('browser point actions reject missing coordinates instead of clicking 0,0', async () => {
  const controller = controllerWithValidator(async () => ({ allowed: true }));
  let moves = 0;
  controller.ensurePage = async () => ({
    isClosed: () => false,
    mouse: {
      async move() { moves += 1; },
      async down() {},
      async up() {},
    },
    url: () => 'https://example.com/',
    async title() { return 'Example'; },
  });

  const result = await controller.clickPoint(undefined, 20, false);

  assert.match(result.error, /x coordinate is required/i);
  assert.equal(moves, 0);
});

test('browser evaluation output is bounded and reports truncation', async () => {
  const controller = controllerWithValidator(async () => ({ allowed: true }));
  const page = {
    isClosed: () => false,
    async evaluate() { return 'x'.repeat((1024 * 1024) + 50); },
  };
  controller.ensurePage = async () => page;

  const result = await controller.evaluate('"large"');

  assert.equal(result.result.length, 1024 * 1024);
  assert.equal(result.truncated, true);
});

test('browser cookie reads settle promptly with the caller cancellation reason', async () => {
  const controller = controllerWithValidator(async () => ({ allowed: true }));
  controller.ensureBrowser = async () => {};
  controller.context = { cookies: () => new Promise(() => {}) };
  const abortController = new AbortController();
  const reason = new Error('stop cookie export');
  const pending = controller.getCookies({ signal: abortController.signal });
  abortController.abort(reason);

  await assert.rejects(pending, (error) => error === reason);
});

test('current-referrer navigation surfaces a failed navigation wait', async () => {
  const controller = controllerWithValidator(async () => ({ allowed: true }));
  const waitError = new Error('navigation did not commit');
  const page = {
    url: () => 'https://example.com/old',
    waitForURL: async () => { throw waitError; },
    evaluate: async () => {},
    waitForLoadState: async () => {},
  };

  await assert.rejects(
    controller._navigatePage(page, 'https://example.com/new', { referrerMode: 'current' }),
    (error) => error === waitError,
  );
});
