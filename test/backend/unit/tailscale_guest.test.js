'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');
const fs = require('node:fs/promises');
const path = require('node:path');
const os = require('node:os');
const net = require('node:net');
const http = require('node:http');
const { spawn } = require('node:child_process');
const { GuestTailscale, OUTBOUND_PREFS, validateOperation } = require('../../../server/services/integrations/tailscale/guest');
const { peerTarget, requestPeer } = require('../../../server/services/integrations/tailscale/guest_network');
const { dialPeer } = require('../../../server/services/integrations/tailscale/guest_api');

const PEER_ID = 'peer-one';
const PEER_IP = '100.101.102.103';
const status = { BackendState: 'Running', Self: { ID: 'own-node' }, CurrentTailnet: { Name: 'private-tailnet' }, Peer: { key: { ID: PEER_ID, HostName: 'nas', DNSName: 'nas.private.ts.net.', TailscaleIPs: [PEER_IP] } } };
const grant = { peerId: PEER_ID, port: 8123, scheme: 'http', path: '/status', methods: ['GET'] };

function request(action = 'list', overrides = {}) {
  return { operationId: 'a'.repeat(48), action, nodeId: 'own-node', state: Buffer.from('node-state').toString('base64'), ...overrides };
}

async function guestFixture(t, options = {}) {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'neo-ts-test-'));
  t.after(() => fs.rm(root, { recursive: true, force: true }));
  const launched = [];
  const apiCalls = [];
  const guest = new GuestTailscale({
    temporaryRoot: root,
    spawnClient(binary, args, settings) {
      launched.push({ binary, args, settings });
      // A real process exercises cancellation and process-group cleanup,
      // without running a Tailscale client or accessing a real tailnet.
      return spawn(process.execPath, ['-e', 'setInterval(() => {}, 1000)'], settings);
    },
    async callApi(socket, method, endpoint, body) {
      apiCalls.push({ socket, method, endpoint, body });
      if (endpoint === 'start') await fs.writeFile(path.join(path.dirname(socket), 'state'), 'rotated-node-state');
      if (endpoint === 'prefs') return { ...OUTBOUND_PREFS, ...options.prefs };
      return status;
    },
    callPeer: options.callPeer || (async () => ({ body: 'private response' })),
  });
  t.after(() => guest.shutdown());
  return { guest, root, launched, apiCalls };
}

test('outbound client uses private memory-backed state, an independent lifetime bound, and no proxy listener', async (t) => {
  const { guest, root, launched, apiCalls } = await guestFixture(t);
  const result = await guest.run(request());
  assert.equal(Buffer.from(result.state, 'base64').toString(), 'rotated-node-state');
  assert.equal(result.nodeId, 'own-node');
  assert.equal(launched.length, 1);
  assert.match(launched[0].binary, /timeout$/);
  assert.ok(launched[0].args.includes('50s'));
  assert.ok(launched[0].args.includes('--tun=userspace-networking'));
  assert.equal(launched[0].args.some((arg) => /socks|proxy|auth-key/.test(arg)), false);
  assert.equal(launched[0].settings.env.TS_AUTHKEY, undefined);
  assert.equal(launched[0].settings.detached, true);
  assert.deepEqual(apiCalls.find((call) => call.endpoint === 'start').body.UpdatePrefs, { ...OUTBOUND_PREFS, Hostname: 'neoagent' });
  assert.deepEqual(await fs.readdir(root), []);
});

test('interactive login exposes only the Tailscale authorization URL and stops the client after approval', async (t) => {
  const { guest, apiCalls, root } = await guestFixture(t);
  let approved = false;
  const call = guest.callApi;
  guest.callApi = async (...args) => {
    if (args[2] === 'status' && !approved) return { BackendState: 'NeedsLogin', AuthURL: 'https://login.tailscale.com/a/test-login' };
    return call(...args);
  };
  const input = request('login', { state: undefined, nodeId: undefined });
  const started = await guest.beginLogin(input);
  assert.equal(started.loginUrl, 'https://login.tailscale.com/a/test-login');
  assert.equal(started.state, undefined);
  assert.equal(guest.active.size, 1);
  approved = true;
  await guest.queue;
  await new Promise(setImmediate);
  const result = guest.loginStatus(input.operationId);
  assert.equal(result.status, 'connected');
  assert.equal(result.nodeId, 'own-node');
  assert.ok(apiCalls.some((call) => call.endpoint === 'login-interactive'));
  assert.deepEqual(await fs.readdir(root), []);
  await guest.cancel(input.operationId);
  assert.equal(guest.loginResults.size, 0);
});

test('a VM rejects wrong node identity and any failure to enforce inbound blocking', async (t) => {
  const first = await guestFixture(t);
  await assert.rejects(first.guest.run(request('list', { nodeId: 'different-node' })), /identity changed/);
  const second = await guestFixture(t, { prefs: { ShieldsUp: false } });
  await assert.rejects(second.guest.run(request()), /outbound-only policy/);
  assert.deepEqual(await fs.readdir(second.root), []);
});

test('service errors still persist rotated state and remove the temporary client', async (t) => {
  const { guest, root } = await guestFixture(t, { callPeer: async () => { throw new Error('Peer request failed.'); } });
  const response = await guest.run(request('request', { grants: [grant], args: { peer_id: PEER_ID, port: 8123, scheme: 'http', path: '/status' } }));
  assert.equal(response.error, 'Peer request failed.');
  assert.equal(Buffer.from(response.state, 'base64').toString(), 'rotated-node-state');
  assert.deepEqual(await fs.readdir(root), []);
});

