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

function createEngine(analysis) {
  const engine = new AgentEngine(null);
  engine.emit = () => {};
  engine.buildSystemPrompt = async () => 'system';
  engine.buildMemoryRecall = async () => null;
  engine.buildContextMessages = (sys) => [{ role: 'system', content: sys }];
  engine.buildUserMessage = (message) => ({ role: 'user', content: message });
  engine.getAvailableTools = () => [];
  engine.getReasoningEffort = () => undefined;
  engine.requestStructuredJson = async ({ normalize, fallback }) => ({
    value: normalize(analysis, fallback || {}),
    raw: JSON.stringify(analysis),
    usage: 8,
  });
  engine.requestModelResponse = async () => ({
    response: {
      content: analysis.draft_reply || 'fallback',
      toolCalls: [],
      usage: { total_tokens: 4 },
    },
    streamContent: analysis.draft_reply || 'fallback',
  });
  return engine;
}

test('ordinary chat completes from one analyzed response without entering execution', async () => {
  const analysis = {
    mode: 'direct_answer',
    draft_reply: 'Hello!',
    draft_status: 'final',
    goal: 'Greet the user',
    confidence: 0.96,
    complexity: 'simple',
    autonomy_level: 'minimal',
    progress_update_policy: 'none',
    research_depth: 'none',
    needs_verification: false,
    success_criteria: ['Friendly greeting'],
    suggested_tools: [],
  };
  const engine = createEngine(analysis);
  let structuredCalls = 0;
  let executionCalls = 0;
  const learningInputs = [];
  engine.skillLearningService = {
    enqueueCompletedRun(input) {
      learningInputs.push(input);
      return Promise.resolve(null);
    },
  };
  engine.requestStructuredJson = async ({ normalize, fallback }) => {
    structuredCalls += 1;
    return {
      value: normalize(analysis, fallback),
      raw: JSON.stringify(analysis),
      usage: 4,
    };
  };
  engine.requestModelResponse = async () => {
    executionCalls += 1;
    throw new Error('direct answers must not enter the execution loop');
  };

  const result = await engine.run(userId, 'hi', {
    triggerSource: 'web',
    stream: false,
    skipGlobalRecall: true,
  });

  assert.equal(result.status, 'completed');
  assert.equal(result.path, 'fast');
  assert.equal(result.content, 'Hello!');
  assert.equal(result.iterations, 1);
  assert.equal(structuredCalls, 1);
  assert.equal(executionCalls, 0);

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

test('voice uses the same one-turn loop and canonical outbox adapter', async () => {
  const engine = createEngine({
    mode: 'direct_answer',
    draft_reply: 'The shared runtime handled this.',
    draft_status: 'final',
    goal: 'Answer the caller',
    confidence: 0.98,
    complexity: 'simple',
    autonomy_level: 'minimal',
    progress_update_policy: 'none',
    research_depth: 'none',
    needs_verification: false,
    success_criteria: ['Accurate answer'],
    suggested_tools: [],
  });
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

  assert.equal(result.path, 'fast');
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

  const run = ctx.db.prepare(
    'SELECT metadata_json FROM agent_runs WHERE id = ?',
  ).get(result.runId);
  const metadata = JSON.parse(run.metadata_json);
  assert.deepEqual(metadata.sessionBinding, {
    sessionId: 'voice-session-fast',
    turnId: 'turn-fast',
  });
  assert.equal(metadata.latencyPriority, 'interactive');
  assert.equal(metadata.provider, undefined);
  assert.equal(metadata.mediaMode, undefined);
});

test('durable path creates task contract and work graph', async () => {
  const engine = createEngine({
    mode: 'execute',
    draft_reply: '',
    draft_status: 'needs_execution',
    goal: 'Inspect the runtime and report findings',
    confidence: 0.8,
    complexity: 'standard',
    autonomy_level: 'normal',
    progress_update_policy: 'required',
    research_depth: 'light',
    research_targets: ['runtime'],
    needs_verification: true,
    success_criteria: ['Findings grounded in inspection'],
    suggested_tools: ['read_file'],
  });

  // Force a short durable loop that ends via partial delivery by answering with text only.
  engine.requestModelResponse = async () => ({
    response: {
      content: 'I inspected the modules and the orchestrator owns final delivery.',
      toolCalls: [],
      usage: { total_tokens: 12 },
    },
    streamContent: 'I inspected the modules and the orchestrator owns final delivery.',
  });
  engine.getAvailableTools = () => ([{
    name: 'read_file',
    description: 'Read a file',
    parameters: { type: 'object', properties: { path: { type: 'string' } } },
  }]);

  // Cap iterations hard through options so the durable path must terminate.
  const result = await engine.run(userId, 'Inspect the runtime and report findings', {
    triggerSource: 'web',
    stream: false,
    skipGlobalRecall: true,
    maxIterations: 3,
  });

  assert.ok(result.runId);
  assert.ok(['completed', 'failed', 'stopped'].includes(result.status));

  const contracts = ctx.db.prepare(
    'SELECT COUNT(*) AS n FROM agent_task_contracts WHERE run_id = ?',
  ).get(result.runId);
  assert.ok(Number(contracts.n) >= 1);

  const nodes = ctx.db.prepare(
    'SELECT COUNT(*) AS n FROM agent_work_nodes WHERE run_id = ?',
  ).get(result.runId);
  assert.ok(Number(nodes.n) >= 1);

  const events = ctx.db.prepare(
    'SELECT COUNT(*) AS n FROM agent_run_events WHERE run_id = ?',
  ).get(result.runId);
  assert.ok(Number(events.n) >= 1);
});

function contextRecoveryAnalysis() {
  return {
    mode: 'execute',
    draft_reply: '',
    draft_status: 'needs_execution',
    goal: 'Finish after recovering context pressure',
    confidence: 0.9,
    complexity: 'standard',
    autonomy_level: 'normal',
    progress_update_policy: 'none',
    research_depth: 'none',
    needs_verification: false,
    verification_need: 'none',
    success_criteria: ['Return the grounded result'],
    suggested_tools: [],
  };
}

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
  const engine = createEngine(contextRecoveryAnalysis());
  const priorMessages = installPriorTurns(engine);
  let normalCalls = 0;
  let compactionCalls = 0;
  let recoveredMessages = [];
  engine.requestModelResponse = async ({ messages, options, iteration }) => {
    if (options.phase === 'context_compaction') {
      compactionCalls += 1;
      return {
        response: { content: 'Older context summarized.', toolCalls: [], usage: { total_tokens: 3 } },
        streamContent: 'Older context summarized.',
      };
    }
    if (iteration === 0) {
      return {
        response: { content: 'Partial result.', toolCalls: [], usage: { total_tokens: 3 } },
        streamContent: 'Partial result.',
      };
    }
    normalCalls += 1;
    if (normalCalls === 1) {
      const error = new Error('maximum context length exceeded');
      error.code = 'context_length_exceeded';
      throw error;
    }
    recoveredMessages = messages;
    return {
      response: { content: 'Recovered final answer.', toolCalls: [], usage: { total_tokens: 4 } },
      streamContent: 'Recovered final answer.',
    };
  };

  const result = await engine.run(userId, 'Current unfinished turn.', {
    triggerSource: 'web',
    stream: false,
    skipGlobalRecall: true,
    priorMessages,
    maxIterations: 3,
  });

  assert.equal(result.status, 'completed');
  assert.ok(normalCalls >= 2);
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

test('repeated overflow returns an honest partial result without provider fallback', async () => {
  const engine = createEngine(contextRecoveryAnalysis());
  const priorMessages = installPriorTurns(engine);
  let normalCalls = 0;
  engine.requestModelResponse = async ({ options, iteration }) => {
    if (options.phase === 'context_compaction') {
      return {
        response: { content: 'Older context summarized.', toolCalls: [], usage: { total_tokens: 3 } },
        streamContent: 'Older context summarized.',
      };
    }
    if (iteration === 0) {
      return {
        response: { content: 'I could not safely fit more context; this is a partial result.', toolCalls: [], usage: { total_tokens: 3 } },
        streamContent: 'I could not safely fit more context; this is a partial result.',
      };
    }
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
  const exhaustedEvents = ctx.db.prepare(
    `SELECT COUNT(*) AS count FROM agent_run_events
     WHERE run_id = ? AND event_type = 'context.overflow_exhausted'`,
  ).get(result.runId);
  assert.equal(Number(exhaustedEvents.count), 1);
});

test('schedule background run keeps tool_calls.function across turns', async () => {
  const engine = createEngine({
    mode: 'execute',
    draft_reply: '',
    draft_status: 'needs_execution',
    goal: 'Calendar reminder',
    confidence: 0.8,
  });

  let modelTurns = 0;
  const toolContexts = [];
  engine.requestModelResponse = async ({ messages }) => {
    modelTurns += 1;
    // Second turn must still see OpenAI-shaped tool_calls from history.
    if (modelTurns >= 2) {
      const priorAssistant = [...messages].reverse().find(
        (m) => m.role === 'assistant' && Array.isArray(m.tool_calls) && m.tool_calls.length,
      );
      assert.ok(priorAssistant, 'expected prior assistant tool call history');
      assert.ok(
        priorAssistant.tool_calls.every((tc) => tc?.function?.name),
        'tool_calls must keep function.name for provider conversion',
      );
      return {
        response: {
          content: '',
          toolCalls: [{
            id: 'c2',
            type: 'function',
            function: {
              name: 'task_complete',
              arguments: JSON.stringify({ message: 'Reminder sent', confidence: 'high' }),
            },
          }],
          usage: { total_tokens: 6 },
        },
        streamContent: '',
      };
    }
    return {
      response: {
        content: '',
        toolCalls: [{
          id: 'c1',
          type: 'function',
          function: {
            name: 'send_message',
            arguments: JSON.stringify({
              platform: 'telegram',
              to: '1',
              content: 'Meeting in 1 hour',
              purpose: 'final_result',
            }),
          },
        }],
        usage: { total_tokens: 8 },
      },
      streamContent: '',
    };
  };
  engine.getAvailableTools = () => ([
    { name: 'task_complete', description: 'done', parameters: { type: 'object', properties: {} } },
    { name: 'send_message', description: 'send', parameters: { type: 'object', properties: {} } },
    { name: 'activate_tools', description: 'act', parameters: { type: 'object', properties: {} } },
    { name: 'think', description: 'think', parameters: { type: 'object', properties: {} } },
  ]);
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
    skipVerifier: true,
    maxIterations: 4,
    bypassUserRateLimits: true,
    deliveryState,
    stageProactiveMessages: true,
    taskId: 'task-1',
  });

  assert.equal(result.status, 'completed');
  assert.ok(modelTurns >= 1, 'expected at least one model turn');
  assert.ok(toolContexts.some((c) => c.name === 'send_message'));
  const sendCtx = toolContexts.find((c) => c.name === 'send_message');
  assert.equal(sendCtx.context.stageProactiveMessages, true);
  assert.equal(sendCtx.context.taskId, 'task-1');
  assert.equal(sendCtx.context.deliveryState, deliveryState);
  assert.equal(deliveryState.proactiveMessageStaged, true);
  assert.equal(deliveryState.stagedProactiveMessage.content, 'Meeting in 1 hour');
  // Final content must use send_message `content` (not only message/text aliases).
  assert.match(String(result.content || ''), /Meeting in 1 hour|Reminder sent/);
  // Hard-coded ack must not be emitted for schedule automation.
  const acks = ctx.db.prepare(
    `SELECT COUNT(*) AS n FROM agent_outbox
     WHERE run_id = ? AND message_kind = 'ack'`,
  ).get(result.runId);
  assert.equal(Number(acks.n), 0);
  assert.equal(taskLearningInputs.length, 1);
  assert.equal(taskLearningInputs[0].runId, result.runId);
  assert.equal(taskLearningInputs[0].taskId, 'task-1');
  assert.equal(taskLearningInputs[0].triggerType, 'schedule');
});

test('tool execution preserves mutation barriers and model-order results', async () => {
  const engine = createEngine({
    mode: 'execute',
    draft_reply: '',
    draft_status: 'needs_execution',
    goal: 'Read, update, then verify a file',
    confidence: 0.9,
    suggested_tools: ['read_before', 'write_middle', 'read_after'],
    needs_verification: false,
  });

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
    return {
      response: {
        content: '',
        toolCalls: [{
          id: 'done',
          type: 'function',
          function: { name: 'task_complete', arguments: JSON.stringify({ message: 'Verified.' }) },
        }],
        usage: { total_tokens: 3 },
      },
      streamContent: '',
    };
  };
  engine.getAvailableTools = () => ([
    { name: 'read_before', description: 'read', parameters: { type: 'object', properties: {} } },
    { name: 'write_middle', description: 'write', parameters: { type: 'object', properties: {} } },
    { name: 'read_after', description: 'read', parameters: { type: 'object', properties: {} } },
    { name: 'task_complete', description: 'done', parameters: { type: 'object', properties: {} } },
  ]);
  engine.isReadOnlyToolCall = (call) => String(call?.function?.name || '').startsWith('read_');
  engine.executeTool = async (name) => {
    trace.push(`${name}:start`);
    if (name === 'read_before') await new Promise((resolve) => setTimeout(resolve, 10));
    trace.push(`${name}:end`);
    return { success: true, name };
  };

  const result = await engine.run(userId, 'Read it, change it, then read it again.', {
    triggerSource: 'cowork',
    interactionMode: 'agent',
    stream: false,
    skipGlobalRecall: true,
    skipVerifier: true,
    maxIterations: 4,
  });

  assert.equal(result.status, 'completed');
  assert.deepEqual(trace.slice(0, 6), [
    'read_before:start',
    'read_before:end',
    'write_middle:start',
    'write_middle:end',
    'read_after:start',
    'read_after:end',
  ]);
});

