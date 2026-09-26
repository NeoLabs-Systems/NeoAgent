'use strict';

const db = require('../../db/database');
const { httpError } = require('../../utils/http_error');
const { recordAccessEvent } = require('./audit');
const {
  MAX_CHAIN_DEPTH,
  PERMISSION_SET,
  managerChain,
  parseAllowed,
  resolvePermissions,
} = require('./permissions');

// The only account fields a manager ever sees about the people they manage.
// Email, activity and everything the account owns stay private.
function publicUser(userId) {
  const row = db.prepare('SELECT id, username, display_name FROM users WHERE id = ?').get(userId);
  if (!row) return null;
  return { id: row.id, username: row.username, displayName: row.display_name || null };
}

function getDelegation(managedUserId) {
  return db.prepare(`
    SELECT managed_user_id, manager_user_id, allowed_permissions_json, created_at
    FROM user_delegations
    WHERE managed_user_id = ?
  `).get(managedUserId) || null;
}

function listDirectlyManaged(managerUserId) {
  return db.prepare(`
    SELECT managed_user_id, allowed_permissions_json, created_at
    FROM user_delegations
    WHERE manager_user_id = ?
    ORDER BY created_at
  `).all(managerUserId);
}

// Levels of management below `userId` (0 when it manages nobody).
function subtreeHeight(userId) {
  const row = db.prepare(`
    WITH RECURSIVE below(user_id, depth) AS (
      SELECT managed_user_id, 1 FROM user_delegations WHERE manager_user_id = ?
      UNION ALL
      SELECT d.managed_user_id, below.depth + 1
      FROM user_delegations d
      JOIN below ON d.manager_user_id = below.user_id
      WHERE below.depth <= ?
    )
    SELECT COALESCE(MAX(depth), 0) AS height FROM below
  `).get(userId, MAX_CHAIN_DEPTH);
  return row.height;
}

/**
 * Throws the reason `managedUserId` cannot be placed under `managerUserId`.
 * Checked on preview and again inside the redeeming transaction.
 */
function assertCanAttach(managerUserId, managedUserId) {
  if (managerUserId === managedUserId) {
    throw httpError(400, 'You can’t redeem your own invite link.', 'INVITE_SELF');
  }
  const current = getDelegation(managedUserId);
  if (current) {
    const manager = publicUser(current.manager_user_id);
    throw httpError(
      409,
      `${manager?.username || 'Another account'} already manages this account. Leave that first.`,
      'ALREADY_MANAGED',
    );
  }
  const issuerChain = managerChain(managerUserId);
  if (issuerChain.some((hop) => hop.managerUserId === managedUserId)) {
    throw httpError(409, 'You already manage the account that created this link.', 'DELEGATION_CYCLE');
  }
  if (issuerChain.length + 1 + subtreeHeight(managedUserId) > MAX_CHAIN_DEPTH) {
    throw httpError(
      409,
      `This would make the management chain longer than ${MAX_CHAIN_DEPTH} levels.`,
      'DELEGATION_TOO_DEEP',
    );
  }
}

function attachDelegation({ managerUserId, managedUserId, allowedPermissions, inviteId }) {
  assertCanAttach(managerUserId, managedUserId);
  db.prepare(`
    INSERT INTO user_delegations (managed_user_id, manager_user_id, allowed_permissions_json, invite_id)
    VALUES (?, ?, ?, ?)
  `).run(managedUserId, managerUserId, JSON.stringify(allowedPermissions), inviteId);
  recordAccessEvent('delegation.create', {
    actorUserId: managedUserId,
    subjectUserId: managedUserId,
    detail: { managerUserId, inviteId, permissions: allowedPermissions },
  });
}

