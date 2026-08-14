'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  createTestRuntime,
  createTestUser,
  teardownTestRuntime,
} = require('../../helpers/db');

function createSocket(id, roomEvents) {
  return {
    id,
    data: {},
    events: [],
    emit(event, payload) {
      this.events.push({ event, payload });
    },
    to(room) {
      return {
        emit(event, payload) {
          roomEvents.push({ room, event, payload, except: id });
        },
      };
    },
  };
}

function createIo(sockets, roomEvents = []) {
  return {
    roomEvents,
    in(room) {
      return { fetchSockets: async () => sockets };
    },
    to(room) {
      return {
        emit(event, payload) {
          roomEvents.push({ room, event, payload });
        },
      };
    },
  };
}

function emittedCallId(io) {
  return io.roomEvents.find((entry) => entry.event === 'voice:incoming_call')?.payload?.callId;
}

test('agent calls are approval-gated in their own permission category', async (t) => {
  const ctx = createTestRuntime();
  t.after(() => teardownTestRuntime(ctx));
  const user = await createTestUser(ctx.db);
  const { ToolPolicyService } = require('../../../server/services/security/tool_policy_service');
  const { getCategoryForTool } = require('../../../server/services/security/tool_categories');
  const { getAvailableTools } = require('../../../server/services/ai/tools');

  assert.equal(getCategoryForTool('call_user', {}), 'user_contact');
  assert.equal(new ToolPolicyService().getPolicy(user.userId, 'call_user', {}), 'require_approval');
  const tool = getAvailableTools(null, { names: ['call_user'], includeDescriptions: true })[0];
  assert.equal(tool.name, 'call_user');
  assert.deepEqual(tool.parameters.required, ['opening_message']);
});

test('agent call distinguishes an offline Flutter client from a missing tool', async (t) => {
  const ctx = createTestRuntime();
  t.after(() => teardownTestRuntime(ctx));
  const user = await createTestUser(ctx.db);
  const { AgentCallCoordinator } = require('../../../server/services/voice/agent_call_coordinator');
  const coordinator = new AgentCallCoordinator({
    io: createIo([]),
    agentEngine: {},
    voiceRuntimeManager: { hasActiveSessionForUser: () => false },
    ringTimeoutMs: 10,
  });

  const result = await coordinator.callUser({
    userId: user.userId,
    openingMessage: 'I have an update.',
  });
  assert.deepEqual(result, {
    status: 'unavailable',
    reason: 'no_connected_flutter_client',
    message: 'The call_user tool is available, but no Flutter app client is currently connected to receive the call.',
  });
});

test('first accepting client wins and opening context is attached to the voice session', async (t) => {
  const ctx = createTestRuntime();
  t.after(() => teardownTestRuntime(ctx));
  const user = await createTestUser(ctx.db);
  const roomEvents = [];
  const first = createSocket('socket-1', roomEvents);
  const second = createSocket('socket-2', roomEvents);
  const io = createIo([first, second], roomEvents);
  let openedWith = null;
  let presented = null;
  const session = { id: 'pending', userId: user.userId, agentInitiated: true };
  const voiceRuntimeManager = {
    sessions: new Map(),
    hasActiveSessionForUser: () => false,
    async openFlutterSession(options) {
      openedWith = options;
      session.id = options.sessionId;
      return session;
    },
    deliveryPresenter: {
      async present(_session, entry) {
        presented = entry;
      },
    },
  };
  const { AgentCallCoordinator } = require('../../../server/services/voice/agent_call_coordinator');
  const coordinator = new AgentCallCoordinator({
    io,
    agentEngine: {},
    voiceRuntimeManager,
    ringTimeoutMs: 1000,
  });

  const outcome = coordinator.callUser({
    userId: user.userId,
    openingMessage: 'The deployment finished successfully.',
    conversationId: null,
  });
  await new Promise((resolve) => setImmediate(resolve));
  const callId = emittedCallId(io);
  assert.ok(callId);

  const accepted = await coordinator.accept(callId, user.userId, first);
  const losingAcceptance = await coordinator.accept(callId, user.userId, second);
  assert.equal(accepted.status, 'accepted');
  assert.equal(losingAcceptance.status, 'unavailable');
  assert.equal(openedWith.sessionId, callId);
  assert.equal(openedWith.agentInitiated, true);
  assert.equal(presented.kind, 'opening');
  assert.equal(presented.content, 'The deployment finished successfully.');
  assert.equal((await outcome).status, 'accepted');
  assert.ok(roomEvents.some((entry) => (
    entry.event === 'voice:call_cancelled' && entry.except === first.id
  )));
});

