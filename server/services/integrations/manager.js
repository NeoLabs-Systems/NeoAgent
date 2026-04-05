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

  listConnections(userId, providerKey = null) {
    const query = providerKey
      ? 'SELECT * FROM integration_connections WHERE user_id = ? AND provider_key = ? ORDER BY updated_at DESC, id DESC'
      : 'SELECT * FROM integration_connections WHERE user_id = ? ORDER BY updated_at DESC, id DESC';
    return providerKey
      ? db.prepare(query).all(userId, providerKey)
      : db.prepare(query).all(userId);
  }

  getConnectionById(userId, connectionId) {
    return db
      .prepare(
        'SELECT * FROM integration_connections WHERE user_id = ? AND id = ?',
      )
      .get(userId, connectionId);
  }

  listProviders(userId) {
    this.cleanupExpiredOauthStates();
    const rows = this.listConnections(userId);
    const rowsByProvider = new Map();
    for (const row of rows) {
      const providerKey = String(row.provider_key || '').trim();
      if (!rowsByProvider.has(providerKey)) rowsByProvider.set(providerKey, []);
      rowsByProvider.get(providerKey).push(row);
    }

    return this.registry
      .list()
      .map((provider) => provider.buildSnapshot(rowsByProvider.get(provider.key) || []));
  }

  async beginOAuth(userId, providerKey, options = {}) {
    this.cleanupExpiredOauthStates();
    const provider = this.getProvider(providerKey);
    if (!provider) {
      throw new Error(`Unknown integration provider: ${providerKey}`);
    }

    const appKey = String(options.appKey || '').trim();
    if (!provider.getApp?.(appKey)) {
      throw new Error(`Unknown ${provider.label} app: ${appKey || 'missing app key'}`);
    }

    const env = provider.getEnvStatus();
    if (!env.configured) {
      throw new Error(env.summary);
    }

    const state = crypto.randomBytes(24).toString('hex');
    const codeVerifier = crypto.randomBytes(48).toString('base64url');
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000).toISOString();
    const { url } = await provider.beginOAuth({
      state,
      codeVerifier,
      userId,
      appKey,
    });

    db.prepare(
      `INSERT INTO integration_oauth_states (
         user_id,
         provider_key,
         app_key,
         state,
         code_verifier,
         expires_at
       ) VALUES (?, ?, ?, ?, ?, ?)`,
    ).run(userId, provider.key, appKey, state, codeVerifier, expiresAt);

    return {
      provider: provider.key,
      appId: appKey,
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
      appKey: stateRow.app_key,
    });

    db.prepare(
      `INSERT INTO integration_connections (
         user_id,
         provider_key,
         app_key,
         status,
         account_email,
         scopes_json,
         credentials_json,
         metadata_json,
         last_connected_at,
         updated_at
       ) VALUES (?, ?, ?, 'connected', ?, ?, ?, ?, datetime('now'), datetime('now'))
       ON CONFLICT(user_id, provider_key, app_key, account_email) DO UPDATE SET
         status = 'connected',
         scopes_json = excluded.scopes_json,
         credentials_json = excluded.credentials_json,
         metadata_json = excluded.metadata_json,
         last_connected_at = excluded.last_connected_at,
         updated_at = excluded.updated_at`,
    ).run(
      stateRow.user_id,
      provider.key,
      stateRow.app_key,
      result.accountEmail,
      JSON.stringify(result.scopes || []),
      JSON.stringify(result.credentials || {}),
      JSON.stringify(result.metadata || {}),
    );

    const connection = db
      .prepare(
        `SELECT * FROM integration_connections
         WHERE user_id = ? AND provider_key = ? AND app_key = ? AND account_email = ?`,
      )
      .get(
        stateRow.user_id,
        provider.key,
        stateRow.app_key,
        result.accountEmail,
      );

    db.prepare('DELETE FROM integration_oauth_states WHERE state = ?').run(
      stateRow.state,
    );

    return {
      provider: provider.key,
      appId: stateRow.app_key,
      connectionId: connection?.id || null,
      accountEmail: result.accountEmail,
    };
  }

  async disconnect(userId, providerKey, options = {}) {
    const provider = this.getProvider(providerKey);
    if (!provider) {
      throw new Error(`Unknown integration provider: ${providerKey}`);
    }

    const connectionId = Number(options.connectionId);
    if (!Number.isInteger(connectionId) || connectionId <= 0) {
      throw new Error('A valid connectionId is required to disconnect an account.');
    }

    const connection = this.getConnectionById(userId, connectionId);
    if (!connection || connection.provider_key !== provider.key) {
      return {
        disconnected: true,
        provider: provider.key,
        connectionId,
        existed: false,
      };
    }

    await provider.disconnect(connection).catch(() => {});
    db.prepare('DELETE FROM integration_connections WHERE user_id = ? AND id = ?').run(
      userId,
      connection.id,
    );

    return {
      disconnected: true,
      provider: provider.key,
      appId: connection.app_key,
      connectionId: connection.id,
      existed: true,
    };
  }

  getToolDefinitions(userId) {
    const definitions = [];
    for (const provider of this.registry.list()) {
      const env = provider.getEnvStatus();
      if (!env.configured) continue;
      const connections = this.listConnections(userId, provider.key);
      const connectedAppIds = Array.from(
        new Set(
          connections
            .filter((connection) => connection.status === 'connected')
            .map((connection) => String(connection.app_key || '').trim())
            .filter(Boolean),
        ),
      );
      if (connectedAppIds.length === 0) continue;
      definitions.push(...provider.getToolDefinitions({ connectedAppIds }));
    }
    return definitions;
  }

  getToolStatus(userId, providerKey) {
    const provider = this.getProvider(providerKey);
    if (!provider) {
      throw new Error(`Unknown integration provider: ${providerKey}`);
    }
    const env = provider.getEnvStatus();
    const connections = this.listConnections(userId, provider.key);
    const snapshot = provider.buildSnapshot(connections);
    const connectedAppIds = snapshot.apps
      .filter((app) => app.connection.connected)
      .map((app) => app.id);
    const tools =
      env.configured && connectedAppIds.length > 0
        ? provider.getToolDefinitions({ connectedAppIds })
        : [];
    return {
      provider: provider.key,
      connection: snapshot.connection,
      apps: snapshot.apps.map((app) => ({
        id: app.id,
        label: app.label,
        accountCount: app.connection.accountCount || 0,
        toolCount: app.availableToolCount || 0,
      })),
      toolCount: tools.length,
      tools: tools.map((tool) => tool.name),
    };
  }

  selectToolConnection(provider, toolName, args, userId) {
    const appKey = provider.getToolAppId?.(toolName);
    if (!appKey) {
      return {
        error: `Unable to resolve an integration app for tool ${toolName}.`,
      };
    }

    const app = provider.getApp?.(appKey);
    const appLabel = app?.label || appKey;
    const connections = this.listConnections(userId, provider.key).filter(
      (connection) =>
        connection.status === 'connected' &&
        String(connection.app_key || '').trim() === appKey,
    );

    if (connections.length === 0) {
      return {
        error: `${provider.label} ${appLabel} is not connected for this user.`,
      };
    }

    const requestedConnectionId = Number(args?.connection_id);
    if (Number.isInteger(requestedConnectionId) && requestedConnectionId > 0) {
      const byId = connections.find((connection) => connection.id === requestedConnectionId);
      if (!byId) {
        return {
          error: `No connected ${provider.label} ${appLabel} account matches connection_id ${requestedConnectionId}.`,
        };
      }
      return { connection: byId };
    }

    const requestedEmail = String(args?.account_email || '').trim().toLowerCase();
    if (requestedEmail) {
      const byEmail = connections.find(
        (connection) =>
          String(connection.account_email || '').trim().toLowerCase() ===
          requestedEmail,
      );
      if (!byEmail) {
        return {
          error: `No connected ${provider.label} ${appLabel} account matches ${requestedEmail}.`,
        };
      }
      return { connection: byEmail };
    }

    if (connections.length === 1) {
      return { connection: connections[0] };
    }

    const accountEmails = connections
      .map((connection) => connection.account_email || `connection ${connection.id}`)
      .join(', ');
    return {
      error: `Multiple ${provider.label} ${appLabel} accounts are connected (${accountEmails}). Re-run the tool with connection_id or account_email.`,
    };
  }

  async executeTool(userId, toolName, args) {
    for (const provider of this.registry.list()) {
      if (!provider.supportsTool(toolName)) continue;
      const env = provider.getEnvStatus();
      if (!env.configured) {
        return { error: env.summary };
      }

      const selection = this.selectToolConnection(provider, toolName, args, userId);
      if (selection.error) {
        return { error: selection.error };
      }

      const execution = await provider.executeTool(
        toolName,
        args,
        selection.connection,
      );
      if (!execution) return null;

      if (execution.credentials) {
        db.prepare(
          `UPDATE integration_connections
           SET credentials_json = ?, updated_at = datetime('now')
           WHERE id = ? AND user_id = ?`,
        ).run(
          JSON.stringify(execution.credentials),
          selection.connection.id,
          userId,
        );
      }

      return execution.result;
    }

    return null;
  }

  summarizeConnectedProviders(userId) {
    const providers = this.registry.list().map((provider) => ({
      provider,
      snapshot: provider.buildSnapshot(this.listConnections(userId, provider.key)),
    }));

    if (providers.length === 0) {
      return 'No official integrations are available in this run.';
    }

    return providers
      .map(({ provider, snapshot }) => {
        if (typeof provider.summarizeForModel === 'function') {
          return provider.summarizeForModel(snapshot);
        }

        if (!snapshot?.env?.configured) {
          return `${provider.label}: available but not configured on the server yet. If the user wants to use it, tell them to finish setup in Official Integrations first.`;
        }

        if (!snapshot.connection?.connected) {
          return `${provider.label}: server setup is ready, but no accounts are connected. If the user wants to use it, tell them to connect an account in Official Integrations first.`;
        }

        return `${provider.label}: native built-in access is connected in this run.`;
      })
      .join('\n');
  }
}

module.exports = {
  IntegrationManager,
};