function leaveManager(userId) {
  const current = getDelegation(userId);
  if (!current) {
    throw httpError(404, 'Nobody manages this account.', 'NOT_MANAGED');
  }
  db.transaction(() => {
    db.prepare('DELETE FROM user_delegations WHERE managed_user_id = ?').run(userId);
    recordAccessEvent('delegation.leave', {
      actorUserId: userId,
      subjectUserId: userId,
      detail: { managerUserId: current.manager_user_id },
    });
  })();
}

function requireDirectlyManaged(managerUserId, managedUserId) {
  const current = getDelegation(managedUserId);
  if (!current || current.manager_user_id !== managerUserId) {
    throw httpError(404, 'You don’t manage this account.', 'NOT_MANAGED_BY_YOU');
  }
  return current;
}

function releaseManaged(managerUserId, managedUserId) {
  requireDirectlyManaged(managerUserId, managedUserId);
  db.transaction(() => {
    db.prepare('DELETE FROM user_delegations WHERE managed_user_id = ?').run(managedUserId);
    recordAccessEvent('delegation.release', {
      actorUserId: managerUserId,
      subjectUserId: managedUserId,
      detail: { managerUserId },
    });
  })();
}

function setManagedPermission(managerUserId, managedUserId, permission, allowed) {
  if (!PERMISSION_SET.has(permission)) {
    throw httpError(400, `Unknown permission: ${permission}`, 'UNKNOWN_PERMISSION');
  }
  if (typeof allowed !== 'boolean') {
    throw httpError(400, 'allowed must be true or false.', 'INVALID_PERMISSION_VALUE');
  }
  const current = requireDirectlyManaged(managerUserId, managedUserId);
  if (allowed && !resolvePermissions(managerUserId).get(permission).allowed) {
    throw httpError(403, 'You can only hand out permissions you hold yourself.', 'PERMISSION_NOT_HELD');
  }
  const next = parseAllowed(current.allowed_permissions_json);
  if (allowed) next.add(permission);
  else next.delete(permission);
  db.transaction(() => {
    db.prepare('UPDATE user_delegations SET allowed_permissions_json = ? WHERE managed_user_id = ?')
      .run(JSON.stringify([...next]), managedUserId);
    recordAccessEvent('delegation.permission', {
      actorUserId: managerUserId,
      subjectUserId: managedUserId,
      detail: { permission, allowed },
    });
  })();
}

/**
 * Stops `userId` acting as a manager: their open invite links are revoked and
 * everyone they manage moves up to their own manager, so upstream limits keep
 * applying. With no manager above, those accounts become unmanaged. Used when
 * the account is deleted. Call inside the caller's transaction.
 */
function retireManager(userId, { reason }) {
  const upstream = getDelegation(userId)?.manager_user_id ?? null;
  const revokedInvites = db.prepare(`
    UPDATE delegation_invites
    SET revoked_at = datetime('now')
    WHERE issuer_user_id = ? AND revoked_at IS NULL
  `).run(userId).changes;
  if (revokedInvites > 0) {
    recordAccessEvent('invite.revoke', {
      subjectUserId: userId,
      detail: { reason, count: revokedInvites },
    });
  }
  for (const row of listDirectlyManaged(userId)) {
    if (upstream == null) {
      db.prepare('DELETE FROM user_delegations WHERE managed_user_id = ?').run(row.managed_user_id);
      recordAccessEvent('delegation.release', {
        subjectUserId: row.managed_user_id,
        detail: { managerUserId: userId, reason },
      });
    } else {
      db.prepare('UPDATE user_delegations SET manager_user_id = ? WHERE managed_user_id = ?')
        .run(upstream, row.managed_user_id);
      recordAccessEvent('delegation.reattach', {
        subjectUserId: row.managed_user_id,
        detail: { fromManagerUserId: userId, toManagerUserId: upstream, reason },
      });
    }
  }
}

module.exports = {
  publicUser,
  getDelegation,
  listDirectlyManaged,
  assertCanAttach,
  attachDelegation,
  leaveManager,
  releaseManaged,
  setManagedPermission,
  retireManager,
};
