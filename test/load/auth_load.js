'use strict';

const { createServer } = require('node:http');
const { once } = require('node:events');
const autocannon = require('autocannon');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../helpers/db');
const { createTestApp, loginAs } = require('../helpers/app');
const { agent } = require('../helpers/supertest');

async function runAutocannon(options) {
  return autocannon({ connections: 4, ...options });
}

function assertHealthy(result, label) {
  if (result.errors > 0) {
    throw new Error(`${label} had ${result.errors} request errors`);
  }
  if (result.non2xx > 0) {
    throw new Error(`${label} had ${result.non2xx} non-2xx responses`);
  }
  if (result.latency.p99 > 750) {
    throw new Error(`${label} p99 latency ${result.latency.p99}ms exceeded 750ms`);
  }
}

async function main() {
  const ctx = createTestRuntime();
  const { app } = createTestApp();
  const server = createServer(app);
  try {
    server.listen(0, '127.0.0.1');
    await once(server, 'listening');
    const baseUrl = `http://127.0.0.1:${server.address().port}`;
    const status = await runAutocannon({ url: `${baseUrl}/api/auth/status`, connections: 10, duration: 3 });
    assertHealthy(status, 'auth status');

    const user = await createTestUser(ctx.db, { username: 'load_user' });
    const http = agent(app);
    const login = await loginAs(http, user);
    const cookie = login.headers['set-cookie'].map((item) => item.split(';')[0]).join('; ');
    const profile = await runAutocannon({
      url: `${baseUrl}/api/agent-profiles`,
      connections: 10,
      duration: 3,
      headers: { Cookie: cookie },
    });
    assertHealthy(profile, 'agent profiles');

    const wrongLogin = await runAutocannon({
      url: `${baseUrl}/api/auth/login`,
      method: 'POST',
      connections: 1,
      amount: 10,
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ username: 'missing', password: 'wrong' }),
      expectBody: undefined,
    });
    if (wrongLogin.errors > 0 || wrongLogin.latency.p99 > 1000) {
      throw new Error('invalid login load threshold exceeded');
    }
  } finally {
    await new Promise((resolve) => server.close(resolve));
    teardownTestRuntime(ctx);
  }
}

if (require.main === module) {
  main().catch((err) => {
    console.error(err);
    process.exitCode = 1;
  });
}
