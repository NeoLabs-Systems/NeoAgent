'use strict';

const db = require('../../db/database');
const { getConnectionAccessMode } = require('./access');
const { encryptValue } = require('./secrets');
const { parseJsonObject } = require('../../utils/text');

// Connecting an account is the same write for every provider: one row per
// (user, agent, provider, app, account), refreshed in place when the same
// account reconnects. Callers pass credentials already serialized, because only
// they know whether the payload needs encrypting.
function upsertConnectedIntegration({
  userId,
  agentId,
  providerKey,
  appKey,
  accountEmail,
  scopes = [],
  credentialsJson,
  metadata = {},
}) {
  return db.prepare(
    `INSERT INTO integration_connections (
       user_id,
       agent_id,
       provider_key,
       app_key,
       status,
       account_email,
       scopes_json,
       credentials_json,
       metadata_json,
       last_connected_at,
       updated_at
     ) VALUES (?, ?, ?, ?, 'connected', ?, ?, ?, ?, datetime('now'), datetime('now'))
     ON CONFLICT(user_id, agent_id, provider_key, app_key, account_email) DO UPDATE SET
       status = 'connected',
       scopes_json = excluded.scopes_json,
       credentials_json = excluded.credentials_json,
       metadata_json = excluded.metadata_json,
       last_connected_at = excluded.last_connected_at,
       updated_at = excluded.updated_at`,
  ).run(
    userId,
    agentId,
    providerKey,
    appKey,
    accountEmail,
    JSON.stringify(scopes),
    credentialsJson,
    JSON.stringify(metadata),
  );
}

function findAppConnection({ userId, agentId, providerKey, appKey, accountEmail }) {
  return db.prepare(`SELECT * FROM integration_connections
    WHERE user_id=? AND agent_id=? AND provider_key=? AND app_key=? AND account_email=?`)
    .get(userId, agentId, providerKey, appKey, accountEmail);
}

// Connecting one app of an account with plain credentials: encrypts them and
// keeps the Read Only / Read Write choice the person already made for it.
function upsertAccountApp({ credentials, metadata = {}, ...key }) {
  const existing = findAppConnection(key);
  upsertConnectedIntegration({
    ...key,
    scopes: key.scopes || [],
    credentialsJson: encryptValue(JSON.stringify(credentials)),
    metadata: {
      ...parseJsonObject(existing?.metadata_json),
      ...metadata,
      access_mode: getConnectionAccessMode(existing || null),
    },
  });
  return findAppConnection(key);
}

// One sign-in can back several apps (one row each). Disconnecting any of them
// disconnects the account, so the other rows go too.
function deleteSiblingConnections(connection) {
  db.prepare(`DELETE FROM integration_connections
    WHERE user_id=? AND agent_id=? AND provider_key=? AND account_email=? AND id!=?`)
    .run(
      connection.user_id,
      connection.agent_id,
      connection.provider_key,
      connection.account_email,
      connection.id,
    );
}

module.exports = { deleteSiblingConnections, upsertAccountApp, upsertConnectedIntegration };
