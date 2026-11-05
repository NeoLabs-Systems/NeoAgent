'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');
const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

function deferred() {
  let resolve;
  let reject;
  const promise = new Promise((done, fail) => { resolve = done; reject = fail; });
  return { promise, resolve, reject };
}

async function fixture(t) {
  const ctx = createTestRuntime();
  const calls = [];
  const runtime = {
    computerBackend: { vmManager: {} },
    async requestComputer(userId, method, path, body, options) {
      calls.push({ userId, method, path, body, options });
      if (path.endsWith('/cancel')) return { canceled: true };
      if (body?.action === 'login') return { loginUrl: 'https://login.tailscale.com/a/test-login', status: 'connecting' };
      const nodeId = body?.nodeId || `node-${userId}`;
      return {
        status: 'connected', nodeId, tailnet: `tailnet-${userId}`, state: Buffer.from(`state-${userId}-${calls.length}`).toString('base64'),
        result: body?.action === 'request' ? { body: `private-data-${userId}` } : { peers: [{ id: 'same-peer-id', name: 'nas', dnsName: 'nas.ts.net', online: true }] },
      };
    },
  };
  const app = { locals: { runtimeManager: runtime } };
  const { IntegrationManager } = require('../../../server/services/integrations/manager');
  const manager = new IntegrationManager({ app });
  app.locals.integrationManager = manager;
  t.after(async () => {
    await manager.shutdown();
    teardownTestRuntime(ctx);
  });
  const { ensureMainAgent, createAgent } = require('../../../server/services/agents/manager');
  const users = await Promise.all([createTestUser(ctx.db), createTestUser(ctx.db)]);
  const agents = users.map((user) => ensureMainAgent(user.userId));
  const provider = manager.getProvider('tailscale');
  const { upsertAccountApp } = require('../../../server/services/integrations/connection_store');
  const services = [{ peerId: 'same-peer-id', port: 8123, scheme: 'http', path: '/api/status?view=full', methods: ['GET', 'POST'] }];
  const connections = users.map((user, index) => {
    return upsertAccountApp({
      userId: user.userId, agentId: agents[index].id, providerKey: 'tailscale', appKey: 'tailnet', accountEmail: `tailscale:${user.userId}`,
      credentials: { nodeId: `node-${user.userId}`, state: Buffer.from(`original-${user.userId}`).toString('base64') }, metadata: { services },
    });
  });
  return { ctx, manager, provider, runtime, calls, users, agents, connections, createAgent, services };
}

test('Connect opens Tailscale sign-in without an OAuth app or pasted credentials and persists only scoped node state', async (t) => {
  const { manager, provider, users, agents, calls } = await fixture(t);
  assert.equal(provider.saveUserConfig, undefined);
  const started = await manager.beginOAuth(users[0].userId, 'tailscale', { appKey: 'tailnet', agentId: agents[0].id });
  assert.equal(started.status, 'interactive_connect');
  assert.equal(new URL(started.loginUrl).origin, 'https://login.tailscale.com');
  assert.equal(calls[0].body.action, 'login');
  assert.equal(calls[0].body.authKey, undefined);
  assert.equal(calls[0].options.deviceTarget, 'cloud');
  assert.equal(await manager.getConnectionSession(users[1].userId, 'tailscale', started.sessionId, agents[1].id), null);
  assert.equal(calls.length, 1);
  const result = await manager.getConnectionSession(users[0].userId, 'tailscale', started.sessionId, agents[0].id);
  assert.equal(result.status, 'connected');
  const row = manager.getConnectionById(users[0].userId, result.connectionId, agents[0].id);
  assert.match(row.credentials_json, /^enc:v1:/);
  assert.equal(manager.parseCredentials(row.credentials_json).access_token, undefined);
  assert.equal(JSON.parse(row.metadata_json).access_mode, 'read_only');
  assert.deepEqual(JSON.parse(row.metadata_json).services, []);
  assert.equal(result.state, undefined);
});