test('guest cancellation terminates the client and removes all temporary state', async (t) => {
  let entered;
  const ready = new Promise((resolve) => { entered = resolve; });
  const { guest, root } = await guestFixture(t, { callPeer: async (_socket, _status, _operation, { signal }) => {
    entered();
    return new Promise((_resolve, reject) => signal.addEventListener('abort', () => reject(signal.reason), { once: true }));
  } });
  const pending = guest.run(request('request', { grants: [grant], args: { peer_id: PEER_ID, port: 8123, scheme: 'http', path: '/status' } }));
  const rejected = assert.rejects(pending, /canceled/);
  await ready;
  await guest.cancel('a'.repeat(48));
  await rejected;
  assert.deepEqual(await fs.readdir(root), []);
});

test('guest rejects ungranted operations before starting any client', () => {
  assert.throws(() => validateOperation(request('request', { grants: [], args: { peer_id: PEER_ID, port: 8123 } })), /not been granted/);
  assert.throws(() => validateOperation(request('list', { state: undefined })), /credentials/);
  assert.throws(() => validateOperation(request('login', { authKey: 'key' })), /new node/);
});

test('concurrent connections share one client execution slot per VM', async (t) => {
  let entered;
  let release;
  const ready = new Promise((resolve) => { entered = resolve; });
  const blocked = new Promise((resolve) => { release = resolve; });
  const { guest, launched } = await guestFixture(t, { callPeer: async () => { entered(); await blocked; return { body: 'done' }; } });
  const first = guest.run(request('request', { grants: [grant], args: { peer_id: PEER_ID, port: 8123, scheme: 'http', path: '/status' } }));
  await ready;
  const second = guest.run(request('list', { operationId: 'b'.repeat(48) }));
  await new Promise(setImmediate);
  assert.equal(launched.length, 1);
  release();
  await Promise.all([first, second]);
  assert.equal(launched.length, 2);
});

test('peer selection uses exact stable IDs and only addresses from the peer map', () => {
  assert.equal(peerTarget(status, PEER_ID).address, PEER_IP);
  for (const id of ['nas', 'nas.attacker.example', '100.100.100.200', 'own-node']) assert.throws(() => peerTarget(status, id), /no longer available/);
  const invalid = { Peer: { key: { ID: PEER_ID, TailscaleIPs: ['127.0.0.1', '10.0.0.1'] } } };
  assert.throws(() => peerTarget(invalid, PEER_ID), /no longer available/);
});

async function socketServer(t, handler) {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'neo-ts-api-'));
  const socket = path.join(root, 'api.sock');
  const server = http.createServer(handler);
  const sockets = new Set();
  server.on('connection', (conn) => { sockets.add(conn); conn.once('close', () => sockets.delete(conn)); });
  await new Promise((resolve) => server.listen(socket, resolve));
  t.after(async () => {
    for (const conn of sockets) conn.destroy();
    await new Promise((resolve) => server.close(resolve));
    await fs.rm(root, { recursive: true, force: true });
  });
  return { server, socket };
}

test('dial refuses the non-tailnet Dial-Self fallback instead of using host networking', async (t) => {
  const { socket } = await socketServer(t, (_req, res) => { res.writeHead(200, { 'Dial-Self': 'true', 'Dial-Addr': '127.0.0.1:80' }); res.end(); });
  await assert.rejects(dialPeer(socket, PEER_IP, 8123), /did not provide a peer stream/);
});

test('HTTP transport uses the pinned peer stream, strips cookies, caps bodies and does not follow redirects', async (t) => {
  const peerCalls = [];
  const service = http.createServer((req, res) => {
    peerCalls.push({ path: req.url, host: req.headers.host });
    if (req.url === '/large') { res.writeHead(200); res.end('x'.repeat(600 * 1024)); }
    else { res.writeHead(302, { location: 'http://127.0.0.1/admin', 'set-cookie': 'private-cookie' }); res.end('redirect'); }
  });
  await new Promise((resolve) => service.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise((resolve) => service.close(resolve)));
  const { server, socket } = await socketServer(t);
  const targets = [];
  server.on('upgrade', (req, stream) => {
    targets.push({ host: req.headers['dial-host'], port: req.headers['dial-port'] });
    const upstream = net.connect(service.address().port, '127.0.0.1', () => {
      stream.write('HTTP/1.1 101 Switching Protocols\r\nConnection: Upgrade\r\nUpgrade: ts-dial\r\n\r\n');
      stream.pipe(upstream).pipe(stream);
    });
    stream.once('close', () => upstream.destroy());
  });
  const operation = { action: 'request', peerId: PEER_ID, port: 8123, scheme: 'http', method: 'GET', path: '/status', headers: {} };
  const response = await requestPeer(socket, status, operation);
  assert.equal(response.status, 302);
  assert.equal(response.headers['set-cookie'], undefined);
  assert.equal(peerCalls.length, 1);
  assert.deepEqual(targets[0], { host: PEER_IP, port: '8123' });
  assert.equal(peerCalls[0].host, 'nas.private.ts.net:8123');
  const large = await requestPeer(socket, status, { ...operation, path: '/large' });
  assert.equal(large.truncated, true);
  assert.equal(large.body.length, 512 * 1024);
});