test('task_complete message field becomes final content', async () => {
  const engine = createEngine({
    mode: 'execute',
    draft_reply: '',
    draft_status: 'needs_execution',
    goal: 'Say done',
    confidence: 0.9,
  });
  engine.requestModelResponse = async () => ({
    response: {
      content: '',
      toolCalls: [{
        id: 'tc1',
        type: 'function',
        function: {
          name: 'task_complete',
          arguments: JSON.stringify({ message: 'All calendar items reviewed.', confidence: 'high' }),
        },
      }],
      usage: { total_tokens: 4 },
    },
    streamContent: '',
  });
  engine.getAvailableTools = () => ([
    { name: 'task_complete', description: 'done', parameters: { type: 'object', properties: {} } },
  ]);
  engine.executeTool = async () => ({ success: true });
  engine.isReadOnlyToolCall = () => false;

  const result = await engine.run(userId, 'Review calendar', {
    triggerSource: 'web',
    stream: false,
    skipGlobalRecall: true,
    skipVerifier: true,
    maxIterations: 3,
  });

  assert.equal(result.status, 'completed');
  assert.match(String(result.content || ''), /All calendar items reviewed/);
});

test('Cowork Plan mode blocks mutating tools before execution', async () => {
  const engine = createEngine({
    mode: 'execute',
    draft_reply: '',
    draft_status: 'needs_execution',
    goal: 'Prepare an implementation plan without changing files',
    confidence: 0.9,
    complexity: 'standard',
    needs_verification: false,
    success_criteria: [],
  });
  let modelTurn = 0;
  engine.requestModelResponse = async () => {
    modelTurn += 1;
    const toolCall = modelTurn === 1
      ? {
        id: 'write-1',
        type: 'function',
        function: {
          name: 'write_file',
          arguments: JSON.stringify({ path: 'src/app.js', content: 'changed' }),
        },
      }
      : {
        id: `done-${modelTurn}`,
        type: 'function',
        function: {
          name: 'task_complete',
          arguments: JSON.stringify({ message: 'Implementation plan prepared.' }),
        },
      };
    return {
      response: {
        content: '',
        toolCalls: [toolCall],
        usage: { total_tokens: 3 },
      },
      streamContent: '',
    };
  };
  engine.getAvailableTools = () => ([
    { name: 'write_file', description: 'write', parameters: { type: 'object', properties: {} } },
    { name: 'task_complete', description: 'done', parameters: { type: 'object', properties: {} } },
  ]);
  const executed = [];
  engine.executeTool = async (name) => {
    executed.push(name);
    return { success: true };
  };
  engine.isReadOnlyToolCall = () => false;

  const result = await engine.run(userId, 'Plan this implementation.', {
    triggerSource: 'cowork',
    interactionMode: 'plan',
    stream: false,
    skipGlobalRecall: true,
    skipVerifier: true,
    maxIterations: 3,
  });

  assert.equal(executed.includes('write_file'), false);
  const blocked = ctx.db.prepare(
    `SELECT status, error FROM agent_steps
     WHERE run_id = ? AND tool_name = 'write_file'`,
  ).get(result.runId);
  assert.equal(blocked.status, 'failed');
  assert.match(blocked.error, /Plan mode blocks tools/);
});

