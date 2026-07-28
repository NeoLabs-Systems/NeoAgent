'use strict';

const db = require('../../../db/database');
const { resolveAgentId } = require('../../agents/manager');
const { getConnectionAccessMode } = require('../access');
const {
  deleteProviderConfig,
  getProviderConfig,
  setProviderConfig,
} = require('../provider_config_store');
const { encryptValue } = require('../secrets');
const { BITWARDEN_APP, BITWARDEN_PROVIDER_KEY } = require('./constants');
const { buildBitwardenSnapshot } = require('./snapshot');

const DEFAULT_SERVER_URL = 'https://vault.bitwarden.com';

function text(value) {
  return String(value || '').trim();
}

function normalizeServerUrl(value) {
  const url = new URL(text(value) || DEFAULT_SERVER_URL);
  if (url.protocol !== 'https:' || url.username || url.password || url.search || url.hash) {
    throw new Error('Bitwarden server must be an HTTPS URL without embedded credentials.');
  }
  return url.toString().replace(/\/+$/, '');
}

function parseConfig(raw, existing = {}) {
  const source = raw && typeof raw === 'object' ? raw : {};
  return {
    serverUrl: normalizeServerUrl(source.serverUrl || existing.serverUrl || DEFAULT_SERVER_URL),
    email: text(source.email) || text(existing.email),
    clientId: text(source.clientId) || text(existing.clientId),
    clientSecret: text(source.clientSecret) || text(existing.clientSecret),
    idleTimeoutMinutes: Math.max(5, Math.min(120, Number(
      source.idleTimeoutMinutes || existing.idleTimeoutMinutes || 30,
    ))),
  };
}

function loadConnection(userId, agentId) {
  return db.prepare(
    `SELECT * FROM integration_connections
     WHERE user_id = ? AND agent_id = ? AND provider_key = ? AND app_key = ?
     ORDER BY updated_at DESC, id DESC LIMIT 1`,
  ).get(userId, agentId, BITWARDEN_PROVIDER_KEY, BITWARDEN_APP.id) || null;
}

function publicConfig(config, connection, status = {}) {
  return {
    serverUrl: config.serverUrl || DEFAULT_SERVER_URL,
    email: config.email || '',
    authenticationMethod: 'master_password',
    hasClientId: Boolean(config.clientId),
    hasClientSecret: Boolean(config.clientSecret),
    configured: Boolean(config.email),
    accountCount: connection?.status === 'connected' ? 1 : 0,
    hasConnectedAccount: connection?.status === 'connected',
    connectionId: connection?.id || null,
    cliAvailable: status.cliAvailable !== false,
    unlocked: Boolean(status.unlocked),
    persistent: Boolean(status.persistent),
    lastUsedAt: status.lastUsedAt || null,
  };
}

function upsertConnection(userId, agentId, config) {
  const existing = loadConnection(userId, agentId);
  const metadata = JSON.stringify({
    access_mode: getConnectionAccessMode(existing),
    idleTimeoutMinutes: config.idleTimeoutMinutes,
  });
  db.prepare(
    `INSERT INTO integration_connections (
       user_id, agent_id, provider_key, app_key, status, account_email,
       scopes_json, credentials_json, metadata_json, last_connected_at, updated_at
     ) VALUES (?, ?, ?, ?, 'connected', ?, ?, ?, ?, datetime('now'), datetime('now'))
     ON CONFLICT(user_id, agent_id, provider_key, app_key, account_email) DO UPDATE SET
       status = excluded.status,
       credentials_json = excluded.credentials_json,
       metadata_json = excluded.metadata_json,
       last_connected_at = excluded.last_connected_at,
       updated_at = excluded.updated_at`,
  ).run(
    userId,
    agentId,
    BITWARDEN_PROVIDER_KEY,
    BITWARDEN_APP.id,
    config.email,
    JSON.stringify(['vault:read_selected']),
    encryptValue(JSON.stringify({
      serverUrl: config.serverUrl,
      email: config.email,
    })),
    metadata,
  );
  if (existing && existing.account_email !== config.email) {
    db.prepare('DELETE FROM integration_connections WHERE id = ?').run(existing.id);
  }
  return loadConnection(userId, agentId);
}

