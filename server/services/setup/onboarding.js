'use strict';

const crypto = require('crypto');
const os = require('os');

const db = require('../../db/database');
const {
  SETUP_COMPLETION_SECTIONS,
} = require('../../../lib/setup/contract');
const { getDeploymentPolicy } = require('../../utils/deployment');
const { getVersionInfo } = require('../../utils/version');

const CLAIM_TTL_MS = 15 * 60 * 1000;
const CLAIM_TOKEN_BYTES = 32;
function parseBoolean(value, fallback) {
  const normalized = String(value || '').trim().toLowerCase();
  if (['1', 'true', 'yes', 'on'].includes(normalized)) return true;
  if (['0', 'false', 'no', 'off'].includes(normalized)) return false;
  return fallback;
}

function isSetupClaimRequired() {
  return parseBoolean(
    process.env.NEOAGENT_SETUP_CLAIM_REQUIRED,
    process.env.NODE_ENV !== 'test',
  );
}

function normalizeDisplayName(value) {
  const normalized = String(value || '')
    .replace(/[\u0000-\u001f\u007f]/g, '')
    .trim()
    .slice(0, 80);
  return normalized || 'NeoAgent';
}

function ensureInstance() {
  let row = db.prepare(
    'SELECT instance_id, display_name, created_at, updated_at FROM neoagent_instance WHERE singleton_id = 1',
  ).get();
  if (row) return row;

  const instanceId = crypto.randomUUID();
  const displayName = normalizeDisplayName(
    process.env.NEOAGENT_INSTANCE_NAME || os.hostname(),
  );
  db.prepare(`
    INSERT OR IGNORE INTO neoagent_instance (singleton_id, instance_id, display_name)
    VALUES (1, ?, ?)
  `).run(instanceId, displayName);
  row = db.prepare(
    'SELECT instance_id, display_name, created_at, updated_at FROM neoagent_instance WHERE singleton_id = 1',
  ).get();
  return row;
}

function hashToken(token) {
  return crypto.createHash('sha256').update(String(token), 'utf8').digest('hex');
}

function userCount() {
  return Number(db.prepare('SELECT COUNT(*) AS count FROM users').get().count);
}

function deleteExpiredClaims() {
  db.prepare(
    `DELETE FROM setup_claim_tokens
     WHERE consumed_at IS NOT NULL OR datetime(expires_at) <= datetime('now')`,
  ).run();
}

function createSetupClaim({ ttlMs = CLAIM_TTL_MS } = {}) {
  if (userCount() > 0) {
    const error = new Error('This NeoAgent instance already has an owner.');
    error.code = 'SETUP_ALREADY_CLAIMED';
    error.statusCode = 409;
    throw error;
  }
  deleteExpiredClaims();
  const token = crypto.randomBytes(CLAIM_TOKEN_BYTES).toString('base64url');
  const id = crypto.randomUUID();
  const expiresAt = new Date(Date.now() + ttlMs).toISOString();
  db.prepare(`
    INSERT INTO setup_claim_tokens (id, token_hash, expires_at)
    VALUES (?, ?, ?)
  `).run(id, hashToken(token), expiresAt);
  return { id, token, expiresAt };
}

function exchangeSetupClaim(token) {
  const normalized = String(token || '').trim();
  if (normalized.length < 32) {
    const error = new Error('The setup code is invalid.');
    error.code = 'SETUP_CLAIM_INVALID';
    error.statusCode = 401;
    throw error;
  }
  deleteExpiredClaims();
  return db.transaction(() => {
    if (userCount() > 0) {
      const error = new Error('This NeoAgent instance already has an owner.');
      error.code = 'SETUP_ALREADY_CLAIMED';
      error.statusCode = 409;
      throw error;
    }
    const row = db.prepare(`
      SELECT id, expires_at
      FROM setup_claim_tokens
      WHERE token_hash = ?
        AND exchanged_at IS NULL
        AND consumed_at IS NULL
        AND datetime(expires_at) > datetime('now')
    `).get(hashToken(normalized));
    if (!row) {
      const error = new Error('The setup code is invalid or has expired.');
      error.code = 'SETUP_CLAIM_INVALID';
      error.statusCode = 401;
      throw error;
    }
    db.prepare(
      `UPDATE setup_claim_tokens
       SET exchanged_at = datetime('now')
       WHERE id = ?`,
    ).run(row.id);
    return { id: row.id, expiresAt: row.expires_at };
  })();
}

function isSetupClaimSessionValid(claimId) {
  if (!claimId) return false;
  const row = db.prepare(`
    SELECT id
    FROM setup_claim_tokens
    WHERE id = ?
      AND exchanged_at IS NOT NULL
      AND consumed_at IS NULL
      AND datetime(expires_at) > datetime('now')
  `).get(String(claimId));
  return Boolean(row);
}

function consumeSetupClaim(claimId) {
  const result = db.prepare(`
    UPDATE setup_claim_tokens
    SET consumed_at = datetime('now')
    WHERE id = ?
      AND exchanged_at IS NOT NULL
      AND consumed_at IS NULL
      AND datetime(expires_at) > datetime('now')
  `).run(String(claimId || ''));
  if (result.changes !== 1) {
    const error = new Error('The setup authorization expired. Start setup again.');
    error.code = 'SETUP_CLAIM_REQUIRED';
    error.statusCode = 403;
    throw error;
  }
  db.prepare(
    `UPDATE setup_claim_tokens
     SET consumed_at = COALESCE(consumed_at, datetime('now'))
     WHERE consumed_at IS NULL`,
  ).run();
}

function getSetupHandshake() {
  const instance = ensureInstance();
  const version = getVersionInfo();
  const policy = getDeploymentPolicy();
  const hasUser = userCount() > 0;
  return {
    product: 'NeoAgent',
    protocolVersion: 1,
    serverVersion: version.packageVersion,
    instanceId: instance.instance_id,
    displayName: instance.display_name,
    deploymentProfile: policy.profile,
    claimed: hasUser,
    claimRequired: !hasUser && isSetupClaimRequired(),
    pairingSupported: true,
    capabilities: ['setup-claim', 'qr-login'],
  };
}

function getSetupProgress() {
  const profile = process.env.NEOAGENT_SETUP_PROFILE === 'full'
    ? 'full'
    : 'quick';
  const completed = new Set(
    String(process.env.NEOAGENT_SETUP_COMPLETED_SECTIONS || 'core')
      .split(',')
      .map((section) => section.trim())
      .filter((section) => SETUP_COMPLETION_SECTIONS.includes(section)),
  );
  return {
    schemaVersion: 1,
    profile,
    completedSections: SETUP_COMPLETION_SECTIONS.filter(
      (section) => completed.has(section),
    ),
    openSections: SETUP_COMPLETION_SECTIONS.filter(
      (section) => !completed.has(section),
    ),
    complete: SETUP_COMPLETION_SECTIONS.every((section) => completed.has(section)),
  };
}

module.exports = {
  CLAIM_TTL_MS,
  consumeSetupClaim,
  createSetupClaim,
  ensureInstance,
  exchangeSetupClaim,
  getSetupHandshake,
  getSetupProgress,
  isSetupClaimRequired,
  isSetupClaimSessionValid,
};
