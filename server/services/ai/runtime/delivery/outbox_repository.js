'use strict';

const { createHash, randomUUID } = require('crypto');
const db = require('../../../../db/database');
const { MESSAGE_KINDS } = require('../constants');

function contentHash(content) {
  // Whitespace only: "aBc" and "ABC" are different messages, as a code or a key.
  const normalized = String(content || '').replace(/\s+/g, ' ').trim();
  return createHash('sha256').update(normalized).digest('hex');
}

function serialize(row) {
  if (!row) return null;
  let payload = {};
  try {
    payload = JSON.parse(row.payload_json || '{}');
  } catch {
    payload = {};
  }
  return {
    id: row.id,
    runId: row.run_id,
    scopeId: row.scope_id || row.run_id,
    channel: row.channel,
    recipient: row.recipient || null,
    messageKind: row.message_kind,
    purpose: row.purpose || null,
    slot: row.slot || null,
    sequence: Number(row.sequence || 1),
    contentHash: row.semantic_hash || null,
    payload,
    status: row.status,
    platformMessageId: row.platform_message_id || null,
    idempotencyKey: row.idempotency_key || null,
    createdAt: row.created_at,
    deliveredAt: row.delivered_at || null,
  };
}

function nextSequence(runId, channel, messageKind) {
  return Number(
    db.prepare(
      `SELECT COALESCE(MAX(sequence), 0) AS max_seq
       FROM agent_outbox
       WHERE run_id = ? AND channel = ? AND message_kind = ?`,
    ).get(runId, channel, messageKind)?.max_seq || 0,
  ) + 1;
}

function bySlot(scopeId, recipient, purpose, slot) {
  return serialize(db.prepare(
    `SELECT * FROM agent_outbox
     WHERE scope_id = ? AND COALESCE(recipient, '') = ? AND purpose = ? AND slot = ?`,
  ).get(scopeId, String(recipient || ''), purpose, slot));
}

// A failed attempt was confirmed not delivered, so its slot opens again. Every
// other status means the message went out, may have gone out, or is on its way.
const reserveTx = db.transaction(({
  runId, scopeId, channel, recipient, messageKind, purpose, slot, payload,
}) => {
  const existing = bySlot(scopeId, recipient, purpose, slot);
  if (existing && existing.status !== 'failed') return { entry: existing, fresh: false };
  if (existing) {
    db.prepare(
      `UPDATE agent_outbox SET status = 'pending', payload_json = ?, semantic_hash = ? WHERE id = ?`,
    ).run(JSON.stringify(payload || {}), contentHash(payload?.content), existing.id);
    return { entry: serialize(db.prepare('SELECT * FROM agent_outbox WHERE id = ?').get(existing.id)), fresh: true };
  }
  const id = randomUUID();
  db.prepare(
    `INSERT INTO agent_outbox (
      id, run_id, scope_id, channel, recipient, message_kind, purpose, slot, sequence,
      semantic_hash, payload_json, status
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending')`,
  ).run(
    id,
    runId,
    scopeId,
    channel,
    recipient,
    messageKind,
    purpose,
    slot,
    nextSequence(runId, channel, messageKind),
    contentHash(payload?.content),
    JSON.stringify(payload || {}),
  );
  return { entry: serialize(db.prepare('SELECT * FROM agent_outbox WHERE id = ?').get(id)), fresh: true };
});

/**
 * Reserves the one slot a message may use. The unique index makes a second
 * delivery of the same slot an impossible state, whichever path asks for it.
 */
function reserve(input) {
  if (!input?.runId || !input?.channel || !input?.purpose || !input?.slot) {
    throw new Error('A delivery reservation needs runId, channel, purpose, and slot.');
  }
  if (!Object.values(MESSAGE_KINDS).includes(input.messageKind)) {
    throw new Error(`Unsupported message kind: ${input.messageKind}`);
  }
  return reserveTx.immediate({ ...input, scopeId: input.scopeId || input.runId });
}

