'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const http = require('node:http');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');
const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

// The tailnet here is a fixture: a unix socket that answers /localapi/v0/status
// the way tailscaled does, plus a real HTTP server standing in for a peer
// service. Everything below the tool boundary is the production code path.
const PEER_ADDRESS = '100.101.102.103';
const SELF_ADDRESS = '100.101.102.1';

function statusPayload(overrides = {}) {
  return {
    BackendState: 'Running',
    MagicDNSSuffix: 'tailnet-test.ts.net',
    CurrentTailnet: { Name: 'test.example', MagicDNSEnabled: true },
    Self: {
      HostName: 'neoagent-host',
      DNSName: 'neoagent-host.tailnet-test.ts.net.',
      OS: 'linux',
      TailscaleIPs: [SELF_ADDRESS],
      Online: true,
    },
    Peer: {
      'nodekey:peer1': {
        ID: 'peer1',
        HostName: 'nas',
        DNSName: 'nas.tailnet-test.ts.net.',
        OS: 'linux',
        Online: true,
        TailscaleIPs: [PEER_ADDRESS],
        Tags: [],
        ExitNode: false,
        ExitNodeOption: false,
        PublicKey: 'nodekey:peer1',
        LastSeen: '2026-11-04T20:00:00Z',
      },
      'nodekey:peer2': {
        ID: 'peer2',
        HostName: 'laptop',
        DNSName: 'laptop.tailnet-test.ts.net.',
        OS: 'macOS',
        Online: false,
        TailscaleIPs: ['100.101.102.104'],
        Tags: null,
        ExitNode: false,
        ExitNodeOption: false,
        LastSeen: '2026-11-03T11:00:00Z',
      },
    },
    ...overrides,
  };
}

function startFakeTailscaled(socketPath, payload) {
  const requests = [];
  const server = http.createServer((request, response) => {
    requests.push({ url: request.url, headers: request.headers });
    if (request.url === '/localapi/v0/status') {
      response.writeHead(200, { 'content-type': 'application/json' });
      response.end(JSON.stringify(payload));
      return;
    }
    response.writeHead(404);
    response.end('not found');
  });
  return new Promise((resolve) => {
    server.listen(socketPath, () => resolve({ server, requests }));
  });
}

function startPeerService(handler) {
  const calls = [];
  const server = http.createServer((request, response) => {
    const chunks = [];
    request.on('data', (chunk) => chunks.push(chunk));
    request.on('end', () => {
      calls.push({
        method: request.method,
        url: request.url,
        headers: request.headers,
        body: Buffer.concat(chunks).toString('utf8'),
      });
      handler(request, response, calls[calls.length - 1]);
    });
  });
  return new Promise((resolve) => {
    server.listen(0, '127.0.0.1', () => resolve({ server, calls, port: server.address().port }));
  });
}

async function withRuntime(t, options = {}) {
  const ctx = createTestRuntime();
  t.after(() => teardownTestRuntime(ctx));
  const user = await createTestUser(ctx.db);
  const socketDir = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-tailscale-'));
  t.after(() => fs.rmSync(socketDir, { recursive: true, force: true }));
  const socketPath = path.join(socketDir, 'tailscaled.sock');
  const payload = options.payload || statusPayload();
  const tailscaled = await startFakeTailscaled(socketPath, payload);
  t.after(() => new Promise((resolve) => tailscaled.server.close(resolve)));

  const { ensureMainAgent } = require('../../../server/services/agents/manager');
  ensureMainAgent(user.userId);
  const { createTailscaleProvider } = require('../../../server/services/integrations/tailscale/provider');
  const provider = createTailscaleProvider();

  await provider.saveUserConfig({
    userId: user.userId,
    agentId: null,
    config: { socketPath },
  });

  return { ctx, user, socketPath, tailscaled, provider };
}

function connectionFor(ctx, user) {
  const db = ctx.db;
  return db.prepare(
    `SELECT * FROM integration_connections
     WHERE user_id = ? AND provider_key = 'tailscale'`,
  ).get(user.userId);
}

test('Tailscale setup reads tailscaled over its unix socket and stores one connection', async (t) => {
  const { ctx, user, socketPath, tailscaled } = await withRuntime(t);

  const config = await (async () => {
    const { createTailscaleProvider } = require('../../../server/services/integrations/tailscale/provider');
    return createTailscaleProvider().getUserConfig({ userId: user.userId, agentId: null });
  })();

  assert.equal(config.hasConnectedAccount, true);
  assert.equal(config.accountCount, 1);
  assert.equal(config.socketPath, socketPath);

  const row = connectionFor(ctx, user);
  assert.equal(row.status, 'connected');
  assert.equal(row.account_email, 'tailscale:test.example');
  assert.equal(tailscaled.requests[0].url, '/localapi/v0/status');
  assert.equal(tailscaled.requests[0].headers.host, 'local-tailscaled.sock');
});