test('Cowork agent runs pass the open folder into the system prompt', async () => {
  const engine = createEngine({
    mode: 'execute',
    draft_reply: '',
    draft_status: 'needs_execution',
    goal: 'Revamp the portfolio',
    confidence: 0.9,
    complexity: 'standard',
    needs_verification: false,
    success_criteria: [],
    suggested_tools: ['list_directory', 'edit_file'],
  });
  let promptContext = null;
  engine.buildSystemPrompt = async (_userId, context) => {
    promptContext = context;
    return 'system';
  };
  engine.requestModelResponse = async () => ({
    response: {
      content: '',
      toolCalls: [{
        id: 'done-1',
        type: 'function',
        function: {
          name: 'task_complete',
          arguments: JSON.stringify({ message: 'Updated the local files.' }),
        },
      }],
      usage: { total_tokens: 4 },
    },
    streamContent: '',
  });
  engine.getAvailableTools = () => ([
    { name: 'list_directory', description: 'list', parameters: { type: 'object', properties: {} } },
    { name: 'task_complete', description: 'done', parameters: { type: 'object', properties: {} } },
  ]);
  engine.executeTool = async () => ({ success: true });

  await engine.run(userId, 'revamp my portfolio', {
    triggerSource: 'cowork',
    interactionMode: 'agent',
    deviceTarget: 'local',
    workspaceRoot: '/Users/neo/Projects/Neotastisch-Portfolio',
    stream: false,
    skipGlobalRecall: true,
    skipVerifier: true,
    maxIterations: 2,
  });

  assert.equal(promptContext.triggerSource, 'cowork');
  assert.equal(promptContext.interactionMode, 'agent');
  assert.equal(promptContext.deviceTarget, 'local');
  assert.equal(promptContext.workspaceRoot, '/Users/neo/Projects/Neotastisch-Portfolio');
});