test('identical peer IDs and addresses remain isolated by the authenticated user VM and connection state', async (t) => {
  const { manager, users, agents, connections, calls } = await fixture(t);
  for (let index = 0; index < 2; index += 1) {
    const result = await manager.executeTool(users[index].userId, 'tailscale_request', {
      connection_id: connections[index].id, peer_id: 'same-peer-id', port: 8123, scheme: 'http', path: '/api/status?view=full',
    }, agents[index].id);
    assert.equal(result.body, `private-data-${users[index].userId}`);
    assert.equal(calls[index].userId, users[index].userId);
    assert.equal(calls[index].body.nodeId, `node-${users[index].userId}`);
    assert.equal(calls[index].options.deviceTarget, 'cloud');
    assert.equal(calls[index].options.retryCount, 0);
  }
  assert.notEqual(calls[0].body.state, calls[1].body.state);
  assert.notEqual(calls[0].body.operationId, calls[1].body.operationId);
});

test('cross-user and cross-agent connection IDs never reach a VM', async (t) => {
  const { manager, provider, users, agents, connections, calls, createAgent } = await fixture(t);
  const result = await manager.executeTool(users[1].userId, 'tailscale_list_peers', { connection_id: connections[0].id }, agents[1].id);
  assert.match(result.error, /No connected/);
  await assert.rejects(provider.getServiceAccess({ userId: users[1].userId, agentId: agents[1].id, connectionId: connections[0].id }), /not available/);
  const other = createAgent(users[0].userId, { displayName: 'Other agent' });
  const wrongAgent = await manager.executeTool(users[0].userId, 'tailscale_list_peers', { connection_id: connections[0].id }, other.id);
  assert.ok(wrongAgent.error);
  assert.equal(calls.length, 0);
});

test('service grants match exact peer, port, scheme, method, path and query', async (t) => {
  const { manager, users, agents, connections, calls } = await fixture(t);
  const args = { connection_id: connections[0].id, peer_id: 'same-peer-id', port: 8123, scheme: 'http', path: '/api/status?view=full', method: 'GET' };
  for (const change of [{ peer_id: 'other' }, { port: 80 }, { scheme: 'https' }, { method: 'DELETE' }, { path: '/api/status' }, { path: '/api/status?view=other' }]) {
    const result = await manager.executeTool(users[0].userId, 'tailscale_request', { ...args, ...change }, agents[0].id);
    assert.match(result.error, /not been granted/);
  }
  assert.equal(calls.length, 0);
});

test('read-only blocks even GET operations and retains peer inventory', async (t) => {
  const { ctx, manager, users, agents, connections, calls } = await fixture(t);
  const metadata = { ...JSON.parse(connections[0].metadata_json), access_mode: 'read_only' };
  ctx.db.prepare('UPDATE integration_connections SET metadata_json = ? WHERE id = ?').run(JSON.stringify(metadata), connections[0].id);
  const result = await manager.executeTool(users[0].userId, 'tailscale_request', { connection_id: connections[0].id, method: 'GET' }, agents[0].id);
  assert.match(result.error, /read-only/);
  assert.equal(calls.length, 0);
  assert.ok((await manager.executeTool(users[0].userId, 'tailscale_list_peers', { connection_id: connections[0].id }, agents[0].id)).peers);
});

test('queued operations resume with the latest encrypted node state', async (t) => {
  const { manager, users, agents, connections, runtime, calls } = await fixture(t);
  const entered = deferred();
  const release = deferred();
  const request = runtime.requestComputer.bind(runtime);
  let count = 0;
  runtime.requestComputer = async (...args) => {
    if (++count === 1) { entered.resolve(); await release.promise; }
    return request(...args);
  };
  const execute = () => manager.executeTool(users[0].userId, 'tailscale_list_peers', { connection_id: connections[0].id }, agents[0].id);
  const first = execute();
  await entered.promise;
  const second = execute();
  release.resolve();
  await Promise.all([first, second]);
  assert.equal(calls.length, 2);
  assert.equal(Buffer.from(calls[1].body.state, 'base64').toString(), `state-${users[0].userId}-1`);
});

