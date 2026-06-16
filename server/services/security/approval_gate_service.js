'use strict';

const { randomUUID } = require('crypto');
const db = require('../../db/database');
const { getCategoryForTool } = require('./tool_categories');

const APPROVAL_TIMEOUT_MS = 30_000;
const SESSION_GRANT_TTL_MS = 12 * 60 * 60 * 1000;

class ApprovalGateService {
  constructor({ io }) {
    this._io = io;
    /** @type {Map<string, { resolve: Function, timer: NodeJS.Timeout, userId: number|string, runId: string|null, toolName: string, toolArgs: object }>} */
    this._pending = new Map();
    /** @type {Set<string>} key = `${userId}:${runId}:${toolName}` */
    this._sessionGrants = new Set();
    this._loadSessionGrants();
  }

  hasSessionGrant(userId, runId, toolName) {
    return this._sessionGrants.has(`${userId}:${runId}:${toolName}`);
  }

  _grantKey(userId, runId, toolName) {
    return `${userId}:${runId}:${toolName}`;
  }

  _loadSessionGrants() {
    try {
      db.prepare(
        `DELETE FROM approval_session_grants
         WHERE expires_at <= datetime('now')`
      ).run();
      const rows = db.prepare(
        `SELECT user_id, run_id, tool_name
         FROM approval_session_grants
         WHERE expires_at > datetime('now')`
      ).all();
      for (const row of rows) {
        this._sessionGrants.add(this._grantKey(row.user_id, row.run_id, row.tool_name));
      }
    } catch (err) {
      console.warn('[ApprovalGate] Failed to load session grants:', err.message);
    }
  }

  _persistSessionGrant(userId, runId, toolName) {
    const expiresAt = new Date(Date.now() + SESSION_GRANT_TTL_MS).toISOString();
    db.prepare(
      `INSERT INTO approval_session_grants (
         user_id, run_id, tool_name, expires_at, updated_at
       ) VALUES (?, ?, ?, ?, datetime('now'))
       ON CONFLICT(user_id, run_id, tool_name) DO UPDATE SET
         expires_at = excluded.expires_at,
         updated_at = excluded.updated_at`
    ).run(userId, runId, toolName, expiresAt);
  }

  _persistPendingApproval(approvalId, userId, runId, toolName, toolArgs, category, expiresAt) {
    db.prepare(
      `INSERT INTO pending_approvals (
         id, user_id, run_id, tool_name, tool_args_json, category, status, expires_at, updated_at
       ) VALUES (?, ?, ?, ?, ?, ?, 'pending', ?, datetime('now'))`
    ).run(
      approvalId,
      userId,
      runId,
      toolName,
      JSON.stringify(toolArgs ?? {}),
      category,
      expiresAt,
    );
  }

  _updatePendingApprovalStatus(approvalId, status, scope = null) {
    db.prepare(
      `UPDATE pending_approvals
       SET status = ?,
           scope = COALESCE(?, scope),
           decided_at = CASE WHEN ? = 'pending' THEN decided_at ELSE COALESCE(decided_at, datetime('now')) END,
           updated_at = datetime('now')
       WHERE id = ?`
    ).run(status, scope, status, approvalId);
  }

  getStoredApproval(approvalId, userId) {
    try {
      return db.prepare(
        `SELECT id, run_id, tool_name, status, scope, expires_at, decided_at
         FROM pending_approvals
         WHERE id = ? AND user_id = ?`
      ).get(approvalId, userId);
    } catch {
      return null;
    }
  }

  shutdown(reason = 'Approval expired because the server restarted.') {
    for (const [approvalId, entry] of this._pending.entries()) {
      clearTimeout(entry.timer);
      this._pending.delete(approvalId);
      this._updatePendingApprovalStatus(approvalId, 'expired', 'once');
      this._io.to(`user:${entry.userId}`).emit('tool:approval_resolved', {
        approvalId,
        decision: 'expired',
        reason,
      });
      this._logDecision(entry.userId, entry.runId, entry.toolName, entry.toolArgs, 'timeout', 'once');
      entry.resolve('expired');
    }
  }

  /**
   * Emits tool:approval_required and waits for a decision.
   * Resolves to 'approved', 'denied', 'timeout', or 'expired'.
   */
  requestApproval(userId, runId, toolName, toolArgs) {
    const approvalId = randomUUID();
    const expiresAt = new Date(Date.now() + APPROVAL_TIMEOUT_MS).toISOString();
    const category = getCategoryForTool(toolName, toolArgs) ?? 'unknown';
    this._persistPendingApproval(approvalId, userId, runId, toolName, toolArgs, category, expiresAt);

    const payload = { approvalId, runId, toolName, toolArgs, category, expiresAt };
    this._io.to(`user:${userId}`).emit('tool:approval_required', payload);

    return new Promise((resolve) => {
      const timer = setTimeout(() => {
        if (this._pending.has(approvalId)) {
          this._pending.delete(approvalId);
          this._updatePendingApprovalStatus(approvalId, 'timeout', 'once');
          this._io.to(`user:${userId}`).emit('tool:approval_resolved', {
            approvalId, decision: 'timeout',
          });
          this._logDecision(userId, runId, toolName, toolArgs, 'timeout', 'once');
          resolve('timeout');
        }
      }, APPROVAL_TIMEOUT_MS);

      this._pending.set(approvalId, {
        resolve,
        timer,
        userId,
        runId,
        toolName,
        toolArgs: toolArgs ?? {},
      });
    });
  }

  /**
   * Called from the REST/notification endpoint when the user decides.
   * @param {'approved'|'denied'} decision
   * @param {'once'|'session'|'always'} scope
   */
  resolve(approvalId, userId, runId, toolName, toolArgs, decision, scope) {
    const entry = this._pending.get(approvalId);
    if (!entry) return false;

    clearTimeout(entry.timer);
    this._pending.delete(approvalId);

    const normalizedDecision = decision === 'approved' ? 'approved' : 'denied';
    const normalizedScope = ['once', 'session', 'always'].includes(scope) ? scope : 'once';

    if (normalizedDecision === 'approved' && normalizedScope === 'session') {
      this._sessionGrants.add(this._grantKey(userId, runId, toolName));
      this._persistSessionGrant(userId, runId, toolName);
    }
    // 'always' scope is handled by the route (sets policy to 'allow') and
    // also acts as a session grant for the current run.
    if (normalizedDecision === 'approved' && normalizedScope === 'always') {
      this._sessionGrants.add(this._grantKey(userId, runId, toolName));
      this._persistSessionGrant(userId, runId, toolName);
    }

    this._updatePendingApprovalStatus(approvalId, normalizedDecision, normalizedScope);
    const logScope = normalizedScope === 'always' ? 'session' : normalizedScope;
    this._logDecision(userId, runId, toolName, toolArgs, normalizedDecision, logScope);
    this._io.to(`user:${userId}`).emit('tool:approval_resolved', { approvalId, decision: normalizedDecision });
    entry.resolve(normalizedDecision);
    return true;
  }

  _logDecision(userId, runId, toolName, toolArgs, decision, scope) {
    try {
      db.prepare(`
        INSERT INTO tool_approval_log (id, user_id, run_id, tool_name, tool_args_json, decision, scope)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      `).run(randomUUID(), userId, runId, toolName, JSON.stringify(toolArgs), decision, scope);
    } catch (err) {
      console.warn('[ApprovalGate] Failed to log decision:', err.message);
    }
  }
}

module.exports = { ApprovalGateService };
