'use strict';

const db = require('../../db/database');
const { decryptValue, encryptValue } = require('../integrations/secrets');
const { createServiceLogger } = require('../../utils/logger');
const { PLAN_USAGE_SCOPE, refreshCredentials, revokeRefreshToken } = require('./oauth');

const log = createServiceLogger('ChatGPT');
const PROVIDER_ID = 'chatgpt';
// Refresh slightly before expiry so a request never starts on a dying token.
const REFRESH_MARGIN_MS = 60 * 1000;

function readConnection(userId) {
  const row = db.prepare(
    `SELECT account_subject, account_email, credentials_json
     FROM user_model_connections
     WHERE user_id = ? AND provider_id = ?`,
  ).get(userId, PROVIDER_ID);
  if (!row) return null;
  try {
    const stored = JSON.parse(decryptValue(row.credentials_json));
    return {
      subject: row.account_subject,
      email: row.account_email || '',
      clientId: stored.clientId,
      credentials: stored.credentials,
    };
  } catch (error) {
    log.warn(`Stored connection for user ${userId} could not be read: ${error.message}`);
    return null;
  }
}

function saveConnection(userId, { subject, email, clientId, credentials }) {
  db.prepare(
    `INSERT INTO user_model_connections (
       user_id, provider_id, account_subject, account_email, credentials_json, updated_at
     ) VALUES (?, ?, ?, ?, ?, datetime('now'))
     ON CONFLICT(user_id, provider_id) DO UPDATE SET
       account_subject = excluded.account_subject,
       account_email = excluded.account_email,
       credentials_json = excluded.credentials_json,
       updated_at = excluded.updated_at`,
  ).run(
    userId,
    PROVIDER_ID,
    subject,
    email || null,
    encryptValue(JSON.stringify({ clientId, credentials })),
  );
}

// A user can sign in without sharing plan usage (the consent screen lets
// them decline it); such a connection identifies them but cannot run models.
function hasPlanUsage(connection) {
  return Array.isArray(connection?.credentials?.scopes)
    && connection.credentials.scopes.includes(PLAN_USAGE_SCOPE);
}

function getAccessToken(userId) {
  const connection = readConnection(userId);
  return hasPlanUsage(connection) ? connection.credentials.accessToken : '';
}

// Refresh tokens rotate, so concurrent requests for one user share a single
// refresh instead of each spending (and invalidating) the same token.
const refreshesInFlight = new Map();

function refreshAccessToken(userId) {
  if (!refreshesInFlight.has(userId)) {
    const refresh = (async () => {
      const connection = readConnection(userId);
      if (!connection) throw new Error('ChatGPT is not connected for this account.');
      const credentials = await refreshCredentials({
        clientId: connection.clientId,
        refreshToken: connection.credentials.refreshToken,
        subject: connection.subject,
        scopes: connection.credentials.scopes,
      });
      saveConnection(userId, { ...connection, credentials });
      return credentials.accessToken;
    })().finally(() => refreshesInFlight.delete(userId));
    refreshesInFlight.set(userId, refresh);
  }
  return refreshesInFlight.get(userId);
}

async function getFreshAccessToken(userId) {
  const connection = readConnection(userId);
  if (!hasPlanUsage(connection)) {
    throw new Error('ChatGPT plan usage is not connected for this account.');
  }
  if (connection.credentials.expiresAt - REFRESH_MARGIN_MS > Date.now()) {
    return connection.credentials.accessToken;
  }
  return refreshAccessToken(userId);
}

async function disconnect(userId) {
  const connection = readConnection(userId);
  db.prepare('DELETE FROM user_model_connections WHERE user_id = ? AND provider_id = ?')
    .run(userId, PROVIDER_ID);
  if (!connection?.credentials?.refreshToken) return;
  try {
    await revokeRefreshToken({
      clientId: connection.clientId,
      refreshToken: connection.credentials.refreshToken,
    });
  } catch (error) {
    log.warn(`Remote disconnect failed for user ${userId}; it can be removed in ChatGPT settings: ${error.message}`);
  }
}

module.exports = {
  PROVIDER_ID,
  disconnect,
  getAccessToken,
  getFreshAccessToken,
  hasPlanUsage,
  refreshAccessToken,
  saveConnection,
};
