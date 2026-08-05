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

test('fast path completes ordinary chat without planning ceremony', async () => {
  const engine = createEngine({
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
  });

  const result = await engine.run(userId, 'hi', {
    triggerSource: 'web',
    stream: false,
    skipGlobalRecall: true,
  });

  assert.equal(result.status, 'completed');
  assert.equal(result.path, 'fast');
  assert.equal(result.content, 'Hello!');
  assert.equal(result.iterations, 1);

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

  const result = await engine.run(userId, '[SYSTEM: Executing Background Task]\nTask Name: Kalender-Reminder', {
    triggerType: 'schedule',
    triggerSource: 'schedule',
    stream: false,
    skipTaskAnalysis: true,
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
    skipTaskAnalysis: true,
    skipGlobalRecall: true,
    skipVerifier: true,
    maxIterations: 3,
  });

  assert.equal(result.status, 'completed');
  assert.match(String(result.content || ''), /All calendar items reviewed/);
});