test('disconnect fences queued calls and cancels VM activity before deleting credentials', async (t) => {
  const { ctx, manager, runtime, calls, users, agents, connections } = await fixture(t);
  const entered = deferred();
  const request = runtime.requestComputer.bind(runtime);
  runtime.requestComputer = async (...args) => {
    if (args[2].endsWith('/cancel')) {
      assert.equal(ctx.db.prepare('SELECT status FROM integration_connections WHERE id = ?').get(connections[0].id)?.status, 'disconnecting');
      return request(...args);
    }
    if (args[3].action === 'logout') return request(...args);
    entered.resolve();
    return new Promise((_resolve, reject) => args[4].signal.addEventListener('abort', () => reject(args[4].signal.reason), { once: true }));
  };
  const execute = () => manager.executeTool(users[0].userId, 'tailscale_list_peers', { connection_id: connections[0].id }, agents[0].id).catch((error) => ({ error: error.message }));
  const active = execute();
  await entered.promise;
  const queued = execute();
  await manager.disconnect(users[0].userId, 'tailscale', { connectionId: connections[0].id, agentId: agents[0].id });
  await active;
  assert.ok((await queued).error);
  assert.ok(calls.some((call) => call.path.endsWith('/cancel')));
  assert.equal(manager.getConnectionById(users[0].userId, connections[0].id, agents[0].id), undefined);
});

test('service revocation persists deny-all and connection tests preserve current grants', async (t) => {
  const { ctx, provider, manager, users, agents, connections } = await fixture(t);
  await provider.setServiceAccess({ userId: users[0].userId, agentId: agents[0].id, connectionId: connections[0].id, services: [] });
  manager.updateConnectionTestMetadata(connections[0], 'passed');
  const row = ctx.db.prepare('SELECT metadata_json FROM integration_connections WHERE id = ?').get(connections[0].id);
  assert.deepEqual(JSON.parse(row.metadata_json).services, []);
});

test('host-backed runtimes are refused instead of falling back to the server network', async (t) => {
  const { manager, runtime, users, agents, connections, calls } = await fixture(t);
  runtime.computerBackend.vmManager = null;
  await assert.rejects(manager.beginOAuth(users[0].userId, 'tailscale', { appKey: 'tailnet', agentId: agents[0].id }), /isolated per-user/);
  const result = await manager.executeTool(users[0].userId, 'tailscale_list_peers', { connection_id: connections[0].id }, agents[0].id);
  assert.match(result.error, /isolated per-user/);
  assert.equal(calls.length, 0);
});

test('sign-in cancellation is scoped and late approval cannot recreate a canceled connection', async (t) => {
  const { manager, provider, runtime, users, agents, calls } = await fixture(t);
  const started = await manager.beginOAuth(users[0].userId, 'tailscale', { appKey: 'tailnet', agentId: agents[0].id });
  await provider.cancelConnectionSession(users[1].userId, agents[1].id, started.sessionId);
  assert.equal(calls.length, 1);
  const original = runtime.requestComputer.bind(runtime);
  const ready = deferred();
  const response = deferred();
  runtime.requestComputer = (...args) => {
    if (args[2].endsWith('/login-status')) { ready.resolve(); return response.promise; }
    return original(...args);
  };
  const count = manager.listConnections(users[0].userId, 'tailscale', agents[0].id).length;
  const poll = manager.getConnectionSession(users[0].userId, 'tailscale', started.sessionId, agents[0].id);
  await ready.promise;
  await provider.cancelConnectionSession(users[0].userId, agents[0].id, started.sessionId);
  response.resolve({ status: 'connected', nodeId: 'late-node', tailnet: 'private', state: Buffer.from('late-state').toString('base64') });
  await poll;
  assert.equal(manager.listConnections(users[0].userId, 'tailscale', agents[0].id).length, count);
  assert.equal(await manager.getConnectionSession(users[0].userId, 'tailscale', started.sessionId, agents[0].id), null);
});

test('a non-Tailscale sign-in URL is refused and its temporary client is canceled', async (t) => {
  const { manager, runtime, users, agents, calls } = await fixture(t);
  const original = runtime.requestComputer.bind(runtime);
  runtime.requestComputer = (...args) => args[3]?.action === 'login'
    ? Promise.resolve({ loginUrl: 'https://attacker.example/login' }) : original(...args);
  await assert.rejects(manager.beginOAuth(users[0].userId, 'tailscale', { appKey: 'tailnet', agentId: agents[0].id }), /invalid sign-in URL/);
  assert.ok(calls.some((call) => call.path.endsWith('/cancel')));
});
