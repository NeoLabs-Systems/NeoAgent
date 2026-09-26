'use strict';

const assert = require('node:assert/strict');
const { after, before, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

let ctx;
let userId;
let AgentEngine;

before(async () => {
  ctx = createTestRuntime();
  userId = (await createTestUser(ctx.db, { username: 'jev_runtime_user' })).userId;

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
});

after(() => teardownTestRuntime(ctx));

const SCHEMA = { type: 'object', properties: {} };
const TOOLS = [
  { name: 'task_complete', description: 'Finish the task', parameters: SCHEMA },
  { name: 'write_file', description: 'Write content to a workspace file', parameters: SCHEMA },
  { name: 'execute_command', description: 'Run shell commands', parameters: SCHEMA },
  { name: 'list_chats', description: 'List messaging conversations', parameters: SCHEMA },
  { name: 'web_search', description: 'Search the web', parameters: SCHEMA },
];

function noul(value) {
  return { type: 'noul', noul: value };
}

function choice(picked, probabilities) {
  return { type: 'choice', choice: picked, confidence: 0.9, probabilities };
}

function triageAnswers({ mode = 'execute', tools = {}, skill = null, longRunning = 0.1 } = {}) {
  return {
    mode: choice(mode, { direct_answer: 0.05, execute: 0.05, plan_execute: 0.05, [mode]: 0.9 }),
    research_depth: choice('none', { none: 1, light: 0, deep: 0 }),
    long_running: noul(longRunning),
    external_side_effect: noul(0.05),
    high_stakes: noul(0.1),
    parallel_parts: noul(0.1),
    check_facts: noul(0.1),
    ...Object.fromEntries(
      ['write_file', 'execute_command', 'list_chats', 'web_search']
        .map((name) => [`tool:${name}`, noul(tools[name] ?? 0.05)]),
    ),
    ...(skill ? { skill: choice(skill, { none: 0.2, [skill]: 0.8 }) } : {}),
  };
}

function createEngine({ decisions = {}, analysis = null } = {}) {
  const engine = new AgentEngine(null);
  const calls = { structured: [], decisions: [], turns: [] };
  engine.emit = () => {};
  engine.buildSystemPrompt = async () => 'system';
  engine.buildMemoryRecall = async () => null;
  engine.buildContextMessages = (sys) => [{ role: 'system', content: sys }];
  engine.buildUserMessage = (message) => ({ role: 'user', content: message });
  engine.getAvailableTools = () => TOOLS;
  engine.getReasoningEffort = () => undefined;
  engine.decide = async ({ phase }) => {
    calls.decisions.push(phase);
    return decisions[phase] || null;
  };
  engine.requestStructuredJson = async ({ phase, normalize, fallback }) => {
    calls.structured.push(phase);
    const value = phase === 'task_analysis' && analysis ? normalize(analysis, fallback) : fallback;
    return { value, parsed: true, raw: '', usage: 5 };
  };
  engine.calls = calls;
  return engine;
}

function finishWith(engine, message) {
  engine.requestModelResponse = async ({ tools, messages }) => {
    engine.calls.turns.push({
      tools: (tools || []).map((tool) => tool.name),
      systemMessages: messages.filter((m) => m.role === 'system').map((m) => String(m.content)),
    });
    return {
      response: {
        content: '',
        toolCalls: [{
          id: `done-${engine.calls.turns.length}`,
          type: 'function',
          function: { name: 'task_complete', arguments: JSON.stringify({ message }) },
        }],
        usage: { total_tokens: 3 },
      },
      streamContent: '',
    };
  };
}

test('a direct answer takes one plain model turn and the fast path, without the model triage', async () => {
  const engine = createEngine({
    decisions: { jev_triage: triageAnswers({ mode: 'direct_answer' }) },
  });
  engine.requestModelResponse = async ({ tools, options }) => {
    engine.calls.turns.push({ tools, phase: options.phase });
    return { response: { content: 'Hello!', toolCalls: [], usage: { total_tokens: 3 } }, streamContent: 'Hello!' };
  };

  const result = await engine.run(userId, 'hi', {
    triggerSource: 'web',
    stream: false,
    skipGlobalRecall: true,
    maxIterations: 3,
  });

  assert.equal(result.status, 'completed');
  assert.equal(result.path, 'fast');
  assert.equal(result.content, 'Hello!');
  assert.equal(engine.calls.structured.includes('task_analysis'), false);
  assert.equal(engine.calls.structured.includes('verification'), false);
  assert.deepEqual(engine.calls.turns, [{ tools: [], phase: 'direct_reply' }]);
  const selection = ctx.db.prepare(
    "SELECT payload_json FROM agent_run_events WHERE run_id = ? AND event_type = 'tool_selection_applied'",
  ).get(result.runId);
  assert.equal(JSON.parse(selection.payload_json).triage, 'jev');
});

test('Jev picks the active tools, and the picked skill reaches the model with its instructions', async () => {
  const engine = createEngine({
    decisions: {
      jev_triage: triageAnswers({ tools: { write_file: 0.9, list_chats: 0.2 }, skill: 'report-writer' }),
    },
  });
  engine.skillRunner = {
    getAll: () => [
      { name: 'report-writer', description: 'Write reports', instructions: 'Always start with a summary.', metadata: {} },
      { name: 'disabled-one', description: 'Off', instructions: 'Never used.', metadata: { enabled: false } },
    ],
  };
  finishWith(engine, 'Written.');

  await engine.run(userId, 'Write the quarterly report into report.md', {
    triggerSource: 'web',
    stream: false,
    skipGlobalRecall: true,
    skipVerifier: true,
    maxIterations: 3,
  });

  const [firstTurn] = engine.calls.turns;
  assert.ok(firstTurn.tools.includes('write_file'));
  assert.ok(firstTurn.tools.includes('execute_command'), 'file work comes with a shell');
  assert.equal(firstTurn.tools.includes('list_chats'), false);
  assert.equal(firstTurn.tools.includes('web_search'), false);
  const hint = firstTurn.systemMessages.find((content) => content.startsWith('[Relevant skill]'));
  assert.match(hint, /`report-writer`/);
  assert.match(hint, /Always start with a summary\./);
});

test('broad work keeps the model triage, while Jev still chooses the tools', async () => {
  const engine = createEngine({
    decisions: { jev_triage: triageAnswers({ mode: 'plan_execute', tools: { web_search: 0.9 } }) },
    analysis: {
      mode: 'plan_execute',
      goal: 'Compare three e-bikes with sources',
      success_criteria: ['Each bike has sourced specs'],
      suggested_tools: ['list_chats'],
      acknowledgement: 'I will compare the three bikes and send the sources.',
    },
  });
  finishWith(engine, 'Compared.');

  await engine.run(userId, 'Compare the three best e-bikes under 3000 EUR with sources', {
    triggerSource: 'web',
    stream: false,
    skipGlobalRecall: true,
    skipVerifier: true,
    maxIterations: 3,
  });

  assert.equal(engine.calls.structured.filter((phase) => phase === 'task_analysis').length, 1);
  const selection = ctx.db.prepare(
    "SELECT payload_json FROM agent_run_events WHERE event_type = 'tool_selection_applied' ORDER BY rowid DESC",
  ).get();
  assert.equal(JSON.parse(selection.payload_json).triage, 'model+jev');
  const [firstTurn] = engine.calls.turns;
  assert.ok(firstTurn.tools.includes('web_search'));
  assert.equal(firstTurn.tools.includes('list_chats'), false);
  const guidance = firstTurn.systemMessages.find((content) => content.includes('Execution mode:'));
  assert.match(guidance, /Compare three e-bikes with sources/);
});

test('without a Jev answer the model triage runs exactly as before', async () => {
  const engine = createEngine({
    analysis: { mode: 'execute', goal: 'List chats', suggested_tools: ['list_chats'] },
  });
  finishWith(engine, 'Listed.');

  await engine.run(userId, 'List my chats', {
    triggerSource: 'web',
    stream: false,
    skipGlobalRecall: true,
    skipVerifier: true,
    maxIterations: 3,
  });

  assert.deepEqual(engine.calls.decisions, ['jev_triage']);
  assert.equal(engine.calls.structured.filter((phase) => phase === 'task_analysis').length, 1);
  assert.ok(engine.calls.turns[0].tools.includes('list_chats'));
});

function verifiedRunEngine(verificationAnswers) {
  const engine = createEngine({
    decisions: {
      jev_verification: verificationAnswers,
    },
    analysis: {
      mode: 'execute',
      goal: 'Search the weather',
      research_depth: 'light',
      needs_verification: true,
      suggested_tools: ['web_search'],
    },
  });
  engine.executeTool = async () => ({ results: [{ title: 'Zurich forecast', snippet: 'Sunny, 24°C' }] });
  let turn = 0;
  engine.requestModelResponse = async () => {
    turn += 1;
    if (turn === 1) {
      return {
        response: {
          content: '',
          toolCalls: [{ id: 'search-1', type: 'function', function: { name: 'web_search', arguments: '{"query":"zurich weather"}' } }],
          usage: { total_tokens: 3 },
        },
        streamContent: '',
      };
    }
    return {
      response: { content: 'Sunny in Zurich, around 24°C.', toolCalls: [], usage: { total_tokens: 3 } },
      streamContent: 'Sunny in Zurich, around 24°C.',
    };
  };
  return engine;
}

test('a reply Jev finds clearly backed skips the verifier model', async () => {
  const engine = verifiedRunEngine({
    grounded: noul(0.95),
    answers_request: noul(0.97),
    unbacked_action: noul(0.02),
  });

  const result = await engine.run(userId, 'What is the weather in Zurich?', {
    triggerSource: 'web',
    stream: false,
    skipGlobalRecall: true,
    maxIterations: 4,
  });

  assert.equal(result.status, 'completed');
  assert.ok(engine.calls.decisions.includes('jev_verification'));
  assert.equal(engine.calls.structured.includes('verification'), false);
});

test('a reply Jev doubts still goes to the verifier model', async () => {
  const engine = verifiedRunEngine({
    grounded: noul(0.4),
    answers_request: noul(0.97),
    unbacked_action: noul(0.02),
  });

  await engine.run(userId, 'What is the weather in Zurich?', {
    triggerSource: 'web',
    stream: false,
    skipGlobalRecall: true,
    maxIterations: 4,
  });

  assert.ok(engine.calls.structured.includes('verification'));
});

test('a direct reply that fails falls back to the normal execution path', async () => {
  const engine = createEngine({
    decisions: { jev_triage: triageAnswers({ mode: 'direct_answer' }) },
  });
  engine.requestModelResponse = async ({ options }) => {
    engine.calls.turns.push({ phase: options.phase || 'model_turn' });
    if (options.phase === 'direct_reply') throw new Error('provider hiccup');
    return { response: { content: 'Hello!', toolCalls: [], usage: { total_tokens: 3 } }, streamContent: 'Hello!' };
  };

  const result = await engine.run(userId, 'hi', {
    triggerSource: 'web',
    stream: false,
    skipGlobalRecall: true,
    maxIterations: 3,
  });

  assert.equal(result.status, 'completed');
  assert.equal(result.content, 'Hello!');
  assert.deepEqual(engine.calls.turns.map((turn) => turn.phase), ['direct_reply', 'model_turn']);
});

function searchRun({ researchDepth }) {
  const engine = createEngine({
    decisions: {
      jev_research_rating: { result_0: noul(0.1), result_1: noul(0.9) },
    },
    analysis: {
      mode: 'execute',
      goal: 'Find the population of Basel',
      research_depth: researchDepth,
      suggested_tools: ['web_search'],
    },
  });
  engine.executeTool = async () => ({
    results: [
      { title: 'Basel airport', url: 'https://a.test', description: 'Flights' },
      { title: 'Basel', url: 'https://b.test', description: 'Population 177,000' },
    ],
  });
  let turn = 0;
  engine.requestModelResponse = async ({ messages }) => {
    turn += 1;
    if (turn === 1) {
      return {
        response: {
          content: '',
          toolCalls: [{ id: 'search-1', type: 'function', function: { name: 'web_search', arguments: '{"query":"basel population"}' } }],
          usage: { total_tokens: 3 },
        },
        streamContent: '',
      };
    }
    engine.toolOutput = messages.filter((message) => message.role === 'tool').at(-1).content;
    return {
      response: {
        content: '',
        toolCalls: [{ id: 'done', type: 'function', function: { name: 'task_complete', arguments: '{"message":"About 177,000."}' } }],
        usage: { total_tokens: 3 },
      },
      streamContent: '',
    };
  };
  return engine;
}

test('research reads come back rated for the task, best result first', async () => {
  const engine = searchRun({ researchDepth: 'light' });
  await engine.run(userId, 'What is the population of Basel?', {
    triggerSource: 'web',
    stream: false,
    skipGlobalRecall: true,
    skipVerifier: true,
    maxIterations: 4,
  });
  assert.ok(engine.calls.decisions.includes('jev_research_rating'));
  const summary = String(engine.toolOutput);
  assert.ok(summary.indexOf('"Basel"') < summary.indexOf('Basel airport'), summary);
  assert.match(summary, /task_relevance/);
});

test('reads outside research runs are not rated', async () => {
  const engine = searchRun({ researchDepth: 'none' });
  await engine.run(userId, 'Search basel population', {
    triggerSource: 'web',
    stream: false,
    skipGlobalRecall: true,
    skipVerifier: true,
    maxIterations: 4,
  });
  assert.equal(engine.calls.decisions.includes('jev_research_rating'), false);
});
