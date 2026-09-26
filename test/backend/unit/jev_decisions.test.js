'use strict';

const assert = require('node:assert/strict');
const { after, before, test } = require('node:test');

const { createTestRuntime, teardownTestRuntime } = require('../../helpers/db');

let ctx;
let triage;
let verification;
let retrieval;
let normalizeTaskAnalysis;
let AgentEngine;

before(() => {
  ctx = createTestRuntime();
  triage = require('../../../server/services/ai/jev_triage');
  verification = require('../../../server/services/ai/jev_verification');
  retrieval = require('../../../server/services/memory/retrieval_reasoning');
  ({ normalizeTaskAnalysis } = require('../../../server/services/ai/taskAnalysis'));
  ({ AgentEngine } = require('../../../server/services/ai/engine'));
});

after(() => teardownTestRuntime(ctx));

const TOOLS = [
  { name: 'execute_command', description: 'Run a shell command.' },
  { name: 'write_file', description: 'Write a file.' },
  { name: 'web_search', description: 'Search the web.' },
  { name: 'task_complete', description: 'Finish the task.' },
];

function noul(value) {
  return { type: 'noul', noul: value };
}

function choice(picked, probabilities) {
  return { type: 'choice', choice: picked, confidence: 0.9, probabilities };
}

function triageAnswers(overrides = {}) {
  return {
    mode: choice('execute', { direct_answer: 0.05, execute: 0.9, plan_execute: 0.05 }),
    research_depth: choice('none', { none: 1, light: 0, deep: 0 }),
    long_running: noul(0.1),
    external_side_effect: noul(0.05),
    high_stakes: noul(0.2),
    parallel_parts: noul(0.1),
    check_facts: noul(0.8),
    'tool:execute_command': noul(0.2),
    'tool:write_file': noul(0.2),
    'tool:web_search': noul(0.2),
    ...overrides,
  };
}

test('triage asks one question per tool beyond the always-active ones, and a skill choice when skills exist', () => {
  const { state, questions } = triage.buildTriageDecision({
    userMessage: 'Rename it to something better.',
    messages: [
      { role: 'system', content: 'You are NeoAgent.' },
      { role: 'user', content: 'Create notes_tmp.md with my shopping list' },
      { role: 'assistant', content: 'Done, I created notes_tmp.md.' },
      { role: 'user', content: 'Rename it to something better.' },
    ],
    tools: TOOLS,
    skills: [{ name: 'pptx-author', description: 'Write slide decks.' }],
  });

  assert.equal(state.request, 'Rename it to something better.');
  assert.deepEqual(state.recent_conversation.map((message) => message.role), ['user', 'assistant']);
  assert.ok(questions['tool:execute_command']);
  assert.equal(questions['tool:task_complete'], undefined);
  assert.deepEqual(Object.keys(questions.skill.criteria), ['none', 'pptx-author']);

  const withoutSkills = triage.buildTriageDecision({ userMessage: 'hi', tools: TOOLS, skills: [] });
  assert.equal(withoutSkills.questions.skill, undefined);
});

test('a direct answer keeps the fast shape, and every other field is filled from the answers', () => {
  const routed = triage.interpretTriageDecision(triageAnswers({
    mode: choice('direct_answer', { direct_answer: 0.95, execute: 0.05, plan_execute: 0 }),
    check_facts: noul(0.05),
  }));

  assert.equal(routed.escalate, false);
  assert.equal(routed.analysis.mode, 'direct_answer');
  assert.deepEqual(routed.analysis.suggested_tools, []);

  const analysis = normalizeTaskAnalysis(routed.analysis, { goal: 'hi', draft_status: 'needs_execution' });
  // Without a model-written draft the run takes one normal turn to answer.
  assert.equal(analysis.mode, 'execute');
  assert.equal(analysis.complexity, 'simple');
  assert.equal(analysis.verification_need, 'none');
  assert.equal(analysis.needs_verification, false);
  assert.equal(analysis.progress_update_policy, 'none');
});

