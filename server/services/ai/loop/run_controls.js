'use strict';

const db = require('../../../db/database');
const { EVENT_TYPES } = require('../runtime/events/event_types');
const {
  TERMINAL_STATUSES,
  checkpointRun,
  closeRun,
  getRunControl,
  requestRunControl,
  transitionRun,
} = require('./lifecycle');

// What stops, pauses, and resumes a run, from any surface.

async function checkpointLifecycle(engine, runId, phase, state = {}) {
  const runMeta = engine.activeRuns.get(runId);
  if (!runMeta) return { action: 'stop' };
  const control = getRunControl(runId);
  if (!control) return null;
  if (control.action !== 'pause') return control;

  checkpointRun(runId, phase, {
    iteration: Number(state.iteration) || 0,
    stepIndex: Number(state.stepIndex) || 0,
    currentPhase: phase,
    activeTools: (runMeta.activeTools || []).map((tool) => tool.name),
  });
  transitionRun(runId, 'paused', {}, ['running', 'pausing']);
  db.transaction(() => {
    db.prepare(
      `UPDATE agent_steps
       SET status = 'paused', error = COALESCE(NULLIF(error, ''), 'Paused by request.'), completed_at = COALESCE(completed_at, datetime('now'))
       WHERE run_id = ? AND status = 'running'`,
    ).run(runId);
    db.prepare(
      `UPDATE pending_approvals
       SET status = 'expired', decided_at = COALESCE(decided_at, datetime('now')), updated_at = datetime('now')
       WHERE run_id = ? AND status = 'pending'`,
    ).run(runId);
  })();
  runMeta.status = 'paused';
  runMeta.abortController = null;
  engine.emit(runMeta.userId, 'run:paused', { runId, reason: control.reason || null });
  engine.recordRunEvent(runMeta.userId, runId, EVENT_TYPES.RUN_STATE, {
    to_state: 'paused',
    phase,
    reason: control.reason || null,
  }, { agentId: runMeta.agentId });

  await new Promise((resolve) => { runMeta.resumeRun = resolve; });
  runMeta.resumeRun = null;
  if (runMeta.status === 'stopped' || runMeta.status === 'interrupted') {
    return { action: runMeta.status === 'interrupted' ? 'interrupt' : 'stop' };
  }
  const persistedStatus = db.prepare('SELECT status FROM agent_runs WHERE id = ?').get(runId)?.status;
  if (persistedStatus !== 'running') {
    const action = persistedStatus === 'interrupted' ? 'interrupt' : 'stop';
    runMeta.status = persistedStatus || 'stopped';
    return { action };
  }
  runMeta.abortController = new AbortController();
  runMeta.status = 'running';
  return null;
}

function interruptRun(engine, runId, reason = 'Server shutting down while run was in progress.') {
  const runMeta = engine.activeRuns.get(runId);
  const persistedRun = runMeta || db.prepare('SELECT user_id AS userId FROM agent_runs WHERE id = ?').get(runId);
  if (persistedRun?.userId != null) {
    requestRunControl(runId, persistedRun.userId, 'interrupt', reason);
  }
  if (runMeta) {
    runMeta.status = 'interrupted';
    runMeta.stopReason = reason;
    runMeta.aborted = true;
    runMeta.abortController?.abort(reason);
    runMeta.resumeRun?.();
    engine.emit(runMeta.userId, 'run:stopping', { runId });
    for (const pid of runMeta.toolPids) {
      if (engine.runtimeManager && typeof engine.runtimeManager.killCommand === 'function') {
        void engine.runtimeManager.killCommand(runMeta.userId, pid, 'aborted', {
          deviceTarget: runMeta.deviceTarget,
        });
      }
    }
    runMeta.toolPids.clear();
  }
  closeRun(runId, 'interrupted', { error: reason }, ['running', 'pausing', 'paused', 'resuming']);
  if (persistedRun?.userId != null) engine.runtimeManager?.releaseControl?.(persistedRun.userId, runId);
}

function interruptAllActiveRuns(engine, reason = 'Server shutting down while run was in progress.') {
  for (const runId of Array.from(engine.activeRuns.keys())) {
    engine.interruptRun(runId, reason);
  }
}

