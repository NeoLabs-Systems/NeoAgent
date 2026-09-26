'use strict';

const assert = require('node:assert/strict');
const { once } = require('node:events');
const { test } = require('node:test');
const { WebSocketServer } = require('ws');

const {
  createTestRuntime,
  createTestUser,
  teardownTestRuntime,
} = require('../../helpers/db');

// A local stand-in for the provider's live socket that records every client
// event and lets the test push server events.
async function startFakeLiveServer() {
  const wss = new WebSocketServer({ port: 0 });
  await once(wss, 'listening');
  const server = {
    url: `http://127.0.0.1:${wss.address().port}`,
    paths: [],
    received: [],
    socket: null,
    waiters: [],
    send(event) {
      server.socket.send(JSON.stringify(event));
    },
    async next(predicate) {
      const found = server.received.find(predicate);
      if (found) return found;
      return new Promise((resolve) => server.waiters.push({ predicate, resolve }));
    },
    close() {
      for (const client of wss.clients) client.terminate();
      return new Promise((resolve) => wss.close(resolve));
    },
  };
  wss.on('connection', (socket, req) => {
    server.socket = socket;
    server.paths.push(req.url);
    socket.on('message', (data) => {
      const event = JSON.parse(String(data));
      server.received.push(event);
      server.waiters = server.waiters.filter((waiter) => {
        if (!waiter.predicate(event)) return true;
        waiter.resolve(event);
        return false;
      });
    });
  });
  return server;
}

function createSink() {
  const events = [];
  return {
    events,
    send(kind, payload) {
      events.push({ kind, payload });
    },
    of(kind) {
      return events.filter((event) => event.kind === kind).map((event) => event.payload);
    },
  };
}

function createFakeEngine(overrides = {}) {
  return {
    runs: [],
    steering: [],
    aborted: [],
    running: new Set(),
    async buildSystemPrompt(_userId, context) {
      return { stable: `SYSTEM PROMPT role=${context.liveVoiceRole}`, dynamic: 'DYNAMIC' };
    },
    getRunMeta(runId) {
      return this.running.has(runId) ? { status: 'running', aborted: false } : null;
    },
    enqueueSteering(runId, content) {
      this.steering.push({ runId, content });
      return { runId };
    },
    abort(runId) {
      this.aborted.push(runId);
    },
    ...overrides,
  };
}

async function setupManager(ctx, engine, settings = {}) {
  const user = await createTestUser(ctx.db);
  const { MemoryManager } = require('../../../server/services/memory/manager');
  const memoryManager = new MemoryManager();
  const upsert = ctx.db.prepare(
    'INSERT INTO user_settings (user_id, key, value) VALUES (?, ?, ?) ON CONFLICT(user_id, key) DO UPDATE SET value = excluded.value',
  );
  for (const [key, value] of Object.entries(settings)) {
    upsert.run(user.userId, key, JSON.stringify(value));
  }
  const { VoiceRuntimeManager } = require('../../../server/services/voice/runtimeManager');
  const manager = new VoiceRuntimeManager({ agentEngine: engine, memoryManager });
  const conversationId = memoryManager.getDefaultWebConversationId(user.userId);
  return { user, manager, conversationId };
}

function historyRows(db, userId) {
  return db.prepare(
    'SELECT role, content, agent_run_id FROM conversation_history WHERE user_id = ? ORDER BY id',
  ).all(userId);
}

test('live voice catalog resolves per-provider defaults and the server default', () => {
  const previous = { ...process.env };
  try {
    delete process.env.VOICE_LIVE_PROVIDER;
    delete process.env.VOICE_LIVE_MODEL;
    const catalog = require('../../../server/services/voice/live/catalog');
    assert.equal(catalog.normalizeLiveProvider(''), 'openai');
    assert.equal(catalog.resolveLiveModel('openai', ''), 'gpt-live-1');
    assert.equal(catalog.resolveLiveModel('google', ''), 'gemini-3.8-live');
    assert.equal(catalog.resolveLiveVoice('google', ''), 'Kore');
    assert.equal(catalog.normalizeInputMode('bogus'), 'hands_free');

    process.env.VOICE_LIVE_PROVIDER = 'google';
    process.env.VOICE_LIVE_MODEL = 'gemini-3.1-flash-live-preview';
    assert.equal(catalog.normalizeLiveProvider('unknown'), 'google');
    assert.equal(catalog.resolveLiveModel('google', ''), 'gemini-3.1-flash-live-preview');
    assert.equal(catalog.resolveLiveModel('openai', ''), 'gpt-live-1');
    assert.equal(catalog.resolveLiveModel('google', 'custom-live'), 'custom-live');
    assert.equal(catalog.describeLiveVoiceCatalog().defaultProvider, 'google');
  } finally {
    process.env = previous;
  }
});

