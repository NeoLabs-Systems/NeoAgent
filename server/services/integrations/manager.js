'use strict';

const crypto = require('crypto');
const db = require('../../db/database');
const { createIntegrationRegistry } = require('./registry');
const { decryptValue, encryptValue } = require('./secrets');
const { resolveAgentId } = require('../agents/manager');
const {
  getConnectionAccessMode,
  normalizeAccessMode,
  withConnectionAccessMode,
} = require('./access');
const {
  abortError,
  waitForAbortableResult,
} = require('./http');
const { throwIfAborted } = require('../../utils/abort');

const OAUTH_STATE_PATTERN = /^[a-f0-9]{32,128}$/i;

function isLikelyExpiredConnectionError(error) {
  const message = String(error?.message || error || '').toLowerCase();
  if (!message) return false;
  return [
    'invalid_grant',
    'token refresh failed',
    'token expired',
    'access token is missing',
    'refresh token is missing',
    'reconnect this integration account',
    'account is no longer authorized',
    'reauthorize',
    're-authorize',
  ].some((hint) => message.includes(hint));
}

function assertDurableOAuthCredentials(provider, credentials) {
  const label = String(provider?.label || 'This integration').trim() || 'This integration';
  const normalizedCredentials =
    credentials && typeof credentials === 'object' ? credentials : {};

  if (!String(normalizedCredentials.access_token || '').trim()) {
    throw new Error(
      `${label} did not return an access token, so the connection could not be completed.`,
    );
  }

  if (
    provider?.requiresRefreshToken === true &&
    !String(normalizedCredentials.refresh_token || '').trim()
  ) {
    throw new Error(
      `${label} did not return a refresh token, so the connection would expire. Revoke the existing app grant for this provider and reconnect it so offline access is granted.`,
    );
  }
}

class IntegrationManager {
  constructor(options = {}) {
    this.app = options.app || null;
    this.registry = createIntegrationRegistry({
      app: this.app,
      io: this.app?.locals?.io || null,
    });
    this.connectionExecutionQueues = new Map();
  }

  parseCredentials(credentialsJson) {
    try {
      const parsed = JSON.parse(decryptValue(credentialsJson || '{}') || '{}');
      return parsed && typeof parsed === 'object' ? parsed : {};
    } catch {
      return {};
    }
  }

  mergeUpdatedCredentials(existingCredentials, updatedCredentials) {
    const existing =
      existingCredentials && typeof existingCredentials === 'object'
        ? existingCredentials
        : {};
    const updated =
      updatedCredentials && typeof updatedCredentials === 'object'
        ? updatedCredentials
        : {};

    const merged = {
      ...existing,
      ...updated,
    };

    // Some OAuth token refresh responses omit refresh_token; keep the existing one.
    if (!merged.refresh_token && existing.refresh_token) {
      merged.refresh_token = existing.refresh_token;
    }

    return merged;
  }

  findReusableConnection(userId, agentId, providerKey, accountEmail, options = {}) {
    const normalizedEmail = String(accountEmail || '').trim().toLowerCase();
    if (!normalizedEmail) return null;
    const excludedConnectionId = Number(options.excludeConnectionId);
    const connections = this.listConnections(userId, providerKey, agentId).filter(
      (connection) =>
        String(connection.account_email || '').trim().toLowerCase() === normalizedEmail &&
        connection.status === 'connected' &&
        (!Number.isInteger(excludedConnectionId) || connection.id !== excludedConnectionId),
    );
    if (connections.length === 0) return null;
    return connections.sort((left, right) =>
      String(right.updated_at || '').localeCompare(String(left.updated_at || '')),
    )[0];
  }

  mergeWithReusableCredentials(userId, agentId, providerKey, accountEmail, credentials, options = {}) {
    const reusableConnection = this.findReusableConnection(
      userId,
      agentId,
      providerKey,
      accountEmail,
      options,
    );
    if (!reusableConnection) {
      return credentials && typeof credentials === 'object' ? credentials : {};
    }
    const reusableCredentials = this.parseCredentials(
      reusableConnection.credentials_json,
    );
    return this.mergeUpdatedCredentials(
      reusableCredentials,
      credentials,
    );
  }

