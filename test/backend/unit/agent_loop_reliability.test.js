'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  normalizeTaskAnalysis,
  isDirectAnswerEligibleAnalysis,
  buildAnalysisPrompt,
  buildExecutionGuidance,
  buildVerifierPrompt,
} = require('../../../server/services/ai/taskAnalysis');
const {
  buildLoopPolicy,
  resolveChurnNudgeThreshold,
} = require('../../../server/services/ai/loopPolicy');
const {
  enforceTerminalReplyDecision,
  enforceChurnAssessment,
  buildCompletionDecisionPrompt,
} = require('../../../server/services/ai/loop/completion_judge');
const {
  assessResearchAdequacy,
  resolveResearchIntensity,
} = require('../../../server/services/ai/toolEvidence');
const {
  buildMaxIterationWrapupPrompt,
} = require('../../../server/services/ai/messagingFallback');
const {
  buildReadOnlyChurnGuidance,
} = require('../../../server/services/ai/loop/progress_classification');

test('simple Q&A stays on the cheap direct-answer path', () => {
  const analysis = normalizeTaskAnalysis({
    mode: 'direct_answer',
    draft_reply: 'Berlin is the capital of Germany.',
    goal: 'quick factual chat answer',
    verification_need: 'none',
    freshness_risk: 'none',
    complexity: 'simple',
    autonomy_level: 'minimal',
    progress_update_policy: 'none',
  });

  assert.equal(analysis.mode, 'direct_answer');
  assert.equal(isDirectAnswerEligibleAnalysis(analysis), true);

  const policy = buildLoopPolicy({}, 'chat', 'direct_answer', {
    autonomyPolicy: {
      complexity: analysis.complexity,
      autonomy_level: analysis.autonomy_level,
    },
  });
  assert.equal(policy.maxIterations, 16);
  assert.equal(policy.maxConsecutiveReadOnlyIterations, 3);
  assert.equal(resolveChurnNudgeThreshold({ complexity: 'simple' }), 2);
});

test('named research targets cannot fast-path as direct answers', () => {
  const analysis = normalizeTaskAnalysis({
    mode: 'direct_answer',
    draft_reply: 'They all look fine.',
    goal: 'Look into three CNC machines',
    research_targets: [
      'AnoleX 3030-Evo Max',
      'Genmitsu 3018 Pro',
      'SainSmart 3018',
    ],
    verification_need: 'none',
    freshness_risk: 'none',
  });

  assert.equal(analysis.mode, 'plan_execute');
  assert.equal(analysis.verification_need, 'required');
  assert.equal(analysis.freshness_risk, 'possible');
  assert.equal(analysis.completion_confidence_required, 'high');
  assert.equal(isDirectAnswerEligibleAnalysis(analysis), false);
  assert.equal(resolveResearchIntensity(analysis), 'deep');
});

test('incomplete multi-target research cannot complete or force-block via churn', () => {
  const analysis = normalizeTaskAnalysis({
    mode: 'execute',
    goal: 'Compare AnoleX 3030-Evo Max and Genmitsu 3018 Pro',
    research_targets: ['AnoleX 3030-Evo Max', 'Genmitsu 3018 Pro'],
    suggested_tools: ['web_search', 'browser_navigate'],
    verification_need: 'required',
    freshness_risk: 'possible',
    completion_confidence_required: 'high',
  });
  const toolExecutions = [
    {
      toolName: 'web_search',
      ok: true,
      evidenceSource: 'search',
      evidenceRelevant: true,
      summary: 'snippets for AnoleX 3030-Evo Max',
      input: { query: 'AnoleX 3030-Evo Max' },
    },
  ];

  const adequacy = assessResearchAdequacy({ analysis, toolExecutions });
  assert.equal(adequacy.adequate, false);

  const terminal = enforceTerminalReplyDecision(
    { status: 'complete', reason: 'Looks complete enough.' },
    'Die AnoleX ist super und die Genmitsu auch, fertig.',
    { analysis, toolExecutions, researchAdequacy: adequacy },
  );
  assert.equal(terminal.status, 'continue');

  const churn = enforceChurnAssessment(
    { assessment: 'blocked', reason: 'I am stuck after searching.' },
    { analysis, toolExecutions, researchAdequacy: adequacy },
  );
  assert.equal(churn.assessment, 'progressing');
});

test('complex research gets more productive read room before hard wrap-up', () => {
  const complex = buildLoopPolicy({}, 'messaging', 'plan_execute', {
    autonomyPolicy: { complexity: 'complex', autonomy_level: 'high' },
  });
  assert.equal(complex.maxIterations, 250);
  assert.equal(complex.maxConsecutiveReadOnlyIterations, 14);
  assert.equal(
    resolveChurnNudgeThreshold({ complexity: 'complex', autonomyLevel: 'high' }),
    6,
  );
});

