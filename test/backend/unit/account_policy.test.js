'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  MIN_PASSWORD_SCORE,
  evaluatePasswordStrength,
  passwordStrengthError,
} = require('../../../server/services/account/password_policy');
const {
  isValidEmail,
  normalizeEmail,
  requireValidEmail,
} = require('../../../server/services/account/email');

test('password policy rejects weak, common, sequential, and personal-info passwords', () => {
  assert.equal(evaluatePasswordStrength('short').isAcceptable, false);
  assert.equal(evaluatePasswordStrength('password123').isAcceptable, false);
  assert.equal(evaluatePasswordStrength('abcd1234').isAcceptable, false);
  assert.equal(
    evaluatePasswordStrength('NeoUser2026!', { username: 'neouser', email: 'neo@example.com' }).isAcceptable,
    false,
  );
});

test('password policy accepts strong passwords and clamps score', () => {
  const result = evaluatePasswordStrength('CorrectHorse9!Battery');
  assert.equal(result.isAcceptable, true);
  assert.ok(result.score >= MIN_PASSWORD_SCORE);
  assert.ok(result.score <= 4);
  assert.ok(evaluatePasswordStrength('').score >= 0);
});

test('passwordStrengthError returns first feedback item', () => {
  const result = evaluatePasswordStrength('short');
  assert.match(passwordStrengthError(result), /Use at least 8 characters/);
});

test('email helpers normalize, accept, and reject expected values', () => {
  assert.equal(normalizeEmail('  USER+tag@Sub.Example.COM  '), 'user+tag@sub.example.com');
  assert.equal(isValidEmail('user@example.com'), true);
  assert.equal(isValidEmail('user+tag@sub.example.com'), true);
  assert.equal(isValidEmail('missing-at.example.com'), false);
  assert.equal(isValidEmail('user@example..com'), false);
  assert.equal(isValidEmail(null), false);
  assert.equal(requireValidEmail(' USER@example.COM '), 'user@example.com');
  assert.throws(() => requireValidEmail('bad'), (err) => err.statusCode === 400);
});
