'use strict';

const db = require('../../../db/database');

const TERMINAL_STATUSES = new Set(['completed', 'failed', 'stopped', 'interrupted']);
const CONTROL_PRIORITY = Object.freeze({ pause: 1, stop: 2, interrupt: 3 });

function getRunControl(runId) {
  return db.prepare(
    `SELECT action, reason, requested_at
     FROM agent_run_controls
     WHERE run_id = ? AND consumed_at IS NULL`,
  ).get(runId) || null;
}

function requestRunControl(runId, userId, action, reason = '') {
  if (!Object.hasOwn(CONTROL_PRIORITY, action)) {
    throw new Error(`Unsupported run control action: ${action}`);
  }
  const run = db.prepare(
    'SELECT status FROM agent_runs WHERE id = ? AND user_id = ?',
  ).get(runId, userId);
  if (!run) return { accepted: false, reason: 'not_found' };
  if (TERMINAL_STATUSES.has(run.status)) return { accepted: false, reason: 'terminal', status: run.status };

  const existing = getRunControl(runId);
  if (existing && CONTROL_PRIORITY[existing.action] > CONTROL_PRIORITY[action]) {
    return { accepted: false, reason: 'stronger_signal_pending', action: existing.action };
  }
  db.prepare(
    `INSERT INTO agent_run_controls (run_id, user_id, action, reason)
     VALUES (?, ?, ?, ?)
     ON CONFLICT(run_id) DO UPDATE SET
       action = excluded.action,
       reason = excluded.reason,
       requested_at = datetime('now'),
       consumed_at = NULL`,
  ).run(runId, userId, action, String(reason || '').slice(0, 1000));
  return { accepted: true, action };
}

function checkpointRun(runId, phase, state = {}) {
  db.prepare(
    `INSERT INTO agent_run_checkpoints (run_id, version, phase, state_json)
     VALUES (?, 1, ?, ?)
     ON CONFLICT(run_id) DO UPDATE SET
       version = 1,
       phase = excluded.phase,
       state_json = excluded.state_json,
       updated_at = datetime('now')`,
  ).run(runId, phase, JSON.stringify(state));
}

function transitionRun(runId, status, fields = {}, allowed = ['running']) {
  const assignments = ['status = ?', "updated_at = datetime('now')"];
  const values = [status];
  if (Object.hasOwn(fields, 'error')) {
    assignments.push('error = ?');
    values.push(fields.error || null);
  }
  if (Object.hasOwn(fields, 'finalResponse')) {
    assignments.push('final_response = ?');
    values.push(fields.finalResponse || null);
  }
  if (Object.hasOwn(fields, 'totalTokens')) {
    assignments.push('total_tokens = ?');
    values.push(Number(fields.totalTokens) || 0);
  }
  if (TERMINAL_STATUSES.has(status)) assignments.push("completed_at = COALESCE(completed_at, datetime('now'))");
  const placeholders = allowed.map(() => '?').join(', ');
  values.push(runId, ...allowed);
  const result = db.prepare(
    `UPDATE agent_runs SET ${assignments.join(', ')}
     WHERE id = ? AND status IN (${placeholders})`,
  ).run(...values);
  return result.changes > 0;
}

function closeRun(runId, status, fields = {}, allowed = ['running']) {
  const transaction = db.transaction(() => {
    if (!transitionRun(runId, status, fields, allowed)) return false;
    db.prepare(
      `UPDATE agent_steps
       SET status = ?, error = COALESCE(NULLIF(error, ''), ?), completed_at = COALESCE(completed_at, datetime('now'))
       WHERE run_id = ? AND status = 'running'`,
    ).run(status, fields.error || null, runId);
    db.prepare(
      `UPDATE agent_delegations
       SET status = ?, error = COALESCE(NULLIF(error, ''), ?), updated_at = datetime('now'), completed_at = COALESCE(completed_at, datetime('now'))
       WHERE parent_run_id = ? AND status = 'running'`,
    ).run(status, fields.error || null, runId);
    db.prepare(
      `UPDATE agent_run_controls SET consumed_at = datetime('now')
       WHERE run_id = ? AND consumed_at IS NULL`,
    ).run(runId);
    return true;
  });
  return transaction();
}

module.exports = {
  TERMINAL_STATUSES,
  checkpointRun,
  closeRun,
  getRunControl,
  requestRunControl,
  transitionRun,
};
