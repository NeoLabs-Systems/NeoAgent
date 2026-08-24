'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  createTestRuntime,
  createTestUser,
  teardownTestRuntime,
} = require('../../helpers/db');

test('provider registry selects native duplex only for matching capable providers', () => {
  const { VoiceProviderRegistry } = require('../../../server/services/voice/provider_registry');
  const registry = new VoiceProviderRegistry();

  const native = registry.resolve({
    mediaMode: 'auto',
    inputMode: 'ptt',
    sttProvider: 'openai',
    ttsProvider: 'openai',
  });
  assert.equal(native.mediaMode, 'duplex');
  assert.equal(native.duplexModel, 'gpt-realtime-2.1');
  assert.equal(native.inputSampleRate, 24000);

  const mixed = registry.resolve({
    mediaMode: 'auto',
    sttProvider: 'deepgram',
    ttsProvider: 'openai',
  });
  assert.equal(mixed.mediaMode, 'composed');
  assert.equal(mixed.duplexProvider, null);

  const forced = registry.resolve({
    mediaMode: 'composed',
    sttProvider: 'openai',
    ttsProvider: 'openai',
  });
  assert.equal(forced.mediaMode, 'composed');
});

test('native shell exposes only the NeoAgent bridge and forbids provider-authored task answers', () => {
  const {
    NEOAGENT_TURN_TOOL,
    SHELL_INSTRUCTIONS,
  } = require('../../../server/services/voice/providers/openai_realtime_shell');

  assert.equal(NEOAGENT_TURN_TOOL.name, 'neoagent_turn');
  assert.deepEqual(NEOAGENT_TURN_TOOL.parameters.required, ['transcript']);
  assert.match(SHELL_INSTRUCTIONS, /every user question, request, correction, status query, or cancellation/i);
  assert.match(SHELL_INSTRUCTIONS, /call neoagent_turn exactly once/i);
  assert.match(SHELL_INSTRUCTIONS, /Never answer a substantive request from your own knowledge/i);

  const { buildRealtimeSessionUpdate } = require(
    '../../../server/services/voice/providers/openai_realtime_contract'
  );
  const ptt = buildRealtimeSessionUpdate({
    duplexModel: 'gpt-realtime-2.1',
    duplexVoice: 'marin',
    inputSampleRate: 24000,
    inputMode: 'ptt',
  });
  assert.equal(ptt.session.audio.input.turn_detection, null);
  assert.equal(ptt.session.reasoning.effort, 'low');
  assert.deepEqual(ptt.session.tools.map((tool) => tool.name), ['neoagent_turn']);
  const handsFree = buildRealtimeSessionUpdate({
    duplexModel: 'gpt-realtime-2.1',
    duplexVoice: 'marin',
    inputSampleRate: 24000,
    inputMode: 'hands_free',
  });
  assert.equal(handsFree.session.audio.input.turn_detection.type, 'semantic_vad');
});

