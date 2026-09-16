'use strict';

const bcrypt = require('bcrypt');
const db = require('../../db/database');
const { evaluatePasswordStrength, passwordStrengthError } = require('./password_policy');

const BCRYPT_ROUNDS = 12;

/**
 * Create the first account on an install that has none.
 *
 * Signing up normally goes through the HTTP route, which also handles the
 * registration policy and email confirmation. Neither applies to the first
 * account on a fresh install -- there is no one to confirm with and nothing to
 * gate -- so headless setups (a container, a CI job, a fresh self-host) have no
 * way in without this. It refuses once any account exists, so it cannot be used
 * to add hidden accounts to a running install.
 */
function provisionFirstAccount({ username, password }) {
  const name = String(username || '').trim();
  if (!name) {
    throw new Error('A username is required.');
  }
  const strength = evaluatePasswordStrength(password, { username: name });
  if (!strength.isAcceptable) {
    throw new Error(passwordStrengthError(strength));
  }

  const hash = bcrypt.hashSync(password, BCRYPT_ROUNDS);
  return db.transaction(() => {
    const { count } = db.prepare('SELECT COUNT(*) AS count FROM users').get();
    if (count > 0) {
      throw new Error(
        'This install already has an account. Sign in, or use the web interface to add another.',
      );
    }
    const result = db
      .prepare('INSERT INTO users (username, password, email_verified_at) '
        + "VALUES (?, ?, datetime('now'))")
      .run(name, hash);
    return { id: result.lastInsertRowid, username: name };
  })();
}

module.exports = { provisionFirstAccount };
