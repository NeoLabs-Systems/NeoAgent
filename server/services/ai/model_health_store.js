'use strict';

const db = require('../../db/database');
const { createServiceLogger } = require('../../utils/logger');

const logger = createServiceLogger('ModelHealth');

function hasUser(userId) {
  try {
    return Boolean(db.prepare('SELECT 1 FROM users WHERE id = ?').get(userId));
  } catch {
    return false;
  }
}

function saveFailure(entry) {
  if (!hasUser(entry.userId)) return;
  try {
    db.prepare(
      `INSERT INTO ai_model_health (
         user_id, agent_id, provider_id, model_selection_id, failure_scope,
         failure_class, failure_count, last_status, cooldown_until_ms
       ) VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?)
       ON CONFLICT(user_id, agent_id, provider_id, model_selection_id) DO UPDATE SET
         failure_scope = excluded.failure_scope,
         failure_class = excluded.failure_class,
         failure_count = ai_model_health.failure_count + 1,
         last_status = excluded.last_status,
         cooldown_until_ms = MAX(ai_model_health.cooldown_until_ms, excluded.cooldown_until_ms),
         updated_at = datetime('now')`,
    ).run(
      entry.userId,
      entry.agentId,
      entry.providerId,
      entry.modelSelectionId,
      entry.scope,
      entry.failureClass,
      entry.status,
      entry.expiresAt,
    );
  } catch (error) {
    logger.warn('Could not persist model health state.', error);
  }
}

function clearFailures(userId, agentId, providerId, modelSelectionIds) {
  if (!hasUser(userId)) return false;
  try {
    const result = db.prepare(
      `DELETE FROM ai_model_health
       WHERE user_id = ? AND agent_id = ? AND provider_id = ?
         AND model_selection_id IN (?, ?)`,
    ).run(
      userId,
      agentId,
      providerId,
      modelSelectionIds[0],
      modelSelectionIds[1],
    );
    return result.changes > 0;
  } catch (error) {
    logger.warn('Could not clear model health state.', error);
    return false;
  }
}

function listActiveFailures(userId, agentId, now) {
  if (!hasUser(userId)) return [];
  try {
    db.prepare(
      `DELETE FROM ai_model_health
       WHERE user_id = ? AND agent_id = ? AND cooldown_until_ms <= ?`,
    ).run(userId, agentId, now);
    return db.prepare(
      `SELECT provider_id, model_selection_id, failure_scope
       FROM ai_model_health
       WHERE user_id = ? AND agent_id = ? AND cooldown_until_ms > ?`,
    ).all(userId, agentId, now);
  } catch (error) {
    logger.warn('Could not read model health state.', error);
    return [];
  }
}

module.exports = {
  clearFailures,
  listActiveFailures,
  saveFailure,
};
