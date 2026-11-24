'use strict';

const { randomUUID } = require('crypto');
const db = require('../../../../db/database');
const { parseJsonObject } = require('../../../../utils/text');
const { redactEventPayload } = require('./redact');
const { EVENT_SCHEMA_VERSION } = require('./event_types');

const EVENT_COLUMNS = 'id, run_id, user_id, agent_id, event_type, request_id, step_id, sequence_index, payload_json, created_at';

function mapEventRow(row) {
  return {
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
  };
}

/**
 * Appends to the run ledger. Events carry metadata only: raw prompts, tool
 * results, and memory text live in the run's captures, under their own expiry.
 */
function appendEvent({
  runId,
  userId,
  agentId = null,
  eventType,
  payload = {},
  actor = null,
  parentEventId = null,
  requestId = null,
  stepId = null,
}) {
  if (!runId || !userId || !eventType) return null;

  const eventId = randomUUID();
  const envelope = {
    schema_version: EVENT_SCHEMA_VERSION,
    event_id: eventId,
    parent_event_id: parentEventId || null,
    timestamp: new Date().toISOString(),
    actor: actor || null,
    ...redactEventPayload(payload && typeof payload === 'object' ? payload : { value: payload }),
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
      requestId || null,
      stepId || null,
      nextSequence,
      JSON.stringify(envelope),
    );

    return db.prepare(`SELECT ${EVENT_COLUMNS} FROM agent_run_events WHERE id = ?`)
      .get(result.lastInsertRowid);
  })();

  if (!row) return null;
  return { ...mapEventRow(row), eventId };
}

// Never lets telemetry take a run down: a failed write costs one event.
function recordEventSafe(input) {
  try {
    return appendEvent(input);
  } catch (error) {
    console.warn('[RunLedger] Could not record event:', input?.eventType, error?.message || error);
    return null;
  }
}

function listEvents(runId, { afterSequence = 0, limit = 5000 } = {}) {
  if (!runId) return [];
  return db.prepare(
    `SELECT ${EVENT_COLUMNS} FROM agent_run_events
     WHERE run_id = ? AND sequence_index > ?
     ORDER BY sequence_index ASC, id ASC
     LIMIT ?`,
  ).all(runId, Number(afterSequence) || 0, Math.max(1, Math.min(Number(limit) || 5000, 20000))).map(mapEventRow);
}

module.exports = {
  appendEvent,
  listEvents,
  recordEventSafe,
};
