'use strict';

const { createHash, randomUUID } = require('crypto');
const db = require('../../../../db/database');
const { MESSAGE_KINDS } = require('../constants');

function semanticHash(payload) {
  const normalized = JSON.stringify(payload || {});
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
    channel: row.channel,
    recipient: row.recipient || null,
    messageKind: row.message_kind,
    sequence: Number(row.sequence || 1),
    semanticHash: row.semantic_hash || null,
    payload,
    status: row.status,
    platformMessageId: row.platform_message_id || null,
    idempotencyKey: row.idempotency_key || null,
    leaseOwner: row.lease_owner || null,
    leaseExpiresAt: row.lease_expires_at || null,
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

function enqueue({
  runId,
  channel,
  recipient = null,
  messageKind,
  payload = {},
  idempotencyKey = null,
  sequence = null,
}) {
  if (!runId || !channel || !messageKind) {
    throw new Error('outbox enqueue requires runId, channel, and messageKind');
  }
  if (!Object.values(MESSAGE_KINDS).includes(messageKind)) {
    throw new Error(`Unsupported message kind: ${messageKind}`);
  }

  if (idempotencyKey) {
    const existing = db.prepare(
      `SELECT * FROM agent_outbox WHERE channel = ? AND idempotency_key = ?`,
    ).get(channel, idempotencyKey);
    if (existing) return serialize(existing);
  }

  const id = randomUUID();
  const seq = sequence != null ? Number(sequence) : nextSequence(runId, channel, messageKind);
  const hash = semanticHash({
    runId,
    channel,
    recipient,
    messageKind,
    payload,
  });

  try {
    db.prepare(
      `INSERT INTO agent_outbox (
        id, run_id, channel, recipient, message_kind, sequence, semantic_hash,
        payload_json, status, idempotency_key
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?)`,
    ).run(
      id,
      runId,
      channel,
      recipient,
      messageKind,
      seq,
      hash,
      JSON.stringify(payload || {}),
      idempotencyKey,
    );
  } catch (error) {
    if (/unique/i.test(String(error?.message || ''))) {
      const existing = db.prepare(
        `SELECT * FROM agent_outbox
         WHERE run_id = ? AND channel = ? AND message_kind = ? AND sequence = ?`,
      ).get(runId, channel, messageKind, seq);
      if (existing) return serialize(existing);
    }
    throw error;
  }

  return serialize(db.prepare('SELECT * FROM agent_outbox WHERE id = ?').get(id));
}


function markDelivered(outboxId, { platformMessageId = null } = {}) {
  db.prepare(
    `UPDATE agent_outbox
     SET status = 'delivered',
         platform_message_id = COALESCE(?, platform_message_id),
         delivered_at = datetime('now'),
         lease_owner = NULL,
         lease_expires_at = NULL
     WHERE id = ?`,
  ).run(platformMessageId, outboxId);
  return serialize(db.prepare('SELECT * FROM agent_outbox WHERE id = ?').get(outboxId));
}

function markFailed(outboxId, { ambiguous = false, error = null } = {}) {
  db.prepare(
    `UPDATE agent_outbox
     SET status = ?,
         lease_owner = NULL,
         lease_expires_at = NULL
     WHERE id = ?`,
  ).run(ambiguous ? 'ambiguous' : 'failed', outboxId);

  if (error) {
    db.prepare(
      `INSERT INTO agent_delivery_attempts (
        id, outbox_id, run_id, attempt_no, status, error
      ) VALUES (?, ?, (SELECT run_id FROM agent_outbox WHERE id = ?), 1, ?, ?)`,
    ).run(randomUUID(), outboxId, outboxId, ambiguous ? 'ambiguous' : 'failed', String(error).slice(0, 2000));
  }

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
      `SELECT * FROM agent_outbox WHERE run_id = ? AND message_kind = ? ORDER BY sequence ASC`,
    ).all(runId, messageKind).map(serialize);
  }
  return db.prepare(
    `SELECT * FROM agent_outbox WHERE run_id = ? ORDER BY created_at ASC`,
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


module.exports = {
  enqueue,
  markDelivered,
  markFailed,
  recordAttempt,
  listForRun,
  countFinalDeliveries,
  MESSAGE_KINDS,
};