test('ChatTurnGateway dispatches one normal interactive chat run with shared history metadata', async () => {
  const ctx = createTestRuntime();
  try {
    const user = await createTestUser(ctx.db, { username: 'voice_gateway_user' });
    const { ChatTurnGateway } = require('../../../server/services/voice/chat_turn_gateway');
    const { VoiceLiveSession } = require('../../../server/services/voice/liveSession');
    const calls = [];
    let dispatchedAt = 0;
    const agentEngine = {
      getRunMeta() { return null; },
      async run(userId, content, options) {
        dispatchedAt = performance.now();
        calls.push({ userId, content, options });
        return {
          runId: options.runId,
          status: 'completed',
          path: 'fast',
          content: 'Shared chat answer',
          totalTokens: 7,
        };
      },
    };
    const runtimeManager = {
      deliveryPresenter: { async flush() {} },
      releaseDetachedSession() {},
    };
    const gateway = new ChatTurnGateway({
      agentEngine,
      memoryManager: {
        getDefaultWebConversationId() { return 'shared-web-conversation'; },
      },
    });
    const session = new VoiceLiveSession({
      id: 'voice-session-1',
      userId: user.userId,
      runtimeManager,
      sink: {},
      voiceSettings: { mediaMode: 'composed' },
    });

    const dispatchStartedAt = performance.now();
    const result = await gateway.submitTurn(session, 'What changed?', {
      turnId: 'turn-1',
      messageId: 'message-1',
    });

    assert.equal(result.path, 'fast');
    assert.equal(calls.length, 1);
    assert.equal(calls[0].content, 'What changed?');
    assert.equal(calls[0].options.triggerSource, 'voice_live');
    assert.equal(calls[0].options.latencyPriority, 'interactive');
    assert.equal(calls[0].options.conversationId, 'shared-web-conversation');
    assert.equal(calls[0].options.forceMode, undefined);
    assert.ok(dispatchedAt - dispatchStartedAt < 100);

    const rows = ctx.db.prepare(
      'SELECT role, content, metadata FROM conversation_history WHERE user_id = ? ORDER BY id',
    ).all(user.userId);
    assert.deepEqual(rows.map((row) => row.role), ['user', 'assistant']);
    const metadata = JSON.parse(rows[0].metadata);
    assert.equal(metadata.sessionId, 'voice-session-1');
    assert.equal(metadata.turnId, 'turn-1');
    assert.equal(metadata.messageId, 'message-1');
  } finally {
    teardownTestRuntime(ctx);
  }
});

test('active voice follow-up is semantically steered without creating another run', async () => {
  const ctx = createTestRuntime();
  try {
    const user = await createTestUser(ctx.db, { username: 'voice_steer_user' });
    const { ChatTurnGateway } = require('../../../server/services/voice/chat_turn_gateway');
    const { VoiceLiveSession } = require('../../../server/services/voice/liveSession');
    const steering = [];
    let runCalls = 0;
    const agentEngine = {
      getRunMeta(runId) {
        return { runId, status: 'running', aborted: false, progressLedger: {} };
      },
      buildProgressLedgerSnapshot() {
        return { phase: 'working', latestMilestone: 'Repository inspected' };
      },
      async inferStructured() {
        return { parsed: { action: 'steer', spoken_reply: '' } };
      },
      enqueueSteering(runId, content, metadata) {
        steering.push({ runId, content, metadata });
      },
      async run() { runCalls += 1; },
    };
    const runtimeManager = {
      deliveryPresenter: { async flush() {} },
      async presentControlReply() {},
    };
    const gateway = new ChatTurnGateway({ agentEngine, memoryManager: {} });
    const session = new VoiceLiveSession({
      id: 'voice-session-active',
      userId: user.userId,
      runtimeManager,
      sink: {},
      voiceSettings: { mediaMode: 'duplex' },
    });
    session.currentRunId = 'durable-run-1';

    const result = await gateway.submitTurn(session, 'Also compare the older implementation.', {
      turnId: 'turn-control',
    });

    assert.equal(result.action, 'steer');
    assert.equal(runCalls, 0);
    assert.equal(steering.length, 1);
    assert.equal(steering[0].runId, 'durable-run-1');
    assert.equal(steering[0].metadata.sessionId, 'voice-session-active');
  } finally {
    teardownTestRuntime(ctx);
  }
});