test('the live front and delegated tasks share the chat system prompt with their own voice section', async (t) => {
  const ctx = createTestRuntime();
  t.after(() => teardownTestRuntime(ctx));
  const user = await createTestUser(ctx.db);
  const { buildSystemPromptSections } = require('../../../server/services/ai/systemPrompt');
  const memoryManager = { buildContext: async () => 'CORE MEMORY: owner likes short answers' };

  const front = await buildSystemPromptSections(user.userId, {
    triggerSource: 'voice_live',
    liveVoiceRole: 'front',
  }, memoryManager);
  const task = await buildSystemPromptSections(user.userId, {
    triggerSource: 'voice_live',
    liveVoiceRole: 'task',
  }, memoryManager);

  assert.match(front.stable, /CRITICAL EXECUTION RULES/);
  assert.match(front.stable, /LIVE VOICE SESSION/);
  assert.doesNotMatch(front.stable, /LIVE VOICE TASK/);
  assert.match(front.dynamic, /CORE MEMORY: owner likes short answers/);
  assert.match(task.stable, /LIVE VOICE TASK/);
  assert.doesNotMatch(task.stable, /LIVE VOICE SESSION/);
});

test('appendFragment joins provider transcript fragments without merging words', () => {
  const { appendFragment } = require('../../../server/services/voice/live/session');
  assert.equal(appendFragment('', ' Hello'), 'Hello');
  assert.equal(appendFragment('What is', 'the time'), 'What is the time');
  assert.equal(appendFragment('Hello ', 'there'), 'Hello there');
  assert.equal(appendFragment('Hello', ' there'), 'Hello there');
  assert.equal(appendFragment('Done', '.'), 'Done.');
});

test('GPT-Live session: shared prompt, transcripts, hand-off as a normal run, result spoken once', async (t) => {
  const ctx = createTestRuntime();
  const fake = await startFakeLiveServer();
  t.after(async () => {
    await fake.close();
    teardownTestRuntime(ctx);
  });
  process.env.OPENAI_API_KEY = 'test-openai-key';
  process.env.OPENAI_BASE_URL = `${fake.url}/v1`;

  let manager = null;
  const engine = createFakeEngine({
    async run(userId, request, options) {
      this.runs.push({ userId, request, options });
      this.running.add(options.runId);
      manager.presentDelivery({
        recipient: options.voiceSessionId,
        runId: options.runId,
        messageKind: 'final',
        payload: { content: 'Die Mail an Max ist raus.' },
      });
      this.running.delete(options.runId);
      return { runId: options.runId, status: 'completed', content: 'Die Mail an Max ist raus.' };
    },
  });
  const setup = await setupManager(ctx, engine);
  manager = setup.manager;
  const { user, conversationId } = setup;
  ctx.db.prepare(
    `INSERT INTO conversation_messages (conversation_id, role, content) VALUES (?, 'user', ?)`,
  ).run(conversationId, 'Earlier typed question');

  const sink = createSink();
  const opening = manager.openSession({ userId: user.userId, sink });
  const start = await fake.next((event) => event.type === 'session.start');
  assert.equal(fake.paths[0], '/v1/live/sessions');
  assert.equal(start.session.model, 'gpt-live-1');
  assert.equal(start.session.audio.output.voice, 'marin');
  assert.deepEqual(start.session.delegation, { type: 'client' });
  assert.match(start.session.instructions, /SYSTEM PROMPT role=front/);
  assert.equal(start.session.input[0].content[0].text, 'Earlier typed question');
  fake.send({ type: 'session.started', session: { id: 'sess_1' } });
  const session = await opening;

  const ready = sink.of('session_ready')[0];
  assert.equal(ready.inputSampleRate, 24000);
  assert.equal(ready.outputSampleRate, 24000);
  assert.equal(ready.provider, 'openai');

  const pcm = Buffer.from([1, 2, 3, 4]);
  manager.appendAudio(session.id, pcm, user.userId);
  const appended = await fake.next((event) => event.type === 'session.input_audio.append'
    && event.audio === pcm.toString('base64'));
  assert.ok(appended);

  fake.send({ type: 'session.input_transcript.delta', delta: 'Schreib Max', start_ms: 0, end_ms: 400 });
  fake.send({ type: 'session.input_transcript.delta', delta: 'dass ich später komme', start_ms: 400, end_ms: 900 });
  fake.send({ type: 'session.delegation.created', delegation: { id: 'item_1', type: 'delegation', target: 'client' } });
  fake.send({ type: 'session.output_transcript.delta', delta: 'Mach ich.' });
  fake.send({ type: 'session.output_audio.delta', delta: Buffer.from([9, 9]).toString('base64') });

  const result = await fake.next((event) => event.type === 'session.commentary.append');
  assert.equal(result.delegation_id, 'item_1');
  assert.equal(result.content, 'Die Mail an Max ist raus.');

  assert.equal(engine.runs.length, 1);
  const run = engine.runs[0];
  assert.equal(run.request, 'Schreib Max dass ich später komme');
  assert.equal(run.options.triggerSource, 'voice_live');
  assert.equal(run.options.voiceSessionId, session.id);
  assert.equal(run.options.conversationId, conversationId);
  assert.equal(run.options.context.liveVoiceRole, 'task');
  assert.ok(sink.of('audio').some((event) => event.audioBase64 === Buffer.from([9, 9]).toString('base64')));
  assert.deepEqual(sink.of('task').map((event) => event.status), ['running', 'completed']);

  await manager.closeSession(session.id, 'client_closed', user.userId);
  await fake.next((event) => event.type === 'session.close');
  assert.equal(fake.received.filter((event) => event.type === 'session.commentary.append').length, 1);

  const rows = historyRows(ctx.db, user.userId);
  assert.deepEqual(rows.map((row) => [row.role, row.content]), [
    ['user', 'Schreib Max dass ich später komme'],
    ['assistant', 'Mach ich.'],
  ]);
  const threadRoles = ctx.db.prepare(
    'SELECT role, content FROM conversation_messages WHERE conversation_id = ? ORDER BY id',
  ).all(conversationId).map((row) => row.content);
  assert.deepEqual(threadRoles, ['Earlier typed question', 'Schreib Max dass ich später komme', 'Mach ich.']);
});

