'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  createTestRuntime,
  teardownTestRuntime,
} = require('../../helpers/db');
const { runWithAbortTimeout } = require('../../../server/utils/abort');
const { VoiceLiveSession } = require('../../../server/services/voice/liveSession');
const { synthesizeSpeechBuffer } = require('../../../server/services/voice/openaiSpeech');
const {
  synthesizeVoiceReply,
  transcribeVoiceInput,
} = require('../../../server/services/voice/providers');

test('voice provider entry points preserve a pre-aborted caller reason', async () => {
  const controller = new AbortController();
  const reason = new Error('voice turn interrupted');
  controller.abort(reason);

  await assert.rejects(
    synthesizeVoiceReply('hello', {
      provider: 'gemini',
      apiKey: 'unused',
      signal: controller.signal,
    }),
    (error) => error === reason,
  );
  await assert.rejects(
    transcribeVoiceInput('/path/does/not/need/to/exist', {
      provider: 'gemini',
      apiKey: 'unused',
      signal: controller.signal,
    }),
    (error) => error === reason,
  );
});

test('a selected voice provider failure is surfaced without cross-provider fallback', async () => {
  const previousFetch = global.fetch;
  const failure = new Error('selected Gemini endpoint is unavailable');
  let calls = 0;
  global.fetch = async () => {
    calls += 1;
    throw failure;
  };
  try {
    await assert.rejects(
      synthesizeVoiceReply('hello', {
        provider: 'gemini',
        apiKey: 'test-key',
      }),
      (error) => error === failure,
    );
    assert.equal(calls, 1);
  } finally {
    global.fetch = previousFetch;
  }
});

test('abort timeout rejects even when an SDK ignores its signal', async () => {
  let operationSignal = null;
  await assert.rejects(
    runWithAbortTimeout((signal) => {
      operationSignal = signal;
      return new Promise(() => {});
    }, {
      timeoutMs: 10,
      timeoutCode: 'VOICE_TEST_TIMEOUT',
      label: 'Voice test',
    }),
    (error) => error.code === 'VOICE_TEST_TIMEOUT',
  );
  assert.ok(operationSignal);
  assert.equal(operationSignal.aborted, true);
});

test('OpenAI speech synthesis bounds response bytes while streaming', async () => {
  const client = {
    audio: {
      speech: {
        create: async () => new Response(new Uint8Array(9)),
      },
    },
  };

  await assert.rejects(
    synthesizeSpeechBuffer(client, 'hello', { maxResponseBytes: 8 }),
    (error) => error.code === 'VOICE_PROVIDER_RESPONSE_TOO_LARGE',
  );
});

test('OpenAI speech synthesis times out even when the SDK ignores cancellation', async () => {
  let capturedSignal = null;
  const client = {
    audio: {
      speech: {
        create: (_payload, options) => {
          capturedSignal = options.signal;
          return new Promise(() => {});
        },
      },
    },
  };

  await assert.rejects(
    synthesizeSpeechBuffer(client, 'hello', { timeoutMs: 10 }),
    (error) => error.code === 'VOICE_PROVIDER_TIMEOUT',
  );
  assert.ok(capturedSignal);
  assert.equal(capturedSignal.aborted, true);
});

test('voice session interruption aborts old turn work and reset creates a fresh signal', async () => {
  const session = new VoiceLiveSession({
    id: 'session-1',
    userId: 1,
    sink: {},
    voiceSettings: {},
  });
  const firstSignal = session.signal;

  await session.interruptOutput();
  assert.equal(firstSignal.aborted, true);
  assert.equal(firstSignal.reason.code, 'VOICE_INTERRUPTED');

  session.resetTurnState();
  assert.notEqual(session.signal, firstSignal);
  assert.equal(session.signal.aborted, false);
  assert.equal(session.interrupted, false);
});

test('voice runtime mutations require the owning user id', async () => {
  const ctx = createTestRuntime();
  const { VoiceRuntimeManager } = require('../../../server/services/voice/runtimeManager');
  const manager = new VoiceRuntimeManager({
    io: null,
    agentEngine: { abort() {} },
    memoryManager: null,
  });
  let inputStarted = false;
  const session = {
    id: 'owned-session',
    userId: 7,
    currentRunId: null,
    async interruptOutput() {},
    resetTurnState() {},
    async setState() {},
    async close() {},
    adapter: {
      async onInputStart() {
        inputStarted = true;
      },
      async close() {},
    },
  };
  manager.sessions.set(session.id, session);

  try {
    await assert.rejects(
      manager.beginInput(session.id, {}, 8),
      /access denied/,
    );
    await assert.rejects(
      manager.beginInput(session.id),
      /access denied/,
    );
    await assert.rejects(
      manager.closeSession(session.id, 'client_closed', 8),
      /access denied/,
    );
    assert.equal(manager.getSession(session.id), session);

    await manager.beginInput(session.id, {}, 7);
    assert.equal(inputStarted, true);
    await manager.closeSession(session.id, 'client_closed', 7);
    assert.equal(manager.getSession(session.id), null);
  } finally {
    teardownTestRuntime(ctx);
  }
});