function createBitwardenProvider(options = {}) {
  const app = options.app || null;
  const cli = () => app?.locals?.bitwardenCli;
  const broker = () => app?.locals?.credentialBroker;

  return {
    key: BITWARDEN_PROVIDER_KEY,
    label: 'Bitwarden',
    description: 'Fill browser logins and authenticate bounded API requests while keeping secrets hidden from the AI.',
    icon: 'password',
    apps: [BITWARDEN_APP],
    connectPrompt: 'Sign in with your Bitwarden email and master password. The password is used only for that sign-in and is never stored or sent to the AI.',
    supportsMultipleAccounts: false,
    connectionMethod: 'user_config',
    getApp(appId) {
      return text(appId) === BITWARDEN_APP.id ? BITWARDEN_APP : null;
    },
    getToolAppId() {
      return null;
    },
    getToolDefinitions() {
      return [];
    },
    supportsTool() {
      return false;
    },
    getEnvStatus(context = {}) {
      const userId = Number(context.userId);
      const agentId = Number.isInteger(userId) && userId > 0
        ? resolveAgentId(userId, context.agentId || null)
        : null;
      const config = agentId ? parseConfig(getProviderConfig(userId, BITWARDEN_PROVIDER_KEY, agentId)) : {};
      const missing = ['email'].filter((key) => !config[key]);
      return {
        configured: missing.length === 0,
        missing,
        summary: missing.length === 0
          ? 'Bitwarden is ready. Sign in once with the master password to connect the vault.'
          : 'Add the Bitwarden account email in Official Integrations.',
        setupMode: 'user',
      };
    },
    buildSnapshot(connectionRows, context = {}) {
      return buildBitwardenSnapshot(this, connectionRows, {
        ...context,
        credentialBindingsSummary: context.userId
          ? broker()?.summarizeBindings(context.userId, context.agentId)
          : 'No credential bindings are configured.',
      });
    },
    summarizeForModel(snapshot) {
      if (!snapshot?.connection?.connected) {
        return 'Bitwarden: not configured. The user can connect it in Official Integrations.';
      }
      const bindings = snapshot.credentialBindingsSummary || 'No credential bindings are configured.';
      return `Bitwarden credential broker: ${bindings} Secret values are never available to the model.`;
    },
    getUserConfig({ userId, agentId }) {
      const normalizedUserId = Number(userId);
      const scopedAgentId = resolveAgentId(normalizedUserId, agentId || null);
      const config = parseConfig(getProviderConfig(normalizedUserId, BITWARDEN_PROVIDER_KEY, scopedAgentId));
      return publicConfig(config, loadConnection(normalizedUserId, scopedAgentId), cli()?.getStatus(normalizedUserId, scopedAgentId));
    },
    async saveUserConfig({ userId, agentId, config }) {
      const normalizedUserId = Number(userId);
      if (!Number.isInteger(normalizedUserId) || normalizedUserId <= 0) {
        throw new Error('A valid user is required to save Bitwarden configuration.');
      }
      const scopedAgentId = resolveAgentId(normalizedUserId, agentId || null);
      const existing = getProviderConfig(normalizedUserId, BITWARDEN_PROVIDER_KEY, scopedAgentId);
      const parsed = parseConfig(config, existing);
      if (!parsed.email) {
        throw new Error('Bitwarden account email is required.');
      }
      if (!cli()) throw new Error('Bitwarden credential service is unavailable.');
      const currentConnection = loadConnection(normalizedUserId, scopedAgentId);
      if (
        currentConnection &&
        (
          text(currentConnection.account_email).toLowerCase() !== parsed.email.toLowerCase() ||
          normalizeServerUrl(existing.serverUrl) !== parsed.serverUrl
        )
      ) {
        await cli().logout(normalizedUserId, scopedAgentId);
        db.prepare('DELETE FROM integration_connections WHERE id = ?').run(
          currentConnection.id,
        );
      }
      setProviderConfig(normalizedUserId, BITWARDEN_PROVIDER_KEY, parsed, scopedAgentId);
      return publicConfig(
        parsed,
        loadConnection(normalizedUserId, scopedAgentId),
        cli().getStatus(normalizedUserId, scopedAgentId),
      );
    },
    async unlock({
      userId,
      agentId,
      masterPassword,
      persistSession = true,
      twoStepMethod,
      twoStepCode,
      signal,
    }) {
      const normalizedUserId = Number(userId);
      const scopedAgentId = resolveAgentId(normalizedUserId, agentId || null);
      const config = parseConfig(
        getProviderConfig(normalizedUserId, BITWARDEN_PROVIDER_KEY, scopedAgentId),
      );
      if (!config.email) {
        throw new Error('Save the Bitwarden account email before signing in.');
      }
      if (!cli()) throw new Error('Bitwarden credential service is unavailable.');
      await cli().unlock(
        normalizedUserId,
        scopedAgentId,
        masterPassword,
        config.idleTimeoutMinutes,
        {
          config,
          persistSession,
          twoStepMethod,
          twoStepCode,
          signal,
        },
      );
      const connection = upsertConnection(normalizedUserId, scopedAgentId, config);
      return publicConfig(
        config,
        connection,
        cli().getStatus(normalizedUserId, scopedAgentId),
      );
    },
    async testConnection(connection, executionOptions = {}) {
      if (!cli()) throw new Error('Bitwarden credential service is unavailable.');
      await cli().sync(
        connection.user_id,
        connection.agent_id,
        { signal: executionOptions.signal || null },
      );
      return {};
    },
    async clearUserConfig({ userId, agentId }) {
      const normalizedUserId = Number(userId);
      const scopedAgentId = resolveAgentId(normalizedUserId, agentId || null);
      await cli()?.logout(normalizedUserId, scopedAgentId);
      deleteProviderConfig(normalizedUserId, BITWARDEN_PROVIDER_KEY, scopedAgentId);
      db.prepare(
        'DELETE FROM integration_connections WHERE user_id = ? AND agent_id = ? AND provider_key = ?',
      ).run(normalizedUserId, scopedAgentId, BITWARDEN_PROVIDER_KEY);
      return { cleared: true };
    },
  };
}

module.exports = {
  createBitwardenProvider,
  normalizeServerUrl,
  parseConfig,
};
