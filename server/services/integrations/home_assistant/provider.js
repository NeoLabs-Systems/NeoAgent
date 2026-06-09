'use strict';

const db = require('../../../db/database');
const { resolveAgentId } = require('../../agents/manager');
const {
  deleteProviderConfig,
  getProviderConfig,
  setProviderConfig,
} = require('../provider_config_store');
const { getConnectionAccessMode } = require('../access');
const { encryptValue } = require('../secrets');
const {
  HOME_ASSISTANT_APP,
  HOME_ASSISTANT_PROVIDER_KEY,
  HOME_ASSISTANT_TOOL_DEFINITIONS,
  toolAppMap,
} = require('./constants');
const {
  assertPublicHomeAssistantEndpoint,
  buildHomeAssistantUrl,
  isBlockedIpAddress,
  normalizeHomeAssistantBaseUrl,
  trimText,
} = require('./network');
const { buildHomeAssistantSnapshot } = require('./snapshot');
const {
  executeHomeAssistantTool,
  fetchHomeAssistantConfig,
  parseCredentials,
} = require('./tools');

function parseJsonObject(value) {
  try {
    const parsed = JSON.parse(String(value || '{}'));
    return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {};
  } catch {
    return {};
  }
}

function parseConfigInput(rawConfig, existingConfig = {}) {
  const source = rawConfig && typeof rawConfig === 'object' ? rawConfig : {};
  return {
    baseUrl: trimText(source.baseUrl) || trimText(existingConfig.baseUrl),
    token: trimText(source.token) || trimText(existingConfig.token),
  };
}

function accountEmailForConfig(baseUrl, config = {}) {
  const host = new URL(normalizeHomeAssistantBaseUrl(baseUrl)).host;
  const location = trimText(config.location_name);
  return `home_assistant:${location || host}`;
}

function resolveHomeAssistantEnvStatus(userId, agentId = null) {
  const normalizedUserId = Number(userId);
  const config = Number.isInteger(normalizedUserId) && normalizedUserId > 0
    ? parseConfigInput(getProviderConfig(normalizedUserId, HOME_ASSISTANT_PROVIDER_KEY, agentId))
    : { baseUrl: '', token: '' };
  const missing = [];
  if (!config.baseUrl) missing.push('baseUrl');
  if (!config.token) missing.push('token');
  return {
    configured: missing.length === 0,
    missing,
    summary: missing.length === 0
      ? 'Home Assistant is ready for account connections.'
      : 'Add your Home Assistant HTTPS URL and a Long-Lived Access Token in Official Integrations.',
    setupMode: 'user',
  };
}

function sanitizeHomeAssistantConfigForClient(rawConfig) {
  const config = parseConfigInput(rawConfig);
  return {
    baseUrl: config.baseUrl,
    hasToken: Boolean(config.token),
    configured: Boolean(config.baseUrl && config.token),
  };
}

function loadExistingConnection(userId, agentId) {
  return db
    .prepare(
      `SELECT *
       FROM integration_connections
       WHERE user_id = ? AND agent_id = ? AND provider_key = ?
       ORDER BY updated_at DESC, id DESC
       LIMIT 1`,
    )
    .get(userId, agentId, HOME_ASSISTANT_PROVIDER_KEY);
}

function upsertHomeAssistantConnection(userId, agentId, baseUrl, token, config) {
  const existing = loadExistingConnection(userId, agentId);
  const accessMode = getConnectionAccessMode(existing || null);
  const metadata = {
    ...parseJsonObject(existing?.metadata_json || '{}'),
    access_mode: accessMode,
    locationName: config?.location_name || null,
    version: config?.version || null,
    timeZone: config?.time_zone || null,
  };
  const accountEmail = accountEmailForConfig(baseUrl, config);

  db.prepare(
    `INSERT INTO integration_connections (
       user_id, agent_id, provider_key, app_key, status, account_email,
       scopes_json, credentials_json, metadata_json, last_connected_at, updated_at
     ) VALUES (?, ?, ?, ?, 'connected', ?, ?, ?, ?, datetime('now'), datetime('now'))
     ON CONFLICT(user_id, agent_id, provider_key, app_key, account_email) DO UPDATE SET
       status = excluded.status,
       scopes_json = excluded.scopes_json,
       credentials_json = excluded.credentials_json,
       metadata_json = excluded.metadata_json,
       last_connected_at = excluded.last_connected_at,
       updated_at = excluded.updated_at`,
  ).run(
    userId,
    agentId,
    HOME_ASSISTANT_PROVIDER_KEY,
    HOME_ASSISTANT_APP.id,
    accountEmail,
    JSON.stringify(['home_assistant:api']),
    encryptValue(JSON.stringify({ baseUrl, token })),
    JSON.stringify(metadata),
  );

  if (existing && existing.account_email !== accountEmail) {
    db.prepare('DELETE FROM integration_connections WHERE id = ? AND user_id = ? AND agent_id = ?')
      .run(existing.id, userId, agentId);
  }

  return loadExistingConnection(userId, agentId);
}

