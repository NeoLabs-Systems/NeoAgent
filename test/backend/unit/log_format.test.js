'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { shortenRunId, summarizeForLog, parseMaybeJson } = require('../../../server/services/ai/logFormat');

test('shortenRunId truncates to 8 chars and handles empties', () => {
  assert.equal(shortenRunId('abcdefghijkl'), 'abcdefgh');
  assert.equal(shortenRunId('short'), 'short');
  assert.equal(shortenRunId(''), 'unknown');
  assert.equal(shortenRunId(null), 'unknown');
});

test('summarizeForLog collapses whitespace and clamps with ellipsis', () => {
  assert.equal(summarizeForLog(null), '');
  assert.equal(summarizeForLog('  a\n\t b  '), 'a b');
  assert.equal(summarizeForLog('abcdef', 3), 'abc...');
  assert.equal(summarizeForLog({ a: 1 }), '{"a":1}');
});

test('summarizeForLog falls back to String() when JSON.stringify throws', () => {
  const circular = {};
  circular.self = circular;
  assert.equal(summarizeForLog(circular), '[object Object]');
});

test('parseMaybeJson returns objects as-is, parses strings, and falls back', () => {
  const obj = { x: 1 };
  assert.equal(parseMaybeJson(obj), obj);
  assert.deepEqual(parseMaybeJson('{"y":2}'), { y: 2 });
  assert.equal(parseMaybeJson('not json', 'fallback'), 'fallback');
  assert.equal(parseMaybeJson('', 'fallback'), 'fallback');
  assert.equal(parseMaybeJson(null), null);
});