test('a satisfied durable run completes without burning the budget on repairs', async () => {
  const engine = createEngine({
    mode: 'execute',
    draft_reply: '',
    draft_status: 'needs_execution',
    goal: 'Check the calendar and report the next appointment',
    confidence: 0.85,
    complexity: 'standard',
    // Free-text criteria must not become obligations the runtime can never close.
    success_criteria: ['Next appointment identified from the calendar', 'User informed'],
    needs_verification: false,
    research_depth: 'none',
    suggested_tools: ['calendar_list'],
  });
  engine.getAvailableTools = () => ([
    { name: 'calendar_list', description: 'list', parameters: { type: 'object', properties: {} } },
    { name: 'task_complete', description: 'done', parameters: { type: 'object', properties: {} } },
  ]);
  let modelTurns = 0;
  engine.requestModelResponse = async ({ tools }) => {
    if (!tools || tools.length === 0) {
      return { response: { content: '', toolCalls: [], usage: {} }, streamContent: '' };
    }
    modelTurns += 1;
    if (modelTurns === 1) {
      return {
        response: {
          content: '',
          toolCalls: [{
            id: 'c1',
            type: 'function',
            function: { name: 'calendar_list', arguments: '{}' },
          }],
          usage: { total_tokens: 3 },
        },
        streamContent: '',
      };
    }
    return {
      response: {
        content: '',
        toolCalls: [{
          id: 'c2',
          type: 'function',
          function: {
            name: 'task_complete',
            arguments: JSON.stringify({ message: 'Next appointment is at 17:00.', confidence: 'high' }),
          },
        }],
        usage: { total_tokens: 3 },
      },
      streamContent: '',
    };
  };
  engine.executeTool = async () => ({ count: 1, events: [{ summary: 'Zahnarzt', start: '17:00' }] });
  engine.isReadOnlyToolCall = () => true;

  const result = await engine.run(userId, 'Was steht als nächstes an?', {
    triggerSource: 'web',
    stream: false,
    skipGlobalRecall: true,
    maxIterations: 12,
  });

  assert.equal(result.status, 'completed');
  assert.equal(result.content, 'Next appointment is at 17:00.');
  assert.ok(result.iterations <= 4, `expected a short run, got ${result.iterations} iterations`);
  assert.doesNotMatch(String(result.content), /Status: partial/);
});

