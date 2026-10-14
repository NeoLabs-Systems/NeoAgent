'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  normalizeOutgoingMessage,
  clampRunContext,
  buildProgressUpdatePrompt,
  buildWrapUpPrompt,
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

test('the wrap-up prompt names the real stop reason and forbids tools and invention', () => {
  const prompt = buildWrapUpPrompt('no_progress', 'whatsapp');
  assert.match(prompt, /changed nothing and found nothing new/);
  assert.match(prompt, /do not call any tools/);
  assert.match(prompt, /Never invent results/);
  assert.doesNotMatch(prompt, /step limit/);
});

test('progress update prompt forbids claiming changes from read-only evidence', () => {
  const prompt = buildProgressUpdatePrompt();

  assert.match(prompt, /only if the actual recent tool activity/);
  assert.match(prompt, /output an empty string/);
  assert.match(prompt, /only shows inspection or failed commands/);
  assert.match(prompt, /do not imply state-changing progress/);
  assert.match(prompt, /internal status/);
});