function stopRun(engine, runId, reason = 'Stopped by request.') {
  const stopReason = String(reason || 'Stopped by request.').slice(0, 1000);
  const runMeta = engine.activeRuns.get(runId);
  const persistedRun = runMeta || db.prepare(
    'SELECT user_id AS userId, status FROM agent_runs WHERE id = ?',
  ).get(runId);
  if (!persistedRun || TERMINAL_STATUSES.has(persistedRun.status)) return false;
  if (persistedRun?.userId != null) {
    requestRunControl(runId, persistedRun.userId, 'stop', stopReason);
  }
  if (runMeta) {
    runMeta.status = 'stopped';
    runMeta.stopReason = stopReason;
    runMeta.aborted = true;
    runMeta.abortController?.abort(stopReason);
    runMeta.resumeRun?.();
    engine.emit(runMeta.userId, 'run:stopping', { runId, reason: stopReason });
    for (const pid of runMeta.toolPids) {
      if (engine.runtimeManager && typeof engine.runtimeManager.killCommand === 'function') {
        void engine.runtimeManager.killCommand(runMeta.userId, pid, 'aborted', {
          deviceTarget: runMeta.deviceTarget,
        });
      }
    }
    runMeta.toolPids.clear();
  }
  closeRun(
    runId,
    'stopped',
    { error: stopReason },
    ['running', 'pausing', 'paused', 'resuming'],
  );
  if (persistedRun?.userId != null) engine.runtimeManager?.releaseControl?.(persistedRun.userId, runId);
  return true;
}

function pauseRun(engine, runId, { userId, reason = '' } = {}) {
  if (!runId || userId == null) return false;
  const runMeta = engine.activeRuns.get(runId);
  if (
    !runMeta
    || Number(runMeta.userId) !== Number(userId)
    || runMeta.status !== 'running'
    || runMeta.pauseAvailable !== true
  ) return false;
  const result = requestRunControl(runId, userId, 'pause', reason);
  if (!result.accepted) return false;
  transitionRun(runId, 'pausing', {}, ['running']);
  runMeta.status = 'pausing';
  runMeta.abortController?.abort('Run paused.');
  for (const pid of runMeta.toolPids) {
    if (engine.runtimeManager && typeof engine.runtimeManager.killCommand === 'function') {
      void engine.runtimeManager.killCommand(runMeta.userId, pid, 'paused', {
        deviceTarget: runMeta.deviceTarget,
      });
    }
  }
  engine.emit(runMeta.userId, 'run:pausing', { runId, reason: reason || null });
  engine.runtimeManager?.releaseControl?.(runMeta.userId, runId);
  return true;
}

function resumeRun(engine, runId, { userId } = {}) {
  if (!runId || userId == null) return false;
  const runMeta = engine.activeRuns.get(runId);
  if (!runMeta || Number(runMeta.userId) !== Number(userId) || runMeta.status !== 'paused') return false;
  if (!transitionRun(runId, 'resuming', {}, ['paused'])) return false;
  db.prepare(
    `UPDATE agent_run_controls SET consumed_at = datetime('now')
     WHERE run_id = ? AND action = 'pause' AND consumed_at IS NULL`,
  ).run(runId);
  transitionRun(runId, 'running', {}, ['resuming']);
  engine.emit(runMeta.userId, 'run:resumed', { runId });
  engine.recordRunEvent(runMeta.userId, runId, EVENT_TYPES.RUN_STATE, { to_state: 'running', reason: 'resumed' }, { agentId: runMeta.agentId });
  runMeta.resumeRun?.();
  return true;
}

function abort(engine, runId, { userId, reason = 'Stopped by request.' } = {}) {
  if (!runId) return false;
  const runMeta = engine.activeRuns.get(runId);
  const persistedRun = runMeta
    || db.prepare('SELECT user_id AS userId, status FROM agent_runs WHERE id = ?').get(runId);
  if (!persistedRun || TERMINAL_STATUSES.has(persistedRun.status)) return false;
  if (userId != null) {
    // Ownership gate applies to both active and persisted runs.
    if (Number(persistedRun.userId) !== Number(userId)) return false;
  }
  return engine.stopRun(runId, reason);
}

function abortAll(engine, userId) {
  for (const [runId, run] of engine.activeRuns) {
    if (run.userId === userId) engine.stopRun(runId);
  }
}

module.exports = {
  checkpointLifecycle,
  interruptRun,
  interruptAllActiveRuns,
  stopRun,
  pauseRun,
  resumeRun,
  abort,
  abortAll,
};
