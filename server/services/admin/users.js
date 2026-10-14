'use strict';

const db = require('../../db/database');
const { isAdminUser } = require('../access/admin');
const { eraseUserData } = require('../account/erasure');
const { recordAccessEvent } = require('../access/audit');
const { hashPassword, validateNewPassword } = require('../account/credentials');
const { revokeAllSessionsForUser } = require('../account/sessions');
const { createServiceLogger } = require('../../utils/logger');
const { httpError } = require('../../utils/http_error');

const logger = createServiceLogger('Admin');

const ADMIN_ACCOUNT_MESSAGE =
  'Admin accounts can’t be deleted here. Revoke admin with `neoagent admin revoke <username>` first.';

function listUsers(search) {
  const pattern = search ? `%${search}%` : null;
  const users = db.prepare(`
    SELECT u.id, u.username, u.display_name, u.email, u.email_verified_at,
           u.created_at, u.last_login, u.rate_limit_4h, u.rate_limit_weekly,
           COALESCE(r.run_count,    0) AS run_count,
           COALESCE(a.storage_bytes,0) AS storage_bytes,
           u.is_admin,
           manager.username AS managed_by
    FROM users u
    LEFT JOIN user_delegations d ON d.managed_user_id = u.id
    LEFT JOIN users manager ON manager.id = d.manager_user_id
    LEFT JOIN (
      SELECT user_id, COUNT(*) AS run_count
      FROM agent_runs GROUP BY user_id
    ) r ON r.user_id = u.id
    LEFT JOIN (
      SELECT user_id, COALESCE(SUM(byte_size),0) AS storage_bytes
      FROM artifacts GROUP BY user_id
    ) a ON a.user_id = u.id
    WHERE ? IS NULL OR u.username LIKE ? OR u.email LIKE ?
    ORDER BY u.created_at DESC LIMIT 200
  `).all(pattern, pattern, pattern);
  return { users };
}

/**
 * Erases a non-admin account and everything it owns. Admin accounts (the
 * caller's own included) are refused: admin is granted and revoked by the
 * operator, so removing one has to start there.
 */
function deleteUser(userId, { actorUserId, runtimeManager }) {
  const user = db.prepare('SELECT id FROM users WHERE id = ?').get(userId);
  if (!user) throw httpError(404, 'User not found', 'NOT_FOUND');
  if (isAdminUser(user.id)) throw httpError(403, ADMIN_ACCOUNT_MESSAGE, 'ADMIN_ACCOUNT');
  const result = eraseUserData(user.id, { runtimeManager });
  logger.info(`Admin ${actorUserId} erased account ${user.id}`);
  return result;
}

function revokeUserSessions(userId) {
  revokeAllSessionsForUser(userId);
  return { ok: true };
}

/**
 * Sets a new password for an account -- the way back in when the server has
 * no email to send a reset link. Signs the account out everywhere and voids
 * any reset link still waiting in its inbox.
 */
async function resetUserPassword(userId, password, { actorUserId }) {
  const user = db.prepare('SELECT id, username, email FROM users WHERE id = ?').get(userId);
  if (!user) throw httpError(404, 'User not found', 'USER_NOT_FOUND');
  const value = String(password || '');
  validateNewPassword(value, { username: user.username, email: user.email });
  const hash = await hashPassword(value);
  db.transaction(() => {
    db.prepare('UPDATE users SET password = ?, password_login_enabled = 1 WHERE id = ?').run(hash, user.id);
    db.prepare(`
      UPDATE user_email_tokens SET consumed_at = datetime('now')
      WHERE user_id = ? AND type = 'password_reset' AND consumed_at IS NULL
    `).run(user.id);
    recordAccessEvent('account.password_reset', { actorUserId, subjectUserId: user.id });
  })();
  revokeAllSessionsForUser(user.id);
  logger.info(`Admin ${actorUserId} reset the password of account ${user.id}`);
  return { success: true };
}

module.exports = { listUsers, deleteUser, revokeUserSessions, resetUserPassword };
