'use strict';

const { randomUUID } = require('crypto');
const db = require('../../../db/database');

function nowIso() {
  return new Date().toISOString();
}

function expiresIso(ms) {
  return new Date(Date.now() + Math.max(1000, ms)).toISOString();
}

function acquireResources({
  runId,
  owner,
  reads = [],
  writes = [],
  leaseMs = 120_000,
} = {}) {
  if (!runId || !owner) return { ok: false, reason: 'invalid_args' };

  return db.transaction(() => {
    // Expire old leases first.
    db.prepare(
      `DELETE FROM agent_resource_leases WHERE lease_expires_at < datetime('now')`,
    ).run();

    for (const resource of writes) {
      const conflict = db.prepare(
        `SELECT * FROM agent_resource_leases
         WHERE resource_key = ?
           AND lease_owner != ?
           AND lease_expires_at >= datetime('now')`,
      ).get(String(resource), owner);
      if (conflict) {
        return {
          ok: false,
          reason: 'write_conflict',
          resource,
          heldBy: conflict.lease_owner,
        };
      }
    }

    for (const resource of reads) {
      const exclusive = db.prepare(
        `SELECT * FROM agent_resource_leases
         WHERE resource_key = ?
           AND mode = 'exclusive'
           AND lease_owner != ?
           AND lease_expires_at >= datetime('now')`,
      ).get(String(resource), owner);
      if (exclusive) {
        return {
          ok: false,
          reason: 'read_conflict',
          resource,
          heldBy: exclusive.lease_owner,
        };
      }
    }

    const acquired = [];
    for (const resource of reads) {
      const id = randomUUID();
      db.prepare(
        `INSERT INTO agent_resource_leases (
          id, run_id, resource_key, mode, lease_owner, lease_expires_at, heartbeat_at
        ) VALUES (?, ?, ?, 'shared_read', ?, ?, ?)`,
      ).run(id, runId, String(resource), owner, expiresIso(leaseMs), nowIso());
      acquired.push(id);
    }
    for (const resource of writes) {
      const id = randomUUID();
      db.prepare(
        `INSERT INTO agent_resource_leases (
          id, run_id, resource_key, mode, lease_owner, lease_expires_at, heartbeat_at
        ) VALUES (?, ?, ?, 'exclusive', ?, ?, ?)`,
      ).run(id, runId, String(resource), owner, expiresIso(leaseMs), nowIso());
      acquired.push(id);
    }

    return { ok: true, leaseIds: acquired };
  })();
}

function releaseResources({ owner, runId = null } = {}) {
  if (!owner) return 0;
  if (runId) {
    return db.prepare(
      'DELETE FROM agent_resource_leases WHERE lease_owner = ? AND run_id = ?',
    ).run(owner, runId).changes;
  }
  return db.prepare(
    'DELETE FROM agent_resource_leases WHERE lease_owner = ?',
  ).run(owner).changes;
}

function heartbeat(owner, { leaseMs = 120_000 } = {}) {
  if (!owner) return 0;
  return db.prepare(
    `UPDATE agent_resource_leases
     SET heartbeat_at = ?, lease_expires_at = ?
     WHERE lease_owner = ?`,
  ).run(nowIso(), expiresIso(leaseMs), owner).changes;
}

module.exports = {
  acquireResources,
  releaseResources,
  heartbeat,
};
