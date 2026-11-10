'use strict';

const assert = require('node:assert/strict');
const { after, afterEach, before, beforeEach, test } = require('node:test');
const { spawn } = require('node:child_process');
const fs = require('node:fs');
const http = require('node:http');
const net = require('node:net');
const os = require('node:os');
const path = require('node:path');
const zlib = require('node:zlib');
const { once } = require('node:events');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

const GUEST_TOKEN = 'dummy-guest-token';
const PAGE = '<!doctype html><html><head><title>Demo</title></head><body class="x"><h1>Hello</h1></body></html>';

let guestRoot;
let guestAgent;
let guestPort;
let appServer;
let appPort;
let ctx;
let user;

async function freePort() {
  const listener = net.createServer();
  listener.listen(0, '127.0.0.1');
  await once(listener, 'listening');
  const { port } = listener.address();
  await new Promise((resolve) => listener.close(resolve));
  return port;
}

// The app the agent started inside its computer. It reports what reached it.
function startApp() {
  return http.createServer((req, res) => {
    const seen = {
      'x-seen-cookie': req.headers.cookie || '',
      'x-seen-authorization': req.headers.authorization || '',
      'x-seen-prefix': req.headers['x-forwarded-prefix'] || '',
      'x-seen-path': req.url,
    };
    if (req.url === '/go') {
      res.writeHead(302, { ...seen, location: '/next' });
      return res.end();
    }
    if (req.url === '/gz') {
      res.writeHead(200, { ...seen, 'content-type': 'text/html', 'content-encoding': 'gzip' });
      return res.end(zlib.gzipSync(PAGE));
    }
    if (req.url === '/app.js') {
      res.writeHead(200, { ...seen, 'content-type': 'text/javascript' });
      return res.end('console.log(1)');
    }
    if (req.method === 'POST') {
      const chunks = [];
      req.on('data', (chunk) => chunks.push(chunk));
      return req.on('end', () => {
        res.writeHead(200, { ...seen, 'content-type': 'text/plain' });
        res.end(`echo:${Buffer.concat(chunks)}`);
      });
    }
    res.writeHead(200, {
      ...seen,
      'content-type': 'text/html; charset=utf-8',
      'set-cookie': 'session=guest',
      'clear-site-data': '"cookies"',
      'content-security-policy': "default-src 'self'",
    });
    return res.end(PAGE);
  });
}

before(async () => {
  guestRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'neo-web-share-'));
  guestPort = await freePort();
  guestAgent = spawn(process.execPath, [path.resolve(__dirname, '../../../server/guest_agent.js')], {
    env: {
      PATH: process.env.PATH, HOME: path.join(guestRoot, 'home'), TMPDIR: guestRoot,
      NEOAGENT_HOME: guestRoot, NEOAGENT_DATA_DIR: path.join(guestRoot, 'data'), NEOAGENT_ENV_FILE: path.join(guestRoot, 'empty.env'),
      NEOAGENT_GUEST_AGENT_PORT: String(guestPort), NEOAGENT_VM_GUEST_TOKEN: GUEST_TOKEN,
      NEOAGENT_GUEST_PROFILE: 'cli', NEOAGENT_WORKSPACE_DIR: path.join(guestRoot, 'workspace'),
    },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  await new Promise((resolve, reject) => {
    guestAgent.stdout.on('data', (data) => { if (String(data).includes('listening')) resolve(); });
    guestAgent.once('exit', () => reject(new Error('guest agent exited before it listened')));
  });
  appServer = startApp();
  appServer.listen(0, '127.0.0.1');
  await once(appServer, 'listening');
  appPort = appServer.address().port;
});

after(async () => {
  appServer?.close();
  guestAgent?.kill('SIGTERM');
  if (guestAgent && guestAgent.exitCode === null) await once(guestAgent, 'close');
  fs.rmSync(guestRoot, { recursive: true, force: true });
});

beforeEach(async () => {
  ctx = createTestRuntime();
  user = await createTestUser(ctx.db);
});

afterEach(() => teardownTestRuntime(ctx));

const runningGuest = () => ({ runningGuestForUser: () => ({ baseUrl: `http://127.0.0.1:${guestPort}`, token: GUEST_TOKEN }) });

async function serve(runtime = runningGuest()) {
  const express = require('express');
  const { createWebShareProxy } = require('../../../server/services/web_shares/proxy');
  const app = express();
  app.locals.httpRuntimeConfig = { publicUrl: 'https://neo.example' };
  app.use(createWebShareProxy({ app, getRuntime: () => runtime }));
  app.use((req, res) => res.status(404).send('not a share'));
  const server = app.listen(0, '127.0.0.1');
  await once(server, 'listening');
  return {
    base: `http://127.0.0.1:${server.address().port}`,
    close: () => new Promise((resolve) => server.close(resolve)),
  };
}

