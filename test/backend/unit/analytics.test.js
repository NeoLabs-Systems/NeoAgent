'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const vm = require('node:vm');
const express = require('express');
const { registerAnalytics } = require('../../../server/analytics');

const { analyticsConfig } = require('../../../server/analytics-config');

const { appKey: countlyKey, endpoint } = analyticsConfig();

function loadBrowserClient() {
  const source = fs.readFileSync(path.join(__dirname, '../../../server/analytics-client.js'), 'utf8');
  return source.replace('/* COUNTLY_CONFIG */ null', JSON.stringify({ endpoint, appKey: countlyKey }));
}

function recordBrowserEvents(events) {
  return (url, options) => {
    if (url === endpoint) {
      assert.equal(options.method, 'POST');
      assert.equal(options.mode, 'cors');
      assert.equal(options.redirect, 'error');
      assert.equal(options.credentials, 'omit');
      assert.equal(options.referrerPolicy, 'no-referrer');
      assert.equal(options.body.get('device_id'), 'aggregate-browser');
      assert.equal(options.body.get('app_key'), countlyKey);
      assert.equal(options.body.has('begin_session'), false);
      assert.equal(options.body.has('metrics'), false);
      events.push(...JSON.parse(options.body.get('events')));
    }
    return Promise.resolve({ status: 200 });
  };
}

test('analytics is delivered only when enabled and preserves app assets', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'analytics-test-'));
  const web = path.join(dir, 'web'); const landing = path.join(dir, 'landing');
  fs.mkdirSync(web); fs.mkdirSync(landing);
  fs.writeFileSync(path.join(web, 'index.html'), '<head><base href="/"></head>app');
  fs.writeFileSync(path.join(landing, 'index.html'), '<head></head>landing');
  const app = express(); registerAnalytics(app, { appWebRoot: web, landingRoot: landing });
  app.use('/app', express.static(web)); app.use(express.static(landing));
  const server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  try {
    assert.equal(endpoint, 'https://data.neo.eu.com/i');
    let page = await (await fetch(`${base}/app/`)).text();
    assert.match(page, /_neolabs\/analytics.js/); assert.match(page, /base href="\/app\/"/);
    assert.match(await (await fetch(`${base}/`)).text(), /_neolabs\/analytics.js/);
    assert.equal((await fetch(`${base}/app/missing.js`)).status, 404);
    assert.match(await (await fetch(`${base}/_neolabs/analytics.js`)).text(), /data\.neo\.eu\.com\/i/);
    process.env.ANALYTICS_ENABLED = 'false';
    page = await (await fetch(`${base}/app/`)).text();
    assert.doesNotMatch(page, /_neolabs\/analytics.js/);
    assert.equal((await fetch(`${base}/_neolabs/analytics.js`)).status, 404);
  } finally { delete process.env.ANALYTICS_ENABLED; server.close(); fs.rmSync(dir, { recursive: true, force: true }); }
});

test('browser analytics sends coarse data only and honors privacy preferences', () => {
  const client = loadBrowserClient();
  function run(dnt, gpc, url = 'https://example.org/app/private-id?token=secret') {
    const sent = []; const listeners = {}; const timers = [];
    const document = { readyState: 'complete', visibilityState: 'hidden', addEventListener: (name, fn) => { listeners[name] = fn; } };
    const window = { fetch: recordBrowserEvents(sent), addEventListener: (name, fn) => { listeners[name] = fn; } };
    const context = { window, document, navigator: { doNotTrack: dnt, globalPrivacyControl: gpc }, location: new URL(url), performance: { getEntriesByType: () => [{ loadEventEnd: 1500 }] }, URL, URLSearchParams, setInterval: (fn, ms) => timers.push({ fn, ms }), setTimeout: fn => fn(), WeakMap, Promise };
    vm.runInNewContext(client, context);
    if (listeners.click) listeners.click();
    if (listeners.error) listeners.error({ message: 'secret error' });
    if (listeners.visibilitychange) listeners.visibilitychange();
    const heartbeat = timers.find(timer => timer.ms === 60000);
    if (heartbeat) {
      heartbeat.fn();
      assert.equal(sent.filter(event => event.key === 'active-browser').length, 0);
      document.visibilityState = 'visible';
      heartbeat.fn();
      assert.equal(sent.filter(event => event.key === 'active-browser').length, 1);
    }
    return sent;
  }
  const enabled = run('0');
  assert.ok(enabled.length >= 4);
  assert.deepEqual(enabled.filter(event => event.key === '[CLY]_view'), [{
    key: '[CLY]_view',
    count: 1,
    segmentation: { name: 'app', view: '/app', visit: 1 },
  }]);
  assert.ok(enabled.some(event => event.key === 'page-load'));
  assert.ok(!enabled.some(event => event.key === 'page-view'));
  const landing = run('0', false, 'https://example.org/?token=secret');
  assert.deepEqual(landing.find(event => event.key === '[CLY]_view').segmentation, {
    name: 'landing', view: '/', visit: 1,
  });
  assert.doesNotMatch(JSON.stringify(enabled), /secret|private|token|referrer|hostname/);
  assert.deepEqual(run('1'), []);
  assert.deepEqual(run('0', true), []);
});