test('barge-in stops voice media without aborting the active NeoAgent run', async () => {
  const ctx = createTestRuntime();
  const { VoiceRuntimeManager } = require('../../../server/services/voice/runtimeManager');
  const abortedRuns = [];
  const manager = new VoiceRuntimeManager({
    io: null,
    agentEngine: {
      abort(runId) { abortedRuns.push(runId); },
    },
    memoryManager: null,
  });
  let mediaInterrupts = 0;
  const session = {
    id: 'barge-session',
    userId: 7,
    currentRunId: 'durable-run',
    inputBytes: 0,
    async interruptOutput() { mediaInterrupts += 1; },
    resetTurnState() {},
    async setState() {},
    adapter: {
      async onInputStart() {},
      async close() {},
    },
  };
  manager.sessions.set(session.id, session);

  try {
    await manager.beginInput(session.id, { turnId: 'turn-2' }, 7);
    assert.equal(mediaInterrupts, 1);
    assert.deepEqual(abortedRuns, []);
    assert.equal(session.currentRunId, 'durable-run');
  } finally {
    await manager.shutdown();
    teardownTestRuntime(ctx);
  }
});

test('transport detach preserves a durable run for reconnect', async () => {
  const ctx = createTestRuntime();
  const { VoiceRuntimeManager } = require('../../../server/services/voice/runtimeManager');
  const manager = new VoiceRuntimeManager({
    io: null,
    agentEngine: { abort() {} },
    memoryManager: null,
  });
  let detached = false;
  const session = {
    id: 'reconnect-session',
    userId: 7,
    currentRunId: 'durable-run',
    state: 'working',
    detachSink() { detached = true; },
    adapter: { async close() {} },
  };
  manager.sessions.set(session.id, session);

  try {
    await manager.detachSession(session.id, 'socket_disconnected', 7);
    assert.equal(detached, true);
    assert.equal(session.state, 'reconnecting');
    assert.equal(manager.getSession(session.id), session);
  } finally {
    await manager.shutdown();
    teardownTestRuntime(ctx);
  }
});

test('terminal origin runs release their agent-initiated voice session binding', async () => {
  const ctx = createTestRuntime();
  const { VoiceRuntimeManager } = require('../../../server/services/voice/runtimeManager');
  const manager = new VoiceRuntimeManager({
    io: null,
    agentEngine: { abort() {} },
    memoryManager: null,
  });
  const stateUpdates = [];
  const session = {
    id: 'agent-call-session',
    userId: 7,
    currentRunId: 'origin-run',
    state: 'working',
    attached: true,
    closed: false,
    async setState(state, metadata) {
      this.state = state;
      stateUpdates.push({ state, metadata });
    },
  };
  manager.sessions.set(session.id, session);

  try {
    manager.handleRunTerminal('origin-run');
    await new Promise((resolve) => setImmediate(resolve));
    assert.equal(session.currentRunId, null);
    assert.deepEqual(stateUpdates, [{
      state: 'idle',
      metadata: { runId: '', clearRunId: true },
    }]);
  } finally {
    manager.sessions.clear();
    teardownTestRuntime(ctx);
  }
});

test('voice runtime shutdown closes sessions, aborts runs, and refuses new sessions', async () => {
  const ctx = createTestRuntime();
  const { VoiceRuntimeManager } = require('../../../server/services/voice/runtimeManager');
  const abortedRuns = [];
  const manager = new VoiceRuntimeManager({
    io: null,
    agentEngine: {
      abort(runId, options) {
        abortedRuns.push({ runId, options });
      },
    },
    memoryManager: null,
  });
  let sessionClosed = false;
  let adapterClosed = false;
  manager.sessions.set('session-1', {
    id: 'session-1',
    userId: 7,
    currentRunId: 'run-1',
    async close() {
      sessionClosed = true;
    },
    adapter: {
      async close() {
        adapterClosed = true;
      },
    },
  });

  try {
    const status = await manager.shutdown();
    assert.equal(status.state, 'stopped');
    assert.equal(sessionClosed, true);
    assert.equal(adapterClosed, true);
    assert.deepEqual(abortedRuns, [{
      runId: 'run-1',
      options: { userId: 7, reason: 'voice_session_closed' },
    }]);
    assert.equal(manager.getSession('session-1'), null);
    await assert.rejects(
      manager.openSession({ userId: 7, sink: {} }),
      (error) => error.code === 'VOICE_RUNTIME_SHUTDOWN',
    );
  } finally {
    teardownTestRuntime(ctx);
  }
});
