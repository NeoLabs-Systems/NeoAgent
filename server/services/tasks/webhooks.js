'use strict';

const crypto = require('crypto');
const { v4: uuidv4 } = require('uuid');
const db = require('../../db/database');
const { encryptValue, decryptValue } = require('../integrations/secrets');

const MAX_PAYLOAD_BYTES = 256 * 1024;
const MAX_CLOCK_SKEW_MS = 5 * 60 * 1000;

function safeEqual(left, right) {
  const a = Buffer.from(String(left || ''), 'utf8');
  const b = Buffer.from(String(right || ''), 'utf8');
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

class TaskWebhookService {
  constructor(options = {}) {
    this.taskRuntime = options.taskRuntime;
  }

  rotateSecret(userId, taskId) {
    const task = this.taskRuntime.taskRepository.getTaskById(taskId, userId);
    if (!task) throw new Error('Task not found.');
    if (task.trigger_type !== 'webhook') throw new Error('Task does not use the webhook trigger.');
    const secret = crypto.randomBytes(32).toString('base64url');
    const fingerprint = crypto.createHash('sha256').update(secret).digest('hex').slice(0, 16);
    db.prepare(
      `INSERT INTO task_webhook_secrets (
        task_id, user_id, secret_encrypted, secret_fingerprint
      ) VALUES (?, ?, ?, ?)
      ON CONFLICT(task_id) DO UPDATE SET
        secret_encrypted = excluded.secret_encrypted,
        secret_fingerprint = excluded.secret_fingerprint,
        rotated_at = datetime('now')`
    ).run(taskId, userId, encryptValue(secret), fingerprint);
    return { taskId, secret, fingerprint };
  }

  getConfiguration(userId, taskId) {
    const task = this.taskRuntime.taskRepository.getTaskById(taskId, userId);
    if (!task) throw new Error('Task not found.');
    const row = db.prepare(
      `SELECT secret_fingerprint, rotated_at, created_at
       FROM task_webhook_secrets WHERE task_id = ? AND user_id = ?`
    ).get(taskId, userId);
    return {
      taskId,
      configured: Boolean(row),
      fingerprint: row?.secret_fingerprint || null,
      rotatedAt: row?.rotated_at || null,
      createdAt: row?.created_at || null,
    };
  }

  listDeliveries(userId, taskId, limit = 50) {
    return db.prepare(
      `SELECT id, request_id, payload_hash, status, response_json, created_at, completed_at
       FROM task_webhook_deliveries
       WHERE task_id = ? AND user_id = ?
       ORDER BY created_at DESC LIMIT ?`
    ).all(taskId, userId, Math.min(Math.max(Number(limit || 50), 1), 200)).map((row) => ({
      id: row.id,
      requestId: row.request_id,
      payloadHash: row.payload_hash,
      status: row.status,
      response: (() => {
        try { return JSON.parse(row.response_json || '{}'); } catch { return {}; }
      })(),
      createdAt: row.created_at,
      completedAt: row.completed_at,
    }));
  }

  async deliver(taskId, headers, rawBody, payload) {
    if (Buffer.byteLength(rawBody || '', 'utf8') > MAX_PAYLOAD_BYTES) {
      const error = new Error('Webhook payload exceeds 256 KiB.');
      error.status = 413;
      throw error;
    }
    const timestamp = Number(headers['x-neoagent-timestamp']);
    const requestId = String(headers['x-neoagent-request-id'] || '').trim();
    const supplied = String(headers['x-neoagent-signature'] || '').replace(/^sha256=/, '');
    if (!requestId || !Number.isFinite(timestamp) || !supplied) {
      const error = new Error('Missing webhook authentication headers.');
      error.status = 401;
      throw error;
    }
    if (Math.abs(Date.now() - timestamp) > MAX_CLOCK_SKEW_MS) {
      const error = new Error('Webhook timestamp is outside the allowed window.');
      error.status = 401;
      throw error;
    }
    const secretRow = db.prepare(
      `SELECT secrets.user_id, secrets.secret_encrypted, tasks.enabled, tasks.trigger_type
       FROM task_webhook_secrets AS secrets
       JOIN scheduled_tasks AS tasks ON tasks.id = secrets.task_id
       WHERE secrets.task_id = ?`
    ).get(taskId);
    if (!secretRow || !secretRow.enabled || secretRow.trigger_type !== 'webhook') {
      const error = new Error('Webhook task is unavailable.');
      error.status = 404;
      throw error;
    }
    const expected = crypto.createHmac('sha256', decryptValue(secretRow.secret_encrypted))
      .update(`${timestamp}.${rawBody || ''}`)
      .digest('hex');
    if (!safeEqual(expected, supplied)) {
      const error = new Error('Invalid webhook signature.');
      error.status = 401;
      throw error;
    }
    const deliveryId = uuidv4();
    const payloadHash = crypto.createHash('sha256').update(rawBody || '').digest('hex');
    try {
      db.prepare(
        `INSERT INTO task_webhook_deliveries (
          id, task_id, user_id, request_id, payload_hash, status
        ) VALUES (?, ?, ?, ?, ?, 'accepted')`
      ).run(deliveryId, taskId, secretRow.user_id, requestId, payloadHash);
    } catch (err) {
      if (err.code === 'SQLITE_CONSTRAINT_UNIQUE') {
        const replayError = new Error('Webhook request ID was already used.');
        replayError.status = 409;
        throw replayError;
      }
      throw err;
    }
    const result = await this.taskRuntime.fireTaskFromTrigger(taskId, secretRow.user_id, {
      fingerprint: requestId,
      timestamp: new Date(timestamp).toISOString(),
      context: { webhook: payload },
    });
    db.prepare(
      `UPDATE task_webhook_deliveries
       SET status = ?, response_json = ?, completed_at = datetime('now')
       WHERE id = ?`
    ).run(result?.error ? 'failed' : 'completed', JSON.stringify(result || {}), deliveryId);
    return { deliveryId, accepted: !result?.error, result };
  }
}

module.exports = {
  TaskWebhookService,
  MAX_PAYLOAD_BYTES,
};
