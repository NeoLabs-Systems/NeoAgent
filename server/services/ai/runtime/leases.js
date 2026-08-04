'use strict';

const { randomUUID } = require('crypto');
const db = require('../../../db/database');
const { DEFAULT_LEASE_MS } = require('./constants');

function isoIn(ms) {
  return new Date(Date.now() + Math.max(1000, ms)).toISOString();
}

function nowIso() {
  return new Date().toISOString();
}

function acquire(runId, {
  workerId = null,
  leaseMs = DEFAULT_LEASE_MS,
} = {}) {
  if (!runId) return null;
  const owner = workerId || `worker_${randomUUID()}`;
  const expiresAt = isoIn(leaseMs);
  const heartbeatAt = nowIso();

  const result = db.transaction(() => {
    const row = db.prepare(
      `SELECT lease_owner, lease_expires_at, runtime_state
       FROM agent_runs WHERE id = ?`,
    ).get(runId);
    if (!row) return null;

    const expiresMs = row.lease_expires_at ? Date.parse(row.lease_expires_at) : 0;
    const leaseLive = row.lease_owner
      && Number.isFinite(expiresMs)
      && expiresMs > Date.now()
      && row.lease_owner !== owner;
    if (leaseLive) return null;

    db.prepare(
      `UPDATE agent_runs
       SET lease_owner = ?, lease_expires_at = ?, heartbeat_at = ?, updated_at = datetime('now')
       WHERE id = ?`,
    ).run(owner, expiresAt, heartbeatAt, runId);

    return {
      runId,
      workerId: owner,
      leaseExpiresAt: expiresAt,
      heartbeatAt,
    };
  })();

  return result;
}

function heartbeat(runId, workerId, { leaseMs = DEFAULT_LEASE_MS } = {}) {
  if (!runId || !workerId) return false;
  const expiresAt = isoIn(leaseMs);
  const heartbeatAt = nowIso();
  const result = db.prepare(
    `UPDATE agent_runs
     SET lease_expires_at = ?, heartbeat_at = ?, updated_at = datetime('now')
     WHERE id = ? AND lease_owner = ?`,
  ).run(expiresAt, heartbeatAt, runId, workerId);
  return result.changes > 0;
}

function release(runId, workerId) {
  if (!runId || !workerId) return false;
  const result = db.prepare(
    `UPDATE agent_runs
     SET lease_owner = NULL, lease_expires_at = NULL, updated_at = datetime('now')
     WHERE id = ? AND lease_owner = ?`,
  ).run(runId, workerId);
  return result.changes > 0;
}

function expireDeadLeases({ olderThanMs = DEFAULT_LEASE_MS } = {}) {
  const cutoff = new Date(Date.now() - olderThanMs).toISOString();
  return db.prepare(
    `UPDATE agent_runs
     SET lease_owner = NULL, lease_expires_at = NULL, updated_at = datetime('now')
     WHERE lease_owner IS NOT NULL
       AND (
         lease_expires_at IS NULL
         OR lease_expires_at < datetime('now')
         OR heartbeat_at < ?
       )
       AND runtime_state NOT IN ('completed', 'cancelled', 'failed')`,
  ).run(cutoff).changes;
}

function listRecoverableRuns({ limit = 50 } = {}) {
  return db.prepare(
    `SELECT id, user_id, agent_id, runtime_state, version, lease_owner, lease_expires_at, heartbeat_at
     FROM agent_runs
     WHERE runtime_state NOT IN ('completed', 'cancelled', 'failed')
       AND (
         lease_owner IS NULL
         OR lease_expires_at IS NULL
         OR lease_expires_at < datetime('now')
       )
     ORDER BY updated_at ASC
     LIMIT ?`,
  ).all(Math.max(1, Math.min(Number(limit) || 50, 500)));
}

module.exports = {
  acquire,
  heartbeat,
  release,
  expireDeadLeases,
  listRecoverableRuns,
};