  persistSharedCredentials(userId, agentId, providerKey, accountEmail, credentials) {
    const normalizedEmail = String(accountEmail || '').trim();
    if (!normalizedEmail) return;
    db.prepare(
      `UPDATE integration_connections
       SET credentials_json = ?, updated_at = datetime('now')
       WHERE user_id = ? AND agent_id = ? AND provider_key = ? AND lower(account_email) = lower(?)`,
    ).run(
      encryptValue(JSON.stringify(credentials || {})),
      userId,
      agentId,
      providerKey,
      normalizedEmail,
    );
  }

  getProvider(providerKey) {
    return this.registry.get(providerKey);
  }

  cleanupExpiredOauthStates() {
    db.prepare(
      "DELETE FROM integration_oauth_states WHERE datetime(expires_at) <= datetime('now')",
    ).run();
  }

  claimOAuthState(state) {
    return db.transaction(() => {
      const stateRow = db
        .prepare(
          `SELECT * FROM integration_oauth_states
           WHERE state = ? AND datetime(expires_at) > datetime('now')`,
        )
        .get(state);
      if (!stateRow) return null;
      const deleted = db.prepare(
        `DELETE FROM integration_oauth_states
         WHERE state = ? AND datetime(expires_at) > datetime('now')`,
      ).run(state);
      return deleted.changes === 1 ? stateRow : null;
    })();
  }

  listConnections(userId, providerKey = null, agentId = null) {
    const scopedAgentId = resolveAgentId(userId, agentId);
    const query = providerKey
      ? 'SELECT * FROM integration_connections WHERE user_id = ? AND agent_id = ? AND provider_key = ? ORDER BY updated_at DESC, id DESC'
      : 'SELECT * FROM integration_connections WHERE user_id = ? AND agent_id = ? ORDER BY updated_at DESC, id DESC';
    return providerKey
      ? db.prepare(query).all(userId, scopedAgentId, providerKey)
      : db.prepare(query).all(userId, scopedAgentId);
  }

  getConnectionById(userId, connectionId, agentId = null) {
    const scopedAgentId = resolveAgentId(userId, agentId);
    return db
      .prepare(
        'SELECT * FROM integration_connections WHERE user_id = ? AND agent_id = ? AND id = ?',
      )
      .get(userId, scopedAgentId, connectionId);
  }

  getSafeConnectionTestTool(provider, appKey) {
    const definitions = provider.getToolDefinitions({
      connectedAppIds: [String(appKey || '').trim()],
    });
    return definitions.find((definition) => {
      if (definition.access !== 'read') return false;
      const required = Array.isArray(definition.parameters?.required)
        ? definition.parameters.required
        : [];
      return required.length === 0;
    }) || null;
  }

  supportsConnectionTest(provider, connection) {
    if (!connection || connection.status !== 'connected') return false;
    return (
      typeof provider.testConnection === 'function' ||
      Boolean(this.getSafeConnectionTestTool(provider, connection.app_key))
    );
  }

  decorateConnectionTestSupport(snapshot, provider, connections) {
    const byId = new Map(connections.map((connection) => [connection.id, connection]));
    const apps = (snapshot.apps || []).map((app) => {
      const accounts = (app.accounts || []).map((account) => ({
        ...account,
        supportsConnectionTest: this.supportsConnectionTest(
          provider,
          byId.get(account.id),
        ),
      }));
      return {
        ...app,
        accounts,
        supportsConnectionTest: accounts.some(
          (account) => account.supportsConnectionTest,
        ),
      };
    });
    return {
      ...snapshot,
      apps,
      supportsConnectionTest: apps.some((app) => app.supportsConnectionTest),
    };
  }

