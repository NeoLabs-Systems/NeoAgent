'use strict';

const { resolveAgentId } = require('../agents/manager');

function ensureOwnedIntegrationConnection(integrationManager, {
  userId,
  agentId,
  connectionId,
  providerKey,
  appKey = null,
}) {
  const numericConnectionId = Number(connectionId);
  if (!Number.isInteger(numericConnectionId) || numericConnectionId <= 0) {
    throw new Error('A valid integration connection is required.');
  }
  if (!integrationManager) {
    throw new Error('Official integration manager is not available.');
  }

  const scopedAgentId = resolveAgentId(userId, agentId);
  const connection = integrationManager.getConnectionById(
    userId,
    numericConnectionId,
    scopedAgentId,
  );
  if (!connection) {
    throw new Error('Integration connection not found for this agent.');
  }
  if (String(connection.provider_key || '').trim() !== String(providerKey || '').trim()) {
    throw new Error('Integration connection does not match the selected provider.');
  }
  if (appKey && String(connection.app_key || '').trim() !== String(appKey).trim()) {
    throw new Error('Integration connection does not match the selected app.');
  }
  if (String(connection.status || '').trim() !== 'connected') {
    throw new Error('Integration connection is not connected.');
  }

  return connection;
}

function normalizeBoolean(value, fallback = false) {
  if (typeof value === 'boolean') return value;
  if (typeof value === 'string') {
    const normalized = value.trim().toLowerCase();
    if (['true', '1', 'yes', 'on'].includes(normalized)) return true;
    if (['false', '0', 'no', 'off'].includes(normalized)) return false;
  }
  return fallback;
}

function normalizeTrimmedText(value, maxLength = 300) {
  return String(value || '').trim().slice(0, maxLength);
}

module.exports = {
  ensureOwnedIntegrationConnection,
  normalizeBoolean,
  normalizeTrimmedText,
};