async function share(name = 'Demo App', port = appPort) {
  const { shareWebPage } = require('../../../server/services/web_shares');
  return shareWebPage({ userId: user.userId, runtime: runningGuest(), name, port, baseUrl: 'https://neo.example' });
}

test('sharing checks the app answers and returns the public link', async () => {
  const result = await share();
  assert.equal(result.shared, true);
  assert.equal(result.slug, 'demo-app');
  assert.equal(result.url, `https://neo.example/${encodeURIComponent(user.username)}/demo-app/`);

  const closed = await share('Nothing', await freePort());
  assert.match(closed.error, /Nothing answers on port/);

  const { shareWebPage } = require('../../../server/services/web_shares');
  const offline = await shareWebPage({ userId: user.userId, runtime: { runningGuestForUser: () => null }, name: 'x', port: appPort });
  assert.match(offline.error, /not running/);
});

test('a shared page is relayed sandboxed, with the notice and without cookies', async () => {
  await share();
  const site = await serve();
  try {
    const prefix = `/${encodeURIComponent(user.username)}/demo-app`;
    const redirect = await fetch(`${site.base}${prefix}?a=1`, { redirect: 'manual' });
    assert.equal(redirect.status, 308);
    assert.equal(redirect.headers.get('location'), `${prefix}/?a=1`);

    const page = await fetch(`${site.base}${prefix}/`, {
      headers: { cookie: 'neoagent.sid=secret', authorization: 'Bearer stolen', 'sec-fetch-dest': 'document' },
    });
    const html = await page.text();
    assert.equal(page.status, 200);
    assert.match(html, /<body class="x"><div id="neoagent-share-notice"/);
    assert.match(html, /does not come from or represent NeoAgent/);
    assert.equal(page.headers.get('x-seen-cookie'), '');
    assert.equal(page.headers.get('x-seen-authorization'), '');
    assert.equal(page.headers.get('x-seen-prefix'), prefix);
    assert.equal(page.headers.get('set-cookie'), null);
    assert.equal(page.headers.get('clear-site-data'), null);
    const policy = page.headers.get('content-security-policy');
    assert.match(policy, /default-src 'self'/);
    assert.match(policy, /sandbox allow-scripts/);
    assert.doesNotMatch(policy, /allow-same-origin/);

    const compressed = await (await fetch(`${site.base}${prefix}/gz`, { headers: { 'sec-fetch-dest': 'document' } })).text();
    assert.match(compressed, /neoagent-share-notice/);

    const script = await fetch(`${site.base}${prefix}/app.js`);
    assert.equal(await script.text(), 'console.log(1)');
    assert.match(script.headers.get('content-security-policy'), /sandbox/);

    const moved = await fetch(`${site.base}${prefix}/go`, { redirect: 'manual' });
    assert.equal(moved.headers.get('location'), `${prefix}/next`);

    const posted = await fetch(`${site.base}${prefix}/form`, { method: 'POST', body: 'hello' });
    assert.equal(await posted.text(), 'echo:hello');

    // fetch() would resolve these itself, so they go out raw. Each would step
    // from /proxy/<port> to the guest agent's own routes.
    for (const escape of ['/../../../health', '/%2e%2e/%2E%2E/health', '/..%2f..%2fhealth', '/.%2e/x']) {
      const status = await new Promise((resolve, reject) => {
        http.get(site.base, { path: `${prefix}${escape}` }, (res) => {
          res.resume();
          resolve(res.statusCode);
        }).on('error', reject);
      });
      assert.equal(status, 400, escape);
    }
  } finally {
    await site.close();
  }
});

test('"don\'t show again" is remembered and keeps the visitor on the page', async () => {
  await share();
  const site = await serve();
  try {
    const prefix = `/${encodeURIComponent(user.username)}/demo-app`;
    const hide = await fetch(`${site.base}${prefix}/.neoagent/hide-notice?back=${encodeURIComponent(`${prefix}/docs`)}`, { redirect: 'manual' });
    assert.equal(hide.status, 303);
    assert.equal(hide.headers.get('location'), `${prefix}/docs`);
    assert.match(hide.headers.get('set-cookie'), /neoagent_share_notice=hidden; Path=\/; .*HttpOnly; Secure/);

    const away = await fetch(`${site.base}${prefix}/.neoagent/hide-notice?back=https://evil.example/`, { redirect: 'manual' });
    assert.equal(away.headers.get('location'), `${prefix}/`);

    const page = await (await fetch(`${site.base}${prefix}/`, { headers: { cookie: 'neoagent_share_notice=hidden', 'sec-fetch-dest': 'document' } })).text();
    assert.doesNotMatch(page, /neoagent-share-notice/);
  } finally {
    await site.close();
  }
});

