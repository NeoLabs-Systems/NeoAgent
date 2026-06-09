'use strict';

const assert = require('node:assert/strict');
const { afterEach, beforeEach, describe, test } = require('node:test');

const {
  createTestRuntime,
  createTestUser,
  teardownTestRuntime,
} = require('../../helpers/db');

function createDeferred() {
  let resolve;
  let reject;
  const promise = new Promise((resolvePromise, rejectPromise) => {
    resolve = resolvePromise;
    reject = rejectPromise;
  });
  return { promise, resolve, reject };
}

async function waitFor(predicate, timeoutMs = 500) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (predicate()) return;
    await new Promise((resolve) => setTimeout(resolve, 5));
  }
  throw new Error('Timed out waiting for condition');
}

describe('MCP client lifecycle', () => {
  let ctx;
  let user;
  let serverId;
  let MCPClient;
  let clients;
  let transports;

  beforeEach(async () => {
    ctx = createTestRuntime();
    user = await createTestUser(ctx.db);
    const { ensureMainAgent } = require('../../../server/services/agents/manager');
    const agentId = ensureMainAgent(user.userId).id;
    const insert = ctx.db.prepare(
      `INSERT INTO mcp_servers (user_id, agent_id, name, command, config, enabled)
       VALUES (?, ?, ?, ?, '{}', 1)`
    ).run(
      user.userId,
      agentId,
      'Test MCP',
      'https://mcp.example.test/sse',
    );
    serverId = Number(insert.lastInsertRowid);
    ({ MCPClient } = require('../../../server/services/mcp/client'));
    clients = [];
    transports = [];
  });

  afterEach(async () => {
    teardownTestRuntime(ctx);
  });

  function createClient(options = {}) {
    const client = {
      closed: false,
      async connect(transport) {
        return options.connect?.(transport);
      },
      async listTools() {
        if (options.listTools) return options.listTools();
        return { tools: [] };
      },
      async callTool(request) {
        return options.callTool?.(request) || { content: [] };
      },
      async close() {
        client.closed = true;
        return options.close?.();
      },
    };
    clients.push(client);
    return client;
  }

  function createTransport(options = {}) {
    const transport = {
      async finishAuth(code) {
        return options.finishAuth?.(code);
      },
    };
    transports.push(transport);
    return transport;
  }

  test('does not report running until tool discovery succeeds', async (t) => {
    const events = [];
    const mcp = new MCPClient({
      createTransport: () => createTransport(),
      createClient: () => createClient({
        listTools() {
          throw new Error('tool discovery failed');
        },
      }),
    });
    t.after(() => mcp.shutdown());
    mcp.on('server_status', (event) => events.push(event));

    await assert.rejects(
      mcp.startServer(
        serverId,
        'https://mcp.example.test/sse',
        'Test MCP',
        user.userId,
      ),
      /tool discovery failed/,
    );

    const status = mcp.getStatus(user.userId)[serverId];
    assert.equal(status.status, 'error');
    assert.match(status.error, /tool discovery failed/);
    assert.equal(status.toolCount, 0);
    assert.equal(clients[0].closed, true);
    assert.equal(
      ctx.db.prepare('SELECT status FROM mcp_servers WHERE id = ?').get(serverId).status,
      'error',
    );
    assert.equal(events.some((event) => event.status === 'running'), false);
  });

  test('times out a hung connection and leaves a truthful error state', async (t) => {
    const mcp = new MCPClient({
      operationTimeoutMs: 10,
      createTransport: () => createTransport(),
      createClient: () => createClient({
        connect: () => new Promise(() => {}),
      }),
    });
    t.after(() => mcp.shutdown());

    await assert.rejects(
      mcp.startServer(
        serverId,
        'https://mcp.example.test/sse',
        'Test MCP',
        user.userId,
      ),
      /timed out after 10 ms/,
    );

    const status = mcp.getStatus(user.userId)[serverId];
    assert.equal(status.status, 'error');
    assert.match(status.error, /timed out/);
    assert.equal(clients[0].closed, true);
  });

  test('loads tools atomically and accepts route-shaped string IDs', async (t) => {
    const mcp = new MCPClient({
      createTransport: () => createTransport(),
      createClient: () => createClient({
        listTools: () => ({
          tools: [{ name: 'search', inputSchema: { type: 'object' } }],
        }),
      }),
    });
    t.after(() => mcp.shutdown());

    const result = await mcp.startServer(
      serverId,
      'https://mcp.example.test/sse',
      'Test MCP',
      user.userId,
    );

    assert.equal(result.status, 'running');
    assert.equal(result.tools.length, 1);
    assert.equal((await mcp.listTools(String(serverId), user.userId)).length, 1);
    assert.equal(mcp.getStatus(user.userId)[serverId].toolCount, 1);
    assert.deepEqual(await mcp.stopServer(String(serverId)), { status: 'stopped' });
    assert.equal(mcp.servers.size, 0);
    assert.equal(clients[0].closed, true);
  });

  test('OAuth completion propagates reconnect failure instead of reporting success', async (t) => {
    let connectCount = 0;
    const events = [];
    const mcp = new MCPClient({
      createTransport: () => createTransport(),
      createClient: () => createClient({
        connect() {
          connectCount += 1;
          if (connectCount === 1) {
            throw new Error('OAUTH_REDIRECT:https://auth.example.test/authorize');
          }
          throw new Error('token exchange connection failed');
        },
      }),
    });
    t.after(() => mcp.shutdown());
    mcp.on('server_status', (event) => events.push(event));

    await assert.rejects(
      mcp.startServer(
        serverId,
        'https://mcp.example.test/sse',
        'Test MCP',
        user.userId,
      ),
      /OAUTH_REDIRECT:/,
    );
    assert.equal(mcp.getStatus(user.userId)[serverId].status, 'auth_required');
    assert.equal(clients[0].closed, false);

    await assert.rejects(
      mcp.finishOAuth(serverId, 'authorization-code'),
      /token exchange connection failed/,
    );

    assert.equal(mcp.getStatus(user.userId)[serverId].status, 'error');
    assert.equal(events.some((event) => event.status === 'running'), false);
  });

  test('OAuth state is server-bound, expiring, and single-use', () => {
    const {
      DBAuthProvider,
      consumeOAuthState,
    } = require('../../../server/services/mcp/client_support');
    ctx.db.prepare('UPDATE mcp_servers SET config = ? WHERE id = ?').run(
      JSON.stringify({
        auth: {
          type: 'oauth',
          clientId: 'client-id',
          authServerUrl: 'https://auth.example.test',
        },
      }),
      serverId,
    );
    const provider = new DBAuthProvider(
      serverId,
      'client-id',
      'https://auth.example.test',
    );

    const state = provider.state();

    assert.equal(consumeOAuthState(serverId, `${serverId}::${'0'.repeat(32)}`), false);
    assert.equal(consumeOAuthState(serverId, state), true);
    assert.equal(consumeOAuthState(serverId, state), false);

    const expiredState = provider.state();
    const stored = JSON.parse(
      ctx.db.prepare('SELECT config FROM mcp_servers WHERE id = ?').get(serverId).config,
    );
    stored.auth.oauthStateCreatedAt = '2000-01-01T00:00:00.000Z';
    ctx.db.prepare('UPDATE mcp_servers SET config = ? WHERE id = ?')
      .run(JSON.stringify(stored), serverId);
    assert.equal(consumeOAuthState(serverId, expiredState), false);
  });

  test('retries with preserved failure history and recovers automatically', async (t) => {
    let clientCount = 0;
    const mcp = new MCPClient({
      reconnectDelayMs: 5,
      maxReconnectDelayMs: 5,
      createTransport: () => createTransport(),
      createClient: () => {
        clientCount += 1;
        if (clientCount < 3) {
          return createClient({
            connect() {
              throw new Error(`temporary failure ${clientCount}`);
            },
          });
        }
        return createClient({
          listTools: () => ({ tools: [{ name: 'recovered' }] }),
        });
      },
    });
    t.after(() => mcp.shutdown());

    const results = await mcp.loadFromDB(user.userId);
    assert.equal(results[0].status, 'reconnecting');

    await waitFor(
      () => mcp.getStatus(user.userId)[serverId]?.status === 'running',
    );

    const status = mcp.getStatus(user.userId)[serverId];
    assert.equal(clientCount, 3);
    assert.equal(status.status, 'running');
    assert.equal(status.consecutiveFails, 0);
    assert.equal(status.toolCount, 1);
    assert.equal(status.nextRetryAt, null);
  });

  test('reconnects after repeated MCP tool failures', async (t) => {
    const mcp = new MCPClient({
      toolFailureThreshold: 2,
      reconnectDelayMs: 60_000,
      maxReconnectDelayMs: 60_000,
      createTransport: () => createTransport(),
      createClient: () => createClient({
        callTool() {
          throw new Error('remote tool unavailable');
        },
      }),
    });
    t.after(() => mcp.shutdown());
    await mcp.startServer(
      serverId,
      'https://mcp.example.test/sse',
      'Test MCP',
      user.userId,
    );

    await assert.rejects(
      mcp.callTool(serverId, 'search', {}, user.userId),
      /remote tool unavailable/,
    );
    assert.equal(mcp.getStatus(user.userId)[serverId].status, 'running');
    assert.equal(mcp.getStatus(user.userId)[serverId].consecutiveFails, 1);

    await assert.rejects(
      mcp.callTool(serverId, 'search', {}, user.userId),
      /remote tool unavailable/,
    );
    const status = mcp.getStatus(user.userId)[serverId];
    assert.equal(status.status, 'reconnecting');
    assert.equal(status.consecutiveFails, 2);
    assert.ok(status.nextRetryAt);
  });

  test('shutdown prevents an in-flight reconnect from reviving a server', async (t) => {
    const reconnectStarted = createDeferred();
    const reconnectRelease = createDeferred();
    let clientCount = 0;
    const events = [];
    const mcp = new MCPClient({
      reconnectDelayMs: 1,
      maxReconnectDelayMs: 1,
      createTransport: () => createTransport(),
      createClient: () => {
        clientCount += 1;
        if (clientCount === 1) {
          return createClient({
            connect() {
              throw new Error('initial failure');
            },
          });
        }
        return createClient({
          async connect() {
            reconnectStarted.resolve();
            await reconnectRelease.promise;
          },
          listTools: () => ({ tools: [{ name: 'late-tool' }] }),
        });
      },
    });
    t.after(() => mcp.shutdown());
    mcp.on('server_status', (event) => events.push(event));

    await mcp.loadFromDB(user.userId);
    await waitFor(() => clientCount === 2);
    await reconnectStarted.promise;
    await mcp.shutdown();
    const runningEventsBeforeRelease = events.filter(
      (event) => event.status === 'running',
    ).length;

    reconnectRelease.resolve();
    await new Promise((resolve) => setTimeout(resolve, 20));

    assert.equal(mcp.servers.size, 0);
    assert.equal(mcp._reconnectTimers.size, 0);
    assert.equal(
      events.filter((event) => event.status === 'running').length,
      runningEventsBeforeRelease,
    );
    assert.equal(clients[1].closed, true);
  });
});