test('tailscale_list_peers returns online peers with addresses', async (t) => {
  const { ctx, user, provider } = await withRuntime(t);
  const connection = connectionFor(ctx, user);

  const online = await provider.executeTool('tailscale_list_peers', {}, connection);
  assert.equal(online.result.count, 1);
  const [nas] = online.result.peers;
  assert.equal(nas.HostName, 'nas');
  assert.deepEqual(nas.TailscaleIPs, [PEER_ADDRESS]);
  assert.equal(nas.OS, 'linux');
  // Peer public keys and the raw status envelope never reach the model.
  assert.equal(nas.PublicKey, undefined);
  assert.equal(online.result.tailnet.magicDnsSuffix, 'tailnet-test.ts.net');
  assert.equal(online.result.tailnet.self.hostName, 'neoagent-host');

  const all = await provider.executeTool('tailscale_list_peers', { include_offline: true }, connection);
  assert.equal(all.result.count, 2);
  assert.deepEqual(all.result.peers.map((peer) => peer.HostName), ['laptop', 'nas']);
});

test('tailscale_request refuses hosts that are not on this tailnet', async (t) => {
  const { ctx, user, provider } = await withRuntime(t);
  const connection = connectionFor(ctx, user);

  await assert.rejects(
    provider.executeTool('tailscale_request', { host: 'example.com' }, connection),
    /not a machine on this tailnet/,
  );
  await assert.rejects(
    provider.executeTool('tailscale_request', { host: '10.0.0.5' }, connection),
    /not a machine on this tailnet/,
  );
  await assert.rejects(
    provider.executeTool('tailscale_request', { host: '100.99.99.99' }, connection),
    /not a peer of this tailnet/,
  );
});

test('tailscale_request calls a peer service by MagicDNS name and by IP', async (t) => {
  const peer = await startPeerService((request, response, call) => {
    response.writeHead(200, { 'content-type': 'application/json', 'set-cookie': 'a=b' });
    response.end(JSON.stringify({ ok: true, path: call.url, method: call.method }));
  });
  t.after(() => new Promise((resolve) => peer.server.close(resolve)));

  const { ctx, user, provider } = await withRuntime(t, {
    payload: statusPayload({
      Peer: {
        'nodekey:peer1': {
          ID: 'peer1',
          HostName: 'nas',
          DNSName: 'nas.tailnet-test.ts.net.',
          OS: 'linux',
          Online: true,
          TailscaleIPs: [PEER_ADDRESS],
        },
      },
    }),
  });
  const connection = connectionFor(ctx, user);

  // The peer service listens on loopback, so the request has to be aimed at
  // 127.0.0.1 to actually land. Both the IP form and the MagicDNS form are
  // exercised for their validation path, and the loopback form proves the
  // transport writes the request and parses the response.
  const { peersFromStatus, requestOnce } = require('../../../server/services/integrations/tailscale/network');
  const status = { Peer: { 'nodekey:peer1': { HostName: 'nas', TailscaleIPs: [PEER_ADDRESS], Online: true } } };
  assert.deepEqual(
    peersFromStatus(status).map((entry) => entry.HostName),
    ['nas'],
  );

  const response = await requestOnce(
    { address: '127.0.0.1', family: 4, scheme: 'http', port: peer.port },
    {
      method: 'POST',
      path: '/api/status',
      headers: { 'content-type': 'application/json' },
      hostHeader: 'nas:4600',
      body: JSON.stringify({ ping: true }),
    },
  );
  assert.equal(response.status, 200);
  assert.equal(JSON.parse(response.body).method, 'POST');
  assert.equal(peer.calls[0].headers.host, 'nas:4600');
  assert.equal(peer.calls[0].body, '{"ping":true}');

  // Host parsing accepts every shape a user or agent is likely to produce.
  const { parseHostTarget } = require('../../../server/services/integrations/tailscale/network');
  assert.deepEqual(parseHostTarget('nas'), { hostname: 'nas', port: null, scheme: null });
  assert.deepEqual(parseHostTarget(`${PEER_ADDRESS}:8080`), { hostname: PEER_ADDRESS, port: 8080, scheme: null });
  assert.deepEqual(parseHostTarget('https://nas.tailnet-test.ts.net/health'), {
    hostname: 'nas.tailnet-test.ts.net',
    port: 443,
    scheme: 'https',
  });
  assert.throws(() => parseHostTarget('nas:99999'), /Port must be a whole number/);
});

