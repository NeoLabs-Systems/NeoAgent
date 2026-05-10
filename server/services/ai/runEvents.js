'use strict';

const db = require('../../db/database');

function parseJsonObject(value, fallback = {}) {
  if (!value) return { ...fallback };
  if (typeof value === 'object' && !Array.isArray(value)) return { ...value };
  try {
    const parsed = JSON.parse(String(value));
    return parsed && typeof parsed === 'object' && !Array.isArray(parsed)
      ? parsed
      : { ...fallback };
  } catch {
    return { ...fallback };
  }
}

function recordRunEvent({
  runId,
  userId,
  agentId = null,
  eventType,
  requestId = null,
  stepId = null,
  sequenceIndex = null,
  payload = {},
}) {
  if (!runId || !userId || !eventType) return null;
  const payloadJson = JSON.stringify(
    payload && typeof payload === 'object' && !Array.isArray(payload) ? payload : {},
  );
  const row = db.transaction(() => {
    const resolvedSequence = Number.isInteger(sequenceIndex) && sequenceIndex > 0
      ? sequenceIndex
      : Number(
        db.prepare(
          'SELECT COALESCE(MAX(sequence_index), 0) AS max_sequence FROM agent_run_events WHERE run_id = ?'
        ).get(runId)?.max_sequence || 0,
      ) + 1;
    const result = db.prepare(
      `INSERT INTO agent_run_events (
        run_id, user_id, agent_id, event_type, request_id, step_id, sequence_index, payload_json
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
    ).run(
      runId,
      userId,
      agentId || null,
      eventType,
      requestId || null,
      stepId || null,
      resolvedSequence,
      payloadJson,
    );
    return db.prepare(
      `SELECT id, run_id, user_id, agent_id, event_type, request_id, step_id, sequence_index, payload_json, created_at
       FROM agent_run_events
       WHERE id = ?`
    ).get(result.lastInsertRowid);
  })();

  return row ? {
    id: Number(row.id),
    runId: row.run_id,
    userId: row.user_id,
    agentId: row.agent_id || null,
    eventType: row.event_type,
    requestId: row.request_id || null,
    stepId: row.step_id || null,
    sequenceIndex: Number(row.sequence_index || 0),
    payload: parseJsonObject(row.payload_json, {}),
    createdAt: row.created_at,
  } : null;
}

function listRunEvents(runId) {
  if (!runId) return [];
  const rows = db.prepare(
    `SELECT id, run_id, user_id, agent_id, event_type, request_id, step_id, sequence_index, payload_json, created_at
     FROM agent_run_events
     WHERE run_id = ?
     ORDER BY sequence_index ASC, id ASC`
  ).all(runId);
  return rows.map((row) => ({
    id: Number(row.id),
    runId: row.run_id,
    userId: row.user_id,
    agentId: row.agent_id || null,
    eventType: row.event_type,
    requestId: row.request_id || null,
    stepId: row.step_id || null,
    sequenceIndex: Number(row.sequence_index || 0),
    payload: parseJsonObject(row.payload_json, {}),
    createdAt: row.created_at,
  }));
}

module.exports = {
  recordRunEvent,
  listRunEvents,
};
