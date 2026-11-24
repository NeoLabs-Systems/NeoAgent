'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { coerceToolArgs, missingRequiredArgs } = require('../../../server/services/ai/tools/coerce_args');

const schema = {
  type: 'object',
  properties: {
    max_results: { type: 'integer' },
    ratio: { type: 'number' },
    include_all_day: { type: 'boolean' },
    names: { type: 'array', items: { type: 'string' } },
    trigger: { type: 'object', properties: { mode: { type: 'string', enum: ['recurring', 'one_time'] }, minutes: { type: 'integer' } } },
    connection_id: { type: ['integer', 'string'] },
    label: { type: 'string' },
  },
};

test('near misses of the declared type are fixed before a call runs', () => {
  assert.deepEqual(coerceToolArgs({
    max_results: '5.0',
    ratio: '0.5',
    include_all_day: 'TRUE',
    names: '["a","b"]',
    trigger: { mode: 'Recurring', minutes: '30' },
    label: 42,
  }, schema), {
    max_results: 5,
    ratio: 0.5,
    include_all_day: true,
    names: ['a', 'b'],
    trigger: { mode: 'recurring', minutes: 30 },
    label: '42',
  });
});

test('anything that is not an unambiguous near miss is left for the tool to reject', () => {
  const args = { max_results: '5.5', include_all_day: 'yes', names: 'a, b', trigger: { mode: 'once' }, connection_id: '3', extra: '1' };
  assert.deepEqual(coerceToolArgs(args, schema), args);
  assert.equal(coerceToolArgs(args, null), args, 'no schema, no change');
});

test('the required arguments a call left out are named; an empty value is the tool\'s to judge', () => {
  const schema = { type: 'object', properties: { path: { type: 'string' }, content: { type: 'string' } }, required: ['path', 'content'] };
  assert.deepEqual(missingRequiredArgs({ content: 'x' }, schema), ['path']);
  assert.deepEqual(missingRequiredArgs({ path: null }, schema), ['path', 'content']);
  assert.deepEqual(missingRequiredArgs({ path: 'a.txt', content: '' }, schema), [], 'an empty file is a file');
  assert.deepEqual(missingRequiredArgs({}, { type: 'object', properties: {} }), [], 'nothing required');
  assert.deepEqual(missingRequiredArgs({}, null), [], 'no schema');
});