// The same text already reached this recipient in this run, under any slot, or
// may have: a send of unknown outcome counts, so it is never followed by a second.
function findDeliveredContent(scopeId, recipient, content, excludeId = null) {
  return serialize(db.prepare(
    `SELECT * FROM agent_outbox
     WHERE scope_id = ? AND COALESCE(recipient, '') = ? AND semantic_hash = ?
       AND status IN ('delivered', 'ambiguous') AND id != ?
     LIMIT 1`,
  ).get(scopeId, String(recipient || ''), contentHash(content), excludeId || ''));
}

function markDelivered(outboxId, { platformMessageId = null } = {}) {
  db.prepare(
    `UPDATE agent_outbox
     SET status = 'delivered',
         platform_message_id = COALESCE(?, platform_message_id),
         delivered_at = datetime('now')
     WHERE id = ?`,
  ).run(platformMessageId, outboxId);
  return serialize(db.prepare('SELECT * FROM agent_outbox WHERE id = ?').get(outboxId));
}

function markSuppressed(outboxId) {
  db.prepare("UPDATE agent_outbox SET status = 'suppressed' WHERE id = ?").run(outboxId);
}

function markFailed(outboxId, { ambiguous = false } = {}) {
  db.prepare('UPDATE agent_outbox SET status = ? WHERE id = ?')
    .run(ambiguous ? 'ambiguous' : 'failed', outboxId);
  return serialize(db.prepare('SELECT * FROM agent_outbox WHERE id = ?').get(outboxId));
}

function recordAttempt(outboxId, {
  status,
  platformMessageId = null,
  error = null,
} = {}) {
  const outbox = db.prepare('SELECT run_id FROM agent_outbox WHERE id = ?').get(outboxId);
  if (!outbox) return null;
  const attemptNo = Number(
    db.prepare(
      'SELECT COALESCE(MAX(attempt_no), 0) AS n FROM agent_delivery_attempts WHERE outbox_id = ?',
    ).get(outboxId)?.n || 0,
  ) + 1;
  const id = randomUUID();
  db.prepare(
    `INSERT INTO agent_delivery_attempts (
      id, outbox_id, run_id, attempt_no, status, platform_message_id, error
    ) VALUES (?, ?, ?, ?, ?, ?, ?)`,
  ).run(
    id,
    outboxId,
    outbox.run_id,
    attemptNo,
    status,
    platformMessageId,
    error ? String(error).slice(0, 2000) : null,
  );
  return id;
}

function listForRun(runId, { messageKind = null } = {}) {
  if (messageKind) {
    return db.prepare(
      'SELECT * FROM agent_outbox WHERE run_id = ? AND message_kind = ? ORDER BY sequence ASC',
    ).all(runId, messageKind).map(serialize);
  }
  return db.prepare(
    'SELECT * FROM agent_outbox WHERE run_id = ? ORDER BY created_at ASC',
  ).all(runId).map(serialize);
}

function countFinalDeliveries(runId) {
  return Number(
    db.prepare(
      `SELECT COUNT(*) AS n FROM agent_outbox
       WHERE run_id = ? AND message_kind = 'final' AND status = 'delivered'`,
    ).get(runId)?.n || 0,
  );
}

// After a crash, a reservation still pending may or may not have reached the
// platform. A final answer whose claim never landed certainly did not, because
// the claim comes before the send; anything else stays unknown and is never
// sent again.
function settleOrphanedReservations(runId) {
  const claimed = db.prepare('SELECT final_delivery_id FROM agent_runs WHERE id = ?').get(runId)?.final_delivery_id || null;
  db.prepare(
    `UPDATE agent_outbox SET status = 'failed'
     WHERE run_id = ? AND status = 'pending' AND message_kind = 'final' AND id != ?`,
  ).run(runId, claimed || '');
  db.prepare(
    "UPDATE agent_outbox SET status = 'ambiguous' WHERE run_id = ? AND status = 'pending'",
  ).run(runId);
}

module.exports = {
  contentHash,
  countFinalDeliveries,
  findDeliveredContent,
  listForRun,
  markDelivered,
  markFailed,
  markSuppressed,
  recordAttempt,
  reserve,
  settleOrphanedReservations,
  MESSAGE_KINDS,
};