  listProviders(userId, agentId = null) {
    const scopedAgentId = resolveAgentId(userId, agentId);
    this.cleanupExpiredOauthStates();
    const rows = this.listConnections(userId, null, scopedAgentId);
    const rowsByProvider = new Map();
    for (const row of rows) {
      const providerKey = String(row.provider_key || '').trim();
      if (!rowsByProvider.has(providerKey)) rowsByProvider.set(providerKey, []);
      rowsByProvider.get(providerKey).push(row);
    }

    const snapshots = this.registry.list().map((provider) => {
      const connections = rowsByProvider.get(provider.key) || [];
      return this.decorateConnectionTestSupport(
        provider.buildSnapshot(connections, {
          userId,
          agentId: scopedAgentId,
        }),
        provider,
        connections,
      );
    });
    const ingestionService = this.app?.locals?.memoryIngestionService || null;
    if (!ingestionService || typeof ingestionService.decorateProviderSnapshot !== 'function') {
      return snapshots;
    }
    return snapshots.map((snapshot) =>
      ingestionService.decorateProviderSnapshot(snapshot, userId, scopedAgentId),
    );
  }

  async beginOAuth(userId, providerKey, options = {}) {
    this.cleanupExpiredOauthStates();
    const agentId = resolveAgentId(userId, options.agentId || options.agent_id || null);
    const provider = this.getProvider(providerKey);
    if (!provider) {
      throw new Error(`Unknown integration provider: ${providerKey}`);
    }

    const appKey = String(options.appKey || '').trim();
    if (!provider.getApp?.(appKey)) {
      throw new Error(`Unknown ${provider.label} app: ${appKey || 'missing app key'}`);
    }

    const env = provider.getEnvStatus({
      userId,
      agentId,
    });
    if (!env.configured) {
      throw new Error(env.summary);
    }

    if (typeof provider.beginConnection === 'function') {
      const result = await provider.beginConnection({
        userId,
        agentId,
        appKey,
        signal: options.signal || null,
      });
      const url = String(result?.url || '').trim();
      const absoluteUrl = url.startsWith('http')
        ? url
        : `${require('./env').resolvePublicBaseUrl()}${url.startsWith('/') ? '' : '/'}${url}`;
      return {
        provider: provider.key,
        appId: appKey,
        ...result,
        url: absoluteUrl,
      };
    }

    const state = crypto.randomBytes(24).toString('hex');
    const codeVerifier = crypto.randomBytes(48).toString('base64url');
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000).toISOString();
    const { url } = await provider.beginOAuth({
      state,
      codeVerifier,
      userId,
      agentId,
      appKey,
      signal: options.signal || null,
    });

    db.prepare(
      `INSERT INTO integration_oauth_states (
         user_id,
         agent_id,
         provider_key,
         app_key,
         state,
         code_verifier,
         expires_at
       ) VALUES (?, ?, ?, ?, ?, ?, ?)`,
    ).run(
      userId,
      agentId,
      provider.key,
      appKey,
      state,
      encryptValue(codeVerifier),
      expiresAt,
    );

