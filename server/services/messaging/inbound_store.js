'use strict';

const { randomUUID } = require('node:crypto');
const db = require('../../db/database');

const MAX_INBOUND_PAYLOAD_BYTES = 1024 * 1024;
const JOB_STATUSES = new Set(['pending', 'processing', 'completed', 'failed']);

function encodePayload(payload) {
  const encoded = JSON.stringify(payload);
  if (Buffer.byteLength(encoded, 'utf8') > MAX_INBOUND_PAYLOAD_BYTES) {
    const error = new Error('Inbound messaging payload exceeds the 1 MiB durability limit.');
    error.code = 'MESSAGING_INBOUND_PAYLOAD_TOO_LARGE';
    throw error;
  }
  return encoded;
}

function decodePayload(value) {
  try {
    const payload = JSON.parse(String(value || ''));
    return payload && typeof payload === 'object' && !Array.isArray(payload)
      ? payload
      : null;
  } catch {
    return null;
  }
}

function getJobByMessageId(messageId) {
  return db.prepare(
    'SELECT * FROM messaging_inbound_jobs WHERE message_id = ?',
  ).get(messageId) || null;
}

function enqueueInboundMessage({
  userId,
  agentId,
  platform,
  platformMessageId,
  chatId,
  content,
  metadata,
  createdAt,
  payload,
}) {
  return db.transaction(() => {
    if (platformMessageId) {
      const existing = db.prepare(
        `SELECT id
         FROM messages
         WHERE user_id = ? AND platform = ? AND platform_msg_id = ? AND role = 'user'
         LIMIT 1`,
      ).get(userId, platform, platformMessageId);
      if (existing) {
        return {
          created: false,
          job: getJobByMessageId(existing.id),
          messageId: existing.id,
        };
      }
    }

    const jobId = randomUUID();
    const durablePayload = {
      ...payload,
      inboundJobId: jobId,
      inboundJobIds: [jobId],
    };
    const insert = db.prepare(
      `INSERT INTO messages (
        user_id, agent_id, role, content, platform, platform_msg_id,
        platform_chat_id, metadata, created_at
      ) VALUES (?, ?, 'user', ?, ?, ?, ?, ?, ?)`,
    ).run(
      userId,
      agentId,
      content,
      platform,
      platformMessageId || null,
      chatId,
      metadata ? JSON.stringify(metadata) : null,
      createdAt || new Date().toISOString(),
    );
    const messageId = Number(insert.lastInsertRowid);
    db.prepare(
      `INSERT INTO messaging_inbound_jobs (
        id, message_id, user_id, agent_id, platform, platform_msg_id,
        platform_chat_id, payload_json, status
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'pending')`,
    ).run(
      jobId,
      messageId,
      userId,
      agentId,
      platform,
      platformMessageId || null,
      chatId,
      encodePayload(durablePayload),
    );
    return {
      created: true,
      job: getJobByMessageId(messageId),
      messageId,
      payload: durablePayload,
    };
  })();
}

function claimInboundJob(jobId) {
  const result = db.prepare(
    `UPDATE messaging_inbound_jobs
     SET status = 'processing',
         attempts = attempts + 1,
         last_error = NULL,
         updated_at = datetime('now')
     WHERE id = ? AND status = 'pending'`,
  ).run(jobId);
  return result.changes === 1;
}

function settleInboundJob(jobId, status, error = null) {
  if (!JOB_STATUSES.has(status) || status === 'processing') {
    throw new Error(`Invalid inbound messaging job status: ${status}`);
  }
  db.prepare(
    `UPDATE messaging_inbound_jobs
     SET status = ?,
         last_error = ?,
         completed_at = CASE WHEN ? IN ('completed', 'failed') THEN datetime('now') ELSE NULL END,
         updated_at = datetime('now')
     WHERE id = ?`,
  ).run(
    status,
    error ? String(error).slice(0, 4000) : null,
    status,
    jobId,
  );
}

function attachRunToInboundJobs(jobIds, runId) {
  const ids = Array.from(new Set(
    (Array.isArray(jobIds) ? jobIds : [jobIds])
      .map((value) => String(value || '').trim())
      .filter(Boolean),
  ));
  if (!ids.length || !runId) return 0;
  const update = db.prepare(
    `UPDATE messaging_inbound_jobs
     SET run_id = ?, updated_at = datetime('now')
     WHERE id = ? AND status = 'processing'`,
  );
  return db.transaction(() => ids.reduce(
    (count, id) => count + update.run(runId, id).changes,
    0,
  ))();
}

function reconcileInterruptedInboundJobs() {
  return db.transaction(() => {
    const completed = db.prepare(
      `UPDATE messaging_inbound_jobs
       SET status = 'completed', completed_at = datetime('now'), updated_at = datetime('now')
       WHERE status = 'processing'
         AND run_id IN (SELECT id FROM agent_runs WHERE status = 'completed')`,
    ).run().changes;
    const failed = db.prepare(
      `UPDATE messaging_inbound_jobs
       SET status = 'failed',
           last_error = COALESCE(last_error, 'The server restarted after this agent run began; it will not be replayed automatically.'),
           completed_at = datetime('now'),
           updated_at = datetime('now')
       WHERE status = 'processing'
         AND run_id IN (SELECT id FROM agent_runs)`,
    ).run().changes;
    const pending = db.prepare(
      `UPDATE messaging_inbound_jobs
       SET status = 'pending',
           last_error = NULL,
           updated_at = datetime('now')
       WHERE status = 'processing'
         AND (run_id IS NULL OR run_id NOT IN (SELECT id FROM agent_runs))`,
    ).run().changes;
    return { completed, failed, pending };
  })();
}

function listPendingInboundJobs(filters = {}) {
  const clauses = ["status = 'pending'"];
  const values = [];
  for (const [column, value] of [
    ['user_id', filters.userId],
    ['agent_id', filters.agentId],
    ['platform', filters.platform],
  ]) {
    if (value === undefined) continue;
    if (value === null) clauses.push(`${column} IS NULL`);
    else {
      clauses.push(`${column} = ?`);
      values.push(value);
    }
  }
  const limit = Math.max(1, Math.min(500, Number(filters.limit) || 100));
  return db.prepare(
    `SELECT * FROM messaging_inbound_jobs
     WHERE ${clauses.join(' AND ')}
     ORDER BY created_at ASC, id ASC
     LIMIT ?`,
  ).all(...values, limit);
}

function payloadForInboundJob(job) {
  return decodePayload(job?.payload_json);
}

module.exports = {
  attachRunToInboundJobs,
  claimInboundJob,
  enqueueInboundMessage,
  listPendingInboundJobs,
  payloadForInboundJob,
  reconcileInterruptedInboundJobs,
  settleInboundJob,
};