test('analysis and execution prompts push primary-source research without task ceremony for short work', () => {
  const analysisPrompt = buildAnalysisPrompt({
    tools: [
      { name: 'web_search', description: 'Search the web.' },
      { name: 'create_task', description: 'Create a task.' },
    ],
  });
  assert.match(analysisPrompt, /direct_answer/);
  assert.match(analysisPrompt, /research_targets/);
  assert.match(analysisPrompt, /Never invent entities/);

  const guidance = buildExecutionGuidance({
    analysis: {
      mode: 'plan_execute',
      goal: 'Compare AnoleX 3030-Evo Max and Genmitsu 3018 Pro',
      research_targets: ['AnoleX 3030-Evo Max', 'Genmitsu 3018 Pro'],
      success_criteria: ['Cover both machines'],
      complexity: 'complex',
      autonomy_level: 'high',
      progress_update_policy: 'optional',
      completion_confidence_required: 'high',
    },
  });
  assert.match(guidance, /Research targets/);
  assert.match(guidance, /primary sources/);

  const verifier = buildVerifierPrompt({
    analysis: {
      freshness_risk: 'possible',
      verification_need: 'required',
      completion_confidence_required: 'high',
    },
    tools: [{ name: 'web_search' }],
    toolExecutionSummary: '1. web_search only',
    evidenceSources: ['search'],
    finalReply: 'Both machines are perfect.',
  });
  assert.match(verifier, /Do not invent missing targets/);
});

test('completion and wrap-up prompts forbid fabricated completion', () => {
  const prompt = buildCompletionDecisionPrompt({
    triggerSource: 'messaging',
    messagingSent: false,
    goalContext: {
      effectiveGoal: 'Compare AnoleX 3030-Evo Max and Genmitsu 3018 Pro',
      successCriteria: ['Cover both machines'],
      effectiveComplexity: 'complex',
      effectiveAutonomyLevel: 'high',
      effectiveProgressPolicy: 'optional',
      effectiveCompletionConfidence: 'high',
      persistedGoalPrompt: '',
    },
    tools: [{ name: 'web_search' }, { name: 'browser_navigate' }],
    toolExecutions: [],
    lastReply: 'Both are great.',
    iteration: 2,
    maxIterations: 20,
    analysis: {
      mode: 'plan_execute',
      research_targets: ['AnoleX 3030-Evo Max', 'Genmitsu 3018 Pro'],
      verification_need: 'required',
      freshness_risk: 'possible',
      completion_confidence_required: 'high',
      goal: 'Compare AnoleX 3030-Evo Max and Genmitsu 3018 Pro',
      suggested_tools: ['web_search', 'browser_navigate'],
    },
  });
  assert.match(prompt, /invent entities|not supported by tool evidence/i);
  assert.match(prompt, /Research intensity|Research adequacy/i);

  assert.match(
    buildMaxIterationWrapupPrompt('whatsapp'),
    /Do not invent entities/,
  );
  assert.match(
    buildReadOnlyChurnGuidance({ readOnlyCount: 4, alreadyRead: 'web_search' }),
    /Never invent missing targets/,
  );
});


test('local implementation work does not inherit a research burden', () => {
  const analysis = normalizeTaskAnalysis({
    mode: 'plan_execute',
    goal: 'Implement the pause/resume fix in the agent loop',
    success_criteria: ['Write the code', 'Run the unit tests'],
    suggested_tools: ['read_file', 'edit_file', 'execute_command'],
    verification_need: 'light',
    freshness_risk: 'none',
    complexity: 'complex',
    autonomy_level: 'high',
    completion_confidence_required: 'high',
  });
  assert.equal(resolveResearchIntensity(analysis), 'none');
  assert.equal(assessResearchAdequacy({ analysis, toolExecutions: [] }).adequate, true);
});

test('multi-target research is inadequate on search snippets alone and adequate with primary sources', () => {
  const analysis = normalizeTaskAnalysis({
    mode: 'execute',
    goal: 'Look into AnoleX 3030-Evo Max, Genmitsu 3018 Pro, and SainSmart 3018',
    research_targets: [
      'AnoleX 3030-Evo Max',
      'Genmitsu 3018 Pro',
      'SainSmart 3018',
    ],
    suggested_tools: ['web_search', 'browser_navigate', 'http_request'],
    verification_need: 'required',
    freshness_risk: 'possible',
    completion_confidence_required: 'high',
  });
  assert.equal(resolveResearchIntensity(analysis), 'deep');

  const onlySearch = assessResearchAdequacy({
    analysis,
    toolExecutions: [
      {
        toolName: 'web_search',
        ok: true,
        evidenceSource: 'search',
        evidenceRelevant: true,
        summary: 'search hits for AnoleX 3030-Evo Max',
        input: { query: 'AnoleX 3030-Evo Max specs' },
      },
    ],
  });
  assert.equal(onlySearch.adequate, false);
  assert.ok(onlySearch.uncoveredTargets.includes('Genmitsu 3018 Pro'));

  const full = assessResearchAdequacy({
    analysis,
    toolExecutions: [
      {
        toolName: 'web_search',
        ok: true,
        evidenceSource: 'search',
        evidenceRelevant: true,
        summary: 'search hits',
        input: { query: 'cnc routers comparison' },
      },
      {
        toolName: 'browser_navigate',
        ok: true,
        evidenceSource: 'browser',
        evidenceRelevant: true,
        summary: 'opened AnoleX product page',
        input: { url: 'https://example.test/anolex-3030-evo-max' },
      },
      {
        toolName: 'http_request',
        ok: true,
        evidenceSource: 'http',
        evidenceRelevant: true,
        summary: 'fetched Genmitsu 3018 Pro docs',
        input: { url: 'https://example.test/genmitsu-3018-pro' },
      },
      {
        toolName: 'browser_navigate',
        ok: true,
        evidenceSource: 'browser',
        evidenceRelevant: true,
        summary: 'opened SainSmart 3018 page',
        input: { url: 'https://example.test/sainsmart-3018' },
      },
    ],
  });
  assert.equal(full.adequate, true);
  assert.equal(full.coveredTargets.length, 3);
  assert.equal(full.primaryCoveredTargets.length, 3);
});

