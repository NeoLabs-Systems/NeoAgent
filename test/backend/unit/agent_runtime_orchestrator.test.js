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
