'use strict';

const db = require('../../../db/database');
const {
  ALLOWED_TRANSITIONS,
  PRODUCT_STATUS_BY_RUNTIME,
  RUNTIME_STATES,
  TERMINAL_RUNTIME_STATES,
} = require('./constants');
const { EVENT_TYPES, VISIBILITY } = require('./events/event_types');

function parseMetadata(raw) {
  if (!raw) return {};
  if (typeof raw === 'object') return { ...raw };
  try {
    const parsed = JSON.parse(String(raw));
    return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {};
  } catch {
    return {};
  }
}

function loadRun(runId) {
  if (!runId) return null;
  const row = db.prepare(
    `SELECT id, user_id, agent_id, title, status, runtime_state, version,
            final_delivery_id, lease_owner, lease_expires_at, heartbeat_at,
            metadata_json, error, final_response, total_tokens, model,
            trigger_type, trigger_source, created_at, updated_at, completed_at
     FROM agent_runs WHERE id = ?`,
  ).get(runId);
  if (!row) return null;
  return {
    id: row.id,
    userId: row.user_id,
    agentId: row.agent_id || null,
    title: row.title || '',
    status: row.status,
    runtimeState: row.runtime_state || RUNTIME_STATES.ACCEPTED,
    version: Number(row.version || 0),
    finalDeliveryId: row.final_delivery_id || null,
    leaseOwner: row.lease_owner || null,
    leaseExpiresAt: row.lease_expires_at || null,
    heartbeatAt: row.heartbeat_at || null,
    metadata: parseMetadata(row.metadata_json),
    error: row.error || null,
    finalResponse: row.final_response || null,
    totalTokens: Number(row.total_tokens || 0),
    model: row.model || null,
    triggerType: row.trigger_type || 'user',
    triggerSource: row.trigger_source || 'web',
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    completedAt: row.completed_at || null,
  };
}

function isTerminal(runOrState) {
  const state = typeof runOrState === 'string'
    ? runOrState
    : (runOrState?.runtimeState || runOrState?.runtime_state);
  return TERMINAL_RUNTIME_STATES.has(state);
}

function canTransition(fromState, toState) {
  const allowed = ALLOWED_TRANSITIONS[fromState] || [];
  return allowed.includes(toState);
}

/**
 * Optimistic-concurrency state transition.
 * Returns { ok, run, event } or { ok:false, reason }.
 */
