'use strict';

const db = require('../../db/database');

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

module.exports = { upsertConnectedIntegration };