test('a budget-exhausted run delivers a model-authored wrap-up, not a canned status', async () => {
  const engine = createEngine({
    mode: 'execute',
    draft_reply: '',
    draft_status: 'needs_execution',
    goal: 'Build the report',
    confidence: 0.8,
    complexity: 'standard',
    success_criteria: ['Report written'],
    needs_verification: false,
    suggested_tools: ['make_report'],
  });
  engine.getAvailableTools = () => ([
    { name: 'make_report', description: 'report', parameters: { type: 'object', properties: {} } },
  ]);
  engine.requestModelResponse = async ({ tools }) => {
    // The tool-less call is the forced wrap-up turn.
    if (!tools || tools.length === 0) {
      return {
        response: { content: 'Ich habe zwei Abschnitte geschrieben, der Rest fehlt noch.', toolCalls: [], usage: {} },
        streamContent: '',
      };
    }
    return {
      response: {
        content: '',
        toolCalls: [{
          id: `t${Math.random()}`,
          type: 'function',
          function: { name: 'make_report', arguments: '{}' },
        }],
        usage: { total_tokens: 2 },
      },
      streamContent: '',
    };
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
  assert.doesNotMatch(String(result.content), /Status: partial|This is not a claim/);
});

test('evidence soft limit tells a productive research loop to synthesize', async () => {
  const engine = createEngine({
    mode: 'execute',
    draft_reply: '',
    draft_status: 'needs_execution',
    goal: 'Research the answer without open-ended exploration',
    confidence: 0.85,
    complexity: 'standard',
    needs_verification: false,
    suggested_tools: ['lookup'],
  });
  engine.getAvailableTools = () => ([
    { name: 'lookup', description: 'Look up a new source', parameters: { type: 'object', properties: {} } },
    { name: 'task_complete', description: 'done', parameters: { type: 'object', properties: {} } },
  ]);

  let modelTurns = 0;
  let sawSoftLimit = false;
  engine.requestModelResponse = async ({ messages }) => {
    modelTurns += 1;
    sawSoftLimit = sawSoftLimit || messages.some((message) => (
      /Run budget is nearing its limit \(evidenceBudget\)/.test(String(message.content || ''))
    ));
    const call = sawSoftLimit
      ? {
        id: 'done',
        type: 'function',
        function: {
          name: 'task_complete',
          arguments: JSON.stringify({ message: 'Synthesized from four sources.' }),
        },
      }
      : {
        id: `lookup-${modelTurns}`,
        type: 'function',
        function: { name: 'lookup', arguments: JSON.stringify({ page: modelTurns }) },
      };
    return {
      response: { content: '', toolCalls: [call], usage: { total_tokens: 2 } },
      streamContent: '',
    };
  };
  engine.executeTool = async (_name, args) => ({ source: `source-${args.page}`, facts: [args.page] });
  engine.isReadOnlyToolCall = (call) => call?.function?.name === 'lookup';

  const result = await engine.run(userId, 'Research this.', {
    triggerSource: 'web',
    stream: false,
    skipGlobalRecall: true,
    skipVerifier: true,
    maxIterations: 10,
    maxEvidenceItems: 5,
  });

  assert.equal(result.status, 'completed');
  assert.equal(result.content, 'Synthesized from four sources.');
  assert.equal(sawSoftLimit, true);
  assert.equal(modelTurns, 5);
});

test('the opening line is written from the real conversation, and only for long work', async () => {
  const longWork = {
    mode: 'execute',
    draft_reply: '',
    draft_status: 'needs_execution',
    goal: 'Recherchiere die Optionen',
    confidence: 0.8,
    complexity: 'complex',
    autonomy_level: 'high',
    progress_update_policy: 'required',
    suggested_tools: ['web_search'],
  };

  function buildEngine(analysis) {
    const engine = createEngine(analysis);
    engine.buildSystemPrompt = async () => 'PERSONA_MARKER: you are Aurora';
    engine.buildContextMessages = (sys) => [
      { role: 'system', content: sys },
      { role: 'user', content: 'earlier question' },
      { role: 'assistant', content: 'PRIOR_ACK_MARKER' },
    ];
    engine.getAvailableTools = () => ([
      { name: 'web_search', description: 'search', parameters: { type: 'object', properties: {} } },
      { name: 'task_complete', description: 'done', parameters: { type: 'object', properties: {} } },
    ]);
    engine.executeTool = async () => ({ success: true });
    engine.isReadOnlyToolCall = () => true;
    return engine;
  }

  // Long work: the acknowledgement call must carry persona + history, and must
  // not carry the runtime's tool catalog scaffolding.
  const engine = buildEngine(longWork);
  let ackMessages = null;
  engine.requestModelResponse = async ({ messages, tools }) => {
    if (!tools || tools.length === 0) {
      ackMessages = messages;
      return {
        response: { content: 'Schaue ich mir an.', toolCalls: [], usage: {} },
        streamContent: '',
      };
    }
    return {
      response: {
        content: '',
        toolCalls: [{
          id: 'd1',
          type: 'function',
          function: { name: 'task_complete', arguments: JSON.stringify({ message: 'Fertig.' }) },
        }],
        usage: { total_tokens: 2 },
      },
      streamContent: '',
    };
  };

  const result = await engine.run(userId, 'Vergleich mal die Optionen für mich', {
    triggerSource: 'messaging',
    source: 'whatsapp',
    chatId: 'chat-ack',
    stream: false,
    skipGlobalRecall: true,
    skipVerifier: true,
    maxIterations: 3,
    forceMode: 'plan_execute',
  });
  assert.equal(result.status, 'completed');

  assert.ok(ackMessages, 'expected an acknowledgement model call');
  const ackText = ackMessages.map((m) => String(m.content || '')).join('\n');
  assert.match(ackText, /PERSONA_MARKER/, 'the opening line must inherit the run persona');
  assert.match(ackText, /PRIOR_ACK_MARKER/, 'it must see prior turns so it can phrase this one differently');
  assert.match(ackText, /Vergleich mal die Optionen/, 'it must see the message it is answering');
  assert.doesNotMatch(ackText, /\[Available tool catalog\]/, 'runtime scaffolding must stay out of it');

  const acks = ctx.db.prepare(
    `SELECT COUNT(*) AS n FROM agent_outbox WHERE run_id = ? AND message_kind = 'ack'`,
  ).get(result.runId);
  assert.equal(Number(acks.n), 1);

  // Ordinary durable work finishes fast enough that an opening line is noise.
  const quick = buildEngine({ ...longWork, complexity: 'standard', autonomy_level: 'normal', progress_update_policy: 'optional' });
  let quickAckCalls = 0;
  quick.requestModelResponse = async ({ tools }) => {
    if (!tools || tools.length === 0) {
      quickAckCalls += 1;
      return { response: { content: 'x', toolCalls: [], usage: {} }, streamContent: '' };
    }
    return {
      response: {
        content: '',
        toolCalls: [{
          id: 'd2',
          type: 'function',
          function: { name: 'task_complete', arguments: JSON.stringify({ message: 'Fertig.' }) },
        }],
        usage: { total_tokens: 2 },
      },
      streamContent: '',
    };
  };
  const quickResult = await quick.run(userId, 'Kurze Frage', {
    triggerSource: 'messaging',
    source: 'whatsapp',
    chatId: 'chat-ack',
    stream: false,
    skipGlobalRecall: true,
    skipVerifier: true,
    maxIterations: 3,
  });
  assert.equal(quickAckCalls, 0, 'short durable work must not be acknowledged');
  const quickAcks = ctx.db.prepare(
    `SELECT COUNT(*) AS n FROM agent_outbox WHERE run_id = ? AND message_kind = 'ack'`,
  ).get(quickResult.runId);
  assert.equal(Number(quickAcks.n), 0);
});

test('a declined opening line is not replaced by canned text', async () => {
  const engine = createEngine({
    mode: 'execute',
    draft_reply: '',
    draft_status: 'needs_execution',
    goal: 'Do long work',
    confidence: 0.8,
    complexity: 'complex',
    autonomy_level: 'high',
    progress_update_policy: 'required',
  });
  engine.getAvailableTools = () => ([
    { name: 'task_complete', description: 'done', parameters: { type: 'object', properties: {} } },
  ]);
  engine.requestModelResponse = async ({ tools }) => {
    // The model judged there was nothing natural to say up front.
    if (!tools || tools.length === 0) {
      return { response: { content: '   ', toolCalls: [], usage: {} }, streamContent: '' };
    }
    return {
      response: {
        content: '',
        toolCalls: [{
          id: 'd1',
          type: 'function',
          function: { name: 'task_complete', arguments: JSON.stringify({ message: 'Done.' }) },
        }],
        usage: { total_tokens: 2 },
      },
      streamContent: '',
    };
  };
  engine.executeTool = async () => ({ success: true });
  engine.isReadOnlyToolCall = () => true;

  const result = await engine.run(userId, 'Start the long thing', {
    triggerSource: 'messaging',
    source: 'whatsapp',
    chatId: 'chat-silent',
    stream: false,
    skipGlobalRecall: true,
    skipVerifier: true,
    maxIterations: 3,
  });

  assert.equal(result.status, 'completed');
  const acks = ctx.db.prepare(
    `SELECT COUNT(*) AS n FROM agent_outbox WHERE run_id = ? AND message_kind = 'ack'`,
  ).get(result.runId);
  assert.equal(Number(acks.n), 0, 'silence is the fallback, never a template');
});

test('one run does the work once and reports its answer to the client once', async () => {
  const engine = createEngine({
    mode: 'execute',
    draft_reply: '',
    draft_status: 'needs_execution',
    goal: 'Check something and answer',
    confidence: 0.8,
    suggested_tools: ['lookup'],
  });

  const emitted = [];
  engine.emit = (_userId, event, payload) => {
    emitted.push({ event, content: payload?.content });
  };
  engine.getAvailableTools = () => ([
    { name: 'lookup', description: 'look up', parameters: { type: 'object', properties: {} } },
    { name: 'task_complete', description: 'done', parameters: { type: 'object', properties: {} } },
  ]);

  let modelCalls = 0;
  let toolCalls = 0;
  engine.requestModelResponse = async ({ tools }) => {
    if (!tools || tools.length === 0) {
      return { response: { content: '', toolCalls: [], usage: {} }, streamContent: '' };
    }
    modelCalls += 1;
    if (modelCalls === 1) {
      return {
        response: {
          content: 'Let me look that up.',
          toolCalls: [{
            id: 'l1',
            type: 'function',
            function: { name: 'lookup', arguments: '{}' },
          }],
          usage: { total_tokens: 4 },
        },
        streamContent: '',
      };
    }
    return {
      response: {
        content: '',
        toolCalls: [{
          id: 'd1',
          type: 'function',
          function: { name: 'task_complete', arguments: JSON.stringify({ message: 'Here is the answer.' }) },
        }],
        usage: { total_tokens: 4 },
      },
      streamContent: '',
    };
  };
  engine.executeTool = async () => { toolCalls += 1; return { value: 42 }; };
  engine.isReadOnlyToolCall = () => true;

  const result = await engine.run(userId, 'Check something', {
    triggerSource: 'web',
    stream: false,
    skipGlobalRecall: true,
    skipVerifier: true,
    maxIterations: 6,
  });

  assert.equal(result.status, 'completed');
  assert.equal(result.content, 'Here is the answer.');

  // The run is not repeated: two model turns and one tool call is the whole cost.
  assert.equal(modelCalls, 2);
  assert.equal(toolCalls, 1);

  // And the answer reaches the client exactly once. A second run:complete used
  // to render the same reply again in clients that consume the first one.
  const completes = emitted.filter((entry) => entry.event === 'run:complete');
  assert.equal(completes.length, 1, `expected one run:complete, got ${completes.length}`);
  assert.equal(completes[0].content, 'Here is the answer.');

  const finals = ctx.db.prepare(
    `SELECT COUNT(*) AS n FROM agent_outbox WHERE run_id = ? AND message_kind = 'final'`,
  ).get(result.runId);
  assert.equal(Number(finals.n), 1);
});

test('an acknowledgement reaches a web client as a visible message', async () => {
  const engine = createEngine({
    mode: 'execute',
    draft_reply: '',
    draft_status: 'needs_execution',
    goal: 'Long job',
    confidence: 0.8,
    complexity: 'complex',
    autonomy_level: 'high',
    progress_update_policy: 'required',
  });
  const emitted = [];
  engine.emit = (_userId, event, payload) => {
    emitted.push({ event, content: payload?.content, kind: payload?.kind });
  };
  engine.getAvailableTools = () => ([
    { name: 'task_complete', description: 'done', parameters: { type: 'object', properties: {} } },
  ]);
  engine.requestModelResponse = async ({ tools }) => {
    if (!tools || tools.length === 0) {
      return { response: { content: 'Bin dran.', toolCalls: [], usage: {} }, streamContent: '' };
    }
    return {
      response: {
        content: '',
        toolCalls: [{
          id: 'd1',
          type: 'function',
          function: { name: 'task_complete', arguments: JSON.stringify({ message: 'Fertig.' }) },
        }],
        usage: { total_tokens: 2 },
      },
      streamContent: '',
    };
  };
  engine.executeTool = async () => ({ success: true });
  engine.isReadOnlyToolCall = () => true;

  await engine.run(userId, 'Mach das lange Ding', {
    triggerSource: 'web',
    stream: false,
    skipGlobalRecall: true,
    skipVerifier: true,
    maxIterations: 3,
    forceMode: 'plan_execute',
  });

  // run:interim carries short status notes under `message`; user-facing interim
  // text must not be sent there or the client silently drops it.
  const interim = emitted.find((entry) => entry.event === 'run:assistant_interim');
  assert.ok(interim, 'the acknowledgement never reached the client');
  assert.equal(interim.content, 'Bin dran.');
  assert.equal(interim.kind, 'ack');
});

test('a blank model turn is recovered instead of ending the run', async () => {
  const engine = createEngine({
    mode: 'execute',
    draft_reply: '',
    draft_status: 'needs_execution',
    goal: 'Look something up',
    confidence: 0.8,
    suggested_tools: ['lookup'],
  });
  engine.getAvailableTools = () => ([
    { name: 'lookup', description: 'look up', parameters: { type: 'object', properties: {} } },
    { name: 'task_complete', description: 'done', parameters: { type: 'object', properties: {} } },
  ]);
  let modelTurns = 0;
  engine.requestModelResponse = async ({ tools }) => {
    if (!tools || tools.length === 0) {
      return { response: { content: '', toolCalls: [], usage: {} }, streamContent: '' };
    }
    modelTurns += 1;
    // A provider hiccup: no content and no tool call.
    if (modelTurns === 1) {
      return { response: { content: '', toolCalls: [], usage: { total_tokens: 1 } }, streamContent: '' };
    }
    return {
      response: {
        content: '',
        toolCalls: [{
          id: 'd1',
          type: 'function',
          function: { name: 'task_complete', arguments: JSON.stringify({ message: 'Found it.' }) },
        }],
        usage: { total_tokens: 3 },
      },
      streamContent: '',
    };
  };
  engine.executeTool = async () => ({ success: true });
  engine.isReadOnlyToolCall = () => true;

  const result = await engine.run(userId, 'Look it up', {
    triggerSource: 'web',
    stream: false,
    skipGlobalRecall: true,
    maxIterations: 6,
  });

  assert.equal(result.status, 'completed');
  assert.equal(result.content, 'Found it.');
  assert.ok(modelTurns >= 2, 'the run must continue past the blank turn');

  const row = ctx.db.prepare('SELECT runtime_state FROM agent_runs WHERE id = ?').get(result.runId);
  assert.equal(row.runtime_state, 'completed');
});

test('background run searches for an inactive tool and activates it', async () => {
  const engine = createEngine({
    mode: 'execute',
    draft_reply: '',
    draft_status: 'needs_execution',
    goal: 'Kalender-Reminder',
    confidence: 0.8,
  });

  // Only the always-active built-ins get a schema on turn one. The calendar tool
  // is reachable through the catalog + activate_tools, never as a hidden schema.
  engine.getAvailableTools = () => ([
    { name: 'task_complete', description: 'done', parameters: { type: 'object', properties: {} } },
    { name: 'search_tools', description: 'search tools', parameters: { type: 'object', properties: {} } },
    { name: 'activate_tools', description: 'activate', parameters: { type: 'object', properties: {} } },
    { name: 'think', description: 'think', parameters: { type: 'object', properties: {} } },
    { name: 'send_message', description: 'send', parameters: { type: 'object', properties: {} } },
    { name: 'send_interim_update', description: 'interim', parameters: { type: 'object', properties: {} } },
    {
      name: 'google_workspace_calendar_list_events',
      description: 'List Google Calendar events in a time window',
      parameters: { type: 'object', properties: { time_min: { type: 'string' } } },
    },
  ]);

  const turnToolNames = [];
  let searchResult = null;
  let modelTurns = 0;
  engine.requestModelResponse = async ({ messages, tools }) => {
    modelTurns += 1;
    turnToolNames.push((tools || []).map((tool) => tool.name));
    if (modelTurns === 1) {
      return {
        response: {
          content: '',
          toolCalls: [{
            id: 'search1',
            type: 'function',
            function: {
              name: 'search_tools',
              arguments: JSON.stringify({ query: 'list Google Calendar events' }),
            },
          }],
          usage: { total_tokens: 5 },
        },
        streamContent: '',
      };
    }
    if (modelTurns === 2) {
      return {
        response: {
          content: '',
          toolCalls: [{
            id: 'act1',
            type: 'function',
            function: {
              name: 'activate_tools',
              arguments: JSON.stringify({ names: ['google_workspace_calendar_list_events'] }),
            },
          }],
          usage: { total_tokens: 5 },
        },
        streamContent: '',
      };
    }
    if (modelTurns === 3) {
      return {
        response: {
          content: '',
          toolCalls: [{
            id: 'cal1',
            type: 'function',
            function: {
              name: 'google_workspace_calendar_list_events',
              arguments: JSON.stringify({ time_min: '2026-08-05T12:00:00Z' }),
            },
          }],
          usage: { total_tokens: 5 },
        },
        streamContent: '',
      };
    }
    return {
      response: {
        content: '',
        toolCalls: [{
          id: 'done1',
          type: 'function',
          function: {
            name: 'task_complete',
            arguments: JSON.stringify({ message: 'Termin um 17:00 Uhr erinnert.' }),
          },
        }],
        usage: { total_tokens: 5 },
      },
      streamContent: '',
    };
  };

  const executed = [];
  engine.executeTool = async (name, args, context) => {
    executed.push(name);
    if (name === 'search_tools') {
      searchResult = engine.searchToolsForRun(context.runId, args.query, args.limit);
      return searchResult;
    }
    if (name === 'activate_tools') {
      return engine.activateToolsForRun(context.runId, args.names || []);
    }
    if (name === 'google_workspace_calendar_list_events') {
      return { count: 1, events: [{ summary: 'Zahnarzt', start: '2026-08-05T17:00:00Z' }] };
    }
    return { success: true };
  };
  engine.isReadOnlyToolCall = () => false;

  const result = await engine.run(userId, '[SYSTEM: Executing Background Task]\nTask Name: Kalender-Reminder', {
    triggerType: 'schedule',
    triggerSource: 'schedule',
    stream: false,
    skipGlobalRecall: true,
    skipConversationHistory: true,
    skipVerifier: true,
    maxIterations: 6,
    bypassUserRateLimits: true,
  });

  assert.equal(result.status, 'completed');
  assert.ok(searchResult.results.some((tool) => tool.name === 'google_workspace_calendar_list_events'));
  assert.ok(
    !turnToolNames[0].includes('google_workspace_calendar_list_events'),
    'catalog tool must not start active',
  );
  assert.ok(
    turnToolNames[2].includes('google_workspace_calendar_list_events'),
    'activate_tools must put the schema into the next model turn',
  );
  assert.ok(executed.includes('google_workspace_calendar_list_events'));
});

test('execution turns keep the agent system prompt and persist tool steps', async () => {
  const engine = createEngine({
    mode: 'execute',
    draft_reply: '',
    draft_status: 'needs_execution',
    goal: 'Read a file and report',
    confidence: 0.8,
  });
  engine.buildSystemPrompt = async () => 'AGENT_SYSTEM_PROMPT_MARKER';
  engine.getAvailableTools = () => ([
    { name: 'task_complete', description: 'done', parameters: { type: 'object', properties: {} } },
    { name: 'read_file', description: 'read', parameters: { type: 'object', properties: {} } },
  ]);

  const sawSystemPrompt = [];
  let modelTurns = 0;
  engine.requestModelResponse = async ({ messages }) => {
    modelTurns += 1;
    sawSystemPrompt.push(
      messages.some((msg) => String(msg.content || '').includes('AGENT_SYSTEM_PROMPT_MARKER')),
    );
    if (modelTurns === 1) {
      return {
        response: {
          content: '',
          toolCalls: [{
            id: 'r1',
            type: 'function',
            function: { name: 'read_file', arguments: JSON.stringify({ path: 'a.txt' }) },
          }],
          usage: { total_tokens: 5 },
        },
        streamContent: '',
      };
    }
    return {
      response: {
        content: '',
        toolCalls: [{
          id: 'd1',
          type: 'function',
          function: { name: 'task_complete', arguments: JSON.stringify({ message: 'File read.' }) },
        }],
        usage: { total_tokens: 5 },
      },
      streamContent: '',
    };
  };
  engine.executeTool = async () => ({ content: 'hello' });
  engine.isReadOnlyToolCall = () => true;

  const result = await engine.run(userId, 'Read a.txt', {
    triggerSource: 'web',
    stream: false,
    skipGlobalRecall: true,
    skipVerifier: true,
    maxIterations: 4,
  });

  assert.equal(result.status, 'completed');
  assert.ok(sawSystemPrompt.length >= 2);
  assert.ok(sawSystemPrompt.every(Boolean), 'every execution turn must carry the system prompt');

  // task_complete is a completion claim handled by the gate, not a dispatched tool.
  const steps = ctx.db.prepare(
    'SELECT tool_name, status, tool_input FROM agent_steps WHERE run_id = ? ORDER BY step_index ASC',
  ).all(result.runId);
  assert.deepEqual(steps.map((step) => step.tool_name), ['read_file']);
  assert.equal(steps[0].status, 'completed');
  assert.match(steps[0].tool_input, /a\.txt/);
});

test('messaging final is not transmitted twice after send_message delivered it', async () => {
  const engine = createEngine({
    mode: 'execute',
    draft_reply: '',
    draft_status: 'needs_execution',
    goal: 'Reply on WhatsApp',
    confidence: 0.8,
  });
  const sends = [];
  engine.messagingManager = {
    sendMessage: async (uid, platform, chatId, content) => {
      sends.push({ platform, chatId, content });
      return { success: true };
    },
    sendTyping: async () => {},
  };
  engine.getAvailableTools = () => ([
    { name: 'send_message', description: 'send', parameters: { type: 'object', properties: {} } },
    { name: 'task_complete', description: 'done', parameters: { type: 'object', properties: {} } },
  ]);
  let modelTurns = 0;
  engine.requestModelResponse = async ({ tools }) => {
    // The acknowledgement request runs without tools; it is not an execution turn.
    if (!tools || tools.length === 0) {
      return { response: { content: '', toolCalls: [], usage: {} }, streamContent: '' };
    }
    modelTurns += 1;
    if (modelTurns === 1) {
      return {
        response: {
          content: '',
          toolCalls: [{
            id: 's1',
            type: 'function',
            function: {
              name: 'send_message',
              arguments: JSON.stringify({
                platform: 'whatsapp',
                to: 'chat-1',
                content: 'Alles erledigt.',
                purpose: 'final_result',
              }),
            },
          }],
          usage: { total_tokens: 5 },
        },
        streamContent: '',
      };
    }
    return {
      response: {
        content: '',
        toolCalls: [{
          id: 'd1',
          type: 'function',
          function: { name: 'task_complete', arguments: JSON.stringify({ message: 'Alles erledigt.' }) },
        }],
        usage: { total_tokens: 5 },
      },
      streamContent: '',
    };
  };
  engine.executeTool = async (name, args, context) => {
    if (name === 'send_message') {
      const delivery = await engine.messagingManager.sendMessage(
        context.userId,
        args.platform,
        args.to,
        args.content,
      );
      return delivery;
    }
    return { success: true };
  };
  engine.isReadOnlyToolCall = () => false;

  const result = await engine.run(userId, 'Sag mir Bescheid wenn fertig', {
    triggerSource: 'messaging',
    source: 'whatsapp',
    chatId: 'chat-1',
    stream: false,
    skipGlobalRecall: true,
    skipConversationHistory: true,
    skipVerifier: true,
    maxIterations: 4,
  });

  assert.equal(result.status, 'completed');
  assert.equal(sends.length, 1, 'the final result must reach the chat exactly once');

  const finals = ctx.db.prepare(
    `SELECT COUNT(*) AS n FROM agent_outbox WHERE run_id = ? AND message_kind = 'final'`,
  ).get(result.runId);
  assert.equal(Number(finals.n), 1, 'the final delivery is still committed exactly once');
});