test('feature counts exclude identifiers, bodies, and unrelated requests', () => {
  const source = loadBrowserClient();
  const group = source.match(/var groups = \['([^']+)'/)[1];
  const sent = []; const listeners = {};
  class XHR {
    open() {}
    send() { this.status = 503; this.done(); }
    addEventListener(_name, fn) { this.done = fn; }
  }
  const document = { readyState: 'complete', visibilityState: 'hidden', addEventListener: (name, fn) => { listeners[name] = fn; } };
  const window = { fetch: recordBrowserEvents(sent), XMLHttpRequest: XHR, addEventListener() {} };
  const context = { window, document, navigator: {}, location: new URL('https://example.org/app/'), performance: { getEntriesByType: () => [] }, URL, URLSearchParams, XMLHttpRequest: XHR, WeakMap, Promise, setInterval() {}, setTimeout() {} };
  vm.runInNewContext(source, context);
  const request = new XHR();
  request.open('POST', `/api/v1/${group}/secret-id?token=secret`);
  request.send('secret body');
  const secondRequest = new XHR();
  secondRequest.open('POST', `/api/v1/${group}/another-secret`);
  secondRequest.send();
  const admin = new XHR();
  admin.open('PATCH', '/api/v1/admin/users/sensitive-user-id?query=secret');
  admin.send('private settings');
  const unknownAdmin = new XHR();
  unknownAdmin.open('GET', '/api/v1/admin/sensitive-user-id');
  unknownAdmin.send();
  const unrelated = new XHR();
  unrelated.open('GET', 'https://outside.example/api/v1/' + group);
  unrelated.send();
  listeners.visibilitychange();
  const event = sent.find(item => item.key === 'feature-requests');
  assert.equal(event.segmentation.feature, group);
  assert.equal(event.segmentation.operation, 'write');
  assert.equal(event.segmentation.outcome, 'server-error');
  assert.equal(event.count, 2);
  const adminEvent = sent.find(item => item.segmentation && item.segmentation.feature === 'admin-users');
  assert.equal(adminEvent.segmentation.operation, 'write');
  assert.equal(adminEvent.segmentation.outcome, 'server-error');
  assert.ok(sent.some(item => item.segmentation && item.segmentation.feature === 'admin'));
  assert.doesNotMatch(JSON.stringify(sent), /secret|outside|sensitive-user-id|private settings/);
});

test('host reports contain only coarse runtime metrics and respect opt-out', async () => {
  const { reportHost, hostSnapshot } = require('../../../server/host_analytics');
  const snapshot = hostSnapshot();
  assert.ok(snapshot.os);
  assert.ok(snapshot.ram_gib_range);
  assert.ok(snapshot.cpu_cores_range);
  assert.ok(!('hostname' in snapshot));
  assert.ok(!('ip' in snapshot));
  const requests = [];
  const fakeFetch = async (...args) => { requests.push(args); return { ok: true }; };
  try {
    process.env.ANALYTICS_ENABLED = 'false';
    await reportHost(fakeFetch);
    assert.equal(requests.length, 0);
    delete process.env.ANALYTICS_ENABLED;
    await reportHost(fakeFetch);
    assert.equal(requests.length, 1);
    const [url, options] = requests[0];
    assert.equal(url, endpoint);
    assert.equal(options.body.get('app_key'), countlyKey);
    assert.equal(options.body.get('device_id'), 'aggregate-server');
    const [event] = JSON.parse(options.body.get('events'));
    assert.equal(event.key, 'host-snapshot');
    assert.equal(event.count, 1);
    assert.ok(!('hostname' in event.segmentation));
    assert.ok(!('id' in event.segmentation));
    await reportHost(async () => { throw new Error('unavailable'); });
  } finally { delete process.env.ANALYTICS_ENABLED; }
});
