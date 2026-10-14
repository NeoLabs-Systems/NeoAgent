'use strict';

const assert = require('node:assert/strict');
const http = require('node:http');
const { once } = require('node:events');
const { mock, test } = require('node:test');
const { WebSocketServer } = require('ws');

const {
  createTestRuntime,
  createTestUser,
  teardownTestRuntime,
} = require('../../helpers/db');

// What OpenAI's model list returns: the live model among models the call
// cannot use.
const OPENAI_MODELS = [
  { id: 'gpt-realtime-2', object: 'model', created: 1778006032, owned_by: 'system' },
  { id: 'gpt-live-1', object: 'model', created: 1788889407, owned_by: 'system' },
  { id: 'gpt-live-transcribe', object: 'model', created: 1785168034, owned_by: 'system' },
  { id: 'gpt-5.5', object: 'model', created: 1776000000, owned_by: 'system' },
];

// A local stand-in for the provider: its live socket records every client
// event and lets the test push server events, and it serves OpenAI's model
// list.
async function startFakeLiveServer() {
  const httpServer = http.createServer((req, res) => {
    res.setHeader('content-type', 'application/json');
    if (req.url === '/v1/models') {
      res.end(JSON.stringify({ object: 'list', data: OPENAI_MODELS }));
      return;
    }
    res.statusCode = 404;
    res.end('{}');
  });
  const wss = new WebSocketServer({ server: httpServer });
  httpServer.listen(0, '127.0.0.1');
  await once(httpServer, 'listening');
  const server = {
    url: `http://127.0.0.1:${httpServer.address().port}`,
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
      wss.close();
      return new Promise((resolve) => httpServer.close(resolve));
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

// Mirrors the engine's run registry: the task tools read the owner's running
// runs from activeRuns, the way the real engine keeps them.
function createFakeEngine(overrides = {}) {
  return {
    runs: [],
    aborted: [],
    activeRuns: new Map(),
    getRunMeta(runId) {
      return this.activeRuns.get(runId) || null;
    },
    track(userId, request, options = {}) {
      const { resolveAgentId } = require('../../../server/services/agents/manager');
      this.activeRuns.set(options.runId, {
        userId,
        agentId: resolveAgentId(userId, options.agentId || null),
        status: 'running',
        aborted: false,
        triggerType: 'user',
        triggerSource: options.triggerSource || 'web',
        request,
        startedAtIso: new Date().toISOString(),
        backgroundEligible: options.backgroundEligible !== false,
        background: { since: new Date().toISOString() },
        systemSteeringQueue: [],
      });
    },
    finish(runId) {
      this.activeRuns.delete(runId);
    },
    enqueueSystemSteering(runId, content) {
      const meta = this.activeRuns.get(runId);
      if (!meta) return null;
      meta.systemSteeringQueue.push({ content });
      return { content };
    },
    recordRunEvent() {},
    abort(runId) {
      const meta = this.activeRuns.get(runId);
      if (!meta || meta.aborted) return false;
      meta.aborted = true;
      this.aborted.push(runId);
      return true;
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

// Google has no configurable base URL, so the session is built directly and
// pointed at the fake server, with the model the manager would have resolved
// from Google's model list.
async function connectGemini(fake, engine, setup, {
  id = 'gemini-session',
  model = 'gemini-3.8-live',
  thinking = false,
} = {}) {
  const { LiveVoiceSession } = require('../../../server/services/voice/live/session');
  const { getVoiceRuntimeSettings } = require('../../../server/services/voice/liveSettings');
  const sink = createSink();
  const session = new LiveVoiceSession({
    id,
    userId: setup.user.userId,
    agentId: null,
    platform: 'voice_live',
    sink,
    agentEngine: engine,
    conversationId: setup.conversationId,
    settings: {
      ...getVoiceRuntimeSettings(setup.user.userId),
      liveModel: model,
      liveModelThinks: thinking,
    },
    credentials: { apiKey: 'test-google-key', baseUrl: fake.url },
    onIdle: () => {},
    onHangUp: (ended) => setup.manager.closeSession(ended.id, 'agent_hung_up', ended.userId),
  });
  setup.manager.sessions.set(session.id, session);
  const connecting = session.connect();
  const setupMessage = await fake.next((event) => event.setup);
  fake.send({ setupComplete: {} });
  await connecting;
  return { session, sink, setupMessage };
}

const pause = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

test('live voice settings name a model only when one is configured', () => {
  const previous = { ...process.env };
  try {
    delete process.env.VOICE_LIVE_PROVIDER;
    delete process.env.VOICE_LIVE_MODEL;
    const catalog = require('../../../server/services/voice/live/catalog');
    assert.equal(catalog.normalizeLiveProvider(''), 'openai');
    assert.equal(catalog.configuredLiveModel('google', ''), '');
    assert.equal(catalog.resolveLiveVoice('google', ''), 'Kore');
    assert.equal(catalog.normalizeInputMode('bogus'), 'hands_free');

    process.env.VOICE_LIVE_PROVIDER = 'google';
    process.env.VOICE_LIVE_MODEL = 'gemini-3.1-flash-live-preview';
    assert.equal(catalog.normalizeLiveProvider('unknown'), 'google');
    assert.equal(catalog.configuredLiveModel('google', ''), 'gemini-3.1-flash-live-preview');
    assert.equal(catalog.configuredLiveModel('openai', ''), '');
    assert.equal(catalog.configuredLiveModel('google', 'custom-live'), 'custom-live');
  } finally {
    process.env = previous;
  }
});

test('without a choice, calls take the newest released model of the provider\'s list', () => {
  const { rankLiveModels } = require('../../../server/services/voice/live/models');
  const ranked = rankLiveModels([
    { id: 'gemini-2.5-flash-native-audio-preview-12-2025' },
    { id: 'gemini-3.1-flash-live-preview' },
    { id: 'gemini-3.8-live-extended-thinking' },
    { id: 'gemini-2.5-flash-native-audio-latest' },
    { id: 'gemini-3.8-live' },
    { id: 'gemini-4.0-live-preview' },
  ]).map((model) => model.id);
  assert.deepEqual(ranked, [
    'gemini-3.8-live',
    'gemini-3.8-live-extended-thinking',
    'gemini-2.5-flash-native-audio-latest',
    'gemini-4.0-live-preview',
    'gemini-3.1-flash-live-preview',
    'gemini-2.5-flash-native-audio-preview-12-2025',
  ]);
  assert.equal(rankLiveModels([{ id: 'gpt-live-1' }, { id: 'gpt-live-2' }])[0].id, 'gpt-live-2');
});

test('Google\'s live models come from its model list, with what it says about thinking', async (t) => {
  const ctx = createTestRuntime();
  const previousFetch = global.fetch;
  const requests = [];
  global.fetch = async (url, options) => {
    requests.push({ url: String(url), key: options?.headers?.['x-goog-api-key'] });
    const model = (name, methods, extra = {}) => ({
      name: `models/${name}`,
      displayName: name,
      supportedGenerationMethods: methods,
      ...extra,
    });
    return new Response(JSON.stringify({
      models: [
        model('gemini-3.5-pro', ['generateContent']),
        model('gemini-3.8-live', ['bidiGenerateContent']),
        model('gemini-3.8-live-extended-thinking', ['bidiGenerateContent'], { thinking: true }),
        model('gemini-3.1-flash-live-preview', ['bidiGenerateContent']),
        model('gemini-3.5-transcribe-live', ['bidiGenerateContent']),
        model('gemini-3.5-live-translate-preview', ['bidiGenerateContent']),
        model('gemini-robotics-er-2-streaming-preview', ['bidiGenerateContent']),
      ],
    }), { status: 200, headers: { 'content-type': 'application/json' } });
  };
  t.after(() => {
    global.fetch = previousFetch;
    teardownTestRuntime(ctx);
  });
  process.env.GOOGLE_AI_KEY = 'listing-key';
  const user = await createTestUser(ctx.db);
  const { describeLiveVoiceCatalog, resolveLiveModel } = require('../../../server/services/voice/live/models');

  const catalog = await describeLiveVoiceCatalog({ userId: user.userId });
  const google = catalog.providers.find((provider) => provider.id === 'google');
  assert.deepEqual(google.models, [
    'gemini-3.8-live',
    'gemini-3.8-live-extended-thinking',
    'gemini-3.1-flash-live-preview',
  ]);
  assert.equal(google.defaultModel, 'gemini-3.8-live');
  assert.equal(requests[0].key, 'listing-key');

  const chosen = await resolveLiveModel({
    userId: user.userId,
    agentId: null,
    providerId: 'google',
    configured: 'gemini-3.8-live-extended-thinking',
  });
  assert.equal(chosen.thinking, true);
  assert.equal(
    (await resolveLiveModel({ userId: user.userId, agentId: null, providerId: 'google', configured: '' })).id,
    'gemini-3.8-live',
  );
  // The list is cached: the lookups above asked Google once.
  assert.equal(requests.length, 1);
});

test('the live model speaks with the shared persona; delegated tasks keep the agent prompt', async (t) => {
  const ctx = createTestRuntime();
  t.after(() => teardownTestRuntime(ctx));
  const user = await createTestUser(ctx.db);
  const { buildSystemPromptSections } = require('../../../server/services/ai/systemPrompt');
  const { buildLivePrompt } = require('../../../server/services/voice/live/prompt');
  const memoryManager = {
    buildContext: async () => '',
    getCoreMemory: () => ({ hometown: 'Berlin' }),
    getUserProfile: () => ({ static: ['Favourite colour is petrol blue'], dynamic: [] }),
    getAssistantBehaviorNotes: () => 'Keep jokes dry.',
    getAssistantSelfState: () => ({ identity: {}, focus: {} }),
  };

  const front = await buildLivePrompt({ memoryManager, userId: user.userId, agentId: null, conversationId: null });
  assert.match(front.instructions, /you're on a live voice call with/);
  assert.match(front.instructions, /how you talk:/);
  assert.doesNotMatch(front.instructions, /\[NO RESPONSE\]|separate texts/);
  assert.match(front.instructions, /hometown: Berlin/);
  assert.match(front.instructions, /Favourite colour is petrol blue/);
  assert.match(front.instructions, /Keep jokes dry\./);
  assert.match(front.instructions, /^## rules for this call/);
  assert.doesNotMatch(front.instructions, /CRITICAL EXECUTION RULES/);

  // A hand-off run keeps the agent prompt and writes with the same persona,
  // in its spoken form because the live model reads the result out.
  const task = await buildSystemPromptSections(user.userId, { triggerSource: 'voice_live' }, memoryManager);
  assert.match(task.stable, /CRITICAL EXECUTION RULES/);
  assert.match(task.stable, /LIVE VOICE TASK/);
  assert.match(task.stable, /you're on a live voice call with/);
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
      this.track(userId, request, options);
      manager.presentDelivery({
        recipient: options.voiceSessionId,
        runId: options.runId,
        messageKind: 'final',
        payload: { content: 'Die Mail an Max ist raus.' },
      });
      this.finish(options.runId);
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
  // Nobody picked a model: the call takes the live model OpenAI's list shows.
  assert.equal(start.session.model, 'gpt-live-1');
  assert.equal(start.session.audio.output.voice, 'marin');
  assert.deepEqual(start.session.delegation, { type: 'client' });
  assert.match(start.session.instructions, /you're on a live voice call with/);
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

  // The result waits until the model's "Mach ich." has played, then goes to
  // the hand-off that asked for it.
  const result = await fake.next((event) => event.type === 'session.commentary.append');
  assert.equal(result.delegation_id, 'item_1');
  assert.match(result.content, /^task 1 \("Schreib Max dass ich später komme"\) finished\. Its outcome:\nDie Mail an Max ist raus\.$/);

  assert.equal(engine.runs.length, 1);
  const run = engine.runs[0];
  assert.equal(run.request, 'Schreib Max dass ich später komme');
  assert.equal(run.options.triggerSource, 'voice_live');
  assert.equal(run.options.voiceSessionId, session.id);
  assert.equal(run.options.conversationId, conversationId);
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

test('each GPT-Live hand-off is a task of its own, and running tasks outlive the call', async (t) => {
  const ctx = createTestRuntime();
  const fake = await startFakeLiveServer();
  t.after(async () => {
    await fake.close();
    teardownTestRuntime(ctx);
  });
  process.env.OPENAI_API_KEY = 'test-openai-key';
  process.env.OPENAI_BASE_URL = `${fake.url}/v1`;

  const finish = new Map();
  const engine = createFakeEngine({
    run(userId, request, options) {
      this.runs.push({ request, options });
      this.track(userId, request, options);
      return new Promise((resolve) => {
        finish.set(request, (content) => {
          this.finish(options.runId);
          resolve({ status: 'completed', content });
        });
      });
    },
  });
  const { user, manager } = await setupManager(ctx, engine);
  const sink = createSink();
  const opening = manager.openSession({ userId: user.userId, sink });
  await fake.next((event) => event.type === 'session.start');
  fake.send({ type: 'session.started', session: { id: 'sess_2' } });
  const session = await opening;

  fake.send({ type: 'session.input_transcript.delta', delta: 'Leg einen Termin an' });
  fake.send({ type: 'session.delegation.created', delegation: { id: 'item_a', target: 'client' } });
  await new Promise((resolve) => setTimeout(resolve, 650));
  fake.send({ type: 'session.output_transcript.delta', delta: 'Mach ich.' });
  fake.send({ type: 'session.input_transcript.delta', delta: 'Und schreib Lisa, dass ich später komme' });
  fake.send({ type: 'session.delegation.created', delegation: { id: 'item_b', target: 'client' } });
  await new Promise((resolve) => setTimeout(resolve, 650));

  // The second request does not land in the first task: both run side by side.
  assert.deepEqual(engine.runs.map((run) => run.request), [
    'Leg einen Termin an',
    'Und schreib Lisa, dass ich später komme',
  ]);
  assert.deepEqual(session.tasks.runningTasks.map((task) => task.taskId), ['1', '2']);
  assert.deepEqual(sink.of('task').map((event) => event.status), ['running', 'running']);

  // The client hangs up; the tasks keep running and their results land in chat.
  await manager.detachSession(session.id, 'socket_disconnected', user.userId);
  finish.get('Leg einen Termin an')('Termin steht.');
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(manager.getSession(session.id), session);
  finish.get('Und schreib Lisa, dass ich später komme')('Lisa weiß Bescheid.');
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(manager.getSession(session.id), null);
  const replies = historyRows(ctx.db, user.userId).filter((row) => row.agent_run_id);
  assert.deepEqual(replies.map((row) => row.content), ['Termin steht.', 'Lisa weiß Bescheid.']);
});

test('wearable calls are push-to-talk even when the agent is set to hands-free', async (t) => {
  const ctx = createTestRuntime();
  const fake = await startFakeLiveServer();
  t.after(async () => {
    await fake.close();
    teardownTestRuntime(ctx);
  });
  process.env.OPENAI_API_KEY = 'test-openai-key';
  process.env.OPENAI_BASE_URL = `${fake.url}/v1`;

  const { user, manager } = await setupManager(ctx, createFakeEngine(), { voice_input_mode: 'hands_free' });
  const sink = createSink();
  const opening = manager.openWearableSession({ userId: user.userId, sink });
  await fake.next((event) => event.type === 'session.start');
  fake.send({ type: 'session.started', session: { id: 'sess_wearable' } });
  const session = await opening;

  assert.equal(sink.of('session_ready')[0].inputMode, 'ptt');
  await manager.closeSession(session.id, 'test_done', user.userId);
});

test('Gemini Live session: run_task returns at once, outcome as a message, interruption, and resumption', async (t) => {
  const ctx = createTestRuntime();
  const fake = await startFakeLiveServer();
  t.after(async () => {
    await fake.close();
    teardownTestRuntime(ctx);
  });
  process.env.GOOGLE_AI_KEY = 'test-google-key';

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
  const { session, sink, setupMessage } = await connectGemini(fake, engine, setup);
  assert.match(fake.paths[0], /BidiGenerateContent\?key=test-google-key$/);
  assert.equal(setupMessage.setup.model, 'models/gemini-3.8-live');
  assert.equal(
    setupMessage.setup.generationConfig.speechConfig.voiceConfig.prebuiltVoiceConfig.voiceName,
    'Puck',
  );
  const declaration = setupMessage.setup.tools[0].functionDeclarations[0];
  assert.equal(declaration.name, 'run_task');
  assert.match(setupMessage.setup.systemInstruction.parts[0].text, /## rules for this call/);
  // Push-to-talk turns are marked explicitly instead of detected from silence.
  assert.deepEqual(setupMessage.setup.realtimeInputConfig, { automaticActivityDetection: { disabled: true } });
  // A model the list does not mark as thinking rejects a thinking level.
  assert.equal(setupMessage.setup.generationConfig.thinkingConfig, undefined);
  assert.equal(sink.of('session_ready')[0].inputSampleRate, 16000);
  assert.equal(sink.of('session_ready')[0].inputMode, 'ptt');

  session.startInput();
  await fake.next((event) => event.realtimeInput?.activityStart);
  session.appendAudio(Buffer.from([5, 6]));
  const audio = await fake.next((event) => event.realtimeInput?.audio);
  assert.equal(audio.realtimeInput.audio.mimeType, 'audio/pcm;rate=16000');
  session.endInput();
  await fake.next((event) => event.realtimeInput?.activityEnd);

  fake.send({ serverContent: { inputTranscription: { text: 'Wie warm ist es?' } } });
  fake.send({ toolCall: { functionCalls: [{ id: 'call-1', name: 'run_task', args: { request: 'Aktuelle Temperatur in Berlin' } }] } });
  // The call returns at once with the task's real state, so the model never
  // has an open call to invent an outcome for.
  const response = await fake.next((event) => event.toolResponse);
  const started = response.toolResponse.functionResponses[0];
  assert.equal(started.id, 'call-1');
  assert.match(started.response.result, /Nothing is done, saved, or sent yet/);
  assert.equal(started.response.task_id, '1');
  // The outcome waits until the model has answered the tool call: a new turn
  // would cut that answer off.
  await pause(20);
  assert.ok(!fake.received.some((event) => event.clientContent));
  fake.send({ serverContent: { modelTurn: { parts: [{ inlineData: { data: 'AAE=' } }] } } });
  fake.send({ serverContent: { turnComplete: true } });
  const outcome = await fake.next((event) => event.clientContent?.turnComplete === true);
  assert.match(outcome.clientContent.turns[0].parts[0].text, /task 1 \("Aktuelle Temperatur in Berlin"\) finished\. Its outcome:\nEs sind 21 Grad\./);
  assert.equal(engine.runs[0].request, 'Aktuelle Temperatur in Berlin');

  fake.send({ serverContent: { modelTurn: { parts: [{ inlineData: { mimeType: 'audio/pcm;rate=24000', data: 'AAE=' } }] } } });
  const interruptionsBefore = sink.of('interrupted').length;
  fake.send({ serverContent: { interrupted: true } });
  await new Promise((resolve) => setTimeout(resolve, 20));
  assert.equal(sink.of('audio')[0].audioBase64, 'AAE=');
  assert.equal(sink.of('interrupted').length, interruptionsBefore + 1);

  fake.send({ sessionResumptionUpdate: { newHandle: 'resume-1', resumable: true } });
  fake.send({ goAway: { timeLeft: '5s' } });
  const resumed = await fake.next((event) => event.setup?.sessionResumption?.handle === 'resume-1');
  assert.ok(resumed);
  fake.send({ setupComplete: {} });
  await new Promise((resolve) => setTimeout(resolve, 20));
  assert.equal(sink.of('session_ready').at(-1).reconnected, true);
  await session.close('test_done');
});

test('Gemini Live can hang up, after its goodbye has played out', async (t) => {
  const ctx = createTestRuntime();
  const fake = await startFakeLiveServer();
  t.after(async () => {
    await fake.close();
    teardownTestRuntime(ctx);
  });
  process.env.GOOGLE_AI_KEY = 'test-google-key';
  const engine = createFakeEngine();
  const setup = await setupManager(ctx, engine, { voice_live_provider: 'google' });
  const { manager } = setup;
  const { session, sink, setupMessage } = await connectGemini(fake, engine, setup, { id: 'gemini-hangup' });
  const names = setupMessage.setup.tools[0].functionDeclarations.map((declaration) => declaration.name);
  assert.deepEqual(names, ['run_task', 'check_tasks', 'update_task', 'cancel_task', 'end_call']);
  // Hands-free, only clear speech starts the owner's turn, so the call's own
  // audio coming back through the microphone does not cut the model off.
  assert.deepEqual(setupMessage.setup.realtimeInputConfig, {
    automaticActivityDetection: { startOfSpeechSensitivity: 'START_SENSITIVITY_LOW' },
  });

  // 300 ms of goodbye at 24 kHz, then the hang-up.
  const goodbye = Buffer.alloc(24000 * 2 * 0.3).toString('base64');
  fake.send({ serverContent: { modelTurn: { parts: [{ inlineData: { data: goodbye } }] } } });
  fake.send({ toolCall: { functionCalls: [{ id: 'bye-1', name: 'end_call', args: {} }] } });
  await new Promise((resolve) => setTimeout(resolve, 400));
  assert.equal(manager.getSession(session.id), session);
  assert.ok(!sink.of('state').some((event) => event.state === 'closed'));

  await new Promise((resolve) => setTimeout(resolve, 700));
  assert.equal(manager.getSession(session.id), null);
  const closed = sink.of('state').filter((event) => event.state === 'closed');
  assert.deepEqual(closed.map((event) => event.reason), ['agent_hung_up']);
  // The hang-up is not answered: nothing more is said on the line.
  assert.ok(!fake.received.some((event) => event.toolResponse));
});

test('Gemini Live task tools check, change, and stop the owner\'s running tasks', async (t) => {
  const ctx = createTestRuntime();
  const fake = await startFakeLiveServer();
  t.after(async () => {
    await fake.close();
    teardownTestRuntime(ctx);
  });
  process.env.GOOGLE_AI_KEY = 'test-google-key';
  const finish = new Map();
  const engine = createFakeEngine({
    run(userId, request, options) {
      this.runs.push({ request, options });
      this.track(userId, request, options);
      return new Promise((resolve) => finish.set(options.runId, (result) => {
        this.finish(options.runId);
        resolve(result);
      }));
    },
  });
  const setup = await setupManager(ctx, engine, { voice_live_provider: 'google' });
  // A chat task of the owner's and another account's task are already running.
  engine.track(setup.user.userId, 'Fasse meine Mails zusammen', { runId: 'chat-run', triggerSource: 'web' });
  const stranger = await createTestUser(ctx.db, { username: 'someone_else' });
  engine.track(stranger.userId, 'Fremde Aufgabe', { runId: 'stranger-run', triggerSource: 'web' });
  const { session, sink, setupMessage } = await connectGemini(fake, engine, setup);

  // The call starts knowing what is already running.
  assert.match(
    setupMessage.setup.systemInstruction.parts[0].text,
    /- task 1 \(started in the chat, running for 0 min\): Fasse meine Mails zusammen/,
  );
  const answer = async (id, name, args = {}) => {
    fake.send({ toolCall: { functionCalls: [{ id, name, args }] } });
    const message = await fake.next((event) => event.toolResponse?.functionResponses?.[0]?.id === id);
    return message.toolResponse.functionResponses[0].response;
  };

  assert.equal((await answer('call-1', 'run_task', { request: 'Recherchiere Laptops unter 1000 Euro' })).task_id, '2');
  const status = await answer('call-2', 'check_tasks');
  assert.deepEqual(status.tasks.map((task) => [task.task_id, task.started_in, task.request]), [
    ['1', 'the chat', 'Fasse meine Mails zusammen'],
    ['2', 'this call', 'Recherchiere Laptops unter 1000 Euro'],
  ]);

  // With two tasks running, the model has to say which one.
  const unnamed = await answer('call-3', 'cancel_task');
  assert.match(unnamed.error, /task_id/);
  assert.equal(unnamed.tasks.length, 2);
  assert.deepEqual(engine.aborted, []);

  const voiceRunId = engine.runs[0].options.runId;
  const instructed = await answer('call-4', 'update_task', { task_id: '2', instruction: 'Auch Geräte bis 1200 Euro' });
  assert.equal(instructed.instructed, true);
  assert.match(engine.getRunMeta(voiceRunId).systemSteeringQueue[0].content, /Auch Geräte bis 1200 Euro/);

  const cancelled = await answer('call-5', 'cancel_task', { task_id: '2' });
  assert.equal(cancelled.cancelled, true);
  assert.deepEqual(engine.aborted, [voiceRunId]);

  // The model already said it stopped the task; its end is not announced again.
  finish.get(voiceRunId)({ status: 'stopped', content: '' });
  fake.send({ serverContent: { turnComplete: true } });
  await pause(20);
  assert.ok(!fake.received.some((event) => event.clientContent));
  assert.deepEqual(sink.of('task').map((event) => event.status), ['running', 'stopped']);
  await session.close('test_done');
});

test('progress is spoken into a quiet line and kept as context while people talk', async (t) => {
  const ctx = createTestRuntime();
  const fake = await startFakeLiveServer();
  t.after(async () => {
    mock.timers.reset();
    await fake.close();
    teardownTestRuntime(ctx);
  });
  process.env.GOOGLE_AI_KEY = 'test-google-key';
  const engine = createFakeEngine({
    run(userId, request, options) {
      this.runs.push({ request, options });
      this.track(userId, request, options);
      return new Promise(() => {});
    },
  });
  const setup = await setupManager(ctx, engine, { voice_live_provider: 'google' });
  const { session } = await connectGemini(fake, engine, setup);
  mock.timers.enable({ apis: ['Date'], now: Date.now() });

  fake.send({ toolCall: { functionCalls: [{ id: 'call-1', name: 'run_task', args: { request: 'Recherchiere Laptops' } }] } });
  await fake.next((event) => event.toolResponse);
  const runId = engine.runs[0].options.runId;
  const present = (messageKind, content, metadata) => setup.manager.presentDelivery({
    recipient: session.id,
    runId,
    messageKind,
    payload: { content, metadata },
  });
  const modelSpeaks = async () => {
    fake.send({ serverContent: { modelTurn: { parts: [{ inlineData: { data: 'AAE=' } }] } } });
    fake.send({ serverContent: { turnComplete: true } });
    await pause(20);
  };
  const delivered = (pattern) => fake.next((event) => pattern.test(event.clientContent?.turns?.[0]?.parts?.[0]?.text || ''));

  // The owner asks something: the update waits for the answer, then joins
  // the context without being read out.
  await modelSpeaks();
  fake.send({ serverContent: { inputTranscription: { text: 'Wie lange dauert das?' } } });
  await pause(20);
  present('progress', 'Zwei Testberichte gefunden.', { liveness: { status: 'working' } });
  await pause(20);
  assert.ok(!fake.received.some((event) => event.clientContent));
  await modelSpeaks();
  const note = await delivered(/Zwei Testberichte gefunden/);
  assert.equal(note.clientContent.turnComplete, false);
  assert.match(note.clientContent.turns[0].parts[0].text, /Progress on task 1 \("Recherchiere Laptops"\):\nZwei Testberichte gefunden\./);

  // After a silence the next update is spoken.
  mock.timers.tick(7000);
  present('progress', 'Drei Modelle im Vergleich.', { liveness: { status: 'working' } });
  const spoken = await delivered(/Drei Modelle im Vergleich/);
  assert.equal(spoken.clientContent.turnComplete, true);
  assert.match(spoken.clientContent.turns[0].parts[0].text, /^Tell the owner now/);

  // Within a minute of a spoken update, the next one stays context.
  await modelSpeaks();
  await pause(750);
  mock.timers.tick(7000);
  present('progress', 'Preise geprüft.', { liveness: { status: 'working' } });
  assert.equal((await delivered(/Preise geprüft/)).clientContent.turnComplete, false);

  // A question from the task is put to the owner at once.
  present('interim', 'Welche Marke bevorzugst du?', { kind: 'question', expectsReply: true });
  assert.equal((await delivered(/Welche Marke bevorzugst du\?/)).clientContent.turnComplete, true);
  await session.close('test_done');
});

test('a thinking Gemini model gets a thinking level and keeps the line while it works', async (t) => {
  const ctx = createTestRuntime();
  const fake = await startFakeLiveServer();
  t.after(async () => {
    await fake.close();
    teardownTestRuntime(ctx);
  });
  process.env.GOOGLE_AI_KEY = 'test-google-key';
  const engine = createFakeEngine({
    async run(userId, request, options) {
      this.runs.push({ request, options });
      return { status: 'completed', content: 'Notiert.' };
    },
  });
  const setup = await setupManager(ctx, engine, { voice_live_provider: 'google' });
  // Google's model list marks it as thinking; such models need a level.
  const { session, setupMessage } = await connectGemini(fake, engine, setup, {
    model: 'gemini-3.8-live-extended-thinking',
    thinking: true,
  });
  assert.equal(setupMessage.setup.model, 'models/gemini-3.8-live-extended-thinking');
  assert.deepEqual(setupMessage.setup.generationConfig.thinkingConfig, { thinkingLevel: 'low' });

  fake.send({ toolCall: { functionCalls: [{ id: 'call-1', name: 'run_task', args: { request: 'Merk dir den Termin' } }] } });
  await fake.next((event) => event.toolResponse);
  // The model speaks and ends its turn while it is still working: its speech
  // is over, but the line stays its own until it reports idle.
  fake.send({ serverContent: { modelTurn: { parts: [{ inlineData: { data: 'AAE=' } }] } } });
  fake.send({ serverContent: { turnComplete: true, interactionStatus: 'IN_PROGRESS' } });
  await pause(750);
  assert.ok(!fake.received.some((event) => event.clientContent));
  fake.send({ serverContent: { turnComplete: true, interactionStatus: 'IDLE' } });
  const outcome = await fake.next((event) => event.clientContent?.turnComplete === true);
  assert.match(outcome.clientContent.turns[0].parts[0].text, /task 1 \("Merk dir den Termin"\) finished\. Its outcome:\nNotiert\./);
  await session.close('test_done');
});

test('a call left open without speech or tasks hangs up after three minutes', async (t) => {
  const ctx = createTestRuntime();
  const fake = await startFakeLiveServer();
  t.after(async () => {
    mock.timers.reset();
    await fake.close();
    teardownTestRuntime(ctx);
  });
  process.env.OPENAI_API_KEY = 'test-openai-key';
  process.env.OPENAI_BASE_URL = `${fake.url}/v1`;
  const { user, manager } = await setupManager(ctx, createFakeEngine());
  const sink = createSink();
  mock.timers.enable({ apis: ['setTimeout'] });
  const opening = manager.openSession({ userId: user.userId, sink });
  await fake.next((event) => event.type === 'session.start');
  fake.send({ type: 'session.started', session: { id: 'sess_idle' } });
  const session = await opening;

  mock.timers.tick(2 * 60 * 1000);
  fake.send({ type: 'session.input_transcript.delta', delta: 'Bist du noch da?' });
  // setTimeout is mocked, so wait on the event loop for the socket message.
  for (let i = 0; i < 5000 && !sink.of('transcript').length; i += 1) {
    await new Promise((resolve) => setImmediate(resolve));
  }
  assert.equal(sink.of('transcript').length, 1);
  mock.timers.tick(2 * 60 * 1000);
  assert.equal(manager.getSession(session.id), session);

  mock.timers.tick(60 * 1000);
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(manager.getSession(session.id), null);
  assert.ok(sink.of('state').some((event) => event.state === 'closed' && event.reason === 'idle_timeout'));
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