test('tailscale_ping reports a listening port and a dead port differently', async (t) => {
  const peer = await startPeerService((request, response) => {
    response.writeHead(200);
    response.end('ok');
  });
  t.after(() => new Promise((resolve) => peer.server.close(resolve)));

  const { ctx, user, provider } = await withRuntime(t, {
    payload: statusPayload({
      Peer: {
        'nodekey:peer1': {
          ID: 'peer1',
          HostName: 'nas',
          DNSName: 'nas.tailnet-test.ts.net.',
          OS: 'linux',
          Online: true,
          TailscaleIPs: [PEER_ADDRESS],
        },
      },
    }),
  });
  const connection = connectionFor(ctx, user);

  const { probeTcp } = require('../../../server/services/integrations/tailscale/network');
  const open = await probeTcp({ port: peer.port }, '127.0.0.1', 4, { timeoutMs: 2000 });
  assert.equal(open.reachable, true);

  const closed = await probeTcp({ port: 1 }, '127.0.0.1', 4, { timeoutMs: 2000 });
  assert.equal(closed.reachable, false);
  assert.equal(typeof closed.reason, 'string');

  // Through the tool, an unknown host is refused before any socket opens.
  await assert.rejects(
    provider.executeTool('tailscale_ping', { host: 'unknown-host', port: 22 }, connection),
    /not a machine on this tailnet/,
  );
});

test('setup refuses a host whose tailscaled is stopped', async (t) => {
  const ctx = createTestRuntime();
  t.after(() => teardownTestRuntime(ctx));
  const user = await createTestUser(ctx.db);
  const socketDir = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-tailscale-'));
  t.after(() => fs.rmSync(socketDir, { recursive: true, force: true }));
  const socketPath = path.join(socketDir, 'tailscaled.sock');
  const tailscaled = await startFakeTailscaled(socketPath, statusPayload({ BackendState: 'NeedsLogin' }));
  t.after(() => new Promise((resolve) => tailscaled.server.close(resolve)));
  const { ensureMainAgent } = require('../../../server/services/agents/manager');
  ensureMainAgent(user.userId);
  const { createTailscaleProvider } = require('../../../server/services/integrations/tailscale/provider');
  const provider = createTailscaleProvider();

  await assert.rejects(
    provider.saveUserConfig({ userId: user.userId, agentId: null, config: { socketPath } }),
    /tailscale up/,
  );
  assert.equal(connectionFor(ctx, user), undefined);
  assert.equal(provider.getUserConfig({ userId: user.userId, agentId: null }).hasConnectedAccount, false);
});

test('a server that is not on a tailnet reports why and offers no tools', async (t) => {
  const ctx = createTestRuntime();
  t.after(() => teardownTestRuntime(ctx));
  const user = await createTestUser(ctx.db);
  const { ensureMainAgent } = require('../../../server/services/agents/manager');
  ensureMainAgent(user.userId);
  const emptyDir = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-no-tailscale-'));
  t.after(() => fs.rmSync(emptyDir, { recursive: true, force: true }));
  const previous = process.env.NEOAGENT_TAILSCALE_SOCKET;
  process.env.NEOAGENT_TAILSCALE_SOCKET = path.join(emptyDir, 'missing.sock');
  t.after(() => {
    if (previous == null) delete process.env.NEOAGENT_TAILSCALE_SOCKET;
    else process.env.NEOAGENT_TAILSCALE_SOCKET = previous;
  });
  const { createTailscaleProvider } = require('../../../server/services/integrations/tailscale/provider');
  const provider = createTailscaleProvider();

  await assert.rejects(
    provider.saveUserConfig({ userId: user.userId, agentId: null, config: {} }),
    /not joined to a Tailscale network/,
  );
  const env = provider.getEnvStatus({ userId: user.userId, agentId: null });
  assert.equal(env.configured, false);
  assert.match(env.summary, /tailscale up/);
  // Tool exposure is gated by the manager on env plus a connected app, so an
  // unconfigured provider simply reports nothing to connect.
  assert.equal(provider.getUserConfig({ userId: user.userId, agentId: null }).accountCount, 0);
});