test('a request that needs a tool, research, or an outside effect is never answered directly', () => {
  const direct = { mode: choice('direct_answer', { direct_answer: 0.9, execute: 0.1, plan_execute: 0 }) };
  assert.equal(triage.interpretTriageDecision(triageAnswers({ ...direct, 'tool:write_file': noul(0.7) })).analysis.mode, 'execute');
  assert.equal(triage.interpretTriageDecision(triageAnswers({ ...direct, external_side_effect: noul(0.77) })).analysis.mode, 'execute');
  assert.equal(
    triage.interpretTriageDecision(triageAnswers({ ...direct, research_depth: choice('light', { none: 0.2, light: 0.8, deep: 0 }) })).analysis.mode,
    'execute',
  );
});

test('tools above the threshold are suggested, strongest first', () => {
  const routed = triage.interpretTriageDecision(triageAnswers({
    'tool:execute_command': noul(0.64),
    'tool:write_file': noul(0.89),
    'tool:web_search': noul(0.55),
  }));
  assert.deepEqual(routed.analysis.suggested_tools, ['write_file', 'execute_command']);
});

test('broad or long work goes to the model triage', () => {
  assert.equal(triage.interpretTriageDecision(triageAnswers({
    mode: choice('plan_execute', { direct_answer: 0, execute: 0.2, plan_execute: 0.8 }),
  })).escalate, true);
  assert.equal(triage.interpretTriageDecision(triageAnswers({
    research_depth: choice('deep', { none: 0, light: 0, deep: 1 }),
  })).escalate, true);
  const long = triage.interpretTriageDecision(triageAnswers({ long_running: noul(0.85) }));
  assert.equal(long.escalate, true);
  assert.equal(long.analysis.progress_update_policy, 'required');
  assert.equal(triage.interpretTriageDecision(triageAnswers()).escalate, false);
});

test('a skill is suggested only when Jev is fairly sure it fits', () => {
  const skill = (picked, probability) => choice(picked, { none: 1 - probability, [picked]: probability });
  assert.equal(triage.interpretTriageDecision(triageAnswers({ skill: skill('pptx-author', 0.7) })).skill, 'pptx-author');
  assert.equal(triage.interpretTriageDecision(triageAnswers({ skill: skill('pptx-author', 0.4) })).skill, null);
  assert.equal(triage.interpretTriageDecision(triageAnswers({ skill: choice('none', { none: 0.9, 'pptx-author': 0.1 }) })).skill, null);
});

test('the skill hint carries the instructions and cuts very long ones', () => {
  const hint = triage.buildSkillHint({ name: 'pptx-author', instructions: 'Use the brand template.' });
  assert.match(hint, /`pptx-author`/);
  assert.match(hint, /Use the brand template\./);
  const long = triage.buildSkillHint({ name: 'huge', instructions: 'x'.repeat(7000) });
  assert.match(long, /Instructions truncated/);
  assert.ok(long.length < 6500);
});

test('the verifier is skipped only for replies that are clearly backed', () => {
  const answers = (grounded, answersRequest, unbacked) => ({
    grounded: noul(grounded),
    answers_request: noul(answersRequest),
    unbacked_action: noul(unbacked),
  });
  assert.equal(verification.isClearlySupported(answers(0.94, 0.98, 0.01)), true);
  assert.equal(verification.isClearlySupported(answers(0.89, 0.98, 0.01)), false);
  assert.equal(verification.isClearlySupported(answers(0.95, 0.85, 0.01)), false);
  assert.equal(verification.isClearlySupported(answers(0.95, 0.98, 0.2)), false);

  const { state } = verification.buildVerificationDecision({
    request: 'Run hostname',
    messages: [
      { role: 'user', content: 'Run hostname' },
      { role: 'tool', name: 'execute_command', content: 'neo-vm-01' },
    ],
    draftReply: 'neo-vm-01',
  });
  assert.deepEqual(state.evidence, [{ tool: 'execute_command', output: 'neo-vm-01' }]);
});

test('memory reranking orders candidates by Jev relevance and keeps the rest after them', () => {
  const candidates = [
    { id: 'pasta', content: 'User likes spicy pasta.' },
    { id: 'birthday', content: 'User\'s sister Lena was born on 14 March 1994.' },
    { id: 'party', content: 'User planned a party for Lena in March.' },
  ];
  const judged = candidates.slice(0, 2);
  const { questions } = retrieval.buildRerankDecision('When is my sister\'s birthday?', judged);
  assert.deepEqual(Object.keys(questions), ['candidate_0', 'candidate_1']);

  const reranked = retrieval.rerankFromDecision({
    candidate_0: noul(0.01),
    candidate_1: noul(0.97),
  }, candidates, judged);
  assert.deepEqual(reranked.map((candidate) => candidate.id), ['birthday', 'pasta', 'party']);
});

