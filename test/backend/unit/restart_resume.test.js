'use strict';

const assert = require('node:assert/strict');
const { after, before, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');
const { throwIfAborted } = require('../../../server/utils/abort');

let ctx;
let userId;
let AgentEngine;
let resume;
let recoverOrphanedRuns;

before(async () => {
  ctx = createTestRuntime();
  userId = (await createTestUser(ctx.db, { username: 'restart_resume_user' })).userId;

  const { ensureDefaultAiSettings } = require('../../../server/services/ai/settings');
  ensureDefaultAiSettings(userId, null);

  const providerPath = require.resolve('../../../server/services/ai/provider_selector');
  require(providerPath);
  require.cache[providerPath].exports.getProviderForUser = async () => ({
    provider: {},
    model: 'test-model',
    modelSelectionId: 'test/test-model',
    providerName: 'test',
  });
  const capPath = require.resolve('../../../server/services/ai/capabilityHealth');
  require(capPath);
  require.cache[capPath].exports.getCapabilityHealth = async () => ({});
  require.cache[capPath].exports.summarizeCapabilityHealth = () => '';
  for (const key of Object.keys(require.cache)) {
    if (
      key.includes('/server/services/ai/runtime/')
      || key.includes('/server/services/ai/loop/')
      || key.endsWith('/server/services/ai/engine.js')
    ) {
      delete require.cache[key];
    }
  }

  ({ AgentEngine } = require('../../../server/services/ai/engine'));
  resume = require('../../../server/services/ai/runtime/restart_resume');
  ({ recoverOrphanedRuns } = require('../../../server/services/ai/runtime/recovery_startup'));
});

after(() => teardownTestRuntime(ctx));

function createEngine(onModelCall) {
  const engine = new AgentEngine(null);
  engine.emit = () => {};
  engine.buildSystemPrompt = async () => 'system';
  engine.buildMemoryRecall = async () => null;
  engine.buildContextMessages = (system, summary, history) => [
    { role: 'system', content: system },
    ...(history || []),
  ];
  engine.buildUserMessage = (message) => ({ role: 'user', content: message });
  engine.getAvailableTools = () => [];
  engine.getReasoningEffort = () => undefined;
  engine.requestModelResponse = async (request) => {
    const content = await onModelCall(request, engine);
    return { response: { content, toolCalls: [], usage: { total_tokens: 3 } }, streamContent: content };
  };
  return engine;
}

// A model call the shutdown aborts, the way a provider call does.
async function cutOffByShutdown({ options }, engine) {
  void engine.shutdown({ timeoutMs: 1000 });
  throwIfAborted(options.signal);
  return 'unreachable';
}

function insertInterruptedRun(id, { heartbeat = "datetime('now', '-5 minutes')", envelope, finalDeliveryId = null } = {}) {
  ctx.db.prepare(
    `INSERT INTO agent_runs (
      id, user_id, title, status, runtime_state, version, trigger_source, metadata_json,
      heartbeat_at, final_delivery_id, completed_at
    ) VALUES (?, ?, ?, 'interrupted', 'cancelled', 1, 'web', ?, ${heartbeat}, ?, datetime('now'))`,
  ).run(
    id,
    userId,
    id,
    JSON.stringify({ resume: envelope || { message: `request for ${id}`, options: { triggerSource: 'web' } } }),
    finalDeliveryId,
  );
}

function metadataOf(runId) {
  return JSON.parse(ctx.db.prepare('SELECT metadata_json FROM agent_runs WHERE id = ?').get(runId).metadata_json);
}

function fakeEngine() {
  const runs = [];
  const events = [];
  return {
    runs,
    events,
    run: async (runUserId, message, options) => {
      runs.push({ userId: runUserId, message, options });
      return { status: 'completed', content: '', runId: options.runId };
    },
    recordRunEvent: (eventUserId, runId, type, payload) => events.push({ runId, type, payload }),
  };
}

test('only top-level web and messaging runs record a resume envelope, with plain options only', () => {
  const envelope = resume.buildResumeEnvelope('fix the build', {
    triggerSource: 'messaging',
    source: 'telegram',
    chatId: '42',
    conversationId: 'c1',
    context: { rawUserMessage: 'fix the build', socialIntelligence: { message: { chatId: '42' } } },
    signal: new AbortController().signal,
    onBackground: () => {},
    deliveryState: { messagingSent: false },
    priorMessages: [{ role: 'user', content: 'earlier' }],
    app: { locals: {} },
    runId: 'old-run',
  });
  assert.deepEqual(envelope, {
    message: 'fix the build',
    options: {
      triggerSource: 'messaging',
      source: 'telegram',
      chatId: '42',
      conversationId: 'c1',
      context: { rawUserMessage: 'fix the build', socialIntelligence: { message: { chatId: '42' } } },
    },
  });
  assert.ok(resume.buildResumeEnvelope('hi', {}), 'a run with no trigger source is a web run');

  for (const options of [
    { triggerSource: 'voice_live' },
    { triggerSource: 'cli' },
    { triggerSource: 'schedule', taskId: 't1' },
    { triggerSource: 'web', taskId: 't1' },
    { triggerSource: 'agent', subagentDepth: 1 },
    { triggerSource: 'agent_delegation', triggerType: 'agent_delegation' },
    { triggerSource: 'messaging', audience: 'public' },
    { triggerSource: 'web', resumedFromRunId: 'older-run' },
  ]) {
    assert.equal(resume.buildResumeEnvelope('task', options), null, JSON.stringify(options));
  }
});

test('a run keeps its envelope only when a shutdown ends it', async () => {
  const finished = await createEngine(async () => 'done').run(userId, 'quick question', {
    triggerSource: 'web',
    stream: false,
    skipGlobalRecall: true,
  });
  assert.equal(finished.status, 'completed');
  assert.equal(metadataOf(finished.runId).resume, undefined);

  const engine = createEngine(cutOffByShutdown);
  const cut = await engine.run(userId, 'long job', { triggerSource: 'web', stream: false, skipGlobalRecall: true });
  const row = ctx.db.prepare('SELECT status FROM agent_runs WHERE id = ?').get(cut.runId);
  assert.equal(row.status, 'interrupted');
  assert.deepEqual(metadataOf(cut.runId).resume, {
    message: 'long job',
    options: { triggerSource: 'web', skipGlobalRecall: true },
  });
  ctx.db.prepare('DELETE FROM agent_runs WHERE id IN (?, ?)').run(finished.runId, cut.runId);
});

test('orphan recovery leaves resumable runs interrupted instead of failing them', () => {
  for (const id of ['orphan-resumable', 'orphan-plain']) {
    ctx.db.prepare(
      `INSERT INTO agent_runs (id, user_id, title, status, runtime_state, version, metadata_json,
        lease_owner, lease_expires_at, heartbeat_at)
       VALUES (?, ?, ?, 'interrupted', 'executing', 1, ?, 'dead', datetime('now', '-5 minutes'), datetime('now', '-5 minutes'))`,
    ).run(id, userId, id, JSON.stringify(id === 'orphan-resumable'
      ? { resume: { message: 'm', options: {} } }
      : {}));
    ctx.db.prepare(
      `INSERT INTO agent_steps (id, run_id, step_index, type, description, status)
       VALUES (?, ?, 1, 'tool', 'execute_command: {}', 'running')`,
    ).run(`${id}-step`, id);
  }

  recoverOrphanedRuns();

  const resumable = ctx.db.prepare('SELECT status, runtime_state, error FROM agent_runs WHERE id = ?').get('orphan-resumable');
  assert.equal(resumable.status, 'interrupted');
  assert.equal(resumable.runtime_state, 'cancelled');
  assert.doesNotMatch(resumable.error, /could not be resumed/);
  assert.equal(ctx.db.prepare('SELECT status FROM agent_steps WHERE id = ?').get('orphan-resumable-step').status, 'interrupted');

  const plain = ctx.db.prepare('SELECT status, error FROM agent_runs WHERE id = ?').get('orphan-plain');
  assert.equal(plain.status, 'failed');
  assert.match(plain.error, /could not be resumed/);
  ctx.db.prepare("DELETE FROM agent_runs WHERE id LIKE 'orphan-%'").run();
});

test('a resumable run is claimed once, with what it already did in the continuation', () => {
  insertInterruptedRun('cut-run', {
    envelope: { message: 'research flights', options: { triggerSource: 'web', conversationId: 'conv-1' } },
  });
  const steps = [
    ['s1', 1, 'web_search: {"q":"flights"}', 'completed'],
    ['s2', 2, 'write_file: {"path":"bad"}', 'failed'],
    ['s3', 3, 'execute_command: {"command":"book"}', 'interrupted'],
  ];
  for (const [id, index, description, status] of steps) {
    ctx.db.prepare(
      `INSERT INTO agent_steps (id, run_id, step_index, type, description, status)
       VALUES (?, 'cut-run', ?, 'tool', ?, ?)`,
    ).run(id, index, description, status);
  }
  ctx.db.prepare(
    `INSERT INTO agent_outbox (id, run_id, channel, message_kind, sequence, payload_json, status)
     VALUES ('o1', 'cut-run', 'web', 'progress', 1, ?, 'delivered')`,
  ).run(JSON.stringify({ content: 'Found three options so far.' }));

  assert.equal(resume.countResumableRuns(), 1);
  const engine = fakeEngine();
  assert.equal(resume.resumeInterruptedRuns(engine), 1);

  assert.equal(engine.runs.length, 1);
  const [{ message, options }] = engine.runs;
  assert.match(message, /research flights/);
  assert.match(message, /done: web_search/);
  assert.match(message, /cut off mid-call: execute_command/);
  assert.doesNotMatch(message, /write_file/);
  assert.match(message, /Found three options so far\./);
  assert.equal(options.resumedFromRunId, 'cut-run');
  assert.equal(options.conversationId, 'conv-1');
  assert.equal(options.title, 'research flights');

  const metadata = metadataOf('cut-run');
  assert.equal(metadata.resume, undefined);
  assert.equal(metadata.resumedAs, options.runId);
  assert.deepEqual(engine.events, [{ runId: 'cut-run', type: 'run_resumed', payload: { resumedAs: options.runId } }]);

  assert.equal(resume.countResumableRuns(), 0);
  assert.equal(resume.resumeInterruptedRuns(engine), 0);
  assert.equal(engine.runs.length, 1);
  ctx.db.prepare("DELETE FROM agent_runs WHERE id = 'cut-run'").run();
});

test('runs that went quiet too long ago or already delivered are not resumed', () => {
  insertInterruptedRun('stale-run', { heartbeat: "datetime('now', '-2 hours')" });
  insertInterruptedRun('delivered-run', { finalDeliveryId: 'outbox-final' });

  assert.equal(resume.countResumableRuns(), 0);
  const engine = fakeEngine();
  assert.equal(resume.resumeInterruptedRuns(engine), 0);
  assert.equal(engine.runs.length, 0);
  ctx.db.prepare("DELETE FROM agent_runs WHERE id IN ('stale-run', 'delivered-run')").run();
});

test('a resumed web run continues the conversation without repeating the user turn', async () => {
  const conversationId = `resume-${Date.now()}`;
  ctx.db.prepare('INSERT INTO conversations (id, user_id) VALUES (?, ?)').run(conversationId, userId);

  const first = createEngine(cutOffByShutdown);
  const cut = await first.run(userId, 'summarize my inbox', {
    conversationId,
    triggerSource: 'web',
    stream: false,
    skipGlobalRecall: true,
  });

  const seen = [];
  const second = createEngine(async ({ messages }) => {
    seen.push(messages);
    return 'Here is the summary.';
  });
  assert.equal(resume.resumeInterruptedRuns(second), 1);
  await new Promise((resolve) => setTimeout(resolve, 50));
  await Promise.allSettled([...second.activeRunPromises]);

  const newRunId = metadataOf(cut.runId).resumedAs;
  const newRun = ctx.db.prepare('SELECT status, title, metadata_json FROM agent_runs WHERE id = ?').get(newRunId);
  assert.equal(newRun.status, 'completed');
  assert.equal(newRun.title, 'summarize my inbox');
  assert.equal(JSON.parse(newRun.metadata_json).resumedFromRunId, cut.runId);
  assert.equal(JSON.parse(newRun.metadata_json).resume, undefined);

  const userRows = ctx.db.prepare(
    "SELECT run_id, content FROM conversation_messages WHERE conversation_id = ? AND role = 'user'",
  ).all(conversationId);
  assert.deepEqual(userRows, [{ run_id: cut.runId, content: 'summarize my inbox' }]);

  const userTurns = seen[0].filter((message) => message.role === 'user').map((message) => message.content);
  assert.equal(userTurns[0], 'summarize my inbox');
  assert.match(userTurns[1], /^\[Resumed after a restart\]/);

  const reply = ctx.db.prepare(
    "SELECT content FROM conversation_history WHERE agent_run_id = ? AND role = 'assistant'",
  ).get(newRunId);
  assert.equal(reply.content, 'Here is the summary.');
});
