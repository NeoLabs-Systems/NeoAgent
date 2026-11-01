'use strict';

const assert = require('node:assert/strict');
const { afterEach, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

let ctx;

afterEach(() => {
  teardownTestRuntime(ctx);
  ctx = null;
});

function addServer(userId, config) {
  return ctx.db.prepare('INSERT INTO mcp_servers (user_id, name, command, config) VALUES (?, ?, ?, ?)')
    .run(userId, 'test', 'https://mcp.example.com/mcp', JSON.stringify(config)).lastInsertRowid;
}

test('servers default to SSE with no extra headers', async () => {
  ctx = createTestRuntime();
  const { userId } = await createTestUser(ctx.db);
  const { buildTransportOptions } = require('../../../server/services/mcp/client_support');
  const options = buildTransportOptions(addServer(userId, {}));
  assert.equal(options.transport, 'sse');
  assert.deepEqual(options.requestInit.headers, {});
});

test('Streamable HTTP and extra headers come from the server config', async () => {
  ctx = createTestRuntime();
  const { userId } = await createTestUser(ctx.db);
  const { buildTransportOptions } = require('../../../server/services/mcp/client_support');
  const options = buildTransportOptions(addServer(userId, {
    transport: 'streamable-http',
    headers: { 'X-Api-Key': 'abc' },
    auth: { type: 'bearer', token: 'tok' },
  }));
  assert.equal(options.transport, 'streamable-http');
  assert.deepEqual(options.requestInit.headers, { 'X-Api-Key': 'abc', Authorization: 'Bearer tok' });
  assert.deepEqual(options.eventSourceInit.headers, { 'X-Api-Key': 'abc', Authorization: 'Bearer tok' });
});
