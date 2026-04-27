'use strict';

const db = require('../../db/database');
const { decryptValue, encryptValue } = require('./secrets');

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

function getProviderConfig(userId, providerKey) {
  const normalizedProviderKey = normalizeProviderKey(providerKey);
  if (!Number.isInteger(Number(userId)) || Number(userId) <= 0 || !normalizedProviderKey) {
    return {};
  }

  const row = db
    .prepare(
      `SELECT config_json
       FROM integration_provider_configs
       WHERE user_id = ? AND provider_key = ?`,
    )
    .get(Number(userId), normalizedProviderKey);

  return parseConfig(row?.config_json);
}

function setProviderConfig(userId, providerKey, config) {
  const normalizedProviderKey = normalizeProviderKey(providerKey);
  if (!Number.isInteger(Number(userId)) || Number(userId) <= 0 || !normalizedProviderKey) {
    throw new Error('A valid user and provider are required to save integration config.');
  }

  const payload = config && typeof config === 'object' ? config : {};
  db.prepare(
    `INSERT INTO integration_provider_configs (
       user_id,
       provider_key,
       config_json,
       created_at,
       updated_at
     ) VALUES (?, ?, ?, datetime('now'), datetime('now'))
     ON CONFLICT(user_id, provider_key) DO UPDATE SET
       config_json = excluded.config_json,
       updated_at = excluded.updated_at`,
  ).run(
    Number(userId),
    normalizedProviderKey,
    encryptValue(JSON.stringify(payload)),
  );
}

function deleteProviderConfig(userId, providerKey) {
  const normalizedProviderKey = normalizeProviderKey(providerKey);
  if (!Number.isInteger(Number(userId)) || Number(userId) <= 0 || !normalizedProviderKey) {
    return;
  }

  db.prepare(
    'DELETE FROM integration_provider_configs WHERE user_id = ? AND provider_key = ?',
  ).run(Number(userId), normalizedProviderKey);
}

module.exports = {
  deleteProviderConfig,
  getProviderConfig,
  setProviderConfig,
};
