'use strict';

// Account identity and password rules shared by sign-up, sign-in and the
// admin password reset. Failures are httpErrors with a stable `code` so
// clients can point at the right field without parsing the English text.

const bcrypt = require('bcrypt');
const db = require('../../db/database');
const { httpError } = require('../../utils/http_error');
const { isReservedAdminUsername } = require('../access/admin');
const {
  MIN_PASSWORD_LENGTH,
  evaluatePasswordStrength,
  passwordStrengthError,
} = require('./password_policy');

const MIN_USERNAME_LENGTH = 3;
const PASSWORD_HASH_ROUNDS = 12;

// Sign-in takes the username or the account email, ignoring case. An exact
// username match wins, so an install that still holds names differing only in
// case signs each of them in as before.
function findUserForSignIn(identifier) {
  const value = String(identifier || '').trim();
  if (!value) return null;
  return db.prepare(`
    SELECT id, username, display_name, email, email_verified_at, password,
           password_login_enabled, created_at, last_login, has_completed_onboarding
    FROM users
    WHERE lower(username) = lower(?) OR lower(email) = lower(?)
    ORDER BY username = ? DESC, lower(username) = lower(?) DESC, id
    LIMIT 1
  `).get(value, value, value, value) || null;
}

function isUsernameTaken(username) {
  return Boolean(db.prepare('SELECT 1 FROM users WHERE lower(username) = lower(?)').get(username));
}

function validateNewUsername(username) {
  if (username.length < MIN_USERNAME_LENGTH) {
    throw httpError(
      400,
      `Username must be at least ${MIN_USERNAME_LENGTH} characters.`,
      'USERNAME_TOO_SHORT',
    );
  }
  if (isReservedAdminUsername(username) || isUsernameTaken(username)) {
    throw httpError(409, 'Username is already taken', 'USERNAME_TAKEN');
  }
}

function assertEmailAvailable(email) {
  if (db.prepare('SELECT 1 FROM users WHERE lower(email) = lower(?)').get(email)) {
    throw httpError(409, 'Email is already in use', 'EMAIL_TAKEN');
  }
}

// `context` carries the account's username/email so the password may not
// contain them.
function validateNewPassword(password, context = {}) {
  const strength = evaluatePasswordStrength(password, context);
  if (!strength.hasMinimumLength) {
    throw httpError(
      400,
      `Password must be at least ${MIN_PASSWORD_LENGTH} characters.`,
      'PASSWORD_TOO_SHORT',
    );
  }
  if (!strength.isAcceptable) {
    throw httpError(400, passwordStrengthError(strength), 'PASSWORD_WEAK');
  }
}

function hashPassword(password) {
  return bcrypt.hash(password, PASSWORD_HASH_ROUNDS);
}

module.exports = {
  assertEmailAvailable,
  findUserForSignIn,
  hashPassword,
  isUsernameTaken,
  validateNewPassword,
  validateNewUsername,
};
