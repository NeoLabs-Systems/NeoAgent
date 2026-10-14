'use strict';

// One-time sign-up keys. While open sign-up is off (NEOAGENT_ALLOW_SIGNUP=false)
// a new account needs one of these; the first account on a fresh install never
// does. Admins create them singly or in batches and hand them out however they
// like, so the code stays readable: twelve Crockford base32 characters
// (60 bits), shown as XXXX-XXXX-XXXX. Codes are kept as written so admins can
// export the unused ones again later.

const crypto = require('crypto');
const db = require('../../db/database');
const { getDeploymentPolicy } = require('../../utils/deployment');
const { httpError } = require('../../utils/http_error');
const { recordAccessEvent } = require('./audit');

const CODE_ALPHABET = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
const CODE_LENGTH = 12;
const GROUP_LENGTH = 4;
const MAX_BATCH = 500;
const MAX_LABEL_LENGTH = 80;

function generateCode() {
  let code = '';
  for (let index = 0; index < CODE_LENGTH; index += 1) {
    code += CODE_ALPHABET[crypto.randomInt(CODE_ALPHABET.length)];
  }
  return code;
}

function formatCode(code) {
  return code.match(new RegExp(`.{1,${GROUP_LENGTH}}`, 'g')).join('-');
}

// Accepts a key however it was typed or pasted: any case, with or without
// dashes and spaces, and with the letters Crockford base32 reads as digits.
function normalizeCode(raw) {
  const code = String(raw || '')
    .toUpperCase()
    .replace(/[\s-]+/g, '')
    .replace(/O/g, '0')
    .replace(/[IL]/g, '1');
  if (code.length !== CODE_LENGTH) return '';
  for (const char of code) {
    if (!CODE_ALPHABET.includes(char)) return '';
  }
  return code;
}

function keyStatus(row) {
  if (row.revoked_at) return 'revoked';
  if (row.used_at) return 'used';
  return 'unused';
}

function serializeKey(row) {
  return {
    id: row.id,
    code: formatCode(row.code),
    label: row.label,
    status: keyStatus(row),
    createdAt: row.created_at,
    createdBy: row.creator_username ?? null,
    usedAt: row.used_at,
    usedBy: row.used_by_user_id == null
      ? null
      : { id: row.used_by_user_id, username: row.used_by_username },
    revokedAt: row.revoked_at,
  };
}

// Whether a new account needs a key right now.
function isSignupKeyRequired() {
  const { count } = db.prepare('SELECT COUNT(*) AS count FROM users').get();
  return count > 0 && getDeploymentPolicy().signupKeyRequired;
}

/**
 * The normalized code of a key that can still be redeemed. Throws the error a
 * sign-up form shows otherwise. Runs before the account form opens and again
 * inside the transaction that creates the account.
 */
function assertSignupKeyUsable(raw) {
  const code = normalizeCode(raw);
  if (!String(raw || '').trim()) {
    throw httpError(403, 'A sign-up key is required to create an account.', 'SIGNUP_KEY_REQUIRED');
  }
  const row = code ? db.prepare('SELECT * FROM signup_keys WHERE code = ?').get(code) : null;
  if (!row || row.revoked_at) {
    throw httpError(403, 'That sign-up key isn’t valid.', 'SIGNUP_KEY_INVALID');
  }
  if (row.used_at) {
    throw httpError(403, 'That sign-up key has already been used.', 'SIGNUP_KEY_USED');
  }
  return code;
}

/**
 * Spends the key on the account just inserted, when the server needs one.
 * Call inside the transaction that creates the account, after the insert, so a
 * rejected key rolls the account back.
 */
function redeemSignupKeyForNewUser(raw, userId) {
  const { count } = db.prepare('SELECT COUNT(*) AS count FROM users WHERE id <> ?').get(userId);
  if (count === 0 || !getDeploymentPolicy().signupKeyRequired) return;
  const code = assertSignupKeyUsable(raw);
  const claimed = db.prepare(`
    UPDATE signup_keys SET used_at = datetime('now'), used_by_user_id = ?
    WHERE code = ? AND used_at IS NULL AND revoked_at IS NULL
  `).run(userId, code);
  if (claimed.changes === 0) {
    throw httpError(403, 'That sign-up key has already been used.', 'SIGNUP_KEY_USED');
  }
}

// Gives the key back when the account it created is removed before it was
// ever usable (the confirmation email could not be sent).
function releaseSignupKey(userId) {
  db.prepare(`
    UPDATE signup_keys SET used_at = NULL, used_by_user_id = NULL WHERE used_by_user_id = ?
  `).run(userId);
}

// --- Admin ---

function listSignupKeys() {
  const rows = db.prepare(`
    SELECT keys.*, creator.username AS creator_username, redeemer.username AS used_by_username
    FROM signup_keys keys
    LEFT JOIN users creator ON creator.id = keys.created_by_user_id
    LEFT JOIN users redeemer ON redeemer.id = keys.used_by_user_id
    ORDER BY keys.created_at DESC, keys.id DESC
  `).all();
  return { keys: rows.map(serializeKey) };
}

function createSignupKeys(actorUserId, { count, label } = {}) {
  if (!Number.isInteger(count) || count < 1 || count > MAX_BATCH) {
    throw httpError(400, `count must be a whole number from 1 to ${MAX_BATCH}.`, 'SIGNUP_KEY_COUNT_INVALID');
  }
  const cleanLabel = String(label ?? '').trim().slice(0, MAX_LABEL_LENGTH);
  const insert = db.prepare(`
    INSERT OR IGNORE INTO signup_keys (code, label, created_by_user_id) VALUES (?, ?, ?)
  `);
  const ids = db.transaction(() => {
    const created = [];
    // A collision is vanishingly rare at 60 bits; draw again if one happens.
    while (created.length < count) {
      const result = insert.run(generateCode(), cleanLabel, actorUserId);
      if (result.changes === 1) created.push(Number(result.lastInsertRowid));
    }
    recordAccessEvent('signup_keys.create', {
      actorUserId,
      detail: { count, label: cleanLabel },
    });
    return created;
  })();
  const rows = db.prepare(`
    SELECT keys.*, creator.username AS creator_username
    FROM signup_keys keys
    LEFT JOIN users creator ON creator.id = keys.created_by_user_id
    WHERE keys.id IN (${ids.map(() => '?').join(', ')})
    ORDER BY keys.id
  `).all(...ids);
  return { keys: rows.map(serializeKey) };
}

function revokeSignupKey(actorUserId, keyId) {
  const result = db.prepare(`
    UPDATE signup_keys SET revoked_at = datetime('now')
    WHERE id = ? AND used_at IS NULL AND revoked_at IS NULL
  `).run(keyId);
  if (result.changes === 0) {
    throw httpError(404, 'No unused sign-up key with that id.', 'SIGNUP_KEY_NOT_FOUND');
  }
  recordAccessEvent('signup_keys.revoke', { actorUserId, detail: { keyId } });
  return { ok: true };
}

module.exports = {
  assertSignupKeyUsable,
  createSignupKeys,
  isSignupKeyRequired,
  listSignupKeys,
  redeemSignupKeyForNewUser,
  releaseSignupKey,
  revokeSignupKey,
};
