'use strict';

const assert = require('node:assert/strict');
const { after, before, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../helpers/db');
const { loginAs } = require('../helpers/app');
const { agent } = require('../helpers/supertest');
const { connectSocket, createSocketFixture } = require('../helpers/socket');

let ctx;
let fixture;

before(async () => {
  ctx = createTestRuntime();
  fixture = await createSocketFixture();
});

after(async () => {
  await fixture.close();
  teardownTestRuntime(ctx);
});

test('unauthenticated socket is disconnected', async () => {
  const socket = connectSocket(fixture.url);
  const disconnected = await new Promise((resolve) => {
    socket.on('disconnect', () => resolve(true));
    socket.on('connect_error', () => resolve(true));
    setTimeout(() => resolve(false), 1500);
  });
  socket.close();
  assert.equal(disconnected, true);
});

test('authenticated socket can request agent history', async () => {
  const user = await createTestUser(ctx.db, { username: 'socket_user' });
  const http = agent(fixture.app);
  const login = await loginAs(http, user);
  const cookie = login.headers['set-cookie'].map((item) => item.split(';')[0]).join('; ');
  const socket = connectSocket(fixture.url, cookie);
  await new Promise((resolve, reject) => {
    socket.on('connect', resolve);
    socket.on('connect_error', reject);
  });
  const history = await new Promise((resolve) => {
    socket.on('agent:history', resolve);
    socket.emit('agent:history', { limit: 5 });
  });
  socket.close();
  assert.ok(Array.isArray(history.runs));
  assert.equal(typeof history.agentId, 'string');
});
