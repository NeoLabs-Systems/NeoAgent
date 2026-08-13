'use strict';

const assert = require('node:assert/strict');
const { after, before, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../helpers/db');
const { loginAs } = require('../helpers/app');
const { connectSocket, createSocketFixture } = require('../helpers/socket');
const { agent } = require('../helpers/supertest');

let ctx;
let fixture;
let resolveRun;
let resolveSteering;
let steerableRun = null;
const observedRuns = [];
const observedSteering = [];

before(async () => {
  ctx = createTestRuntime();
  fixture = await createSocketFixture({
    agentEngine: {
      findSteerableRunForUser() {
        return steerableRun;
      },
      enqueueSteering(runId, task, options) {
        if (!steerableRun) return false;
        const observed = { runId, task, options };
        observedSteering.push(observed);
        resolveSteering?.(observed);
        return true;
      },
      async run(userId, task, options) {
        observedRuns.push({ userId, task, options });
        resolveRun?.(observedRuns.at(-1));
        return {
          status: 'completed',
          content: 'Plan ready.',
          runId: 'cowork-test-run',
          totalTokens: 4,
        };
      },
    },
  });
  fixture.app.locals.runtimeManager.getComputerProvider = () => 'cloud';
  fixture.app.locals.runtimeManager.getComputerStatus = () => ({
    providers: {
      cloud: { available: true },
      local: { available: true, connected: true },
    },
  });
});

after(async () => {
  await fixture.close();
  teardownTestRuntime(ctx);
});

test('Cowork socket runs capture the chat agent, plan mode, and device target', async () => {
  const user = await createTestUser(ctx.db, { username: 'cowork_socket_user' });
  const http = agent(fixture.app);
  const login = await loginAs(http, user);
  const cookie = login.headers['set-cookie']
    .map((item) => item.split(';')[0])
    .join('; ');
  const created = await http.post('/api/cowork/chats').send({
    mode: 'plan',
    deviceTargetOverride: 'local',
  }).expect(201);
  const chat = created.body.chat;

  const socket = connectSocket(fixture.url, cookie);
  await new Promise((resolve, reject) => {
    socket.on('connect', resolve);
    socket.on('connect_error', reject);
  });
  const runObserved = new Promise((resolve) => {
    resolveRun = resolve;
  });
  socket.emit('agent:run', {
    task: 'Inspect the repository and prepare the implementation plan.',
    options: { conversationId: chat.id },
  });
  const observed = await runObserved;
  socket.close();

  assert.equal(observed.userId, user.userId);
  assert.equal(observed.options.agentId, chat.agentId);
  assert.equal(observed.options.conversationId, chat.id);
  assert.equal(observed.options.triggerSource, 'cowork');
  assert.equal(observed.options.interactionMode, 'plan');
  assert.equal(observed.options.deviceTarget, 'local');
  assert.equal(observed.options.priorMessages.length, 0);
  assert.equal(
    ctx.db.prepare('SELECT title FROM conversations WHERE id = ?').get(chat.id).title,
    'Inspect the repository and prepare the implementation plan.',
  );
});

test('Cowork steering is retained in the selected chat history', async () => {
  const user = await createTestUser(ctx.db, { username: 'cowork_steering_user' });
  const http = agent(fixture.app);
  const login = await loginAs(http, user);
  const cookie = login.headers['set-cookie']
    .map((item) => item.split(';')[0])
    .join('; ');
  const created = await http.post('/api/cowork/chats').send({}).expect(201);
  const chat = created.body.chat;
  steerableRun = {
    runId: 'cowork-steering-run',
    agentId: chat.agentId,
    conversationId: chat.id,
  };

  const socket = connectSocket(fixture.url, cookie);
  await new Promise((resolve, reject) => {
    socket.on('connect', resolve);
    socket.on('connect_error', reject);
  });
  const steeringObserved = new Promise((resolve) => {
    resolveSteering = resolve;
  });
  socket.emit('agent:run', {
    task: 'Also include the migration rollback strategy.',
    options: { conversationId: chat.id },
  });
  const observed = await steeringObserved;
  socket.close();
  steerableRun = null;
  resolveSteering = null;

  assert.equal(observed.runId, 'cowork-steering-run');
  assert.equal(observed.options.conversationId, chat.id);
  const message = ctx.db.prepare(
    `SELECT role, content, metadata_json
     FROM conversation_messages
     WHERE conversation_id = ? ORDER BY id DESC LIMIT 1`,
  ).get(chat.id);
  assert.equal(message.role, 'user');
  assert.equal(message.content, 'Also include the migration rollback strategy.');
  const metadata = JSON.parse(message.metadata_json);
  assert.equal(metadata.steering, true);
  assert.equal(
    metadata.displayContent,
    'Also include the migration rollback strategy.',
  );
});
