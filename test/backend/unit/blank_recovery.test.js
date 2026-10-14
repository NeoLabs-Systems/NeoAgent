'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { buildBlankOutputGuidance } = require('../../../server/services/ai/loop/blank_recovery');

test('blank turn guidance names the latest failed tool', () => {
  const guidance = buildBlankOutputGuidance([
    { toolName: 'web_search', ok: false, error: 'rate limited' },
    { toolName: 'read_file', ok: false, error: 'EISDIR: illegal operation on a directory, read' },
    { toolName: 'think', ok: true },
  ]);
  assert.match(guidance, /"read_file" failed with: EISDIR/);
  assert.match(guidance, /task is not terminal/);
});

test('blank turn guidance without a failure asks for the next concrete action', () => {
  const guidance = buildBlankOutputGuidance([{ toolName: 'web_search', ok: true }]);
  assert.doesNotMatch(guidance, /failed with/);
  assert.match(guidance, /Take the next concrete action now/);
});
