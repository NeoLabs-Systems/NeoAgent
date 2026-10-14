'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { sanitizeModelOutput } = require('../../../server/services/ai/outputSanitizer');

test('sanitizeModelOutput removes closed thought blocks and keeps the reply', () => {
  const text = '<think>private reasoning</think>\n\nThe answer is 42.';
  assert.equal(sanitizeModelOutput(text), 'The answer is 42.');
});

test('sanitizeModelOutput removes thinking blocks without touching the reply', () => {
  const text = 'Before\n<thinking>step one</thinking>\nAfter';
  assert.equal(sanitizeModelOutput(text), 'Before\n\nAfter');
});

test('sanitizeModelOutput leaves ordinary replies unchanged', () => {
  const text = 'No thought tags here.';
  assert.equal(sanitizeModelOutput(text), text);
});