test('a hand-off during a running task steers that run instead of starting another', async (t) => {
  const ctx = createTestRuntime();
  const fake = await startFakeLiveServer();
  t.after(async () => {
    await fake.close();
    teardownTestRuntime(ctx);
  });
  process.env.OPENAI_API_KEY = 'test-openai-key';
  process.env.OPENAI_BASE_URL = `${fake.url}/v1`;

  let finishRun = null;
  const engine = createFakeEngine({
    run(_userId, request, options) {
      this.runs.push({ request, options });
      this.running.add(options.runId);
      return new Promise((resolve) => {
        finishRun = () => {
          this.running.delete(options.runId);
          resolve({ status: 'completed', content: 'Termin steht.' });
        };
      });
    },
  });
  const { user, manager } = await setupManager(ctx, engine);
  const opening = manager.openSession({ userId: user.userId, sink: createSink() });
  await fake.next((event) => event.type === 'session.start');
  fake.send({ type: 'session.started', session: { id: 'sess_2' } });
  const session = await opening;

  fake.send({ type: 'session.input_transcript.delta', delta: 'Leg einen Termin an' });
  fake.send({ type: 'session.delegation.created', delegation: { id: 'item_a', target: 'client' } });
  await new Promise((resolve) => setTimeout(resolve, 650));
  fake.send({ type: 'session.output_transcript.delta', delta: 'Mach ich, für wann?' });
  fake.send({ type: 'session.input_transcript.delta', delta: 'lieber um drei' });
  fake.send({ type: 'session.delegation.created', delegation: { id: 'item_b', target: 'client' } });

  const ack = await fake.next((event) => event.type === 'session.thinking.append'
    && event.delegation_id === 'item_b');
  assert.ok(ack.content);
  assert.equal(engine.runs.length, 1);
  assert.deepEqual(engine.steering, [{ runId: engine.runs[0].options.runId, content: 'lieber um drei' }]);

  // The client hangs up; the task keeps running and its result lands in chat.
  await manager.detachSession(session.id, 'socket_disconnected', user.userId);
  assert.ok(manager.getSession(session.id));
  finishRun();
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(manager.getSession(session.id), null);
  const reply = historyRows(ctx.db, user.userId).find((row) => row.agent_run_id);
  assert.equal(reply.role, 'assistant');
  assert.equal(reply.content, 'Termin steht.');
  assert.equal(reply.agent_run_id, engine.runs[0].options.runId);
});