test('a page is offline while the computer or the app is down', async () => {
  await share();
  const prefix = `/${encodeURIComponent(user.username)}/demo-app`;
  const stopped = await serve({ runningGuestForUser: () => null });
  try {
    const page = await fetch(`${stopped.base}${prefix}/`);
    assert.equal(page.status, 503);
    assert.match(await page.text(), /Demo App is offline/);
  } finally {
    await stopped.close();
  }

  const { saveShare } = require('../../../server/services/web_shares/shares');
  saveShare({ userId: user.userId, name: 'Demo App', port: await freePort() });
  const appDown = await serve();
  try {
    assert.equal((await fetch(`${appDown.base}${prefix}/`)).status, 503);
  } finally {
    await appDown.close();
  }
});

test('turning sharing off takes every page down and hides the tool', async () => {
  await share();
  ctx.db.prepare("INSERT INTO user_settings (user_id, key, value) VALUES (?, 'web_sharing_enabled', 'false')").run(user.userId);
  const site = await serve();
  try {
    const page = await fetch(`${site.base}/${encodeURIComponent(user.username)}/demo-app/`);
    assert.equal(page.status, 404);
    assert.equal(await page.text(), 'not a share');
  } finally {
    await site.close();
  }
  const { getAvailableTools } = require('../../../server/services/ai/tools');
  const names = (options) => getAvailableTools(null, options).map((tool) => tool.name);
  assert.equal(names({ userId: user.userId }).includes('share_web_page'), false);
  ctx.db.prepare("UPDATE user_settings SET value = 'true' WHERE user_id = ? AND key = 'web_sharing_enabled'").run(user.userId);
  assert.equal(names({ userId: user.userId }).includes('share_web_page'), true);
});

test('only publishing needs approval, and odd names and ports are refused', () => {
  const { getCategoryForTool } = require('../../../server/services/security/tool_categories');
  assert.equal(getCategoryForTool('share_web_page', { action: 'share' }), 'network_write');
  assert.equal(getCategoryForTool('share_web_page', { action: 'list' }), null);
  assert.equal(getCategoryForTool('share_web_page', null), null);

  const { slugFor, validatePort, findPublicShare, isReservedSegment } = require('../../../server/services/web_shares/shares');
  assert.equal(slugFor('  Mein Café — Übersicht! '), 'mein-cafe-ubersicht');
  assert.equal(slugFor('!!!'), '');
  assert.equal(validatePort(8421), null);
  assert.equal(validatePort('3000'), 3000);
  assert.equal(validatePort(70000), null);
  assert.equal(isReservedSegment('API'), true);
  assert.equal(findPublicShare('api', 'x'), null);
  assert.equal(findPublicShare('%E0%A4%A', 'x'), null);
});

test('stopping a share by its name removes it', async () => {
  await share();
  const { stopSharingWebPage, listShares } = require('../../../server/services/web_shares');
  assert.deepEqual(stopSharingWebPage({ userId: user.userId, ref: 'Demo App' }), { stopped: true });
  assert.deepEqual(listShares(user.userId), []);
  assert.match(stopSharingWebPage({ userId: user.userId, ref: 'Demo App' }).error, /No shared page/);
});

test('the admin switch takes sharing away from everyone, at once', async (t) => {
  await share();
  const previous = process.env.NEOAGENT_WEB_SHARING;
  t.after(() => {
    if (previous === undefined) delete process.env.NEOAGENT_WEB_SHARING;
    else process.env.NEOAGENT_WEB_SHARING = previous;
  });
  process.env.NEOAGENT_WEB_SHARING = 'false';
  const site = await serve();
  try {
    assert.equal((await fetch(`${site.base}/${encodeURIComponent(user.username)}/demo-app/`)).status, 404);
  } finally {
    await site.close();
  }
  const { isWebSharingEnabled } = require('../../../server/services/web_shares');
  assert.equal(isWebSharingEnabled(user.userId), false);
  const { getAvailableTools } = require('../../../server/services/ai/tools');
  assert.equal(getAvailableTools(null, { userId: user.userId }).some((tool) => tool.name === 'share_web_page'), false);
  assert.match((await share('Other')).error, /turned off/);

  const { getVmSettings } = require('../../../server/services/admin/server_config');
  assert.equal(getVmSettings().settings.webSharing, false);
  delete process.env.NEOAGENT_WEB_SHARING;
  assert.equal(getVmSettings().settings.webSharing, true);
});
