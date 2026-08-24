'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  normalizeTaskAnalysis,
  isDirectAnswerEligibleAnalysis,
  buildExecutionGuidance,
  buildVerifierPrompt,
  normalizeVerificationResult,
} = require('../../../server/services/ai/taskAnalysis');
const {
  buildLoopPolicy,
  resolveChurnNudgeThreshold,
} = require('../../../server/services/ai/loopPolicy');
const {
  enforceTerminalReplyDecision,
  enforceChurnAssessment,
  buildCompletionDecisionPrompt,
  normalizeCompletionDecision,
} = require('../../../server/services/ai/loop/completion_judge');
const {
  assessResearchAdequacy,
  resolveResearchIntensity,
  summarizeResearchEvidenceCatalog,
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
    draft_status: 'final',
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
  assert.equal(policy.maxIterations, 8);
  assert.equal(policy.maxConsecutiveReadOnlyIterations, 3);
  assert.equal(resolveChurnNudgeThreshold({ complexity: 'simple' }), 2);
});

test('named research targets cannot fast-path as direct answers', () => {
  const analysis = normalizeTaskAnalysis({
    mode: 'direct_answer',
    draft_reply: 'They all look fine.',
    draft_status: 'final',
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

test('incomplete multi-target research cannot complete but real blockers remain terminal', () => {
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
  assert.equal(adequacy.structurallyReady, true);
  assert.equal(adequacy.semanticReviewRequired, true);

  const terminal = enforceTerminalReplyDecision(
    normalizeCompletionDecision({
      status: 'complete',
      reason: 'Looks complete enough.',
      research_review: {
        required: true,
        adequate: false,
        missing_targets: ['Genmitsu 3018 Pro'],
      },
    }),
    'Die AnoleX ist super und die Genmitsu auch, fertig.',
    { analysis, toolExecutions, researchAdequacy: adequacy },
  );
  assert.equal(terminal.status, 'continue');

  const churn = enforceChurnAssessment(
    {
      assessment: 'blocked',
      reason: 'The user must identify the third device.',
      blocker_kind: 'user_input',
      resolvable_in_run: false,
    },
    { analysis, toolExecutions, researchAdequacy: adequacy },
  );
  assert.equal(churn.assessment, 'blocked');
});

test('complex research gets more productive read room before hard wrap-up', () => {
  const complex = buildLoopPolicy({}, 'messaging', 'plan_execute', {
    autonomyPolicy: { complexity: 'complex', autonomy_level: 'high' },
  });
  assert.equal(complex.maxIterations, 80);
  assert.equal(complex.maxConsecutiveReadOnlyIterations, 14);
  assert.equal(
    resolveChurnNudgeThreshold({ complexity: 'complex', autonomyLevel: 'high' }),
    6,
  );
});

test('execution and verification prompts require primary-source research', () => {
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

test('multi-target research completion requires AI-reviewed primary evidence for every exact target', () => {
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
  assert.equal(onlySearch.structurallyReady, true);
  const searchOnlyCompletion = enforceTerminalReplyDecision(
    normalizeCompletionDecision({
      status: 'complete',
      reason: 'Search snippets look sufficient.',
      research_review: {
        required: true,
        adequate: true,
        target_coverage: [
          {
            target: 'AnoleX 3030-Evo Max',
            support: 'secondary',
            evidence_indexes: [1],
          },
        ],
        missing_targets: ['Genmitsu 3018 Pro', 'SainSmart 3018'],
      },
    }),
    'All three devices look good.',
    { analysis, toolExecutions: onlySearchToolExecutions(), researchAdequacy: onlySearch },
  );
  assert.equal(searchOnlyCompletion.status, 'continue');

  const fullToolExecutions = [
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
    ];
  const full = assessResearchAdequacy({
    analysis,
    toolExecutions: fullToolExecutions,
  });
  const completed = enforceTerminalReplyDecision(
    normalizeCompletionDecision({
      status: 'complete',
      reason: 'Every target has primary evidence.',
      research_review: {
        required: true,
        adequate: true,
        evidence_indexes: [2, 3, 4],
        target_coverage: [
          { target: 'AnoleX 3030-Evo Max', support: 'primary', evidence_indexes: [2] },
          { target: 'Genmitsu 3018 Pro', support: 'primary', evidence_indexes: [3] },
          { target: 'SainSmart 3018', support: 'primary', evidence_indexes: [4] },
        ],
        missing_targets: [],
      },
    }),
    'Evidence-backed comparison.',
    { analysis, toolExecutions: fullToolExecutions, researchAdequacy: full },
  );
  assert.equal(completed.status, 'complete');
});

function onlySearchToolExecutions() {
  return [
    {
      toolName: 'web_search',
      ok: true,
      evidenceSource: 'search',
      evidenceRelevant: true,
      summary: 'search hits for AnoleX 3030-Evo Max',
      input: { query: 'AnoleX 3030-Evo Max specs' },
    },
  ];
}

test('pending direct-answer drafts enter the loop without phrase matching', () => {
  const explicitPending = normalizeTaskAnalysis({
    mode: 'direct_answer',
    draft_reply: 'I will investigate and report back.',
    draft_status: 'needs_execution',
    verification_need: 'none',
    freshness_risk: 'none',
  });
  assert.equal(explicitPending.mode, 'execute');
  assert.equal(isDirectAnswerEligibleAnalysis(explicitPending), false);

  const missingStatus = normalizeTaskAnalysis({
    mode: 'direct_answer',
    draft_reply: 'A draft with no structured terminal state.',
    verification_need: 'none',
    freshness_risk: 'none',
  });
  assert.equal(missingStatus.mode, 'execute');
  assert.equal(isDirectAnswerEligibleAnalysis(missingStatus), false);
});

test('unsafe verifier output cannot pass through unchanged', () => {
  const rejected = normalizeVerificationResult({
    status: 'insufficient_evidence',
    missing_evidence: ['No source supports the third device.'],
    final_reply: 'All three devices are definitely excellent.',
    safe_to_deliver: false,
  }, 'All three devices are definitely excellent.');
  assert.equal(rejected.safe_to_deliver, false);
  assert.equal(rejected.final_reply, '');

  const safePartial = normalizeVerificationResult({
    status: 'insufficient_evidence',
    missing_evidence: ['No source supports the third device.'],
    final_reply: 'I verified two devices; the third model is still unidentified.',
    safe_to_deliver: true,
  });
  assert.equal(safePartial.safe_to_deliver, true);
  assert.match(safePartial.final_reply, /verified two devices/);
});

test('research evidence keeps stable global ids beyond the recent-tool window', () => {
  const analysis = normalizeTaskAnalysis({
    mode: 'plan_execute',
    research_targets: ['Target Alpha'],
    research_depth: 'deep',
    verification_need: 'required',
    freshness_risk: 'possible',
  });
  const toolExecutions = Array.from({ length: 15 }, (_, index) => ({
    toolName: 'browser_navigate',
    ok: true,
    evidenceSource: 'browser',
    evidenceRelevant: true,
    summary: index === 0 ? 'Primary source for Target Alpha' : `Later evidence ${index + 1}`,
    input: { url: `https://example.test/source-${index + 1}` },
  }));
  const catalog = summarizeResearchEvidenceCatalog(toolExecutions);
  assert.match(catalog, /^E1\./);
  assert.match(catalog, /E15\./);

  const adequacy = assessResearchAdequacy({ analysis, toolExecutions });
  const decision = normalizeCompletionDecision({
    status: 'complete',
    reason: 'Target Alpha is supported.',
    research_review: {
      required: true,
      adequate: true,
      target_coverage: [
        { target: 'Target Alpha', support: 'primary', evidence_indexes: [1] },
      ],
    },
  });
  assert.equal(
    enforceTerminalReplyDecision(
      decision,
      'Evidence-backed result.',
      { analysis, toolExecutions, researchAdequacy: adequacy },
    ).status,
    'complete',
  );
});

test('deep research without named targets still requires primary overall support', () => {
  const analysis = normalizeTaskAnalysis({
    mode: 'plan_execute',
    research_depth: 'deep',
    verification_need: 'required',
    freshness_risk: 'possible',
  });
  const toolExecutions = [
    {
      toolName: 'browser_navigate',
      ok: true,
      evidenceSource: 'browser',
      evidenceRelevant: true,
      summary: 'Opened an authoritative primary document.',
      input: { url: 'https://example.test/primary-document' },
    },
  ];
  const researchAdequacy = assessResearchAdequacy({ analysis, toolExecutions });
  const secondaryOnly = normalizeCompletionDecision({
    status: 'complete',
    research_review: {
      required: true,
      adequate: true,
      overall_support: 'secondary',
      evidence_indexes: [1],
    },
  });
  assert.equal(
    enforceTerminalReplyDecision(
      secondaryOnly,
      'Research result.',
      { analysis, toolExecutions, researchAdequacy },
    ).status,
    'continue',
  );

  const primary = normalizeCompletionDecision({
    status: 'complete',
    research_review: {
      required: true,
      adequate: true,
      overall_support: 'primary',
      evidence_indexes: [1],
    },
  });
  assert.equal(
    enforceTerminalReplyDecision(
      primary,
      'Research result.',
      { analysis, toolExecutions, researchAdequacy },
    ).status,
    'complete',
  );
});
