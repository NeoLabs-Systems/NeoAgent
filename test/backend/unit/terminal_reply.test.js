'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { isDirectAnswerEligibleAnalysis } = require('../../../server/services/ai/taskAnalysis');
const {
  enforceTerminalReplyDecision,
} = require('../../../server/services/ai/loop/completion_judge');
const {
  isDeferredWorkReply,
  isTerminalQuestionOrBlockerReply,
} = require('../../../server/services/ai/terminal_reply');

test('detects progress-only replies that must not terminate a run', () => {
  const deferred = [
    "I'm working on that.",
    'I am still checking the logs.',
    "Sure, I'll investigate and get back to you.",
    'Let me run the tests.',
    'Give me a moment.',
    'Working on it…',
    "I’ll update you once I know more.",
    'Ich prüfe gerade die Logs.',
    'Lass mich das testen.',
    'Gib mir einen Moment.',
    'Ich melde mich, sobald ich mehr weiß.',
  ];

  for (const reply of deferred) {
    assert.equal(isDeferredWorkReply(reply), true, reply);
  }
});

test('does not confuse concrete answers or real blockers with progress-only replies', () => {
  const terminal = [
    'The tests pass and the fix is in server.js.',
    "I couldn't continue because your API key is missing. Please provide it.",
    "I'm working on a novel about Berlin.",
    'I’ll remind you tomorrow at 09:00.',
  ];

  for (const reply of terminal) {
    assert.equal(isDeferredWorkReply(reply), false, reply);
  }
});

test('detects questions and explicit blockers that must wait for the user', () => {
  const terminal = [
    'Which three devices do you mean?',
    'Welche drei Geräte meinst du genau? Wir hatten gerade nur die AnoleX besprochen.',
    'Bitte nenn mir die zwei anderen Modelle, dann kann ich sie vergleichen.',
    "I can't continue because the API key is missing.",
  ];

  for (const reply of terminal) {
    assert.equal(isTerminalQuestionOrBlockerReply(reply), true, reply);
  }
});

test('completion decisions cannot mark a progress-only reply complete or blocked', () => {
  assert.deepEqual(
    enforceTerminalReplyDecision(
      { status: 'complete', reason: 'Looks done.' },
      "I'm working on that and will update you.",
    ),
    {
      status: 'continue',
      reason: 'The latest reply only announces or promises unfinished work; the run must continue or return a concrete blocker.',
    },
  );
  assert.deepEqual(
    enforceTerminalReplyDecision(
      { status: 'blocked', reason: 'Need a minute.' },
      'Give me a moment.',
    ).status,
    'continue',
  );
});

test('completion decisions cannot loop after a user-facing clarification', () => {
  assert.deepEqual(
    enforceTerminalReplyDecision(
      { status: 'continue', reason: '' },
      'Welche drei Geräte meinst du genau? Wir hatten gerade nur die AnoleX besprochen.',
    ),
    {
      status: 'blocked',
      reason: 'The latest reply asks for user input or states a concrete blocker, so the run must wait instead of repeating it.',
    },
  );
});

test('task analysis cannot fast-path a deferred-work draft as a direct answer', () => {
  const analysis = {
    mode: 'direct_answer',
    verification_need: 'none',
    freshness_risk: 'none',
    planning_depth: 'none',
    needs_subagents: false,
    draft_reply: "I'll check that now.",
  };
  assert.equal(isDirectAnswerEligibleAnalysis(analysis), false);
  assert.equal(
    isDirectAnswerEligibleAnalysis({ ...analysis, draft_reply: 'The answer is 42.' }),
    true,
  );
});
