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
} = require('../../../server/services/ai/loop/completion_judge');
const {
  isDeferredWorkReply,
  isTerminalQuestionOrBlockerReply,
} = require('../../../server/services/ai/terminal_reply');
const {
  assessResearchAdequacy,
} = require('../../../server/services/ai/toolEvidence');

test('terminal_reply helpers stay free of phrase-based filtering', () => {
  assert.equal(isDeferredWorkReply("I'm working on that."), false);
  assert.equal(isDeferredWorkReply('The tests pass.'), false);
  assert.equal(isTerminalQuestionOrBlockerReply('Which three devices?'), false);
  assert.equal(isTerminalQuestionOrBlockerReply('Blocked without the API key.'), false);
});

test('incomplete research still cannot complete even without phrase filters', () => {
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
  assert.equal(researchAdequacy.adequate, false);

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
      { assessment: 'blocked', reason: 'stuck' },
      { analysis, toolExecutions, researchAdequacy },
    ).assessment,
    'progressing',
  );
});

test('named research targets cannot fast-path as direct answers', () => {
  const analysis = normalizeTaskAnalysis({
    mode: 'direct_answer',
    draft_reply: 'They all look fine.',
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
    goal: 'quick answer',
    verification_need: 'none',
    freshness_risk: 'none',
    complexity: 'simple',
    autonomy_level: 'minimal',
  });
  assert.equal(isDirectAnswerEligibleAnalysis(analysis), true);
});
