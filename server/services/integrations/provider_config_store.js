'use strict';

const db = require('../../db/database');
const { decryptValue, encryptValue } = require('./secrets');
const { resolveAgentId } = require('../agents/manager');

function normalizeProviderKey(providerKey) {
  return String(providerKey || '').trim();
}

function parseConfig(value) {
  try {
    const parsed = JSON.parse(decryptValue(value || '{}') || '{}');
    return parsed && typeof parsed === 'object' ? parsed : {};
  } catch {
    return {};
  }
}

function getProviderConfig(userId, providerKey, agentId = null) {
  const normalizedProviderKey = normalizeProviderKey(providerKey);
  const normalizedUserId = Number(userId);
  if (!Number.isInteger(normalizedUserId) || normalizedUserId <= 0 || !normalizedProviderKey) {
    return {};
  }
  const scopedAgentId = resolveAgentId(normalizedUserId, agentId);

  const row = db
    .prepare(
      `SELECT config_json
       FROM integration_provider_configs
       WHERE user_id = ? AND agent_id = ? AND provider_key = ?`,
    )
    .get(normalizedUserId, scopedAgentId, normalizedProviderKey);

  return parseConfig(row?.config_json);
}

function setProviderConfig(userId, providerKey, config, agentId = null) {
  const normalizedProviderKey = normalizeProviderKey(providerKey);
  const normalizedUserId = Number(userId);
  if (!Number.isInteger(normalizedUserId) || normalizedUserId <= 0 || !normalizedProviderKey) {
    throw new Error('A valid user and provider are required to save integration config.');
  }
  const scopedAgentId = resolveAgentId(normalizedUserId, agentId);

  const payload = config && typeof config === 'object' ? config : {};
  db.prepare(
    `INSERT INTO integration_provider_configs (
       user_id,
       agent_id,
       provider_key,
       config_json,
       created_at,
       updated_at
     ) VALUES (?, ?, ?, ?, datetime('now'), datetime('now'))
     ON CONFLICT(user_id, agent_id, provider_key) DO UPDATE SET
       config_json = excluded.config_json,
       updated_at = excluded.updated_at`,
  ).run(
    normalizedUserId,
    scopedAgentId,
    normalizedProviderKey,
    encryptValue(JSON.stringify(payload)),
  );
}

function deleteProviderConfig(userId, providerKey, agentId = null) {
  const normalizedProviderKey = normalizeProviderKey(providerKey);
  const normalizedUserId = Number(userId);
  if (!Number.isInteger(normalizedUserId) || normalizedUserId <= 0 || !normalizedProviderKey) {
    return;
  }
  const scopedAgentId = resolveAgentId(normalizedUserId, agentId);

  db.prepare(
    'DELETE FROM integration_provider_configs WHERE user_id = ? AND agent_id = ? AND provider_key = ?',
  ).run(normalizedUserId, scopedAgentId, normalizedProviderKey);
}

module.exports = {
  deleteProviderConfig,
  getProviderConfig,
  setProviderConfig,
};
