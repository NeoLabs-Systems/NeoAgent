'use strict';

// QR pairing: a signed-in screen mints a short-lived, single-use code; a phone
// scans it (neoagent://pair?server=…&code=…, or the /app/pair web link that
// carries the same code) and swaps it for a session of that account. Only the
// code's SHA-256 is stored.
//
// The other direction (a screen that is not signed in shows a code, a signed-in
// phone approves it) is qr_login.js; the wearable uses that one.

const crypto = require('crypto');
const db = require('../../db/database');
const { httpError } = require('../../utils/http_error');

const LIFETIME_SECONDS = 300;
const MAX_OPEN_CODES = 5;
const DEVICE_LABEL_MAX_LENGTH = 80;

function hashCode(code) {
  return crypto.createHash('sha256').update(String(code)).digest('hex');
}

function cleanDeviceLabel(value) {
  return String(value || '').replace(/\s+/g, ' ').trim().slice(0, DEVICE_LABEL_MAX_LENGTH);
}

/** [serverUrl] is where the phone reaches this server, base path included. */
function startPairing(userId, serverUrl) {
  db.prepare("DELETE FROM user_device_pairings WHERE datetime(expires_at) < datetime('now', '-1 day')").run();
  const open = db.prepare(`
    SELECT COUNT(*) AS count FROM user_device_pairings
    WHERE user_id = ? AND status = 'pending' AND datetime(expires_at) > datetime('now')
  `).get(userId).count;
  if (open >= MAX_OPEN_CODES) {
    throw httpError(429, 'Too many open pairing codes. Wait a few minutes and try again.', 'TOO_MANY_PAIRING_CODES');
  }
  const code = crypto.randomBytes(32).toString('base64url');
  const { expires_at: expiresAt } = db.prepare(`
    INSERT INTO user_device_pairings (user_id, code_hash, expires_at)
    VALUES (?, ?, datetime('now', ?))
    RETURNING expires_at
  `).get(userId, hashCode(code), `+${LIFETIME_SECONDS} seconds`);
  const query = new URLSearchParams({ server: serverUrl, code });
  return { code, expiresAt, server: serverUrl, qrPayload: `neoagent://pair?${query}` };
}

function isExpired(row) {
  return db.prepare("SELECT datetime(?) <= datetime('now') AS expired").get(row.expires_at).expired === 1;
}

/** The pairing dialog's poll: pending, used (with the phone) or expired. */
function getPairingStatus(userId, code) {
  const row = db.prepare('SELECT * FROM user_device_pairings WHERE code_hash = ? AND user_id = ?')
    .get(hashCode(code), userId);
  if (!row) throw httpError(404, 'Pairing code not found', 'NOT_FOUND');
  if (row.status === 'used') {
    return { status: 'used', device: row.device_label ? { name: row.device_label } : null };
  }
  return { status: isExpired(row) ? 'expired' : 'pending' };
}

/**
 * The phone's swap: spends the code and returns the account to sign in as.
 * Used, expired or unknown codes all answer 410.
 */
function redeemPairing({ code, deviceLabel }) {
  return db.transaction(() => {
    const row = typeof code === 'string' && code
      ? db.prepare('SELECT * FROM user_device_pairings WHERE code_hash = ?').get(hashCode(code))
      : null;
    if (!row || row.status !== 'pending' || isExpired(row)) {
      throw httpError(410, 'The pairing code has expired. Show a new one on the signed-in screen.', 'EXPIRED_TOKEN');
    }
    const user = db.prepare(`
      SELECT id, username, email, email_verified_at, password_login_enabled, created_at, last_login, has_completed_onboarding
      FROM users WHERE id = ?
    `).get(row.user_id);
    if (!user) throw httpError(410, 'The account that showed this code is no longer available.', 'EXPIRED_TOKEN');
    db.prepare(`
      UPDATE user_device_pairings
      SET status = 'used', device_label = ?, used_at = datetime('now')
      WHERE id = ?
    `).run(cleanDeviceLabel(deviceLabel) || null, row.id);
    return user;
  })();
}

module.exports = { getPairingStatus, redeemPairing, startPairing };
