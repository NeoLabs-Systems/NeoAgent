'use strict';

// The single resolver for delegated permissions. Everything that asks "may this
// account use X" -- the tool hook, the delegation API, the admin page -- goes
// through resolvePermissions(), so the chain rules live in exactly one place.
//
// Rules:
//   - An account nobody manages holds every permission.
//   - A manager hands a managed account an allow-list. Anything missing from it
//     is denied for that account and for everyone below it.
//   - Walking the chain from the top down, the first denial wins, so an upstream
//     manager's decision overrides anything set further down (A > B > C).

const db = require('../../db/database');
const { DEFAULT_POLICY } = require('../security/tool_categories');

// The delegable permissions are the tool categories the security policy
// already governs (shell, file writes, desktop control, ...).
const PERMISSIONS = Object.freeze(Object.keys(DEFAULT_POLICY));
const PERMISSION_SET = new Set(PERMISSIONS);

// Most managers an account can have above it (A > B > C > D > E).
const MAX_CHAIN_DEPTH = 4;

function parseAllowed(json) {
  try {
    const parsed = JSON.parse(json || '[]');
    return new Set(Array.isArray(parsed) ? parsed.filter((key) => PERMISSION_SET.has(key)) : []);
  } catch {
    return new Set();
  }
}

// Delegations from `userId` upward, nearest manager first.
function managerChain(userId) {
  // The depth bound keeps a corrupted (cyclic) table from recursing forever;
  // attachDelegation() never lets a cycle in.
  return db.prepare(`
    WITH RECURSIVE chain(managed_user_id, manager_user_id, allowed_permissions_json, created_at, depth) AS (
      SELECT managed_user_id, manager_user_id, allowed_permissions_json, created_at, 1
      FROM user_delegations
      WHERE managed_user_id = ?
      UNION ALL
      SELECT d.managed_user_id, d.manager_user_id, d.allowed_permissions_json, d.created_at, chain.depth + 1
      FROM user_delegations d
      JOIN chain ON d.managed_user_id = chain.manager_user_id
      WHERE chain.depth <= ?
    )
    SELECT managed_user_id, manager_user_id, allowed_permissions_json, created_at
    FROM chain
    ORDER BY depth
  `).all(userId, MAX_CHAIN_DEPTH).map((row) => ({
    managedUserId: row.managed_user_id,
    managerUserId: row.manager_user_id,
    allowed: parseAllowed(row.allowed_permissions_json),
    since: row.created_at,
  }));
}

/**
 * @returns {Map<string, { allowed: boolean, setBy: number|null }>} `setBy` is
 *   the manager whose decision is in force: for a denial, the highest manager
 *   who denied it; for an allowed permission, the direct manager (who could
 *   still take it away). Null when nobody manages the account.
 */
function resolvePermissions(userId) {
  const chain = managerChain(userId);
  const resolved = new Map(PERMISSIONS.map((key) => [key, { allowed: true, setBy: null }]));
  for (let index = chain.length - 1; index >= 0; index -= 1) {
    const hop = chain[index];
    for (const key of PERMISSIONS) {
      if (resolved.get(key).allowed && !hop.allowed.has(key)) {
        resolved.set(key, { allowed: false, setBy: hop.managerUserId });
      }
    }
  }
  const directManager = chain[0]?.managerUserId ?? null;
  for (const entry of resolved.values()) {
    if (entry.allowed) entry.setBy = directManager;
  }
  return resolved;
}

function isPermitted(userId, permission) {
  if (!PERMISSION_SET.has(permission)) return true;
  return resolvePermissions(userId).get(permission).allowed;
}

module.exports = {
  PERMISSIONS,
  PERMISSION_SET,
  MAX_CHAIN_DEPTH,
  managerChain,
  parseAllowed,
  resolvePermissions,
  isPermitted,
};