    return {
      provider: provider.key,
      appId: appKey,
      status: 'oauth_redirect',
      url,
    };
  }

  getConnectionSession(userId, providerKey, sessionId, agentId = null) {
    const provider = this.getProvider(providerKey);
    if (!provider || typeof provider.getConnectionSession !== 'function') {
      return null;
    }
    return provider.getConnectionSession(
      userId,
      providerKey,
      sessionId,
      resolveAgentId(userId, agentId),
    );
  }

  async finishOAuth(state, code, options = {}) {
    throwIfAborted(options.signal, 'OAuth callback request aborted.');
    this.cleanupExpiredOauthStates();
    const normalizedState = String(state || '').trim();
    if (!OAUTH_STATE_PATTERN.test(normalizedState)) {
      throw new Error('OAuth state is invalid or malformed.');
    }
    const normalizedCode = String(code || '').trim();
    if (!normalizedCode) {
      throw new Error('OAuth authorization code is required.');
    }
    const stateRow = this.claimOAuthState(normalizedState);
    if (!stateRow) {
      throw new Error('OAuth state is missing or expired.');
    }

    const provider = this.getProvider(stateRow.provider_key);
    if (!provider) {
      throw new Error(`Unknown integration provider: ${stateRow.provider_key}`);
    }

    const result = await provider.finishOAuth({
      userId: stateRow.user_id,
      agentId: stateRow.agent_id || resolveAgentId(stateRow.user_id, null),
      state: stateRow.state,
      code: normalizedCode,
      codeVerifier: decryptValue(stateRow.code_verifier),
      appKey: stateRow.app_key,
      signal: options.signal || null,
    });

    const mergedCredentials = this.mergeWithReusableCredentials(
      stateRow.user_id,
      stateRow.agent_id || resolveAgentId(stateRow.user_id, null),
      provider.key,
      result.accountEmail,
      result.credentials,
    );
    assertDurableOAuthCredentials(provider, mergedCredentials);

    db.prepare(
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
      stateRow.user_id,
      stateRow.agent_id || resolveAgentId(stateRow.user_id, null),
      provider.key,
      stateRow.app_key,
      result.accountEmail,
      JSON.stringify(result.scopes || []),
      encryptValue(JSON.stringify(mergedCredentials)),
      JSON.stringify(result.metadata || {}),
    );

    this.persistSharedCredentials(
      stateRow.user_id,
      stateRow.agent_id || resolveAgentId(stateRow.user_id, null),
      provider.key,
      result.accountEmail,
      mergedCredentials,
    );

    const connection = db
      .prepare(
        `SELECT * FROM integration_connections
         WHERE user_id = ? AND agent_id = ? AND provider_key = ? AND app_key = ? AND account_email = ?`,
      )
      .get(
        stateRow.user_id,
        stateRow.agent_id || resolveAgentId(stateRow.user_id, null),
        provider.key,
        stateRow.app_key,
        result.accountEmail,
      );

    return {
      provider: provider.key,
      appId: stateRow.app_key,
      connectionId: connection?.id || null,
      accountEmail: result.accountEmail,
    };
  }

  async disconnect(userId, providerKey, options = {}) {
    const agentId = resolveAgentId(userId, options.agentId || options.agent_id || null);
    const provider = this.getProvider(providerKey);
    if (!provider) {
      throw new Error(`Unknown integration provider: ${providerKey}`);
    }

    const connectionId = Number(options.connectionId);
    if (!Number.isInteger(connectionId) || connectionId <= 0) {
      throw new Error('A valid connectionId is required to disconnect an account.');
    }

    const connection = this.getConnectionById(userId, connectionId, agentId);
    if (!connection || connection.provider_key !== provider.key) {
      return {
        disconnected: true,
        provider: provider.key,
        connectionId,
        existed: false,
      };
    }

    if (typeof provider.disconnect === 'function') {
      await provider.disconnect(connection, {
        signal: options.signal || null,
      }).catch(() => {});
    }
    db.prepare('DELETE FROM integration_connections WHERE user_id = ? AND agent_id = ? AND id = ?').run(
      userId,
      agentId,
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

  updateConnectionTestMetadata(connection, status) {
    let metadata = {};
    try {
      metadata = JSON.parse(connection.metadata_json || '{}') || {};
    } catch {
      metadata = {};
    }
    const checkedAt = new Date().toISOString();
    db.prepare(
      `UPDATE integration_connections
       SET metadata_json = ?, updated_at = datetime('now')
       WHERE id = ? AND user_id = ? AND agent_id = ?`,
    ).run(
      JSON.stringify({
        ...metadata,
        last_connection_test_at: checkedAt,
        last_connection_test_status: status,
      }),
      connection.id,
      connection.user_id,
      connection.agent_id,
    );
    return checkedAt;
  }

  async testConnection(userId, providerKey, options = {}) {
    const agentId = resolveAgentId(userId, options.agentId || options.agent_id || null);
    const provider = this.getProvider(providerKey);
    if (!provider) {
      throw new Error(`Unknown integration provider: ${providerKey}`);
    }
    const connectionId = Number(options.connectionId);
    if (!Number.isInteger(connectionId) || connectionId <= 0) {
      throw new Error('Choose a connected account to test.');
    }
    const connection = this.getConnectionById(userId, connectionId, agentId);
    if (
      !connection ||
      connection.provider_key !== provider.key ||
      connection.status !== 'connected'
    ) {
      throw new Error(`The selected ${provider.label} account is not connected.`);
    }
    if (!this.supportsConnectionTest(provider, connection)) {
      throw new Error(`${provider.label} does not provide a safe connection test yet.`);
    }

    try {
      if (typeof provider.testConnection === 'function') {
        const execution = await provider.testConnection(connection, {
          signal: options.signal || null,
        });
        if (execution?.credentials) {
          const credentials = this.mergeUpdatedCredentials(
            this.parseCredentials(connection.credentials_json),
            execution.credentials,
          );
          this.persistSharedCredentials(
            userId,
            agentId,
            provider.key,
            connection.account_email,
            credentials,
          );
        }
      } else {
        const definition = this.getSafeConnectionTestTool(
          provider,
          connection.app_key,
        );
        const result = await this.executeTool(
          userId,
          definition.name,
          { connection_id: connection.id },
          agentId,
          { signal: options.signal || null },
        );
        if (result?.error) {
          throw new Error(result.error);
        }
      }
      const checkedAt = this.updateConnectionTestMetadata(connection, 'passed');
      return {
        ok: true,
        provider: provider.key,
        connectionId: connection.id,
        accountEmail: connection.account_email || null,
        checkedAt,
        message: `${provider.label} is connected and responding.`,
      };
    } catch (error) {
      if (
        options.signal?.aborted ||
        error?.name === 'AbortError' ||
        error?.code === 'ABORT_ERR'
      ) {
        throw options.signal?.aborted ? abortError(options.signal) : error;
      }
      this.updateConnectionTestMetadata(connection, 'failed');
      if (isLikelyExpiredConnectionError(error)) {
        db.prepare(
          `UPDATE integration_connections
           SET status = 'expired', updated_at = datetime('now')
           WHERE id = ? AND user_id = ? AND agent_id = ?`,
        ).run(connection.id, userId, agentId);
        throw new Error(
          `Your ${provider.label} connection has expired. Reconnect the account and try again.`,
        );
      }
      throw error;
    }
  }

  getToolDefinitions(userId, agentId = null) {
    const definitions = [];
    for (const provider of this.registry.list()) {
      const env = provider.getEnvStatus({
        userId,
        agentId,
      });
      if (!env.configured) continue;
      const connections = this.listConnections(userId, provider.key, agentId);
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

  getToolStatus(userId, providerKey, agentId = null) {
    const provider = this.getProvider(providerKey);
    if (!provider) {
      throw new Error(`Unknown integration provider: ${providerKey}`);
    }
    const env = provider.getEnvStatus({
      userId,
      agentId,
    });
    const connections = this.listConnections(userId, provider.key, agentId);
    const snapshot = provider.buildSnapshot(connections, {
      userId,
      agentId,
    });
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

  updateConnectionAccessMode(userId, providerKey, options = {}) {
    const agentId = resolveAgentId(userId, options.agentId || options.agent_id || null);
    const provider = this.getProvider(providerKey);
    if (!provider) {
      throw new Error(`Unknown integration provider: ${providerKey}`);
    }

    const connectionId = Number(options.connectionId);
    if (!Number.isInteger(connectionId) || connectionId <= 0) {
      throw new Error('A valid connectionId is required to update integration access mode.');
    }

    const connection = this.getConnectionById(userId, connectionId, agentId);
    if (!connection || connection.provider_key !== provider.key) {
      throw new Error(`No connected ${provider.label} account matches connection_id ${connectionId}.`);
    }

    const accessMode = normalizeAccessMode(options.accessMode, null);
    if (!accessMode) {
      throw new Error('Invalid accessMode. Use "read_only" or "read_write".');
    }

    const metadata = withConnectionAccessMode(connection.metadata_json, accessMode);
    db.prepare(
      `UPDATE integration_connections
       SET metadata_json = ?, updated_at = datetime('now')
       WHERE id = ? AND user_id = ? AND agent_id = ?`
    ).run(
      JSON.stringify(metadata),
      connection.id,
      userId,
      agentId,
    );

    return {
      provider: provider.key,
      connectionId: connection.id,
      accessMode,
    };
  }

  isWriteToolExecution(provider, toolName, args = {}) {
    if (typeof provider?.isWriteTool === 'function') {
      const providerDecision = provider.isWriteTool(toolName, args);
      if (typeof providerDecision === 'boolean') {
        return providerDecision;
      }
    }

    const connectedAppIds = Array.from(
      new Set([
        ...(Array.isArray(provider?.connections)
          ? provider.connections
            .map((connection) => String(connection?.appId || connection?.app_key || '').trim())
            .filter(Boolean)
          : []),
        ...(Array.isArray(provider?.apps)
          ? provider.apps
            .map((app) => String(app?.id || '').trim())
            .filter(Boolean)
          : []),
      ]),
    );
    const definitions = typeof provider?.getToolDefinitions === 'function'
      ? provider.getToolDefinitions({ connectedAppIds })
      : [];
    const definition = Array.isArray(definitions)
      ? definitions.find((tool) => String(tool?.name || '').trim() === String(toolName || '').trim())
      : null;

    const declaredAccess = String(definition?.access || '').trim().toLowerCase();
    if (declaredAccess === 'write') return true;
    if (declaredAccess === 'read') return false;
    if (declaredAccess === 'dynamic_http_method') {
      const method = String(args?.method || args?.http_method || 'GET').trim().toUpperCase();
      return !['GET', 'HEAD', 'OPTIONS'].includes(method);
    }

    // No explicit access metadata means we cannot safely allow writes in read-only mode.
    return true;
  }

  selectToolConnection(provider, toolName, args, userId, agentId = null) {
    const appKey = provider.getToolAppId?.(toolName);
    if (!appKey) {
      return {
        error: `Unable to resolve an integration app for tool ${toolName}.`,
      };
    }

    const app = provider.getApp?.(appKey);
    const appLabel = app?.label || appKey;
    const connections = this.listConnections(userId, provider.key, agentId).filter(
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

  connectionExecutionKey(connection) {
    return [
      connection.user_id,
      connection.agent_id,
      connection.provider_key,
      String(connection.account_email || '').trim().toLowerCase(),
    ].join(':');
  }

  async acquireConnectionExecution(connection, signal) {
    const key = this.connectionExecutionKey(connection);
    const previous = this.connectionExecutionQueues.get(key) || Promise.resolve();
    let releaseGate;
    const gate = new Promise((resolve) => {
      releaseGate = resolve;
    });
    const tail = previous.catch(() => {}).then(() => gate);
    this.connectionExecutionQueues.set(key, tail);
    void tail.finally(() => {
      if (this.connectionExecutionQueues.get(key) === tail) {
        this.connectionExecutionQueues.delete(key);
      }
    });

    try {
      await waitForAbortableResult(previous.catch(() => {}), signal);
    } catch (error) {
      releaseGate();
      throw error;
    }

    let released = false;
    return () => {
      if (released) return;
      released = true;
      releaseGate();
    };
  }

  async executeTool(userId, toolName, args, agentId = null, options = {}) {
    let foundSupportingProvider = false;
    for (const provider of this.registry.list()) {
      if (!provider.supportsTool(toolName)) continue;
      foundSupportingProvider = true;
      const env = provider.getEnvStatus({
        userId,
        agentId,
      });
      if (!env.configured) {
        return { error: env.summary };
      }

      const selection = this.selectToolConnection(provider, toolName, args, userId, agentId);
      if (selection.error) {
        return { error: selection.error };
      }

      const accessMode = getConnectionAccessMode(selection.connection);
      if (accessMode === 'read_only' && this.isWriteToolExecution(provider, toolName, args)) {
        return {
          error: `This ${provider.label} account is set to read-only access. Change the connection access mode to read/write to allow this action.`,
        };
      }

      const storedCredentials = this.parseCredentials(
        selection.connection.credentials_json,
      );
      const needsCredentialLock =
        provider.requiresRefreshToken === true ||
        Boolean(storedCredentials.refresh_token);
      const releaseExecution = needsCredentialLock
        ? await this.acquireConnectionExecution(selection.connection, options.signal)
        : () => {};
      try {
        const connection = this.getConnectionById(
          userId,
          selection.connection.id,
          agentId,
        );
        if (!connection || connection.status !== 'connected') {
          return {
            error: `The selected ${provider.label} connection is no longer available.`,
          };
        }

        let execution;
        try {
          execution = await provider.executeTool(
            toolName,
            args,
            connection,
            { signal: options.signal || null },
          );
        } catch (err) {
          if (
            options.signal?.aborted ||
            err?.name === 'AbortError' ||
            err?.code === 'ABORT_ERR'
          ) {
            throw options.signal?.aborted ? abortError(options.signal) : err;
          }
          if (isLikelyExpiredConnectionError(err)) {
            db.prepare(
              `UPDATE integration_connections
               SET status = 'expired', updated_at = datetime('now')
               WHERE id = ? AND user_id = ? AND agent_id = ?`,
            ).run(
              connection.id,
              userId,
              resolveAgentId(userId, agentId),
            );
            return {
              error: `Your ${provider.label} account connection has expired and needs to be reconnected. Open Official Integrations to reconnect your account.`,
              expired: true,
              connectionId: connection.id,
            };
          }
          return { error: err?.message || 'execution_error' };
        }
        if (!execution) {
          return { error: 'execution_failed' };
        }

        if (execution.credentials) {
          const existingCredentials = this.parseCredentials(
            connection.credentials_json,
          );
          const mergedCredentials = this.mergeUpdatedCredentials(
            existingCredentials,
            execution.credentials,
          );
          this.persistSharedCredentials(
            userId,
            resolveAgentId(userId, agentId),
            provider.key,
            connection.account_email,
            mergedCredentials,
          );
        }

        return execution.result;
      } finally {
        releaseExecution();
      }
    }

    return foundSupportingProvider
      ? { error: 'execution_failed' }
      : { error: 'no_provider_support' };
  }

  async shutdown() {
    const providers = this.registry.list();
    await Promise.allSettled(
      providers.map((provider) => {
        if (typeof provider.shutdown !== 'function') return null;
        return provider.shutdown();
      }),
    );
    this.connectionExecutionQueues.clear();
    return { state: 'stopped', providerCount: providers.length };
  }

  summarizeConnectedProviders(userId, agentId = null) {
    const scopedAgentId = resolveAgentId(userId, agentId);
    const ingestionService = this.app?.locals?.memoryIngestionService || null;
    const providers = this.registry.list().map((provider) => ({
      provider,
      snapshot: (() => {
        const snapshot = provider.buildSnapshot(
          this.listConnections(userId, provider.key, scopedAgentId),
          {
            userId,
            agentId: scopedAgentId,
          },
        );
        return ingestionService?.decorateProviderSnapshot?.(snapshot, userId, scopedAgentId) || snapshot;
      })(),
    }));

    if (providers.length === 0) {
      return 'No official integrations are available in this run.';
    }

    return providers
      .map(({ provider, snapshot }) => {
        const memoryCoverage = snapshot.memoryCoverage?.supported
          ? ` Memory ingestion: ${snapshot.memoryCoverage.status}; domains: ${(snapshot.memoryCoverage.dataDomains || []).join(', ') || 'none'}; documents: ${snapshot.memoryCoverage.documentCount || 0}.`
          : '';

        if (typeof provider.summarizeForModel === 'function') {
          return `${provider.summarizeForModel(snapshot)}${memoryCoverage}`;
        }

        if (!snapshot?.env?.configured) {
          if (snapshot?.env?.setupMode === 'user') {
            return `${provider.label}: setup is not complete for this user yet. If the user wants to use it, tell them to finish setup in Official Integrations first.${memoryCoverage}`;
          }
          return `${provider.label}: available but not configured on the server yet. If the user wants to use it, tell them to finish setup in Official Integrations first.${memoryCoverage}`;
        }

        if (!snapshot.connection?.connected) {
          return `${provider.label}: server setup is ready, but no accounts are connected. If the user wants to use it, tell them to connect an account in Official Integrations first.${memoryCoverage}`;
        }

        return `${provider.label}: native built-in access is connected in this run.${memoryCoverage}`;
      })
      .join('\n');
  }
}

module.exports = {
  assertDurableOAuthCredentials,
  IntegrationManager,
};
