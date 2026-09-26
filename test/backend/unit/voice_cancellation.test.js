'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');

const {
  createTestRuntime,
  teardownTestRuntime,
} = require('../../helpers/db');
const { runWithAbortTimeout } = require('../../../server/utils/abort');
const { transcribeVoiceInput } = require('../../../server/services/voice/providers');

function tempAudioFile(t) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-voice-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const filePath = path.join(dir, 'clip.wav');
  fs.writeFileSync(filePath, Buffer.from('RIFF'));
  return filePath;
}

test('transcription preserves a pre-aborted caller reason', async () => {
  const controller = new AbortController();
  const reason = new Error('voice turn interrupted');
  controller.abort(reason);

  await assert.rejects(
    transcribeVoiceInput('/path/does/not/need/to/exist', {
      provider: 'gemini',
      apiKey: 'unused',
      signal: controller.signal,
    }),
    (error) => error === reason,
  );
});

test('a selected transcription provider failure is surfaced without cross-provider fallback', async (t) => {
  const filePath = tempAudioFile(t);
  const previousFetch = global.fetch;
  const failure = new Error('selected Gemini endpoint is unavailable');
  let calls = 0;
  global.fetch = async () => {
    calls += 1;
    throw failure;
  };
  t.after(() => {
    global.fetch = previousFetch;
  });
  await assert.rejects(
    transcribeVoiceInput(filePath, { provider: 'gemini', apiKey: 'test-key', mimeType: 'audio/wav' }),
    (error) => error === failure,
  );
  assert.equal(calls, 1);
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

function fakeSession(overrides = {}) {
  return {
    id: 'owned-session',
    userId: 7,
    attached: true,
    received: [],
    closedWith: null,
    tasks: { hasRunningWork: false },
    appendAudio(pcm) {
      this.received.push(pcm);
    },
    async close(reason, options) {
      this.closedWith = { reason, options };
    },
    ...overrides,
  };
}

test('voice runtime mutations require the owning user id', async (t) => {
  const ctx = createTestRuntime();
  t.after(() => teardownTestRuntime(ctx));
  const { VoiceRuntimeManager } = require('../../../server/services/voice/runtimeManager');
  const manager = new VoiceRuntimeManager({ agentEngine: {}, memoryManager: null });
  const session = fakeSession();
  manager.sessions.set(session.id, session);

  assert.throws(() => manager.appendAudio(session.id, Buffer.from([1]), 8), /access denied/);
  assert.throws(() => manager.appendAudio(session.id, Buffer.from([1])), /access denied/);
  await assert.rejects(manager.closeSession(session.id, 'client_closed', 8), /access denied/);
  assert.equal(manager.getSession(session.id), session);

  manager.appendAudio(session.id, Buffer.from([1]), 7);
  assert.equal(session.received.length, 1);
  await manager.closeSession(session.id, 'client_closed', 7);
  assert.equal(manager.getSession(session.id), null);
  assert.equal(session.closedWith.reason, 'client_closed');
});

test('voice runtime shutdown closes sessions with their tasks and refuses new sessions', async (t) => {
  const ctx = createTestRuntime();
  t.after(() => teardownTestRuntime(ctx));
  const { VoiceRuntimeManager } = require('../../../server/services/voice/runtimeManager');
  const manager = new VoiceRuntimeManager({ agentEngine: {}, memoryManager: null });
  const session = fakeSession({ id: 'session-1', tasks: { hasRunningWork: true } });
  manager.sessions.set(session.id, session);

  const status = await manager.shutdown();
  assert.equal(status.state, 'stopped');
  assert.deepEqual(session.closedWith, { reason: 'server_shutdown', options: { cancelTasks: true } });
  assert.equal(manager.getSession('session-1'), null);
  await assert.rejects(
    manager.openSession({ userId: 7, sink: {} }),
    (error) => error.code === 'VOICE_RUNTIME_SHUTDOWN',
  );
});
