'use strict';

const assert = require('node:assert/strict');
const { after, before, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../helpers/db');
const { loginAs } = require('../helpers/app');
const { agent } = require('../helpers/supertest');
const { connectSocket, createSocketFixture } = require('../helpers/socket');

let ctx;
let fixture;
let accepted;
let declined;

before(async () => {
  ctx = createTestRuntime();
  fixture = await createSocketFixture({
    agentCallCoordinator: {
      async accept(callId, userId, socket) {
        accepted = { callId, userId, socketId: socket.id };
        return { accepted: true, status: 'accepted', sessionId: callId };
      },
      decline(callId, userId, socket) {
        declined = { callId, userId, socketId: socket.id };
        return { declined: true, status: 'declined' };
      },
      handleDisconnect() {},
    },
  });
});

after(async () => {
  await fixture.close();
  teardownTestRuntime(ctx);
});

async function authenticatedSocket(username) {
  const user = await createTestUser(ctx.db, { username });
  const http = agent(fixture.app);
  const login = await loginAs(http, user);
  const cookie = login.headers['set-cookie'].map((item) => item.split(';')[0]).join('; ');
  const socket = connectSocket(fixture.url, cookie);
  await new Promise((resolve, reject) => {
    socket.on('connect', resolve);
    socket.on('connect_error', reject);
  });
  return { socket, user };
}

test('authenticated clients can accept and decline only well-formed call ids', async () => {
  const { socket, user } = await authenticatedSocket('agent_call_socket_user');
  socket.emit('voice:call_accept', { callId: 'call-accept' });
  socket.emit('voice:call_decline', { callId: 'call-decline' });

  await new Promise((resolve) => setTimeout(resolve, 30));
  assert.deepEqual(accepted, {
    callId: 'call-accept',
    userId: user.userId,
    socketId: socket.id,
  });
  assert.deepEqual(declined, {
    callId: 'call-decline',
    userId: user.userId,
    socketId: socket.id,
  });

  const error = await new Promise((resolve) => {
    socket.once('voice:error', resolve);
    socket.emit('voice:call_accept', {});
  });
  assert.equal(error.error, 'callId is required');
  socket.close();
});
