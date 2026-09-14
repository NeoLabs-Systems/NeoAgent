'use strict';

const { createHash, randomUUID } = require('crypto');
const db = require('../../../../db/database');
const { EVENT_TYPES, VISIBILITY } = require('../events/event_types');

const WRITE_CLASSES = Object.freeze({
  EPHEMERAL: 'ephemeral',
  EPISODIC: 'episodic',
  SEMANTIC: 'semantic',
  PROCEDURAL: 'procedural',
  DISCARD: 'discard',
});

function buildIdempotencyKey({
  userId,
  agentId = null,
  scope = {},
  subject = '',
  predicate = '',
  object = '',
  sourceEventId = '',
}) {
  return createHash('sha256').update(JSON.stringify({
    userId,
    agentId,
    scope,
    subject: String(subject || '').trim().toLowerCase(),
    predicate: String(predicate || '').trim().toLowerCase(),
    object: String(object || '').trim().toLowerCase(),
    sourceEventId: String(sourceEventId || ''),
  })).digest('hex');
}

/**
 * Atomic candidate enqueue. Durable semantic writes still go through MemoryManager,
 * but exact duplicates are prevented at the queue boundary.
 */
function enqueueCandidate({
  userId,
  agentId = null,
  runId = null,
  candidate = {},
  writeClass = WRITE_CLASSES.SEMANTIC,
  eventBus = null,
} = {}) {
  if (!userId || writeClass === WRITE_CLASSES.DISCARD || writeClass === WRITE_CLASSES.EPHEMERAL) {
    return { ok: true, skipped: true, reason: writeClass };
  }

  const idempotencyKey = candidate.idempotencyKey || buildIdempotencyKey({
    userId,
    agentId,
    scope: candidate.scope || {},
    subject: candidate.subject,
    predicate: candidate.predicate,
    object: candidate.object,
    sourceEventId: candidate.sourceEventId || candidate.source_event_id,
  });

  const existing = db.prepare(
    'SELECT id, status FROM agent_memory_write_queue WHERE idempotency_key = ?',
  ).get(idempotencyKey);
  if (existing) {
    return { ok: true, duplicate: true, id: existing.id, status: existing.status };
  }

  const id = randomUUID();
  db.prepare(
    `INSERT INTO agent_memory_write_queue (
      id, user_id, agent_id, run_id, candidate_json, write_class, status, idempotency_key
    ) VALUES (?, ?, ?, ?, ?, ?, 'pending', ?)`,
  ).run(
    id,
    userId,
    agentId,
    runId,
    JSON.stringify(candidate || {}),
    writeClass,
    idempotencyKey,
  );

  if (eventBus) {
    eventBus.publish({
      runId,
      userId,
      agentId,
      eventType: EVENT_TYPES.MEMORY_CANDIDATE,
      payload: { queue_id: id, write_class: writeClass },
      visibility: VISIBILITY.INTERNAL,
    });
  }

  return { ok: true, id, idempotencyKey };
}

module.exports = {
  WRITE_CLASSES,
  enqueueCandidate,
};