test('active voice status and cancellation use the control engine without duplicate runs', async () => {
  const ctx = createTestRuntime();
  try {
    const user = await createTestUser(ctx.db, { username: 'voice_control_user' });
    const { ChatTurnGateway } = require('../../../server/services/voice/chat_turn_gateway');
    const { VoiceLiveSession } = require('../../../server/services/voice/liveSession');
    const decisions = [
      { action: 'status', spoken_reply: 'The deployment check is still running.' },
      { action: 'cancel', spoken_reply: 'The deployment check was cancelled.' },
    ];
    const aborted = [];
    const spoken = [];
    let runCalls = 0;
    const agentEngine = {
      getRunMeta(runId) {
        return { runId, status: 'running', aborted: false, progressLedger: {} };
      },
      buildProgressLedgerSnapshot() {
        return { currentlyRunning: ['health check'] };
      },
      async inferStructured() {
        return { parsed: decisions.shift() };
      },
      abort(runId, options) { aborted.push({ runId, options }); },
      async run() { runCalls += 1; },
    };
    const runtimeManager = {
      deliveryPresenter: { async flush() {} },
      async presentControlReply(_session, content) { spoken.push(content); },
    };
    const gateway = new ChatTurnGateway({ agentEngine, memoryManager: {} });
    const session = new VoiceLiveSession({
      id: 'voice-control-session',
      userId: user.userId,
      runtimeManager,
      sink: {},
      voiceSettings: { mediaMode: 'composed' },
    });
    session.currentRunId = 'durable-control-run';

    const status = await gateway.submitTurn(session, 'How is it going?', {
      turnId: 'control-status',
    });
    const cancel = await gateway.submitTurn(session, 'Stop that task.', {
      turnId: 'control-cancel',
    });

    assert.equal(status.action, 'status');
    assert.equal(cancel.action, 'cancel');
    assert.equal(runCalls, 0);
    assert.deepEqual(spoken, [
      'The deployment check is still running.',
      'The deployment check was cancelled.',
    ]);
    assert.equal(aborted.length, 1);
    assert.equal(aborted[0].runId, 'durable-control-run');
  } finally {
    teardownTestRuntime(ctx);
  }
});

test('canonical voice audio accepts ordered chunks, dedupes retries, and gates commit gaps', () => {
  const { VoiceLiveSession } = require('../../../server/services/voice/liveSession');
  const session = new VoiceLiveSession({
    id: 'sequence-session',
    userId: 1,
    sink: {},
    voiceSettings: {},
  });
  session.startTurn('turn-sequence', 'audio/pcm;rate=24000;channels=1');

  const second = session.appendInputChunk(Buffer.from([3, 4]), null, {
    turnId: 'turn-sequence',
    sequence: 1,
  });
  assert.equal(second.receivedThrough, -1);
  assert.equal(session.markCommitPending('turn-sequence', 1).ready, false);

  const first = session.appendInputChunk(Buffer.from([1, 2]), null, {
    turnId: 'turn-sequence',
    sequence: 0,
  });
  assert.equal(first.receivedThrough, 1);
  const duplicate = session.appendInputChunk(Buffer.from([9, 9]), null, {
    turnId: 'turn-sequence',
    sequence: 0,
  });
  assert.equal(duplicate.duplicate, true);
  assert.deepEqual(session.getInputAudioBuffer(), Buffer.from([1, 2, 3, 4]));
  assert.equal(session.markCommitPending('turn-sequence', 1).ready, true);
});

test('socket voice transport forwards stable audio metadata without internal buffering', async () => {
  const { SocketVoiceTransport } = require('../../../server/services/voice/voice_transport');
  const events = [];
  const transport = new SocketVoiceTransport({
    emit(event, payload) {
      events.push({ event, payload, observedAt: performance.now() });
    },
  }, () => ({ providers: [] }));
  const startedAt = performance.now();

  await transport.publishAudioChunk(
    { id: 'session-transport' },
    Buffer.from([1, 2, 3]),
    {
      turnId: 'turn-transport',
      runId: 'run-transport',
      messageId: 'message-transport',
      sequence: 4,
      mimeType: 'audio/wav',
    },
  );

  assert.equal(events.length, 1);
  assert.equal(events[0].event, 'voice:audio_chunk');
  assert.equal(events[0].payload.sessionId, 'session-transport');
  assert.equal(events[0].payload.turnId, 'turn-transport');
  assert.equal(events[0].payload.runId, 'run-transport');
  assert.equal(events[0].payload.messageId, 'message-transport');
  assert.equal(events[0].payload.sequence, 4);
  assert.ok(events[0].observedAt - startedAt < 50);
});