function createHomeAssistantProvider() {
  return {
    key: HOME_ASSISTANT_PROVIDER_KEY,
    label: 'Home Assistant',
    description: 'Official Home Assistant integration for one user-managed HTTPS instance with state reads and service calls.',
    icon: 'home_assistant',
    apps: [HOME_ASSISTANT_APP],
    connectPrompt: 'Save your Home Assistant HTTPS URL and a Long-Lived Access Token. Private and loopback network targets are blocked server-side.',
    supportsMultipleAccounts: false,
    connectionMethod: 'user_config',
    getApp(appId) {
      return String(appId || '').trim() === HOME_ASSISTANT_APP.id ? HOME_ASSISTANT_APP : null;
    },
    getToolAppId(toolName) {
      return toolAppMap.get(String(toolName || '').trim()) || null;
    },
    getEnvStatus(context = {}) {
      return resolveHomeAssistantEnvStatus(context.userId, context.agentId);
    },
    getToolDefinitions(options = {}) {
      const connectedAppIds = new Set(options.connectedAppIds || []);
      return connectedAppIds.has(HOME_ASSISTANT_APP.id) ? HOME_ASSISTANT_TOOL_DEFINITIONS.slice() : [];
    },
    supportsTool(toolName) {
      return toolAppMap.has(String(toolName || '').trim());
    },
    buildSnapshot(connectionRows, context = {}) {
      return buildHomeAssistantSnapshot(this, connectionRows, context);
    },
    summarizeForModel(snapshot) {
      if (!snapshot?.env?.configured) {
        return 'Home Assistant: setup is not complete for this user yet. Tell them to finish Home Assistant setup in Official Integrations first.';
      }
      if (!snapshot.connection?.connected) {
        return 'Home Assistant: setup is ready, but no Home Assistant instance is connected yet. Tell the user to open Official Integrations and connect it.';
      }
      return 'Home Assistant: native Home Assistant access is connected in this run with tools for config, states, entity state, service calls, and /api requests.';
    },
    async executeTool(toolName, args, connection) {
      return executeHomeAssistantTool(toolName, args, connection);
    },
    getUserConfig({ userId, agentId }) {
      const normalizedUserId = Number(userId);
      const scopedAgentId = resolveAgentId(normalizedUserId, agentId || null);
      const storedConfig = getProviderConfig(normalizedUserId, HOME_ASSISTANT_PROVIDER_KEY, scopedAgentId);
      const connection = loadExistingConnection(normalizedUserId, scopedAgentId);
      return {
        ...sanitizeHomeAssistantConfigForClient({ ...storedConfig, ...parseCredentials(connection) }),
        accountCount: connection?.status === 'connected' ? 1 : 0,
        hasConnectedAccount: connection?.status === 'connected',
      };
    },
    async saveUserConfig({ userId, agentId, config }) {
      const normalizedUserId = Number(userId);
      if (!Number.isInteger(normalizedUserId) || normalizedUserId <= 0) {
        throw new Error('A valid user is required to save Home Assistant configuration.');
      }
      const scopedAgentId = resolveAgentId(normalizedUserId, agentId || null);
      const existingConnection = loadExistingConnection(normalizedUserId, scopedAgentId);
      const existingConfig = parseConfigInput({
        ...getProviderConfig(normalizedUserId, HOME_ASSISTANT_PROVIDER_KEY, scopedAgentId),
        ...parseCredentials(existingConnection),
      });
      const parsedConfig = parseConfigInput(config, existingConfig);
      const baseUrl = normalizeHomeAssistantBaseUrl(parsedConfig.baseUrl);
      const token = parsedConfig.token;
      if (!token) throw new Error('Home Assistant Long-Lived Access Token is required.');

      const credentials = { baseUrl, token };
      await assertPublicHomeAssistantEndpoint(baseUrl);
      let haConfig;
      try {
        haConfig = await fetchHomeAssistantConfig(credentials);
      } catch (error) {
        const message = String(error?.message || '').toLowerCase();
        if (message.includes('401') || message.includes('unauthorized')) {
          throw new Error('Home Assistant rejected the token. Create a new Long-Lived Access Token and try again.');
        }
        throw error;
      }

      setProviderConfig(normalizedUserId, HOME_ASSISTANT_PROVIDER_KEY, { baseUrl, token }, scopedAgentId);
      const connection = upsertHomeAssistantConnection(normalizedUserId, scopedAgentId, baseUrl, token, haConfig || {});
      return {
        ...sanitizeHomeAssistantConfigForClient({ baseUrl, token }),
        accountCount: connection?.status === 'connected' ? 1 : 0,
        hasConnectedAccount: connection?.status === 'connected',
        accountEmail: connection?.account_email || null,
        locationName: haConfig?.location_name || null,
        version: haConfig?.version || null,
      };
    },
    clearUserConfig({ userId, agentId }) {
      const normalizedUserId = Number(userId);
      if (!Number.isInteger(normalizedUserId) || normalizedUserId <= 0) {
        throw new Error('A valid user is required to clear Home Assistant configuration.');
      }
      const scopedAgentId = resolveAgentId(normalizedUserId, agentId || null);
      deleteProviderConfig(normalizedUserId, HOME_ASSISTANT_PROVIDER_KEY, scopedAgentId);
      db.prepare('DELETE FROM integration_connections WHERE user_id = ? AND agent_id = ? AND provider_key = ?')
        .run(normalizedUserId, scopedAgentId, HOME_ASSISTANT_PROVIDER_KEY);
      return { cleared: true };
    },
  };
}

module.exports = {
  assertPublicHomeAssistantEndpoint,
  buildHomeAssistantUrl,
  createHomeAssistantProvider,
  isBlockedIpAddress,
  normalizeHomeAssistantBaseUrl,
};
