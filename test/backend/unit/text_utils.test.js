'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  asObject,
  normalizeStoredString,
  parseJsonObject,
  parseMaybeJson,
  requireText,
  toOptionalString,
  trimText,
} = require('../../../server/utils/text');

test('trimText and requireText normalize empty input', () => {
  assert.equal(trimText('  hello  '), 'hello');
  assert.equal(requireText('  ok  ', 'name'), 'ok');
  assert.throws(() => requireText('  ', 'name'), /name is required/);
});

test('asObject rejects arrays and scalars', () => {
  assert.deepEqual(asObject({ a: 1 }), { a: 1 });
  assert.deepEqual(asObject([1]), {});
  assert.deepEqual(asObject('x', { fallback: true }), { fallback: true });
});

test('toOptionalString trims and clamps', () => {
  assert.equal(toOptionalString(null), '');
  assert.equal(toOptionalString('  hi  '), 'hi');
  assert.equal(toOptionalString('abcdef', 3), 'abc');
});

test('parseMaybeJson and parseJsonObject tolerate bad input', () => {
  assert.deepEqual(parseMaybeJson(Buffer.from('{"a":1}')), { a: 1 });
  assert.equal(parseMaybeJson(Buffer.from('nope'), 'fallback'), 'fallback');
  assert.deepEqual(parseJsonObject(Buffer.from('{"a":1}')), { a: 1 });
  assert.deepEqual(parseJsonObject('nope', { ok: false }), { ok: false });
  assert.deepEqual(parseJsonObject([1, 2], { ok: true }), { ok: true });
  assert.deepEqual(parseJsonObject({ a: 1 }), { a: 1 });
  const fallback = { ok: false };
  const parsed = parseJsonObject('[]', fallback);
  assert.deepEqual(parsed, { ok: false });
  parsed.ok = true;
  assert.equal(fallback.ok, false);
});

test('normalizeStoredString keeps numeric ids and unwraps JSON strings', () => {
  assert.equal(normalizeStoredString('1549742688482623558'), '1549742688482623558');
  assert.equal(normalizeStoredString('"discord"'), 'discord');
  assert.equal(normalizeStoredString('"-1001234567890"'), '-1001234567890');
  assert.equal(normalizeStoredString('null'), '');
  assert.equal(normalizeStoredString('{"a":1}'), '');
});
