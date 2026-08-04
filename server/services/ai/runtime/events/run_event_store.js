'use strict';

const { randomUUID } = require('crypto');
const db = require('../../../../db/database');
const { VISIBILITY } = require('./event_types');

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

function appendEvent({
  runId,
  userId,
  agentId = null,
  eventType,
  payload = {},
  actor = null,
  causationId = null,
  correlationId = null,
  stepId = null,
  visibility = VISIBILITY.OPERATOR,
  sensitivity = 'internal',
}) {
  if (!runId || !userId || !eventType) return null;

  const eventId = randomUUID();
  const envelope = {
    event_id: eventId,
    schema_version: 1,
    actor: actor || null,
    causation_id: causationId || null,
    correlation_id: correlationId || runId,
    visibility,
    sensitivity,
    ...(payload && typeof payload === 'object' ? payload : { value: payload }),
  };

  const row = db.transaction(() => {
    const nextSequence = Number(
      db.prepare(
        'SELECT COALESCE(MAX(sequence_index), 0) AS max_sequence FROM agent_run_events WHERE run_id = ?',
      ).get(runId)?.max_sequence || 0,
    ) + 1;

    const result = db.prepare(
      `INSERT INTO agent_run_events (
        run_id, user_id, agent_id, event_type, request_id, step_id, sequence_index, payload_json
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    ).run(
      runId,
      userId,
      agentId || null,
      eventType,
      correlationId || null,
      stepId || null,
      nextSequence,
      JSON.stringify(envelope),
    );

    return db.prepare(
      `SELECT id, run_id, user_id, agent_id, event_type, request_id, step_id, sequence_index, payload_json, created_at
       FROM agent_run_events WHERE id = ?`,
    ).get(result.lastInsertRowid);
  })();

  if (!row) return null;
  return {
    id: Number(row.id),
    eventId,
    runId: row.run_id,
    userId: row.user_id,
    agentId: row.agent_id || null,
    eventType: row.event_type,
    requestId: row.request_id || null,
    stepId: row.step_id || null,
    sequenceIndex: Number(row.sequence_index || 0),
    payload: parseJsonObject(row.payload_json, {}),
    createdAt: row.created_at,
  };
}

function listEvents(runId, { afterSequence = 0, limit = 500 } = {}) {
  if (!runId) return [];
  const rows = db.prepare(
    `SELECT id, run_id, user_id, agent_id, event_type, request_id, step_id, sequence_index, payload_json, created_at
     FROM agent_run_events
     WHERE run_id = ? AND sequence_index > ?
     ORDER BY sequence_index ASC, id ASC
     LIMIT ?`,
  ).all(runId, Number(afterSequence) || 0, Math.max(1, Math.min(Number(limit) || 500, 5000)));

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

function getLatestSequence(runId) {
  if (!runId) return 0;
  return Number(
    db.prepare(
      'SELECT COALESCE(MAX(sequence_index), 0) AS max_sequence FROM agent_run_events WHERE run_id = ?',
    ).get(runId)?.max_sequence || 0,
  );
}

module.exports = {
  appendEvent,
  listEvents,
  getLatestSequence,
};
