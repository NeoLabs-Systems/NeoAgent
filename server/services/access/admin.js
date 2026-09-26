'use strict';

// Admin is a flag on the account row, read fresh on every request, so granting
// or revoking it takes effect immediately. The first account on an install is
// promoted by a schema trigger; every later change goes through grantAdmin() /
// revokeAdmin(), driven by the operator (the `neoagent admin` CLI or the
// NEOAGENT_ADMIN_USERS env list), never from inside the app.

const db = require('../../db/database');
const { recordAccessEvent } = require('./audit');

const ADMIN_USERS_ENV_KEY = 'NEOAGENT_ADMIN_USERS';

function isAdminUser(userId) {
  const row = db.prepare('SELECT is_admin FROM users WHERE id = ?').get(userId);
  return Number(row?.is_admin) === 1;
}

function listAdmins() {
  return db.prepare('SELECT id, username FROM users WHERE is_admin = 1 ORDER BY id').all();
}

function findAccount(username) {
  const name = String(username || '').trim();
  const user = db.prepare('SELECT id, username, is_admin FROM users WHERE username = ?').get(name);
  if (!user) {
    const error = new Error(`No account named "${name}".`);
    error.code = 'NOT_FOUND';
    throw error;
  }
  return user;
}

function grantAdmin(username, { source }) {
  const user = findAccount(username);
  if (Number(user.is_admin) === 1) return { username: user.username, changed: false };
  db.transaction(() => {
    db.prepare('UPDATE users SET is_admin = 1 WHERE id = ?').run(user.id);
    recordAccessEvent('admin.grant', { subjectUserId: user.id, detail: { source } });
  })();
  return { username: user.username, changed: true };
}

function revokeAdmin(username, { source }) {
  const user = findAccount(username);
  if (Number(user.is_admin) !== 1) return { username: user.username, changed: false };
  db.transaction(() => {
    db.prepare('UPDATE users SET is_admin = 0 WHERE id = ?').run(user.id);
    recordAccessEvent('admin.revoke', { subjectUserId: user.id, detail: { source } });
  })();
  return { username: user.username, changed: true };
}

function envAdminUsernames(env = process.env) {
  return String(env[ADMIN_USERS_ENV_KEY] || '')
    .split(',')
    .map((name) => name.trim())
    .filter(Boolean);
}

// A name in NEOAGENT_ADMIN_USERS with no account behind it would hand admin to
// whoever registers it before the next start, so nobody may take it.
function isReservedAdminUsername(username, env = process.env) {
  const name = String(username || '').trim();
  if (!envAdminUsernames(env).includes(name)) return false;
  return !db.prepare('SELECT 1 FROM users WHERE username = ?').get(name);
}

function wasRevokedByOperator(userId) {
  const last = db.prepare(`
    SELECT action FROM access_audit_log
    WHERE subject_user_id = ? AND action IN ('admin.grant', 'admin.revoke')
    ORDER BY id DESC LIMIT 1
  `).get(userId);
  return last?.action === 'admin.revoke';
}

/**
 * Grants admin to every username listed in NEOAGENT_ADMIN_USERS. Additive only:
 * removing a name from the list does not revoke it (use `neoagent admin revoke`),
 * and an account the operator revoked stays revoked until granted with the CLI.
 */
function applyEnvAdminGrants(env = process.env) {
  const granted = [];
  const missing = [];
  const revoked = [];
  for (const name of envAdminUsernames(env)) {
    const user = db.prepare('SELECT id, is_admin FROM users WHERE username = ?').get(name);
    if (!user) {
      missing.push(name);
    } else if (Number(user.is_admin) !== 1 && wasRevokedByOperator(user.id)) {
      revoked.push(name);
    } else if (grantAdmin(name, { source: 'env' }).changed) {
      granted.push(name);
    }
  }
  return { granted, missing, revoked };
}

// True when accounts exist but none of them can open the admin page -- an
// install that predates per-account admin. Startup and the CLI surface a hint.
function needsAdminGrant() {
  const row = db.prepare(`
    SELECT COUNT(*) AS accounts, COALESCE(SUM(is_admin), 0) AS admins FROM users
  `).get();
  return row.accounts > 0 && row.admins === 0;
}

module.exports = {
  isAdminUser,
  listAdmins,
  grantAdmin,
  revokeAdmin,
  applyEnvAdminGrants,
  isReservedAdminUsername,
  needsAdminGrant,
};
