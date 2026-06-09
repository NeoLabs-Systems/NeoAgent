'use strict';

const bcrypt  = require('bcrypt');
const crypto  = require('crypto');
const { generateSecret, generateURI, verifySync } = require('otplib');
const db      = require('../../db/database');
const { encryptValue, decryptValue } = require('../integrations/secrets');

const TOTP_OPTS = { strategy: 'totp', digits: 6, period: 30, epochTolerance: 30 };
const RECOVERY_ALPHA = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

// ── Helpers ────────────────────────────────────────────────────────────────

function getRow() {
  return db.prepare('SELECT * FROM admin_two_factor WHERE id = 1').get() || null;
}

function normalizeCode(v) {
  return String(v || '').trim().replace(/\s+/g, '').toUpperCase();
}

function verifyTotpCode(secret, code) {
  const token = String(code || '').trim().replace(/\s+/g, '');
  if (!/^\d{6}$/.test(token)) return false;
  return verifySync({ ...TOTP_OPTS, secret, token })?.valid === true;
}

function makeRecoveryCode() {
  let raw = '';
  while (raw.length < 10) raw += RECOVERY_ALPHA[crypto.randomInt(RECOVERY_ALPHA.length)];
  return `${raw.slice(0, 5)}-${raw.slice(5)}`;
}

// ── Public API ─────────────────────────────────────────────────────────────

function getStatus() {
  const row = getRow();
  const codesLeft = db.prepare('SELECT COUNT(*) AS n FROM admin_recovery_codes WHERE used_at IS NULL').get().n;
  return {
    enabled:                row?.enabled === 1,
    pending:                Boolean(row?.pending_secret),
    enabledAt:              row?.enabled_at || null,
    recoveryCodesRemaining: codesLeft,
  };
}

function beginSetup() {
  if (!String(process.env.SESSION_SECRET || '').trim()) {
    throw Object.assign(new Error('SESSION_SECRET must be configured before enabling 2FA'), { statusCode: 500 });
  }
  const secret      = generateSecret();
  const otpauthUrl  = generateURI({ ...TOTP_OPTS, issuer: 'NeoAgent Admin', label: 'admin', secret });
  db.prepare(`
    INSERT INTO admin_two_factor (id, pending_secret, enabled, created_at, updated_at)
    VALUES (1, ?, COALESCE((SELECT enabled FROM admin_two_factor WHERE id = 1), 0), datetime('now'), datetime('now'))
    ON CONFLICT(id) DO UPDATE SET pending_secret = excluded.pending_secret, updated_at = datetime('now')
  `).run(encryptValue(secret));
  return { otpauthUrl, manualKey: secret };
}

async function enable(code) {
  const row = getRow();
  if (!row?.pending_secret) throw Object.assign(new Error('No 2FA setup pending'), { statusCode: 400 });
  const secret = decryptValue(row.pending_secret);
  if (!verifyTotpCode(secret, code)) throw Object.assign(new Error('Invalid code — try again'), { statusCode: 401 });

  const codes  = Array.from({ length: 10 }, makeRecoveryCode);
  const hashes = await Promise.all(codes.map((c) => bcrypt.hash(normalizeCode(c).replace(/-/g, ''), 12)));

  db.transaction(() => {
    db.prepare('DELETE FROM admin_recovery_codes').run();
    const ins = db.prepare("INSERT INTO admin_recovery_codes (code_hash, created_at) VALUES (?, datetime('now'))");
    for (const h of hashes) ins.run(h);
    db.prepare(`
      UPDATE admin_two_factor
      SET secret = pending_secret, pending_secret = NULL, enabled = 1,
          enabled_at = datetime('now'), updated_at = datetime('now')
      WHERE id = 1
    `).run();
  })();

  return { recoveryCodes: codes };
}

/**
 * Verifies a TOTP code or recovery code.
 * Returns true if valid (or if 2FA is not enabled).
 */
async function verifyCode(code) {
  const row = getRow();
  if (!row?.enabled || !row.secret) return true; // 2FA not configured

  const secret = decryptValue(row.secret);
  if (verifyTotpCode(secret, code)) return true;

  // Try recovery code
  const normalized = normalizeCode(String(code || '')).replace(/-/g, '');
  if (normalized.length < 6) return false;
  const rows = db.prepare('SELECT id, code_hash FROM admin_recovery_codes WHERE used_at IS NULL ORDER BY id').all();
  for (const r of rows) {
    if (await bcrypt.compare(normalized, r.code_hash)) {
      db.prepare("UPDATE admin_recovery_codes SET used_at = datetime('now') WHERE id = ?").run(r.id);
      return true;
    }
  }
  return false;
}

async function disable(code) {
  const row = getRow();
  if (!row?.enabled) return;
  if (!await verifyCode(code)) throw Object.assign(new Error('Invalid 2FA code'), { statusCode: 401 });
  db.transaction(() => {
    db.prepare(`UPDATE admin_two_factor SET enabled = 0, secret = NULL, pending_secret = NULL,
      enabled_at = NULL, updated_at = datetime('now') WHERE id = 1`).run();
    db.prepare('DELETE FROM admin_recovery_codes').run();
  })();
}

async function regenerateCodes(code) {
  if (!await verifyCode(code)) throw Object.assign(new Error('Invalid 2FA code'), { statusCode: 401 });
  const codes  = Array.from({ length: 10 }, makeRecoveryCode);
  const hashes = await Promise.all(codes.map((c) => bcrypt.hash(normalizeCode(c).replace(/-/g, ''), 12)));
  db.transaction(() => {
    db.prepare('DELETE FROM admin_recovery_codes').run();
    const ins = db.prepare("INSERT INTO admin_recovery_codes (code_hash, created_at) VALUES (?, datetime('now'))");
    for (const h of hashes) ins.run(h);
  })();
  return { recoveryCodes: codes };
}

module.exports = { getStatus, beginSetup, enable, verifyCode, disable, regenerateCodes };