function transition({
  runId,
  toState,
  reason = '',
  expectedVersion = null,
  workerId = null,
  eventBus = null,
  patch = {},
}) {
  if (!runId || !toState) {
    return { ok: false, reason: 'invalid_args' };
  }

  return db.transaction(() => {
    const current = loadRun(runId);
    if (!current) return { ok: false, reason: 'not_found' };
    if (isTerminal(current)) {
      return { ok: false, reason: 'terminal', run: current };
    }
    if (expectedVersion != null && Number(expectedVersion) !== current.version) {
      return { ok: false, reason: 'version_conflict', run: current };
    }
    if (!canTransition(current.runtimeState, toState)) {
      return {
        ok: false,
        reason: 'illegal_transition',
        run: current,
        fromState: current.runtimeState,
        toState,
      };
    }
    if (workerId && current.leaseOwner && current.leaseOwner !== workerId) {
      const expiresMs = current.leaseExpiresAt ? Date.parse(current.leaseExpiresAt) : 0;
      if (Number.isFinite(expiresMs) && expiresMs > Date.now()) {
        return { ok: false, reason: 'lease_held', run: current };
      }
    }

    const nextVersion = current.version + 1;
    const productStatus = PRODUCT_STATUS_BY_RUNTIME[toState] || 'running';
    const metadata = {
      ...current.metadata,
      ...(patch.metadata && typeof patch.metadata === 'object' ? patch.metadata : {}),
      lastTransitionReason: reason || null,
      lastTransitionAt: new Date().toISOString(),
    };

    const assignments = [
      'runtime_state = ?',
      'status = ?',
      'version = ?',
      "updated_at = datetime('now')",
      'metadata_json = ?',
    ];
    const values = [toState, productStatus, nextVersion, JSON.stringify(metadata)];

    if (Object.hasOwn(patch, 'error')) {
      assignments.push('error = ?');
      values.push(patch.error || null);
    }
    if (Object.hasOwn(patch, 'finalResponse')) {
      assignments.push('final_response = ?');
      values.push(patch.finalResponse || null);
    }
    if (Object.hasOwn(patch, 'totalTokens')) {
      assignments.push('total_tokens = ?');
      values.push(Number(patch.totalTokens) || 0);
    }
    if (Object.hasOwn(patch, 'model')) {
      assignments.push('model = ?');
      values.push(patch.model || null);
    }
    if (isTerminal(toState)) {
      assignments.push("completed_at = COALESCE(completed_at, datetime('now'))");
    }

    values.push(runId, current.version);
    const result = db.prepare(
      `UPDATE agent_runs SET ${assignments.join(', ')}
       WHERE id = ? AND version = ? AND runtime_state = ?`,
    ).run(...values.slice(0, -2), runId, current.version, current.runtimeState);

    // Re-check with state guard when version column was missing on older rows.
    if (result.changes === 0) {
      const retry = db.prepare(
        `UPDATE agent_runs SET ${assignments.join(', ')}
         WHERE id = ? AND COALESCE(version, 0) = ?`,
      ).run(...values.slice(0, -2), runId, current.version);
      if (retry.changes === 0) {
        return { ok: false, reason: 'cas_failed', run: loadRun(runId) };
      }
    }

    const updated = loadRun(runId);
    let event = null;
    if (eventBus) {
      event = eventBus.publish({
        runId,
        userId: updated.userId,
        agentId: updated.agentId,
        eventType: EVENT_TYPES.RUN_STATE_CHANGED,
        actor: workerId,
        payload: {
          from_state: current.runtimeState,
          to_state: toState,
          reason: reason || null,
          expected_version: current.version,
          version: updated.version,
          worker_id: workerId,
        },
        visibility: VISIBILITY.OPERATOR,
      });
    }

    return { ok: true, run: updated, event, fromState: current.runtimeState, toState };
  })();
}

/**
 * Final-delivery compare-and-swap.
 * Only one worker may claim final_delivery_id.
 */
function claimFinalDelivery({
  runId,
  deliveryId,
  expectedVersion = null,
  workerId = null,
}) {
  if (!runId || !deliveryId) return { ok: false, reason: 'invalid_args' };

  return db.transaction(() => {
    const current = loadRun(runId);
    if (!current) return { ok: false, reason: 'not_found' };
    if (current.finalDeliveryId) {
      return {
        ok: false,
        reason: 'already_committed',
        run: current,
        finalDeliveryId: current.finalDeliveryId,
      };
    }
    if (isTerminal(current) && current.runtimeState !== RUNTIME_STATES.DELIVERING) {
      return { ok: false, reason: 'terminal', run: current };
    }
    if (expectedVersion != null && Number(expectedVersion) !== current.version) {
      return { ok: false, reason: 'version_conflict', run: current };
    }
    if (workerId && current.leaseOwner && current.leaseOwner !== workerId) {
      const expiresMs = current.leaseExpiresAt ? Date.parse(current.leaseExpiresAt) : 0;
      if (Number.isFinite(expiresMs) && expiresMs > Date.now()) {
        return { ok: false, reason: 'lease_held', run: current };
      }
    }

    const nextVersion = current.version + 1;
    const result = db.prepare(
      `UPDATE agent_runs
       SET final_delivery_id = ?,
           runtime_state = ?,
           status = 'running',
           version = ?,
           updated_at = datetime('now')
       WHERE id = ?
         AND final_delivery_id IS NULL
         AND COALESCE(version, 0) = ?
         AND runtime_state NOT IN ('completed', 'cancelled', 'failed')`,
    ).run(
      deliveryId,
      RUNTIME_STATES.DELIVERING,
      nextVersion,
      runId,
      current.version,
    );

    if (result.changes === 0) {
      return { ok: false, reason: 'cas_failed', run: loadRun(runId) };
    }
    return { ok: true, run: loadRun(runId), deliveryId };
  })();
}


module.exports = {
  loadRun,
  isTerminal,
  transition,
  claimFinalDelivery,
  RUNTIME_STATES,
  TERMINAL_RUNTIME_STATES,
};