test('enhanced recall uses Jev for the rerank and the model only for the plan', async () => {
  const INITIAL = [
    { id: 'mem-a', content: 'a', score: 0.6, scoreBreakdown: { semantic: 0.5 } },
    { id: 'mem-b', content: 'b', score: 0.58, scoreBreakdown: { semantic: 0.5 } },
  ];
  const engine = new AgentEngine(null);
  const phases = [];
  engine.requestStructuredJson = async ({ phase, fallback }) => {
    phases.push(phase);
    return { value: fallback, parsed: true };
  };
  engine.decide = async ({ phase }) => {
    phases.push(phase);
    return { candidate_0: noul(0.1), candidate_1: noul(0.9) };
  };

  const message = await engine.buildMemoryRecall({
    memoryManager: {
      recallMemory: async () => INITIAL,
      getPendingExtractionChunks: () => [],
      getMemoryStats: () => ({ total: 2 }),
      recordRetrievalEnhancement: () => {},
      buildRecallMessage: async (_userId, _query, { recalled }) => recalled.map((item) => item.id).join(','),
    },
    userId: 1,
    agentId: null,
    query: 'what did I say about b',
    provider: {},
    providerName: 'test',
    model: 'test-model',
    runId: null,
    options: { signal: new AbortController().signal },
  });

  assert.deepEqual(phases, ['memory_retrieval_plan', 'jev_memory_rerank']);
  assert.equal(message, 'mem-b,mem-a');
});

test('search results are sorted by how likely they hold what the task needs', () => {
  const research = require('../../../server/services/ai/jev_research');
  const result = {
    query: 'swiss city populations',
    results: [
      { rank: 1, title: 'Swiss cheese', url: 'https://a.test', description: 'Cheese' },
      { rank: 2, title: 'List of cities in Switzerland', url: 'https://b.test', description: 'Population and area' },
    ],
  };
  const decision = research.buildResearchDecision({ task: 'Compare Swiss city populations', toolName: 'web_search', result });
  assert.deepEqual(Object.keys(decision.questions), ['result_0', 'result_1']);

  const rated = research.applyResearchRating({
    toolName: 'web_search',
    result,
    answers: { result_0: noul(0.02), result_1: noul(0.951) },
  });
  assert.deepEqual(rated.results.map((item) => [item.task_relevance, item.title]), [
    [0.95, 'List of cities in Switzerland'],
    [0.02, 'Swiss cheese'],
  ]);
});

test('a fetched page is rated for the task and each research target, ahead of its content', () => {
  const research = require('../../../server/services/ai/jev_research');
  const { compactToolResult } = require('../../../server/services/ai/toolResult');
  const targets = ['Zurich', 'Geneva'];
  const decision = research.buildResearchDecision({
    task: 'Compare Zurich and Geneva',
    targets,
    toolName: 'browser_extract',
    result: { result: 'Zurich has 443,000 inhabitants.' },
  });
  assert.deepEqual(Object.keys(decision.questions), ['has_needed_info', 'blocked_or_empty', 'target_0', 'target_1']);

  const rated = research.applyResearchRating({
    toolName: 'browser_extract',
    result: { result: 'Zurich has 443,000 inhabitants.' },
    answers: {
      has_needed_info: noul(0.86),
      blocked_or_empty: noul(0.04),
      target_0: noul(0.9),
      target_1: noul(0.1),
    },
    targets,
  });
  assert.deepEqual(rated.task_relevance, {
    has_needed_info: 0.86,
    blocked_or_empty: 0.04,
    targets_covered: ['Zurich'],
    targets_missing: ['Geneva'],
  });
  assert.equal(Object.keys(rated)[0], 'task_relevance');
  assert.deepEqual(
    JSON.parse(compactToolResult('browser_extract', {}, rated)).task_relevance,
    rated.task_relevance,
  );

  assert.equal(research.buildResearchDecision({ task: 't', toolName: 'http_request', args: { method: 'POST' }, result: { body: 'ok' } }), null);
  assert.equal(research.buildResearchDecision({ task: 't', toolName: 'browser_navigate', result: { error: 'timeout' } }), null);
});
