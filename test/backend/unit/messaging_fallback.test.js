'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  normalizeOutgoingMessage,
  clampRunContext,
  joinSentMessages,
  buildBlankMessagingReplyPrompt,
  toolWorkDescription,
  summarizeRecentWork,
  hasFailureSignal,
  extractToolFailureMessage,
  buildDeterministicMessagingFallback,
  buildMessagingFailureScenario,
  buildDeterministicMessagingErrorReply,
  buildModelFailureLoopPrompt,
} = require('../../../server/services/ai/messagingFallback');

test('normalizeOutgoingMessage collapses whitespace by default and can preserve it', () => {
  assert.equal(normalizeOutgoingMessage('  hello\n\n  world  '), 'hello world');
  assert.equal(
    normalizeOutgoingMessage('a\n\nb', null, { collapseWhitespace: false }),
    'a\n\nb',
  );
});

test('clampRunContext truncates with ellipsis past the limit', () => {
  assert.equal(clampRunContext('', 10), '');
  assert.equal(clampRunContext('short', 10), 'short');
  assert.equal(clampRunContext('abcdefghijkl', 4), 'abcd...');
});

test('joinSentMessages joins non-empty trimmed entries with blank lines', () => {
  assert.equal(joinSentMessages(['a', '', '  b  ']), 'a\n\nb');
  assert.equal(joinSentMessages('not-an-array'), '');
});

test('buildBlankMessagingReplyPrompt escalates wording on retry', () => {
  const first = buildBlankMessagingReplyPrompt(1);
  const second = buildBlankMessagingReplyPrompt(2);
  assert.match(first, /one non-empty reply/);
  assert.match(second, /previous reply was empty/);
});

test('toolWorkDescription maps tool names to human phrases', () => {
  assert.equal(toolWorkDescription('execute_command'), 'ran shell commands');
  assert.equal(toolWorkDescription('read_file'), 'checked files');
  assert.equal(toolWorkDescription('browser_navigate'), 'checked the browser state');
  assert.equal(toolWorkDescription('unknown_tool'), '');
});

test('summarizeRecentWork describes at most two distinct activities', () => {
  assert.equal(summarizeRecentWork([]), '');
  assert.equal(
    summarizeRecentWork([{ toolName: 'execute_command' }]),
    'I ran shell commands',
  );
  assert.equal(
    summarizeRecentWork([{ toolName: 'execute_command' }, { toolName: 'read_file' }]),
    'I ran shell commands and checked files',
  );
});

test('hasFailureSignal detects error vocabulary', () => {
  assert.equal(hasFailureSignal('all good'), false);
  assert.equal(hasFailureSignal('command failed: permission denied'), true);
});

test('extractToolFailureMessage prefers a direct error then parsed summaries', () => {
  assert.equal(extractToolFailureMessage({ error: 'boom' }), 'boom');
  assert.equal(
    extractToolFailureMessage({ summary: JSON.stringify({ status: 'error', message: 'nope' }) }),
    'nope',
  );
  assert.equal(
    extractToolFailureMessage({ summary: JSON.stringify({ status: 'error', exitCode: 2 }) }),
    'The last shell command exited with code 2',
  );
  assert.equal(extractToolFailureMessage({}), '');
});

test('buildDeterministicMessagingFallback narrates work and blockers honestly', () => {
  const both = buildDeterministicMessagingFallback({
    failedStepCount: 1,
    stepIndex: 2,
    toolExecutions: [{ toolName: 'execute_command', error: 'disk full' }],
  });
  assert.match(both, /ran shell commands/);
  assert.match(both, /disk full/);
  assert.match(both, /do not have a confirmed finished result/);

  assert.equal(
    buildDeterministicMessagingFallback({ failedStepCount: 0, stepIndex: 0, toolExecutions: [] }),
    'I could not produce a reliable final reply just now.',
  );
});

test('buildMessagingFailureScenario assembles a structured evidence string', () => {
  const scenario = buildMessagingFailureScenario({
    err: { message: 'kaboom' },
    failedStepCount: 1,
    stepIndex: 3,
    toolExecutions: [{ toolName: 'read_file', error: 'no such file' }],
  });
  assert.match(scenario, /Runtime error: kaboom/);
  assert.match(scenario, /Completed steps before failure: 3/);
  assert.match(scenario, /Failed tool steps: 1/);
});

test('buildDeterministicMessagingErrorReply special-cases provider and timeout errors', () => {
  assert.match(
    buildDeterministicMessagingErrorReply({ err: { message: 'No AI providers are currently available' }, toolExecutions: [] }),
    /no AI provider is available/,
  );
  assert.match(
    buildDeterministicMessagingErrorReply({ err: { message: 'request timed out' }, toolExecutions: [] }),
    /hit a timeout/,
  );
  assert.match(
    buildDeterministicMessagingErrorReply({ err: { message: '' }, toolExecutions: [{ error: 'blocked here' }] }),
    /blocked while checking this: blocked here/,
  );
});

test('buildModelFailureLoopPrompt instructs autonomous recovery on the next model', () => {
  const prompt = buildModelFailureLoopPrompt({
    failedModel: 'model-a',
    nextModel: 'model-b',
    errorMessage: 'overloaded',
  });
  assert.match(prompt, /"model-a" failed with: overloaded/);
  assert.match(prompt, /Continue on "model-b"/);
});
