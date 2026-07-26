'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  isDirectAnswerEligibleAnalysis,
  normalizeTaskAnalysis,
} = require('../../../server/services/ai/taskAnalysis');
const {
  enforceTerminalReplyDecision,
  enforceChurnAssessment,
  normalizeCompletionDecision,
} = require('../../../server/services/ai/loop/completion_judge');
const {
  assessResearchAdequacy,
} = require('../../../server/services/ai/toolEvidence');

test('incomplete research cannot complete while structured blockers can stop', () => {
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
  const researchAdequacy = assessResearchAdequacy({ analysis, toolExecutions });
  assert.equal(researchAdequacy.structurallyReady, true);
  assert.equal(researchAdequacy.semanticReviewRequired, true);

  assert.deepEqual(
    enforceTerminalReplyDecision(
      { status: 'complete', reason: 'Looks done.' },
      'Both machines look solid.',
      { analysis, toolExecutions, researchAdequacy },
    ).status,
    'continue',
  );

  assert.equal(
    enforceChurnAssessment(
      {
        assessment: 'blocked',
        reason: 'The user must identify the third device.',
        blocker_kind: 'user_input',
        resolvable_in_run: false,
      },
      { analysis, toolExecutions, researchAdequacy },
    ).assessment,
    'blocked',
  );
  assert.equal(
    enforceTerminalReplyDecision(
      normalizeCompletionDecision({
        status: 'blocked',
        reason: 'The user must identify the third device.',
        blocker_review: {
          kind: 'user_input',
          resolvable_in_run: false,
          required_value: 'The exact third device model',
        },
      }),
      'Which exact third device do you mean?',
      { analysis, toolExecutions, researchAdequacy },
    ).status,
    'blocked',
  );
});

test('named research targets cannot fast-path as direct answers', () => {
  const analysis = normalizeTaskAnalysis({
    mode: 'direct_answer',
    draft_reply: 'They all look fine.',
    draft_status: 'final',
    goal: 'Look into three CNC machines',
    research_targets: ['AnoleX 3030-Evo Max', 'Genmitsu 3018 Pro', 'SainSmart 3018'],
    verification_need: 'none',
    freshness_risk: 'none',
  });
  assert.equal(analysis.mode, 'plan_execute');
  assert.equal(isDirectAnswerEligibleAnalysis(analysis), false);
});

test('simple direct answers remain eligible without research burden', () => {
  const analysis = normalizeTaskAnalysis({
    mode: 'direct_answer',
    draft_reply: 'The answer is 42.',
    draft_status: 'final',
    goal: 'quick answer',
    verification_need: 'none',
    freshness_risk: 'none',
    complexity: 'simple',
    autonomy_level: 'minimal',
  });
  assert.equal(isDirectAnswerEligibleAnalysis(analysis), true);
});