test('opening speech is pre-generated while ringing and reused when the user answers', async (t) => {
  const ctx = createTestRuntime();
  t.after(() => teardownTestRuntime(ctx));
  const user = await createTestUser(ctx.db);
  const roomEvents = [];
  const socket = createSocket('socket-1', roomEvents);
  const io = createIo([socket], roomEvents);
  const prepared = { chunks: [{ audioBytes: Buffer.from('abc'), mimeType: 'audio/wav' }] };
  let preparedWith = null;
  let presented = null;
  const voiceRuntimeManager = {
    hasActiveSessionForUser: () => false,
    async prepareComposedSpeech(options) {
      preparedWith = options;
      return prepared;
    },
    async openFlutterSession(options) {
      return { id: options.sessionId, userId: user.userId, agentInitiated: true };
    },
    deliveryPresenter: {
      async present(_session, entry) {
        presented = entry;
      },
    },
  };
  const { AgentCallCoordinator } = require('../../../server/services/voice/agent_call_coordinator');
  const coordinator = new AgentCallCoordinator({
    io,
    agentEngine: {},
    voiceRuntimeManager,
    ringTimeoutMs: 1000,
  });

  const outcome = coordinator.callUser({
    userId: user.userId,
    openingMessage: 'The build is green.',
  });
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(preparedWith.text, 'The build is green.');
  const callId = emittedCallId(io);
  const accepted = await coordinator.accept(callId, user.userId, socket);
  assert.equal(accepted.status, 'accepted');
  assert.deepEqual(presented.audioChunks, prepared.chunks);
  assert.equal((await outcome).status, 'accepted');
});

test('a reconnecting client is offered the pending call and can accept it', async (t) => {
  const ctx = createTestRuntime();
  t.after(() => teardownTestRuntime(ctx));
  const user = await createTestUser(ctx.db);
  const roomEvents = [];
  const original = createSocket('socket-original', roomEvents);
  const late = createSocket('socket-late', roomEvents);
  const io = createIo([original], roomEvents);
  const voiceRuntimeManager = {
    hasActiveSessionForUser: () => false,
    async openFlutterSession(options) {
      return { id: options.sessionId, userId: user.userId, agentInitiated: true };
    },
    deliveryPresenter: {
      async present() {},
    },
  };
  const { AgentCallCoordinator } = require('../../../server/services/voice/agent_call_coordinator');
  const coordinator = new AgentCallCoordinator({
    io,
    agentEngine: {},
    voiceRuntimeManager,
    ringTimeoutMs: 1000,
  });

  const outcome = coordinator.callUser({
    userId: user.userId,
    openingMessage: 'I need you on the line.',
  });
  await new Promise((resolve) => setImmediate(resolve));
  const callId = emittedCallId(io);
  coordinator.handleDisconnect(original.id, user.userId);
  assert.equal(coordinator.offerPendingCall(late, user.userId), true);
  assert.ok(late.events.some((entry) => (
    entry.event === 'voice:incoming_call' && entry.payload.callId === callId
  )));
  const accepted = await coordinator.accept(callId, user.userId, late);
  assert.equal(accepted.status, 'accepted');
  assert.equal((await outcome).status, 'accepted');
});

test('all recipients declining resolves the call and abort cancels a pending ring', async (t) => {
  const ctx = createTestRuntime();
  t.after(() => teardownTestRuntime(ctx));
  const user = await createTestUser(ctx.db);
  const roomEvents = [];
  const first = createSocket('socket-1', roomEvents);
  const second = createSocket('socket-2', roomEvents);
  const io = createIo([first, second], roomEvents);
  const { AgentCallCoordinator } = require('../../../server/services/voice/agent_call_coordinator');
  const coordinator = new AgentCallCoordinator({
    io,
    agentEngine: {},
    voiceRuntimeManager: { hasActiveSessionForUser: () => false },
    ringTimeoutMs: 1000,
  });

  const declinedOutcome = coordinator.callUser({
    userId: user.userId,
    openingMessage: 'Please call me back.',
  });
  await new Promise((resolve) => setImmediate(resolve));
  const declinedCallId = emittedCallId(io);
  coordinator.decline(declinedCallId, user.userId, first);
  coordinator.decline(declinedCallId, user.userId, second);
  assert.equal((await declinedOutcome).status, 'declined');

  const abortController = new AbortController();
  const cancelledOutcome = coordinator.callUser({
    userId: user.userId,
    openingMessage: 'This call will be cancelled.',
    signal: abortController.signal,
  });
  await new Promise((resolve) => setImmediate(resolve));
  abortController.abort();
  assert.equal((await cancelledOutcome).status, 'cancelled');
});
