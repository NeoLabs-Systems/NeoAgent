'use strict';

// Invite links put the redeeming account under the issuer's management. Only a
// SHA-256 of the token is stored; the raw token exists once, in the link handed
// to the issuer. A link carries its permission scope, an optional expiry, and a
// single-use or reusable limit, and can be revoked at any time.

const crypto = require('crypto');
const db = require('../../db/database');
const { recordAccessEvent } = require('./audit');
const { httpError } = require('../../utils/http_error');
const {
  assertCanAttach,
  attachDelegation,
  publicUser,
} = require('./delegations');
const { PERMISSION_SET, resolvePermissions } = require('./permissions');

const TOKEN_BYTES = 24;
const MAX_EXPIRY_HOURS = 24 * 90;
// Open (usable) links one account may hold at once; revoke or let some expire
// to make more. Keeps any one account from filling the table.
const MAX_ACTIVE_INVITES = 25;
const INVITE_QUERY_PARAM = 'invite';

function hashToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

function buildInviteLink(baseUrl, token) {
  return `${String(baseUrl).replace(/\/+$/, '')}/app/?${INVITE_QUERY_PARAM}=${token}`;
}

// Accepts the full link or just the token, however it was pasted.
function tokenFromLink(link) {
  const text = String(link || '').trim();
  if (!text) return '';
  try {
    return new URL(text).searchParams.get(INVITE_QUERY_PARAM) || '';
  } catch {
    return /^[A-Za-z0-9_-]+$/.test(text) ? text : '';
  }
}

function parseScope(json) {
  try {
    const parsed = JSON.parse(json || '[]');
    return Array.isArray(parsed) ? parsed.filter((key) => PERMISSION_SET.has(key)) : [];
  } catch {
    return [];
  }
}

function inviteStatus(row, now = Date.now()) {
  if (row.revoked_at) return 'revoked';
  // SQLite datetime('now') values are UTC without a zone marker.
  if (row.expires_at && Date.parse(`${row.expires_at.replace(' ', 'T')}Z`) <= now) return 'expired';
  if (row.max_uses != null && row.use_count >= row.max_uses) return 'used';
  return 'active';
}

function serializeInvite(row) {
  return {
    id: row.id,
    label: row.label,
    permissions: parseScope(row.permissions_json),
    maxUses: row.max_uses,
    useCount: row.use_count,
    expiresAt: row.expires_at,
    revokedAt: row.revoked_at,
    createdAt: row.created_at,
    status: inviteStatus(row),
  };
}

function heldPermissions(userId) {
  const held = new Set();
  for (const [key, entry] of resolvePermissions(userId)) {
    if (entry.allowed) held.add(key);
  }
  return held;
}

function normalizeCreateInput({ label, permissions, expiresInHours, maxUses }) {
  if (!Array.isArray(permissions) || permissions.some((key) => !PERMISSION_SET.has(key))) {
    throw httpError(400, 'permissions must be a list of known permission keys.', 'INVITE_SCOPE_UNKNOWN');
  }
  if (expiresInHours != null
    && !(Number.isInteger(expiresInHours) && expiresInHours >= 1 && expiresInHours <= MAX_EXPIRY_HOURS)) {
    throw httpError(400, `expiresInHours must be between 1 and ${MAX_EXPIRY_HOURS}, or null.`, 'INVITE_EXPIRY_INVALID');
  }
  if (maxUses != null && maxUses !== 1) {
    throw httpError(400, 'maxUses must be 1 (single-use) or null (reusable).', 'INVITE_USES_INVALID');
  }
  return {
    label: String(label || '').trim().slice(0, 80),
    permissions: [...new Set(permissions)],
    expiresInHours: expiresInHours ?? null,
    maxUses: maxUses ?? null,
  };
}

