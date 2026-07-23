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
