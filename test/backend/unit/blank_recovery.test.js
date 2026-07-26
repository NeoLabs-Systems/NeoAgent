'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  shouldContinueAfterRecoverableToolFailure,
  shouldContinueAfterBlankToolFailure,
  buildBlankAfterToolFailureGuidance,
} = require('../../../server/services/ai/loop/blank_recovery');

test('recoverable tool failure continues on poke-style fallback wording', () => {
  const toolExecutions = [{
    toolName: 'read_file',
    ok: false,
    error: 'Failed to read file for user 1: ENOENT: no such file or directory',
  }];

  assert.equal(
    shouldContinueAfterRecoverableToolFailure({
      lastContent: 'hit an internal tool issue while checking that, so no verified answer yet.',
      remainingIterations: 3,
      toolExecutions,
    }),
    true,
  );

  assert.equal(
    shouldContinueAfterRecoverableToolFailure({
      lastContent: 'got partway through, but no finished result yet.',
      remainingIterations: 2,
      toolExecutions,
    }),
    true,
  );
});

test('blank after tool failure continues while budget remains', () => {
  const toolExecutions = [{
    toolName: 'web_search',
    ok: false,
    error: 'timeout',
  }];
  assert.equal(
    shouldContinueAfterBlankToolFailure({
      lastContent: '',
      failedStepCount: 1,
      remainingIterations: 2,
      toolExecutions,
    }),
    true,
  );
  assert.match(
    buildBlankAfterToolFailureGuidance(toolExecutions),
    /next safe recovery action now/i,
  );
});