test('Gemini Live session: run_task returns at once, outcome as a message, interruption, and resumption', async (t) => {
  const ctx = createTestRuntime();
  const fake = await startFakeLiveServer();
  t.after(async () => {
    await fake.close();
    teardownTestRuntime(ctx);
  });
  process.env.GOOGLE_AI_KEY = 'test-google-key';

  let manager = null;
  const engine = createFakeEngine({
    async run(_userId, request, options) {
      this.runs.push({ request, options });
      return { status: 'completed', content: 'Es sind 21 Grad.' };
    },
  });
  const setup = await setupManager(ctx, engine, {
    voice_live_provider: 'google',
    voice_live_voice: 'Puck',
    voice_input_mode: 'ptt',
  });
  manager = setup.manager;
  const { user } = setup;
  const { LiveVoiceSession } = require('../../../server/services/voice/live/session');
  const sink = createSink();
  // Google has no configurable base URL; point this session at the fake server.
  const session = new LiveVoiceSession({
    id: 'gemini-session',
    userId: user.userId,
    agentId: null,
    platform: 'voice_live',
    sink,
    agentEngine: engine,
    conversationId: setup.conversationId,
    settings: require('../../../server/services/voice/liveSettings').getVoiceRuntimeSettings(user.userId),
    credentials: { apiKey: 'test-google-key', baseUrl: fake.url },
    onIdle: () => {},
  });
  manager.sessions.set(session.id, session);
  const connecting = session.connect();
  const setupMessage = await fake.next((event) => event.setup);
  assert.match(fake.paths[0], /BidiGenerateContent\?key=test-google-key$/);
  assert.equal(setupMessage.setup.model, 'models/gemini-3.8-live');
  assert.equal(
    setupMessage.setup.generationConfig.speechConfig.voiceConfig.prebuiltVoiceConfig.voiceName,
    'Puck',
  );
  const declaration = setupMessage.setup.tools[0].functionDeclarations[0];
  assert.equal(declaration.name, 'run_task');
  assert.match(setupMessage.setup.systemInstruction.parts[0].text, /SYSTEM PROMPT role=front/);
  fake.send({ setupComplete: {} });
  await connecting;
  assert.equal(sink.of('session_ready')[0].inputSampleRate, 16000);
  assert.equal(sink.of('session_ready')[0].inputMode, 'ptt');

  session.appendAudio(Buffer.from([5, 6]));
  const audio = await fake.next((event) => event.realtimeInput?.audio);
  assert.equal(audio.realtimeInput.audio.mimeType, 'audio/pcm;rate=16000');
  session.endInput();
  await fake.next((event) => event.realtimeInput?.audioStreamEnd === true);

  fake.send({ serverContent: { inputTranscription: { text: 'Wie warm ist es?' } } });
  fake.send({ toolCall: { functionCalls: [{ id: 'call-1', name: 'run_task', args: { request: 'Aktuelle Temperatur in Berlin' } }] } });
  // The call returns at once with the task's real state, so the model never
  // has an open call to invent an outcome for.
  const response = await fake.next((event) => event.toolResponse);
  const started = response.toolResponse.functionResponses[0];
  assert.equal(started.id, 'call-1');
  assert.match(started.response.result, /Nothing is done yet/);
  const outcome = await fake.next((event) => event.clientContent?.turnComplete === true);
  assert.match(outcome.clientContent.turns[0].parts[0].text, /Task "Aktuelle Temperatur in Berlin": The task finished\. Its outcome:\nEs sind 21 Grad\./);
  assert.equal(engine.runs[0].request, 'Aktuelle Temperatur in Berlin');

  fake.send({ serverContent: { modelTurn: { parts: [{ inlineData: { mimeType: 'audio/pcm;rate=24000', data: 'AAE=' } }] } } });
  fake.send({ serverContent: { interrupted: true } });
  await new Promise((resolve) => setTimeout(resolve, 20));
  assert.equal(sink.of('audio')[0].audioBase64, 'AAE=');
  assert.equal(sink.of('interrupted').length, 1);

  fake.send({ sessionResumptionUpdate: { newHandle: 'resume-1', resumable: true } });
  fake.send({ goAway: { timeLeft: '5s' } });
  const resumed = await fake.next((event) => event.setup?.sessionResumption?.handle === 'resume-1');
  assert.ok(resumed);
  fake.send({ setupComplete: {} });
  await new Promise((resolve) => setTimeout(resolve, 20));
  assert.equal(sink.of('session_ready').at(-1).reconnected, true);
  await session.close('test_done');
});

test('a voice delivery whose call has ended is shown in chat instead', async () => {
  const { transmit } = require('../../../server/services/ai/runtime/delivery/delivery_worker');
  const emitted = [];
  const engine = {
    voiceRuntimeManager: { presentDelivery: () => ({ detached: true }) },
    emit(userId, event, payload) {
      emitted.push({ userId, event, payload });
    },
  };
  const result = await transmit(engine, {
    id: 'outbox-1',
    channel: 'voice_live',
    recipient: 'gone-session',
    messageKind: 'final',
    payload: { content: 'Fertig.' },
  }, { id: 'run-1', userId: 7 });
  assert.equal(result.ok, true);
  assert.equal(emitted[0].event, 'run:complete');
  assert.equal(emitted[0].payload.content, 'Fertig.');
});
