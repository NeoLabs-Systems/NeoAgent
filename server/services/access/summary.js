'use strict';

const { isAdminUser } = require('./admin');
const { getDelegation, listDirectlyManaged, publicUser } = require('./delegations');
const { listInvites } = require('./invites');
const {
  MAX_CHAIN_DEPTH,
  PERMISSIONS,
  managerChain,
  resolvePermissions,
} = require('./permissions');

function describePermissions(resolved) {
  return PERMISSIONS.map((key) => {
    const entry = resolved.get(key);
    return { key, allowed: entry.allowed, setBy: entry.setBy == null ? null : publicUser(entry.setBy) };
  });
}

// A managed account's permissions as its direct manager sees them. A manager
// can only change what they hold themselves; anything an upstream manager took
// away from them is shown but read-only.
function describeManagedPermissions(managerResolved, managedUserId) {
  const resolved = resolvePermissions(managedUserId);
  return PERMISSIONS.map((key) => {
    const entry = resolved.get(key);
    return {
      key,
      allowed: entry.allowed,
      editable: managerResolved.get(key).allowed,
      setBy: entry.setBy == null ? null : publicUser(entry.setBy),
    };
  });
}

function describeManagedBy(userId) {
  const delegation = getDelegation(userId);
  if (!delegation) return null;
  return {
    manager: publicUser(delegation.manager_user_id),
    since: delegation.created_at,
    chain: managerChain(userId).map((hop) => publicUser(hop.managerUserId)),
  };
}

/** Categories a manager has turned off for `userId`, keyed by permission. */
function describeManagerLocks(userId) {
  const locks = {};
  for (const [key, entry] of resolvePermissions(userId)) {
    if (!entry.allowed) locks[key] = publicUser(entry.setBy);
  }
  return locks;
}

/** Everything the Team page shows for `userId`, in one payload. */
function buildAccessSummary(userId) {
  const resolved = resolvePermissions(userId);
  return {
    isAdmin: isAdminUser(userId),
    catalog: PERMISSIONS,
    maxDepth: MAX_CHAIN_DEPTH,
    permissions: describePermissions(resolved),
    managedBy: describeManagedBy(userId),
    managing: listDirectlyManaged(userId).map((row) => ({
      user: publicUser(row.managed_user_id),
      since: row.created_at,
      permissions: describeManagedPermissions(resolved, row.managed_user_id),
    })),
    invites: listInvites(userId),
  };
}

module.exports = { buildAccessSummary, describeManagerLocks };
