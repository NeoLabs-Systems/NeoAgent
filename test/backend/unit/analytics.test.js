'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const vm = require('node:vm');
const express = require('express');
const { registerAnalytics } = require('../../../server/analytics');

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
    delete process.env.ANALYTICS_ENABLED;
    let page = await (await fetch(`${base}/app/`)).text();
    assert.match(page, /_neolabs\/analytics.js/); assert.match(page, /base href="\/app\/"/);
    assert.match(await (await fetch(`${base}/`)).text(), /_neolabs\/analytics.js/);
    assert.equal((await fetch(`${base}/app/missing.js`)).status, 404);
    assert.match(await (await fetch(`${base}/_neolabs/analytics.js`)).text(), /data.neo.eu.com/);
    process.env.ANALYTICS_ENABLED = 'false';
    page = await (await fetch(`${base}/app/`)).text();
    assert.doesNotMatch(page, /_neolabs\/analytics.js/);
    assert.equal((await fetch(`${base}/_neolabs/analytics.js`)).status, 404);
  } finally { delete process.env.ANALYTICS_ENABLED; server.close(); fs.rmSync(dir, { recursive: true, force: true }); }
});

test('browser analytics sends coarse data only and honors privacy preferences', () => {
  const client = fs.readFileSync(path.join(__dirname, '../../../server/analytics-client.js'), 'utf8');
  function run(dnt) {
    const sent = []; const listeners = {}; const timers = []; let added;
    const document = { readyState: 'complete', visibilityState: 'hidden', createElement: () => ({ dataset: {} }), head: { appendChild: script => { added = script; } }, addEventListener: (name, fn) => { listeners[name] = fn; } };
    const window = { addEventListener: (name, fn) => { listeners[name] = fn; }, umami: { track: fn => { sent.push(fn({ website: 'id', language: 'en', screen: '1x1', url: '/secret?token=x', referrer: 'secret', title: 'secret', hostname: 'private' })); return Promise.resolve(); } } };
    const context = { window, document, navigator: { doNotTrack: dnt }, location: new URL('https://example.org/app/?token=secret'), performance: { getEntriesByType: () => [{ loadEventEnd: 1500 }] }, URL, setInterval: (fn, ms) => timers.push({ fn, ms }), setTimeout: fn => fn(), WeakMap, Promise };
    vm.runInNewContext(client, context);
    if (added) added.onload();
    if (listeners.click) listeners.click();
    if (listeners.error) listeners.error({ message: 'secret error' });
    if (listeners.visibilitychange) listeners.visibilitychange();
    const heartbeat = timers.find(timer => timer.ms === 60000);
    if (heartbeat) {
      heartbeat.fn();
      assert.equal(sent.filter(event => event.name === 'active-browser').length, 0);
      document.visibilityState = 'visible';
      heartbeat.fn();
      assert.equal(sent.filter(event => event.name === 'active-browser').length, 1);
    }
    return { sent, added };
  }
  const enabled = run('0');
  assert.ok(enabled.added); assert.ok(enabled.sent.length >= 4);
  assert.doesNotMatch(JSON.stringify(enabled.sent), /secret|private|token|referrer|hostname/);
  assert.equal(run('1').added, undefined);
});

test('feature counts exclude identifiers, bodies, and unrelated requests', () => {
  const source = fs.readFileSync(path.join(__dirname, '../../../server/analytics-client.js'), 'utf8');
  const group = source.match(/var groups = \['([^']+)'/)[1];
  const sent = []; const listeners = {}; let script;
  class XHR {
    open() {}
    send() { this.status = 503; this.done(); }
    addEventListener(_name, fn) { this.done = fn; }
  }
  const document = { readyState: 'complete', visibilityState: 'hidden', createElement: () => ({ dataset: {} }), head: { appendChild: value => { script = value; } }, addEventListener: (name, fn) => { listeners[name] = fn; } };
  const window = { XMLHttpRequest: XHR, addEventListener() {}, umami: { track: fn => { sent.push(fn({ website: 'id' })); return Promise.resolve(); } } };
  const context = { window, document, navigator: {}, location: new URL('https://example.org/app/'), performance: { getEntriesByType: () => [] }, URL, XMLHttpRequest: XHR, WeakMap, Promise, setInterval() {}, setTimeout() {} };
  vm.runInNewContext(source, context);
  script.onload();
  const request = new XHR();
  request.open('POST', `/api/v1/${group}/secret-id?token=secret`);
  request.send('secret body');
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
  const event = sent.find(item => item.name === 'feature-requests');
  assert.equal(event.data.feature, group);
  assert.equal(event.data.operation, 'write');
  assert.equal(event.data.outcome, 'server-error');
  assert.equal(event.data.count, 1);
  const adminEvent = sent.find(item => item.data && item.data.feature === 'admin-users');
  assert.equal(adminEvent.data.operation, 'write');
  assert.equal(adminEvent.data.outcome, 'server-error');
  assert.ok(sent.some(item => item.data && item.data.feature === 'admin'));
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
    const payload = JSON.parse(requests[0][1].body);
    assert.equal(payload.payload.name, 'host-snapshot');
    assert.equal(payload.payload.url, '/server');
    assert.ok(!('hostname' in payload.payload));
    assert.ok(!('id' in payload.payload));
    await reportHost(async () => { throw new Error('unavailable'); });
  } finally { delete process.env.ANALYTICS_ENABLED; }
});
