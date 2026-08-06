'use strict';

const db = require('../../../db/database');
const { RUNTIME_STATES, PRODUCT_STATUS_BY_RUNTIME } = require('./constants');
const { expireDeadLeases, listRecoverableRuns } = require('./leases');
const { loadLatestCheckpoint } = require('./checkpoint_service');
const { appendEvent } = require('./events/run_event_store');
const { EVENT_TYPES, VISIBILITY } = require('./events/event_types');
const { shortenRunId } = require('../logFormat');

/**
 * A process that dies mid-run leaves its runs non-terminal with a lease nobody
 * owns. Nothing resumes them, so without this pass they stay "running" forever:
 * the UI shows a live run, the outbox never commits, and the user is never told.
 *
 * Recovery is deliberately conservative. The in-memory execution state is gone,
 * so a run is not silently restarted; it is closed with an explicit terminal
 * outcome and its checkpoint is preserved for inspection or a manual re-run.
 */
function recoverOrphanedRuns({ reason = 'process_restart' } = {}) {
  const expiredLeases = expireDeadLeases();
  const orphans = listRecoverableRuns({ limit: 200 });
  const recovered = [];

  for (const orphan of orphans) {
    const toState = orphan.runtime_state === RUNTIME_STATES.PAUSED
      ? RUNTIME_STATES.PAUSED
      : RUNTIME_STATES.FAILED;
    // A paused run is resumable by design and keeps its state.
    if (toState === RUNTIME_STATES.PAUSED) continue;

    const checkpoint = loadLatestCheckpoint(orphan.id);
    const result = db.prepare(
      `UPDATE agent_runs
       SET runtime_state = ?,
           status = ?,
           version = COALESCE(version, 0) + 1,
           error = COALESCE(error, ?),
           completed_at = COALESCE(completed_at, datetime('now')),
           updated_at = datetime('now')
       WHERE id = ? AND runtime_state NOT IN ('completed', 'cancelled', 'failed')`,
    ).run(
      RUNTIME_STATES.FAILED,
      PRODUCT_STATUS_BY_RUNTIME[RUNTIME_STATES.FAILED],
      'Run was interrupted by a service restart and could not be resumed.',
      orphan.id,
    );
    if (result.changes === 0) continue;

    db.prepare(
      `UPDATE agent_steps SET status = 'failed', completed_at = datetime('now')
       WHERE run_id = ? AND status = 'running'`,
    ).run(orphan.id);

    appendEvent({
      runId: orphan.id,
      userId: orphan.user_id,
      agentId: orphan.agent_id || null,
      eventType: EVENT_TYPES.RUN_FAILED,
      payload: {
        reason,
        interrupted_state: orphan.runtime_state,
        checkpoint_version: checkpoint?.version || null,
      },
      visibility: VISIBILITY.USER,
    });
    recovered.push(orphan.id);
  }

  if (expiredLeases > 0 || recovered.length > 0) {
    console.warn(
      `[Runtime] Recovered ${recovered.length} interrupted run(s), released ${expiredLeases} stale lease(s)`
      + (recovered.length ? `: ${recovered.map(shortenRunId).join(', ')}` : ''),
    );
  }

  return { expiredLeases, recovered };
}

module.exports = {
  recoverOrphanedRuns,
};
