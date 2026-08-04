'use strict';

const { randomUUID } = require('crypto');
const db = require('../../../db/database');
const { EVENT_TYPES, VISIBILITY } = require('./events/event_types');

function saveCheckpoint(runId, phase, state = {}, {
  eventBus = null,
  userId = null,
  agentId = null,
} = {}) {
  const version = Number(
    db.prepare(
      'SELECT COALESCE(MAX(version), 0) AS v FROM agent_runtime_checkpoints WHERE run_id = ?',
    ).get(runId)?.v || 0,
  ) + 1;
  const id = randomUUID();
  const payload = {
    ...state,
    savedAt: new Date().toISOString(),
  };
  db.prepare(
    `INSERT INTO agent_runtime_checkpoints (id, run_id, version, phase, state_json)
     VALUES (?, ?, ?, ?, ?)`,
  ).run(id, runId, version, String(phase || 'checkpoint'), JSON.stringify(payload));

  // Keep legacy single-row checkpoint table in sync for older UI.
  try {
    db.prepare(
      `INSERT INTO agent_run_checkpoints (run_id, version, phase, state_json)
       VALUES (?, ?, ?, ?)
       ON CONFLICT(run_id) DO UPDATE SET
         version = excluded.version,
         phase = excluded.phase,
         state_json = excluded.state_json,
         updated_at = datetime('now')`,
    ).run(runId, version, String(phase || 'checkpoint'), JSON.stringify(payload));
  } catch {
    // Optional on fresh schemas where legacy table may differ.
  }

  if (eventBus && userId) {
    eventBus.publish({
      runId,
      userId,
      agentId,
      eventType: EVENT_TYPES.CHECKPOINT_SAVED,
      payload: { checkpoint_id: id, version, phase },
      visibility: VISIBILITY.OPERATOR,
    });
  }

  return { id, runId, version, phase, state: payload };
}

function loadLatestCheckpoint(runId) {
  const row = db.prepare(
    `SELECT * FROM agent_runtime_checkpoints
     WHERE run_id = ?
     ORDER BY version DESC
     LIMIT 1`,
  ).get(runId);
  if (!row) return null;
  let state = {};
  try {
    state = JSON.parse(row.state_json || '{}');
  } catch {
    state = {};
  }
  return {
    id: row.id,
    runId: row.run_id,
    version: Number(row.version || 1),
    phase: row.phase,
    state,
    createdAt: row.created_at,
  };
}

function listCheckpoints(runId, { limit = 20 } = {}) {
  return db.prepare(
    `SELECT id, run_id, version, phase, state_json, created_at
     FROM agent_runtime_checkpoints
     WHERE run_id = ?
     ORDER BY version DESC
     LIMIT ?`,
  ).all(runId, Math.max(1, Math.min(Number(limit) || 20, 100))).map((row) => {
    let state = {};
    try {
      state = JSON.parse(row.state_json || '{}');
    } catch {
      state = {};
    }
    return {
      id: row.id,
      runId: row.run_id,
      version: Number(row.version || 1),
      phase: row.phase,
      state,
      createdAt: row.created_at,
    };
  });
}

module.exports = {
  saveCheckpoint,
  loadLatestCheckpoint,
  listCheckpoints,
};