function createInvite(issuerUserId, input) {
  const { label, permissions, expiresInHours, maxUses } = normalizeCreateInput(input);
  const held = heldPermissions(issuerUserId);
  if (permissions.some((key) => !held.has(key))) {
    throw httpError(403, 'A link can only grant permissions you hold yourself.', 'INVITE_SCOPE');
  }
  const active = listInvites(issuerUserId).filter((invite) => invite.status === 'active').length;
  if (active >= MAX_ACTIVE_INVITES) {
    throw httpError(
      429,
      `You already have ${MAX_ACTIVE_INVITES} open invite links. Revoke some before creating more.`,
      'INVITE_LIMIT',
    );
  }
  const id = crypto.randomUUID();
  const token = crypto.randomBytes(TOKEN_BYTES).toString('base64url');
  db.transaction(() => {
    db.prepare(`
      INSERT INTO delegation_invites (id, issuer_user_id, token_hash, label, permissions_json, max_uses, expires_at)
      VALUES (?, ?, ?, ?, ?, ?, CASE WHEN ? IS NULL THEN NULL ELSE datetime('now', '+' || ? || ' hours') END)
    `).run(id, issuerUserId, hashToken(token), label, JSON.stringify(permissions), maxUses, expiresInHours, expiresInHours);
    recordAccessEvent('invite.create', {
      actorUserId: issuerUserId,
      subjectUserId: issuerUserId,
      detail: { inviteId: id, permissions, maxUses, expiresInHours },
    });
  })();
  const row = db.prepare('SELECT * FROM delegation_invites WHERE id = ?').get(id);
  return { invite: serializeInvite(row), token };
}

function listInvites(issuerUserId) {
  return db.prepare(`
    SELECT * FROM delegation_invites WHERE issuer_user_id = ? ORDER BY created_at DESC, id
  `).all(issuerUserId).map(serializeInvite);
}

function revokeInvite(issuerUserId, inviteId) {
  const result = db.prepare(`
    UPDATE delegation_invites SET revoked_at = datetime('now')
    WHERE id = ? AND issuer_user_id = ? AND revoked_at IS NULL
  `).run(inviteId, issuerUserId);
  if (result.changes === 0) {
    throw httpError(404, 'No active invite link with that id.', 'INVITE_NOT_FOUND');
  }
  recordAccessEvent('invite.revoke', {
    actorUserId: issuerUserId,
    subjectUserId: issuerUserId,
    detail: { inviteId },
  });
}

/**
 * Everything that must hold for `userId` to redeem `link`. Returns the invite
 * row and its scope. Runs for the preview and again inside the redeeming
 * transaction, so a link that changed in between is caught.
 */
function checkRedeemable(userId, link) {
  const token = tokenFromLink(link);
  const row = token
    ? db.prepare('SELECT * FROM delegation_invites WHERE token_hash = ?').get(hashToken(token))
    : null;
  if (!row) throw httpError(404, 'This invite link isn’t valid.', 'INVITE_INVALID');
  const status = inviteStatus(row);
  if (status === 'revoked') throw httpError(410, 'This invite link was revoked.', 'INVITE_REVOKED');
  if (status === 'expired') throw httpError(410, 'This invite link has expired.', 'INVITE_EXPIRED');
  if (status === 'used') throw httpError(410, 'This invite link has already been used.', 'INVITE_USED');
  const scope = parseScope(row.permissions_json);
  const held = heldPermissions(row.issuer_user_id);
  if (scope.some((key) => !held.has(key))) {
    throw httpError(409, 'This link grants permissions its creator no longer holds.', 'INVITE_SCOPE');
  }
  assertCanAttach(row.issuer_user_id, userId);
  return { row, scope };
}

function previewInvite(userId, link) {
  const { row, scope } = checkRedeemable(userId, link);
  return {
    issuer: publicUser(row.issuer_user_id),
    permissions: scope,
    expiresAt: row.expires_at,
    singleUse: row.max_uses === 1,
  };
}

function redeemInvite(userId, link) {
  db.transaction(() => {
    const { row, scope } = checkRedeemable(userId, link);
    const consumed = db.prepare(`
      UPDATE delegation_invites SET use_count = use_count + 1
      WHERE id = ? AND revoked_at IS NULL AND (max_uses IS NULL OR use_count < max_uses)
    `).run(row.id);
    if (consumed.changes === 0) {
      throw httpError(410, 'This invite link has already been used.', 'INVITE_USED');
    }
    attachDelegation({
      managerUserId: row.issuer_user_id,
      managedUserId: userId,
      allowedPermissions: scope,
      inviteId: row.id,
    });
  })();
}

module.exports = {
  buildInviteLink,
  createInvite,
  listInvites,
  revokeInvite,
  previewInvite,
  redeemInvite,
};
