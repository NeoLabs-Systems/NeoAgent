'use strict';

const { randomUUID } = require('crypto');
const db = require('../../db/database');
const { getCategoryForTool } = require('./tool_categories');

const APPROVAL_TIMEOUT_MS = 30_000;

class ApprovalGateService {
  constructor({ io }) {
    this._io = io;
    /** @type {Map<string, { resolve: Function, timer: NodeJS.Timeout }>} */
    this._pending = new Map();
    /** @type {Set<string>} key = `${userId}:${runId}:${toolName}` */
    this._sessionGrants = new Set();
  }

  hasSessionGrant(userId, runId, toolName) {
    return this._sessionGrants.has(`${userId}:${runId}:${toolName}`);
  }

  /**
   * Emits tool:approval_required and waits for a decision.
   * Resolves to 'approved', 'denied', or 'timeout'.
   */
  requestApproval(userId, runId, toolName, toolArgs) {
    const approvalId = randomUUID();
    const expiresAt = new Date(Date.now() + APPROVAL_TIMEOUT_MS).toISOString();
    const category = getCategoryForTool(toolName, toolArgs) ?? 'unknown';

    const payload = { approvalId, runId, toolName, toolArgs, category, expiresAt };
    this._io.to(`user:${userId}`).emit('tool:approval_required', payload);

    return new Promise((resolve) => {
      const timer = setTimeout(() => {
        if (this._pending.has(approvalId)) {
          this._pending.delete(approvalId);
          this._io.to(`user:${userId}`).emit('tool:approval_resolved', {
            approvalId, decision: 'timeout',
          });
          this._logDecision(userId, runId, toolName, toolArgs, 'timeout', 'once');
          resolve('timeout');
        }
      }, APPROVAL_TIMEOUT_MS);

      this._pending.set(approvalId, { resolve, timer });
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
      this._sessionGrants.add(`${userId}:${runId}:${toolName}`);
    }
    // 'always' scope is handled by the route (sets policy to 'allow') and
    // also acts as a session grant for the current run.
    if (normalizedDecision === 'approved' && normalizedScope === 'always') {
      this._sessionGrants.add(`${userId}:${runId}:${toolName}`);
    }

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
