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

test('reasoning written as tags never reaches the reply, closed or not', () => {
  const { sanitizeModelOutput } = require('../../../server/services/ai/outputSanitizer');
  assert.equal(sanitizeModelOutput('<think>plan it</think>Hallo.'), 'Hallo.');
  assert.equal(sanitizeModelOutput('Hallo.<think>a stream cut off mid thought'), 'Hallo.');
  assert.equal(sanitizeModelOutput('the template dropped the opening tag</think>Hallo.'), 'Hallo.');
  assert.equal(sanitizeModelOutput('Ein Satz über <b>HTML</b>.'), 'Ein Satz über <b>HTML</b>.');
});
