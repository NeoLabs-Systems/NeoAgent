'use strict';

const assert = require('node:assert/strict');
const { after, before, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

let ctx;
let userId;
let AgentEngine;

before(async () => {
  ctx = createTestRuntime();
  userId = (await createTestUser(ctx.db, { username: 'runtime_orch_user' })).userId;

  const { ensureDefaultAiSettings } = require('../../../server/services/ai/settings');
  ensureDefaultAiSettings(userId, null);

  const providerPath = require.resolve('../../../server/services/ai/provider_selector');
  require(providerPath);
  require.cache[providerPath].exports.getProviderForUser = async () => ({
    provider: {
      chat: async () => ({ content: 'ok', toolCalls: [], usage: { total_tokens: 3 } }),
      stream: async function* stream() {
        yield { type: 'done', content: 'ok', toolCalls: [], usage: { total_tokens: 3 } };
      },
    },
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
});

after(() => teardownTestRuntime(ctx));


const EMPTY_SCHEMA = { type: 'object', properties: {} };

function tool(name, description = name, parameters = EMPTY_SCHEMA) {
  return { name, description, parameters };
}

// Enough unrelated tools that the catalog exceeds the schema cap, so the run
// has to choose which tools start active.
function fillerTools(count = 25) {
  return Array.from({ length: count }, (_, index) => tool(`filler_${index}`, `Unrelated capability ${index}`));
}

function answer(content) {
  return { response: { content, toolCalls: [], usage: { total_tokens: 3 } }, streamContent: content };
}

function toolCall(name, args = {}, id = `${name}-${Math.random()}`, content = '') {
  return {
    response: {
      content,
      toolCalls: [{ id, type: 'function', function: { name, arguments: JSON.stringify(args) } }],
      usage: { total_tokens: 3 },
    },
    streamContent: content,
  };
}

function createEngine(reply = 'fallback') {
  const engine = new AgentEngine(null);
  engine.emit = () => {};
  engine.buildSystemPrompt = async () => 'system';
  engine.buildMemoryRecall = async () => null;
  engine.buildContextMessages = (sys) => [{ role: 'system', content: sys }];
  engine.buildUserMessage = (message) => ({ role: 'user', content: message });
  engine.getAvailableTools = () => [];
  engine.getReasoningEffort = () => undefined;
  // Every run is one loop: nothing asks a model for structured routing first.
  engine.requestStructuredJson = async () => {
    throw new Error('a run must not make a structured pre-pass model call');
  };
  engine.requestModelResponse = async () => answer(reply);
  return engine;
}

function userTurns(messages) {
  return messages.filter((message) => message.role === 'user').map((message) => message.content);
}

test('a plain answer ends the run in one model turn, with no model call before it', async () => {
  const engine = createEngine();
  const learningInputs = [];
  engine.skillLearningService = {
    enqueueCompletedRun(input) {
      learningInputs.push(input);
      return Promise.resolve(null);
    },
  };
  const calls = [];
  engine.getAvailableTools = () => [tool('web_search')];
  engine.requestModelResponse = async ({ tools, options }) => {
    calls.push({ tools: tools.map((entry) => entry.name), phase: options.phase || null });
    return answer('Hello!');
  };

  const result = await engine.run(userId, 'hi', {
    triggerSource: 'web',
    stream: false,
    skipGlobalRecall: true,
  });

  assert.equal(result.status, 'completed');
  assert.equal(result.content, 'Hello!');
  assert.equal(result.iterations, 1);
  assert.deepEqual(calls, [{ tools: ['web_search'], phase: null }]);

  const row = ctx.db.prepare(
    'SELECT status, runtime_state, final_delivery_id, final_response FROM agent_runs WHERE id = ?',
  ).get(result.runId);
  assert.equal(row.status, 'completed');
  assert.equal(row.runtime_state, 'completed');
  assert.ok(row.final_delivery_id);
  assert.equal(row.final_response, 'Hello!');

  const finals = ctx.db.prepare(
    `SELECT COUNT(*) AS n FROM agent_outbox
     WHERE run_id = ? AND message_kind = 'final'`,
  ).get(result.runId);
  assert.equal(Number(finals.n), 1);
  assert.equal(learningInputs.length, 1);
  assert.equal(learningInputs[0].runId, result.runId);
  assert.equal(learningInputs[0].triggerType, 'user');
  assert.equal(learningInputs[0].triggerSource, 'web');
  assert.equal(learningInputs[0].task, 'hi');
  assert.equal(learningInputs[0].taskId, null);
  assert.equal(learningInputs[0].finalContent, 'Hello!');
});

test('completed conversations queue source-grounded learning instead of run receipts', async () => {
  const conversationId = `learning-${Date.now()}`;
  ctx.db.prepare('INSERT INTO conversations (id, user_id) VALUES (?, ?)')
    .run(conversationId, userId);
  const engine = createEngine('Use the existing release checklist.');
  engine.memoryManager = {};
  const learningInputs = [];
  engine.refreshConversationState = async (input) => {
    learningInputs.push(input);
    return { summary: 'Learned thread state' };
  };

  const result = await engine.run(userId, 'Remember how I prefer releases.', {
    conversationId,
    triggerSource: 'web',
    stream: false,
    skipGlobalRecall: true,
  });
  await new Promise((resolve) => setImmediate(resolve));
  await Promise.allSettled([...engine.backgroundTasks]);

  assert.equal(result.status, 'completed');
  assert.equal(learningInputs.length, 1);
  assert.equal(learningInputs[0].conversationId, conversationId);
  assert.equal(learningInputs[0].runId, result.runId);
  assert.equal(learningInputs[0].finalReply, result.content);
  assert.equal(learningInputs[0].options.userId, userId);
  assert.ok(learningInputs[0].options.signal instanceof AbortSignal);
  const stored = ctx.db.prepare(
    `SELECT content FROM conversation_messages
     WHERE conversation_id = ? AND run_id = ? AND role = 'assistant'`,
  ).get(conversationId, result.runId);
  assert.equal(stored.content, result.content);
});

test('messaging turns are stored without the per-turn routing envelope', async () => {
  const conversationId = `messaging-${Date.now()}`;
  ctx.db.prepare('INSERT INTO conversations (id, user_id) VALUES (?, ?)')
    .run(conversationId, userId);
  const engine = createEngine('kurz und schmerzlos.');
  const { buildIncomingPrompt } = require('../../../server/services/messaging/automation');
  const msg = {
    platform: 'whatsapp',
    isGroup: false,
    chatId: '4915112345678@lid',
    sender: '4915112345678@lid',
    senderName: 'Neo',
    content: 'wieso kann ich nein nicht ausschreiben',
  };
  const envelope = buildIncomingPrompt(msg);

  const result = await engine.run(userId, envelope, {
    conversationId,
    triggerSource: 'messaging',
    source: msg.platform,
    chatId: msg.chatId,
    stream: false,
    skipGlobalRecall: true,
    context: {
      rawUserMessage: msg.content,
      socialIntelligence: { message: msg },
    },
  });

  assert.equal(result.status, 'completed');
  const stored = ctx.db.prepare(
    `SELECT content FROM conversation_messages
     WHERE conversation_id = ? AND run_id = ? AND role = 'user'`,
  ).get(conversationId, result.runId);
  assert.equal(
    stored.content,
    `[whatsapp message from Neo]\n<external_message>\n${msg.content}\n</external_message>`,
  );
  assert.ok(stored.content.length < envelope.length / 4);
});

test('voice uses the same loop and the canonical outbox adapter', async () => {
  const engine = createEngine('The shared runtime handled this.');
  const deliveries = [];
  engine.voiceRuntimeManager = {
    async presentDelivery(entry) {
      deliveries.push(entry);
      return { delivered: true };
    },
  };

  const result = await engine.run(userId, 'Give me the quick answer.', {
    triggerSource: 'voice_live',
    source: 'voice_live',
    chatId: 'voice-session-fast',
    voiceSessionId: 'voice-session-fast',
    sessionBinding: { sessionId: 'voice-session-fast', turnId: 'turn-fast' },
    latencyPriority: 'interactive',
    stream: false,
    skipGlobalRecall: true,
  });

  assert.equal(result.content, 'The shared runtime handled this.');
  assert.equal(deliveries.length, 1);
  assert.equal(deliveries[0].channel, 'voice_live');
  assert.equal(deliveries[0].recipient, 'voice-session-fast');
  assert.equal(deliveries[0].messageKind, 'final');

  const finals = ctx.db.prepare(
    `SELECT channel, recipient, status, COUNT(*) AS n
     FROM agent_outbox
     WHERE run_id = ? AND message_kind = 'final'`,
  ).get(result.runId);
  assert.equal(finals.channel, 'voice_live');
  assert.equal(finals.recipient, 'voice-session-fast');
  assert.equal(finals.status, 'delivered');
  assert.equal(Number(finals.n), 1);

  const run = ctx.db.prepare('SELECT metadata_json FROM agent_runs WHERE id = ?').get(result.runId);
  const metadata = JSON.parse(run.metadata_json);
  assert.deepEqual(metadata.sessionBinding, { sessionId: 'voice-session-fast', turnId: 'turn-fast' });
  assert.equal(metadata.latencyPriority, 'interactive');
});

function installPriorTurns(engine) {
  engine.buildContextMessages = (system, summary, history, recall) => [
    { role: 'system', content: system },
    summary,
    ...(history || []),
    recall,
  ].filter(Boolean);
  return [
    { role: 'user', content: `Old oversized turn ${'x'.repeat(20_000)}` },
    { role: 'assistant', content: 'Old turn answer.' },
    { role: 'user', content: 'Newest completed turn.' },
    { role: 'assistant', content: 'Newest completed answer.' },
  ];
}

test('provider context overflow compacts and retries the same model call once', async () => {
  const engine = createEngine();
  const priorMessages = installPriorTurns(engine);
  let normalCalls = 0;
  let compactionCalls = 0;
  let recoveredMessages = [];
  engine.requestModelResponse = async ({ messages, options }) => {
    if (options.phase === 'context_compaction') {
      compactionCalls += 1;
      return answer('Older context summarized.');
    }
    normalCalls += 1;
    if (normalCalls === 1) {
      const error = new Error('maximum context length exceeded');
      error.code = 'context_length_exceeded';
      throw error;
    }
    recoveredMessages = messages;
    return answer('Recovered final answer.');
  };

  const result = await engine.run(userId, 'Current unfinished turn.', {
    triggerSource: 'web',
    stream: false,
    skipGlobalRecall: true,
    priorMessages,
    maxIterations: 3,
  });

  assert.equal(result.status, 'completed');
  assert.equal(result.content, 'Recovered final answer.');
  assert.equal(normalCalls, 2);
  assert.ok(compactionCalls >= 1);
  assert.ok(recoveredMessages.some((message) => (
    message.role === 'system'
    && String(message.content).startsWith('[Previous conversation summary]')
  )));
  const recoveryEvents = ctx.db.prepare(
    `SELECT COUNT(*) AS count FROM agent_run_events
     WHERE run_id = ? AND event_type = 'context.overflow_recovered'`,
  ).get(result.runId);
  assert.equal(Number(recoveryEvents.count), 1);
});

test('repeated overflow ends in a model-written wrap-up without provider fallback', async () => {
  const engine = createEngine();
  const priorMessages = installPriorTurns(engine);
  let normalCalls = 0;
  engine.requestModelResponse = async ({ options }) => {
    if (options.phase === 'context_compaction') return answer('Older context summarized.');
    if (options.phase === 'wrap_up') return answer('I could not safely fit more context; this is a partial result.');
    normalCalls += 1;
    const error = new Error('prompt is too long for this context window');
    error.code = 'context_overflow';
    throw error;
  };

  const result = await engine.run(userId, 'Current unfinished turn.', {
    triggerSource: 'web',
    stream: false,
    skipGlobalRecall: true,
    priorMessages,
    maxIterations: 3,
  });

  assert.equal(result.status, 'completed');
  assert.equal(normalCalls, 2);
  assert.match(result.content, /partial result/i);
});

test('a background send the model marks final is the answer, and tool calls keep their wire shape', async () => {
  const engine = createEngine();
  let modelTurns = 0;
  const toolContexts = [];
  engine.requestModelResponse = async () => {
    modelTurns += 1;
    return toolCall('send_message', {
      platform: 'telegram',
      to: '1',
      content: 'Meeting in 1 hour',
      purpose: 'final_result',
    }, 'c1');
  };
  engine.getAvailableTools = () => [tool('send_message'), tool('activate_tools'), tool('think')];
  engine.executeTool = async (name, args, context) => {
    toolContexts.push({ name, args, context });
    if (name === 'send_message' && context.stageProactiveMessages) {
      context.deliveryState.proactiveMessageStaged = true;
      context.deliveryState.stagedProactiveMessage = {
        platform: args.platform,
        to: args.to,
        content: args.content,
        purpose: args.purpose,
      };
      return { success: true, staged: true, content: args.content };
    }
    return { success: true, tool: name };
  };
  engine.isReadOnlyToolCall = () => false;

  const deliveryState = {
    messagingSent: false,
    noResponse: false,
    proactiveMessageStaged: false,
    stagedProactiveMessage: null,
    lastSentMessage: '',
    sentMessages: [],
  };
  const taskLearningInputs = [];
  engine.skillLearningService = {
    enqueueCompletedRun(input) {
      taskLearningInputs.push(input);
      return Promise.resolve(null);
    },
  };

  const result = await engine.run(userId, '[SYSTEM: Executing Background Task]\nTask Name: Kalender-Reminder', {
    triggerType: 'schedule',
    triggerSource: 'schedule',
    stream: false,
    skipGlobalRecall: true,
    skipConversationHistory: true,
    maxIterations: 4,
    bypassUserRateLimits: true,
    deliveryState,
    stageProactiveMessages: true,
    taskId: 'task-1',
  });

  assert.equal(result.status, 'completed');
  assert.equal(modelTurns, 1, 'a send the model marked final needs no further turn');
  assert.equal(result.content, 'Meeting in 1 hour');
  const sendCtx = toolContexts.find((entry) => entry.name === 'send_message');
  assert.equal(sendCtx.context.stageProactiveMessages, true);
  assert.equal(sendCtx.context.taskId, 'task-1');
  assert.equal(sendCtx.context.deliveryState, deliveryState);
  assert.equal(deliveryState.stagedProactiveMessage.content, 'Meeting in 1 hour');
  // Background automation never gets an opening line.
  const acks = ctx.db.prepare(
    `SELECT COUNT(*) AS n FROM agent_outbox WHERE run_id = ? AND message_kind = 'ack'`,
  ).get(result.runId);
  assert.equal(Number(acks.n), 0);
  assert.equal(taskLearningInputs.length, 1);
  assert.equal(taskLearningInputs[0].taskId, 'task-1');
  assert.equal(taskLearningInputs[0].triggerType, 'schedule');
});

test('tool execution preserves mutation barriers and model-order results', async () => {
  const engine = createEngine();
  const trace = [];
  let modelTurn = 0;
  engine.requestModelResponse = async ({ messages }) => {
    modelTurn += 1;
    if (modelTurn === 1) {
      return {
        response: {
          content: '',
          toolCalls: [
            { id: 'read-1', type: 'function', function: { name: 'read_before', arguments: '{}' } },
            { id: 'write-1', type: 'function', function: { name: 'write_middle', arguments: '{}' } },
            { id: 'read-2', type: 'function', function: { name: 'read_after', arguments: '{}' } },
          ],
          usage: { total_tokens: 5 },
        },
        streamContent: '',
      };
    }
    const toolResultIds = messages
      .filter((message) => message.role === 'tool')
      .map((message) => message.tool_call_id);
    assert.deepEqual(toolResultIds.slice(-3), ['read-1', 'write-1', 'read-2']);
    // Earlier assistant tool calls keep function.name so every provider can
    // convert the history.
    const priorAssistant = messages.find((message) => Array.isArray(message.tool_calls));
    assert.ok(priorAssistant.tool_calls.every((call) => call?.function?.name));
    return answer('Verified.');
  };
  engine.getAvailableTools = () => [tool('read_before'), tool('write_middle'), tool('read_after')];
  engine.isReadOnlyToolCall = (call) => String(call?.function?.name || '').startsWith('read_');
  engine.executeTool = async (name) => {
    trace.push(`${name}:start`);
    if (name === 'read_before') await new Promise((resolve) => setTimeout(resolve, 10));
    trace.push(`${name}:end`);
    return { success: true, name };
  };

  const result = await engine.run(userId, 'Read it, change it, then read it again.', {
    triggerSource: 'web',
    stream: false,
    skipGlobalRecall: true,
    maxIterations: 4,
  });

  assert.equal(result.status, 'completed');
  assert.equal(result.content, 'Verified.');
  assert.deepEqual(trace, [
    'read_before:start',
    'read_before:end',
    'write_middle:start',
    'write_middle:end',
    'read_after:start',
    'read_after:end',
  ]);
});

test('the answer after tool work is what the user gets, and every turn keeps the system prompt', async () => {
  const engine = createEngine();
  engine.buildSystemPrompt = async () => 'AGENT_SYSTEM_PROMPT_MARKER';
  engine.getAvailableTools = () => [tool('read_file')];
  const sawSystemPrompt = [];
  let modelTurns = 0;
  engine.requestModelResponse = async ({ messages }) => {
    modelTurns += 1;
    sawSystemPrompt.push(messages.some((msg) => String(msg.content || '').includes('AGENT_SYSTEM_PROMPT_MARKER')));
    return modelTurns === 1 ? toolCall('read_file', { path: 'a.txt' }, 'r1') : answer('File read.');
  };
  engine.executeTool = async () => ({ content: 'hello' });
  engine.isReadOnlyToolCall = () => true;

  const result = await engine.run(userId, 'Read a.txt', {
    triggerSource: 'web',
    stream: false,
    skipGlobalRecall: true,
    maxIterations: 4,
  });

  assert.equal(result.status, 'completed');
  assert.equal(result.content, 'File read.');
  assert.equal(result.iterations, 2);
  assert.deepEqual(sawSystemPrompt, [true, true]);
  const steps = ctx.db.prepare(
    'SELECT tool_name, status, tool_input FROM agent_steps WHERE run_id = ? ORDER BY step_index ASC',
  ).all(result.runId);
  assert.deepEqual(steps.map((step) => step.tool_name), ['read_file']);
  assert.equal(steps[0].status, 'completed');
  assert.match(steps[0].tool_input, /a\.txt/);
});

test('a run the guards stop gets a model-authored wrap-up, not a canned status', async () => {
  const engine = createEngine();
  engine.getAvailableTools = () => [tool('make_report')];
  const wrapUpPrompts = [];
  engine.requestModelResponse = async ({ messages, options }) => {
    if (options.phase === 'wrap_up') {
      wrapUpPrompts.push(messages[messages.length - 1].content);
      return answer('Ich habe zwei Abschnitte geschrieben, der Rest fehlt noch.');
    }
    return toolCall('make_report');
  };
  let call = 0;
  engine.executeTool = async () => {
    call += 1;
    return { section: call };
  };
  engine.isReadOnlyToolCall = () => false;

  const result = await engine.run(userId, 'Schreib mir den Bericht', {
    triggerSource: 'web',
    stream: false,
    skipGlobalRecall: true,
    maxIterations: 2,
  });

  assert.equal(result.content, 'Ich habe zwei Abschnitte geschrieben, der Rest fehlt noch.');
  assert.equal(wrapUpPrompts.length, 1);
  assert.match(wrapUpPrompts[0], /emergency turn limit/);
  assert.match(wrapUpPrompts[0], /do not call any tools/);
});

test('when the wrap-up cannot be written the run fails instead of sending canned text', async () => {
  const engine = createEngine();
  engine.getAvailableTools = () => [tool('make_report')];
  engine.requestModelResponse = async ({ options }) => {
    if (options.phase === 'wrap_up') throw new Error('provider down');
    return toolCall('make_report', {}, undefined, 'Writing the next section.');
  };
  let call = 0;
  engine.executeTool = async () => {
    call += 1;
    return { section: call };
  };
  engine.isReadOnlyToolCall = () => false;

  await assert.rejects(
    engine.run(userId, 'Schreib mir den Bericht', {
      triggerSource: 'web',
      stream: false,
      skipGlobalRecall: true,
      maxIterations: 2,
    }),
    /could not write a reply/,
  );
});

test('an identical write repeated over and over is stopped as spinning', async () => {
  const engine = createEngine();
  engine.getAvailableTools = () => [tool('write_file')];
  let sawRepeatNote = false;
  engine.requestModelResponse = async ({ messages, options }) => {
    if (options.phase === 'wrap_up') return answer('Ich komme hier nicht weiter.');
    sawRepeatNote = sawRepeatNote || messages.some((m) => /Identical to your previous call/.test(String(m.content || '')));
    return toolCall('write_file', { path: 'solution.py', content: 'def f(): pass' });
  };
  let writes = 0;
  engine.executeTool = async () => {
    writes += 1;
    return { success: true, path: 'solution.py', bytesWritten: 13 };
  };
  engine.isReadOnlyToolCall = () => false;

  const result = await engine.run(userId, 'Schreib die Lösung', {
    triggerSource: 'web',
    stream: false,
    skipGlobalRecall: true,
    maxIterations: 60,
  });

  assert.ok(writes > 2 && writes < 20, `expected the spin to be cut short, got ${writes} identical writes`);
  assert.equal(sawRepeatNote, true, 'the model must be told its call changed nothing');
  assert.equal(result.content, 'Ich komme hier nicht weiter.');
});

test('productive evidence collection is never cut short', async () => {
  const engine = createEngine();
  engine.getAvailableTools = () => [tool('lookup', 'Look up a new source')];
  let modelTurns = 0;
  engine.requestModelResponse = async () => {
    modelTurns += 1;
    return modelTurns > 12
      ? answer('Synthesized from twelve sources.')
      : toolCall('lookup', { page: modelTurns }, `lookup-${modelTurns}`);
  };
  engine.executeTool = async (_name, args) => ({ source: `source-${args.page}`, facts: [args.page] });
  engine.isReadOnlyToolCall = () => true;

  const result = await engine.run(userId, 'Research this.', {
    triggerSource: 'web',
    stream: false,
    skipGlobalRecall: true,
  });

  assert.equal(result.status, 'completed');
  assert.equal(result.content, 'Synthesized from twelve sources.');
  assert.equal(modelTurns, 13);
});

test('one run does the work once and reports its answer to the client once', async () => {
  const engine = createEngine();
  const emitted = [];
  engine.emit = (_userId, event, payload) => {
    emitted.push({ event, content: payload?.content });
  };
  engine.getAvailableTools = () => [tool('lookup')];
  let modelCalls = 0;
  let toolCalls = 0;
  engine.requestModelResponse = async () => {
    modelCalls += 1;
    // Text next to a tool call is part of the work, not the answer.
    return modelCalls === 1
      ? toolCall('lookup', {}, 'l1', 'Let me look that up.')
      : answer('Here is the answer.');
  };
  engine.executeTool = async () => {
    toolCalls += 1;
    return { value: 42 };
  };
  engine.isReadOnlyToolCall = () => true;

  const result = await engine.run(userId, 'Check something', {
    triggerSource: 'web',
    stream: false,
    skipGlobalRecall: true,
    maxIterations: 6,
  });

  assert.equal(result.status, 'completed');
  assert.equal(result.content, 'Here is the answer.');
  assert.equal(modelCalls, 2);
  assert.equal(toolCalls, 1);
  const completes = emitted.filter((entry) => entry.event === 'run:complete');
  assert.equal(completes.length, 1, `expected one run:complete, got ${completes.length}`);
  assert.equal(completes[0].content, 'Here is the answer.');
  const finals = ctx.db.prepare(
    `SELECT COUNT(*) AS n FROM agent_outbox WHERE run_id = ? AND message_kind = 'final'`,
  ).get(result.runId);
  assert.equal(Number(finals.n), 1);
});

test('an opening line the model sends reaches a web client as a visible message', async () => {
  const engine = createEngine();
  const emitted = [];
  engine.emit = (_userId, event, payload) => {
    emitted.push({ event, content: payload?.content, kind: payload?.kind });
  };
  engine.getAvailableTools = () => [tool('send_interim_update')];
  let modelTurns = 0;
  engine.requestModelResponse = async () => {
    modelTurns += 1;
    return modelTurns === 1
      ? toolCall('send_interim_update', { content: 'Bin dran.', kind: 'ack' })
      : answer('Fertig.');
  };

  const result = await engine.run(userId, 'Mach das lange Ding', {
    triggerSource: 'web',
    stream: false,
    skipGlobalRecall: true,
    maxIterations: 4,
  });

  assert.equal(result.content, 'Fertig.');
  // run:interim carries short status notes under `message`; user-facing interim
  // text must not be sent there or the client silently drops it.
  const interim = emitted.find((entry) => entry.event === 'run:assistant_interim');
  assert.ok(interim, 'the opening line never reached the client');
  assert.equal(interim.content, 'Bin dran.');
});

test('a blank model turn is recovered instead of ending the run', async () => {
  const engine = createEngine();
  engine.getAvailableTools = () => [tool('lookup')];
  let modelTurns = 0;
  engine.requestModelResponse = async () => {
    modelTurns += 1;
    // A provider hiccup: no content and no tool call.
    return modelTurns === 1 ? answer('') : answer('Found it.');
  };

  const result = await engine.run(userId, 'Look it up', {
    triggerSource: 'web',
    stream: false,
    skipGlobalRecall: true,
    maxIterations: 6,
  });

  assert.equal(result.status, 'completed');
  assert.equal(result.content, 'Found it.');
  assert.equal(modelTurns, 2);
  const row = ctx.db.prepare('SELECT runtime_state FROM agent_runs WHERE id = ?').get(result.runId);
  assert.equal(row.runtime_state, 'completed');
});

test('a large catalog starts with the same core set in any language and lists the rest', async () => {
  const engine = createEngine('Fertig.');
  engine.getAvailableTools = () => [
    tool('android_install_apk', 'Install an APK on the Android device'),
    tool('desktop_drag', 'Drag on the desktop screen'),
    tool('execute_command', 'Run shell commands'),
    tool('http_request', 'Fetch a URL'),
    tool('web_search', 'Search the web'),
    ...fillerTools(),
  ];
  const firstTurns = [];
  engine.requestModelResponse = async ({ tools, messages }) => {
    firstTurns.push({
      tools: tools.map((entry) => entry.name),
      discovery: messages.find((m) => String(m.content || '').startsWith('[Tool discovery]'))?.content || '',
    });
    return answer('Fertig.');
  };

  for (const task of ['Wie wird das Wetter morgen in Berlin?', 'What is the weather in Berlin tomorrow?']) {
    await engine.run(userId, task, { triggerSource: 'web', stream: false, skipGlobalRecall: true });
  }

  const [german, english] = firstTurns;
  assert.deepEqual(german.tools, english.tools);
  for (const name of ['web_search', 'http_request', 'execute_command']) {
    assert.ok(german.tools.includes(name), `${name} starts active`);
  }
  // Word overlap with the request ("in" / "install") activates nothing.
  assert.equal(german.tools.includes('android_install_apk'), false);
  assert.equal(german.tools.includes('desktop_drag'), false);
  assert.match(german.discovery, /android_install_apk: Install an APK/);
});

test('a run searches for an inactive tool and activates it', async () => {
  const engine = createEngine();
  engine.getAvailableTools = () => [
    tool('search_tools', 'search tools'),
    tool('activate_tools', 'activate'),
    tool('send_message', 'send'),
    tool('google_workspace_calendar_list_events', 'List Google Calendar events in a time window', {
      type: 'object',
      properties: { time_min: { type: 'string' } },
    }),
    ...fillerTools(),
  ];
  const turnToolNames = [];
  let searchResult = null;
  let modelTurns = 0;
  engine.requestModelResponse = async ({ tools }) => {
    modelTurns += 1;
    turnToolNames.push(tools.map((entry) => entry.name));
    if (modelTurns === 1) return toolCall('search_tools', { query: 'list Google Calendar events' }, 'search1');
    if (modelTurns === 2) return toolCall('activate_tools', { names: ['google_workspace_calendar_list_events'] }, 'act1');
    if (modelTurns === 3) return toolCall('google_workspace_calendar_list_events', { time_min: '2026-08-05T12:00:00Z' }, 'cal1');
    return answer('Termin um 17:00 Uhr erinnert.');
  };
  const executed = [];
  engine.executeTool = async (name, args, context) => {
    executed.push(name);
    if (name === 'search_tools') {
      searchResult = engine.searchToolsForRun(context.runId, args.query, args.limit);
      return searchResult;
    }
    if (name === 'activate_tools') return engine.activateToolsForRun(context.runId, args.names || []);
    return { count: 1, events: [{ summary: 'Zahnarzt', start: '2026-08-05T17:00:00Z' }] };
  };
  engine.isReadOnlyToolCall = () => false;

  const result = await engine.run(userId, '[SYSTEM: Executing Background Task]\nTask Name: Kalender-Reminder', {
    triggerType: 'schedule',
    triggerSource: 'schedule',
    stream: false,
    skipGlobalRecall: true,
    skipConversationHistory: true,
    maxIterations: 6,
    bypassUserRateLimits: true,
  });

  assert.equal(result.status, 'completed');
  assert.equal(result.content, 'Termin um 17:00 Uhr erinnert.');
  assert.ok(searchResult.results.some((entry) => entry.name === 'google_workspace_calendar_list_events'));
  assert.ok(!turnToolNames[0].includes('google_workspace_calendar_list_events'), 'catalog tool must not start active');
  assert.ok(turnToolNames[2].includes('google_workspace_calendar_list_events'), 'activate_tools must put the schema into the next model turn');
  assert.ok(executed.includes('google_workspace_calendar_list_events'));
});

test('messaging final is not transmitted twice after send_message delivered it', async () => {
  const engine = createEngine();
  const sends = [];
  engine.messagingManager = {
    sendMessage: async (uid, platform, chatId, content) => {
      sends.push({ platform, chatId, content });
      return { success: true };
    },
    sendTyping: async () => {},
  };
  engine.getAvailableTools = () => [tool('send_message')];
  engine.requestModelResponse = async () => toolCall('send_message', {
    platform: 'whatsapp',
    to: 'chat-1',
    content: 'Alles erledigt.',
    purpose: 'final_result',
  }, 's1');
  engine.executeTool = async (name, args, context) => (name === 'send_message'
    ? engine.messagingManager.sendMessage(context.userId, args.platform, args.to, args.content)
    : { success: true });
  engine.isReadOnlyToolCall = () => false;

  const result = await engine.run(userId, 'Sag mir Bescheid wenn fertig', {
    triggerSource: 'messaging',
    source: 'whatsapp',
    chatId: 'chat-1',
    stream: false,
    skipGlobalRecall: true,
    skipConversationHistory: true,
    maxIterations: 4,
  });

  assert.equal(result.status, 'completed');
  assert.equal(sends.length, 1, 'the final result must reach the chat exactly once');
  const finals = ctx.db.prepare(
    `SELECT COUNT(*) AS n FROM agent_outbox WHERE run_id = ? AND message_kind = 'final'`,
  ).get(result.runId);
  assert.equal(Number(finals.n), 1, 'the final delivery is still committed exactly once');
});

test('a follow-up sent during the final model turn is answered before delivery', async () => {
  const engine = createEngine();
  const seenUserTurns = [];
  engine.requestModelResponse = async ({ messages }) => {
    seenUserTurns.push(userTurns(messages));
    if (seenUserTurns.length === 1) {
      const active = engine.findSteerableRunForUser(userId, 'web');
      assert.ok(engine.enqueueSteering(active.runId, 'Und was steht morgen an?'));
      return answer('Heute: Zahnarzt um 17:00.');
    }
    return answer('Heute Zahnarzt um 17:00, morgen ist nichts eingetragen.');
  };

  const result = await engine.run(userId, 'Was steht heute an?', {
    triggerSource: 'web',
    stream: false,
    skipGlobalRecall: true,
    maxIterations: 12,
  });

  assert.equal(result.status, 'completed');
  assert.equal(seenUserTurns.length, 2);
  assert.ok(seenUserTurns[1].includes('Und was steht morgen an?'));
  assert.equal(result.content, 'Heute Zahnarzt um 17:00, morgen ist nichts eingetragen.');
});

test('a follow-up sent after the answer is committed is refused so it starts its own run', async () => {
  const engine = createEngine('Heute: Zahnarzt um 17:00.');
  let runId = null;
  const lateRouting = [];
  engine.emit = (_userId, event, data) => {
    if (event === 'run:start') runId = data.runId;
    if (event === 'run:complete') {
      lateRouting.push({
        steerable: engine.findSteerableRunForUser(userId, 'web'),
        queued: engine.enqueueSteering(runId, 'Noch eine Frage'),
      });
    }
  };

  const result = await engine.run(userId, 'Was steht heute an?', {
    triggerSource: 'web',
    stream: false,
    skipGlobalRecall: true,
    maxIterations: 12,
  });

  assert.equal(result.status, 'completed');
  assert.equal(lateRouting.length, 1);
  assert.equal(lateRouting[0].steerable, null);
  assert.equal(lateRouting[0].queued, null);
});

test('a follow-up queued before a forced wrap-up reaches the wrap-up turn', async () => {
  const engine = createEngine();
  engine.getAvailableTools = () => [tool('make_report')];
  let wrapUpUserTurns = null;
  let turns = 0;
  engine.requestModelResponse = async ({ messages, options }) => {
    if (options.phase === 'wrap_up') {
      wrapUpUserTurns = userTurns(messages);
      return answer('Der Bericht ist halb fertig; die Grafik kommt als Nächstes.');
    }
    turns += 1;
    if (turns === 2) {
      const active = engine.findSteerableRunForUser(userId, 'web');
      assert.ok(engine.enqueueSteering(active.runId, 'Bitte auch eine Grafik.'));
    }
    return toolCall('make_report', {}, `t${turns}`);
  };
  let call = 0;
  engine.executeTool = async () => {
    call += 1;
    return { section: call };
  };
  engine.isReadOnlyToolCall = () => false;

  const result = await engine.run(userId, 'Schreib mir den Bericht', {
    triggerSource: 'web',
    stream: false,
    skipGlobalRecall: true,
    maxIterations: 2,
  });

  assert.equal(result.content, 'Der Bericht ist halb fertig; die Grafik kommt als Nächstes.');
  assert.ok(wrapUpUserTurns.includes('Bitte auch eine Grafik.'));
});

test('a run stopped between steps reports its end to clients', async () => {
  const engine = createEngine();
  engine.getAvailableTools = () => [tool('make_report')];
  engine.isReadOnlyToolCall = () => false;
  const emitted = [];
  engine.emit = (_userId, event, data) => emitted.push({ event, runId: data?.runId });
  let runId = null;
  engine.requestModelResponse = async () => toolCall('make_report', {}, 'r1');
  engine.executeTool = async (_name, _args, context) => {
    runId = context.runId;
    engine.abort(runId, { userId, reason: 'Cancelled from another conversation.' });
    return { section: 1 };
  };

  const result = await engine.run(userId, 'Schreib mir den Bericht', {
    triggerSource: 'web',
    stream: false,
    skipGlobalRecall: true,
    maxIterations: 6,
  });

  assert.equal(result.status, 'stopped');
  const terminal = emitted.filter((entry) => entry.runId === runId
    && ['run:stopped', 'run:complete', 'run:error', 'run:interrupted'].includes(entry.event));
  assert.deepEqual(terminal.map((entry) => entry.event), ['run:stopped']);
});
