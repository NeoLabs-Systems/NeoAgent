'use strict';

const crypto = require('crypto');
const db = require('../../db/database');
const { createIntegrationRegistry } = require('./registry');

class IntegrationManager {
  constructor() {
    this.registry = createIntegrationRegistry();
  }

  getProvider(providerKey) {
    return this.registry.get(providerKey);
  }

  cleanupExpiredOauthStates() {
    db.prepare(
      "DELETE FROM integration_oauth_states WHERE datetime(expires_at) <= datetime('now')",
    ).run();
  }

  getConnection(userId, providerKey) {
    return db
      .prepare(
        'SELECT * FROM integration_connections WHERE user_id = ? AND provider_key = ?',
      )
      .get(userId, providerKey);
  }

  listConnections(userId) {
    const rows = db
      .prepare('SELECT * FROM integration_connections WHERE user_id = ?')
      .all(userId);
    return new Map(rows.map((row) => [row.provider_key, row]));
  }

  listProviders(userId) {
    this.cleanupExpiredOauthStates();
    const connections = this.listConnections(userId);
    return this.registry
      .list()
      .map((provider) =>
        provider.buildSnapshot(connections.get(provider.key) || null),
      );
  }

  async beginOAuth(userId, providerKey) {
    this.cleanupExpiredOauthStates();
    const provider = this.getProvider(providerKey);
    if (!provider) {
      throw new Error(`Unknown integration provider: ${providerKey}`);
    }

    const env = provider.getEnvStatus();
    if (!env.configured) {
      throw new Error(env.summary);
    }

    const state = crypto.randomBytes(24).toString('hex');
    const codeVerifier = crypto.randomBytes(48).toString('base64url');
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000).toISOString();
    const { url } = await provider.beginOAuth({ state, codeVerifier, userId });

    db.prepare(
      `INSERT INTO integration_oauth_states (user_id, provider_key, state, code_verifier, expires_at)
       VALUES (?, ?, ?, ?, ?)`,
    ).run(userId, provider.key, state, codeVerifier, expiresAt);

    db.prepare(
      `INSERT INTO integration_connections (user_id, provider_key, status, metadata_json, updated_at)
       VALUES (?, ?, 'authorizing', '{}', datetime('now'))
       ON CONFLICT(user_id, provider_key) DO UPDATE SET
         status = 'authorizing',
         updated_at = datetime('now')`,
    ).run(userId, provider.key);

    return {
      provider: provider.key,
      status: 'oauth_redirect',
      url,
    };
  }

  async finishOAuth(state, code) {
    this.cleanupExpiredOauthStates();
    const stateRow = db
      .prepare(
        `SELECT * FROM integration_oauth_states
         WHERE state = ? AND datetime(expires_at) > datetime('now')`,
      )
      .get(state);
    if (!stateRow) {
      throw new Error('OAuth state is missing or expired.');
    }

    const provider = this.getProvider(stateRow.provider_key);
    if (!provider) {
      throw new Error(`Unknown integration provider: ${stateRow.provider_key}`);
    }

    const result = await provider.finishOAuth({
      userId: stateRow.user_id,
      state: stateRow.state,
      code,
      codeVerifier: stateRow.code_verifier,
    });

    db.prepare(
      `INSERT INTO integration_connections (
         user_id,
         provider_key,
         status,
         account_email,
         scopes_json,
         credentials_json,
         metadata_json,
         last_connected_at,
         updated_at
       ) VALUES (?, ?, 'connected', ?, ?, ?, ?, datetime('now'), datetime('now'))
       ON CONFLICT(user_id, provider_key) DO UPDATE SET
         status = 'connected',
         account_email = excluded.account_email,
         scopes_json = excluded.scopes_json,
         credentials_json = excluded.credentials_json,
         metadata_json = excluded.metadata_json,
         last_connected_at = excluded.last_connected_at,
         updated_at = excluded.updated_at`,
    ).run(
      stateRow.user_id,
      provider.key,
      result.accountEmail,
      JSON.stringify(result.scopes || []),
      JSON.stringify(result.credentials || {}),
      JSON.stringify(result.metadata || {}),
    );

    db.prepare('DELETE FROM integration_oauth_states WHERE state = ?').run(
      stateRow.state,
    );

    return {
      provider: provider.key,
      accountEmail: result.accountEmail,
    };
  }

  async disconnect(userId, providerKey) {
    const provider = this.getProvider(providerKey);
    if (!provider) {
      throw new Error(`Unknown integration provider: ${providerKey}`);
    }

    const connection = this.getConnection(userId, provider.key);
    if (!connection) {
      return { disconnected: true, provider: provider.key, existed: false };
    }

    await provider.disconnect(connection).catch(() => {});
    db.prepare(
      'DELETE FROM integration_connections WHERE user_id = ? AND provider_key = ?',
    ).run(userId, provider.key);
    db.prepare(
      'DELETE FROM integration_oauth_states WHERE user_id = ? AND provider_key = ?',
    ).run(userId, provider.key);

    return { disconnected: true, provider: provider.key, existed: true };
  }

  getToolDefinitions(userId) {
    const definitions = [];
    for (const provider of this.registry.list()) {
      const env = provider.getEnvStatus();
      const connection = this.getConnection(userId, provider.key);
      if (!env.configured || connection?.status !== 'connected') continue;
      definitions.push(...provider.getToolDefinitions());
    }
    return definitions;
  }

  getToolStatus(userId, providerKey) {
    const provider = this.getProvider(providerKey);
    if (!provider) {
      throw new Error(`Unknown integration provider: ${providerKey}`);
    }
    const env = provider.getEnvStatus();
    const connection = this.getConnection(userId, provider.key);
    const tools =
      env.configured && connection?.status === 'connected'
        ? provider.getToolDefinitions()
        : [];
    return {
      provider: provider.key,
      connection: provider.buildSnapshot(connection).connection,
      toolCount: tools.length,
      tools: tools.map((tool) => tool.name),
    };
  }

  async executeTool(userId, toolName, args) {
    for (const provider of this.registry.list()) {
      if (!provider.supportsTool(toolName)) continue;
      const env = provider.getEnvStatus();
      if (!env.configured) {
        return { error: env.summary };
      }

      const connection = this.getConnection(userId, provider.key);
      if (!connection || connection.status !== 'connected') {
        return { error: `${provider.label} is not connected for this user.` };
      }

      const execution = await provider.executeTool(toolName, args, connection);
      if (!execution) return null;

      if (execution.credentials) {
        db.prepare(
          `UPDATE integration_connections
           SET credentials_json = ?, updated_at = datetime('now')
           WHERE user_id = ? AND provider_key = ?`,
        ).run(JSON.stringify(execution.credentials), userId, provider.key);
      }

      return execution.result;
    }

    return null;
  }

  summarizeConnectedProviders(userId) {
    const providers = this.registry
      .list()
      .map((provider) => {
        const connection = this.getConnection(userId, provider.key);
        return {
          provider,
          snapshot: provider.buildSnapshot(connection),
        };
      })
      .filter(({ snapshot }) => snapshot.connection.connected);

    if (providers.length === 0) {
      return 'No official integrations are connected.';
    }

    return providers
      .map(({ provider, snapshot }) => {
        const appLabels = snapshot.apps.map((app) => app.label).join(', ');
        return `${provider.label}: connected as ${snapshot.connection.accountEmail || 'unknown'} (${appLabels})`;
      })
      .join('\n');
  }
}

module.exports = {
  IntegrationManager,
};
