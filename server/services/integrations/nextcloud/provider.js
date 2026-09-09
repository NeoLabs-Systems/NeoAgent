'use strict';

const crypto = require('node:crypto');
const db = require('../../../db/database');
const { resolveAgentId } = require('../../agents/manager');
const { createOAuthProvider } = require('../oauth_provider');
const {
  deleteProviderConfig,
  getProviderConfig,
  setProviderConfig,
} = require('../provider_config_store');
const { getConnectionAccessMode } = require('../access');
const { decryptValue, encryptValue } = require('../secrets');
const {
  APPS,
  FILES_APP,
  LOGIN_TIMEOUT_MS,
  PROVIDER_KEY,
} = require('./constants');
const { fetchStatus, fetchUser } = require('./client');
const { CALENDAR_TOOLS, executeCalendarTool } = require('./calendar');
const { CONTACT_TOOLS, executeContactsTool } = require('./contacts');
const { FILE_TOOLS, executeFilesTool } = require('./files');
const { pollLoginFlow, revokeAppPassword, startLoginFlow } = require('./login');
const { normalizeBaseUrl, text } = require('./network');

const TOOLS = Object.freeze([...FILE_TOOLS, ...CALENDAR_TOOLS, ...CONTACT_TOOLS]);
const SESSION_TTL_MS = LOGIN_TIMEOUT_MS + 60_000;

function parseConfig(input, existing = {}) {
  return { baseUrl: text(input?.baseUrl) || text(existing.baseUrl) };
}

function storedConfig(userId, agentId) {
  return parseConfig(getProviderConfig(Number(userId), PROVIDER_KEY, agentId));
}

function envStatus(context = {}) {
  const userId = Number(context.userId);
  const stored = Number.isInteger(userId) && userId > 0
    ? storedConfig(userId, context.agentId)
    : { baseUrl: '' };
  const configured = Boolean(stored.baseUrl);
  return {
    configured,
    missing: configured ? [] : ['baseUrl'],
    summary: configured
      ? 'Nextcloud is ready for account connections.'
      : 'Add your Nextcloud instance URL to enable Files, Calendar, and Contacts tools.',
    setupMode: 'user',
  };
}

function connectionCredentials(connection) {
  try {
    const parsed = JSON.parse(decryptValue(connection?.credentials_json || '{}') || '{}');
    return parsed && typeof parsed === 'object' ? parsed : {};
  } catch {
    return {};
  }
}

function connectionRows(userId, agentId) {
  return db.prepare(`SELECT * FROM integration_connections
    WHERE user_id=? AND agent_id=? AND provider_key=?`).all(userId, agentId, PROVIDER_KEY);
}

function connectedAccountCount(userId, agentId) {
  return db.prepare(`SELECT COUNT(DISTINCT account_email) count FROM integration_connections
    WHERE user_id=? AND agent_id=? AND provider_key=? AND status='connected'`)
    .get(userId, agentId, PROVIDER_KEY)?.count || 0;
}

function accountEmailForUser(baseUrl, user) {
  const host = new URL(normalizeBaseUrl(baseUrl)).host;
  return text(user.email) || `${text(user.id) || 'nextcloud'}@${host}`;
}

function parseJsonObject(value) {
  try {
    const parsed = JSON.parse(String(value || '{}'));
    return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {};
  } catch {
    return {};
  }
}

function upsertAppConnection(userId, agentId, appId, accountEmail, credentials, metadata) {
  const existing = db.prepare(`SELECT * FROM integration_connections
    WHERE user_id=? AND agent_id=? AND provider_key=? AND app_key=? AND account_email=?`)
    .get(userId, agentId, PROVIDER_KEY, appId, accountEmail);
  const accessMode = getConnectionAccessMode(existing || null);
  db.prepare(`INSERT INTO integration_connections (
       user_id, agent_id, provider_key, app_key, status, account_email,
       scopes_json, credentials_json, metadata_json, last_connected_at, updated_at
     ) VALUES (?, ?, ?, ?, 'connected', ?, ?, ?, ?, datetime('now'), datetime('now'))
     ON CONFLICT(user_id, agent_id, provider_key, app_key, account_email) DO UPDATE SET
       status = excluded.status,
       scopes_json = excluded.scopes_json,
       credentials_json = excluded.credentials_json,
       metadata_json = excluded.metadata_json,
       last_connected_at = excluded.last_connected_at,
       updated_at = excluded.updated_at`)
    .run(
      userId,
      agentId,
      PROVIDER_KEY,
      appId,
      accountEmail,
      JSON.stringify(['nextcloud:dav', 'nextcloud:ocs']),
      encryptValue(JSON.stringify(credentials)),
      JSON.stringify({
        ...parseJsonObject(existing?.metadata_json),
        access_mode: accessMode,
        ...metadata,
      }),
    );
  return db.prepare(`SELECT * FROM integration_connections
    WHERE user_id=? AND agent_id=? AND provider_key=? AND app_key=? AND account_email=?`)
    .get(userId, agentId, PROVIDER_KEY, appId, accountEmail);
}

async function revokeUniqueAccounts(rows, signal) {
  const seen = new Set();
  for (const row of rows) {
    const credentials = connectionCredentials(row);
    const key = `${text(credentials.username)}:${text(credentials.appPassword)}`;
    if (!credentials.appPassword || seen.has(key)) continue;
    seen.add(key);
    await revokeAppPassword(credentials, { signal });
  }
}

function createNextcloudProvider() {
  const sessions = new Map();
  const pruneTimer = setInterval(() => {
    const cutoff = Date.now() - SESSION_TTL_MS;
    for (const [id, session] of sessions) {
      if (Number(session.createdAt) < cutoff) sessions.delete(id);
    }
  }, 30_000);
  pruneTimer.unref?.();

  async function completeLogin(session) {
    try {
      const issued = await pollLoginFlow(session.poll, { timeoutMs: LOGIN_TIMEOUT_MS });
      const credentials = {
        baseUrl: session.baseUrl,
        username: issued.loginName,
        appPassword: issued.appPassword,
      };
      const user = await fetchUser(credentials);
      const accountEmail = accountEmailForUser(session.baseUrl, { ...user, id: user.id || issued.loginName });
      const metadata = {
        baseUrl: session.baseUrl,
        username: issued.loginName,
        displayName: user.displayName || null,
        email: user.email || null,
      };
      let filesConnection = null;
      for (const app of APPS) {
        const connection = upsertAppConnection(
          session.userId,
          session.agentId,
          app.id,
          accountEmail,
          credentials,
          metadata,
        );
        if (app.id === FILES_APP.id) filesConnection = connection;
      }
      session.status = 'connected';
      session.accountEmail = accountEmail;
      session.connectionId = filesConnection?.id || null;
      session.error = null;
    } catch (error) {
      session.status = 'failed';
      session.error = error?.message || 'Nextcloud login failed.';
    }
  }

  const provider = createOAuthProvider({
    key: PROVIDER_KEY,
    label: 'Nextcloud',
    description: 'Connect a Nextcloud instance so agents can manage files, shares, calendars, and contacts.',
    icon: 'nextcloud',
    apps: APPS,
    toolDefinitions: TOOLS,
    connectPrompt: 'Add your Nextcloud URL once, then sign in on the Nextcloud login page.',
    supportsMultipleAccounts: true,
    connectionMethod: 'user_config',
    getEnvStatus: envStatus,
    async beginOAuth() {
      throw new Error('Nextcloud uses Login Flow v2. Open Official Integrations, save the instance URL, and connect.');
    },
    async finishOAuth() {
      throw new Error('Nextcloud uses Login Flow v2 rather than an OAuth callback.');
    },
    executeTool(toolName, args, context) {
      const credentials = context.credentials;
      const options = { signal: context.signal || null };
      const result = executeFilesTool(toolName, args || {}, credentials, options)
        || executeCalendarTool(toolName, args || {}, credentials, options)
        || executeContactsTool(toolName, args || {}, credentials, options);
      if (result) return result;
      throw new Error(`Unsupported Nextcloud tool: ${toolName}`);
    },
    async disconnect(connection, executionOptions = {}) {
      await revokeUniqueAccounts([connection], executionOptions.signal || null);
      db.prepare(`DELETE FROM integration_connections
        WHERE user_id=? AND agent_id=? AND provider_key=? AND account_email=? AND id!=?`)
        .run(
          connection.user_id,
          connection.agent_id,
          PROVIDER_KEY,
          connection.account_email,
          connection.id,
        );
    },
    async testConnection(context) {
      await fetchUser(context.credentials, { signal: context.signal });
      return {};
    },
  });

  provider.beginConnection = async ({ userId, agentId, appKey }) => {
    if (!provider.getApp(appKey)) {
      throw new Error(`Unknown ${provider.label} app: ${appKey || 'missing app key'}`);
    }
    const scoped = resolveAgentId(userId, agentId);
    const baseUrl = normalizeBaseUrl(storedConfig(userId, scoped).baseUrl);
    const started = await startLoginFlow(baseUrl);
    const sessionId = crypto.randomBytes(18).toString('hex');
    const session = {
      id: sessionId,
      userId,
      agentId: scoped,
      appKey,
      baseUrl,
      status: 'connecting',
      loginUrl: started.loginUrl,
      poll: started.poll,
      connectionId: null,
      accountEmail: null,
      error: null,
      createdAt: Date.now(),
    };
    sessions.set(sessionId, session);
    completeLogin(session);
    return {
      provider: provider.key,
      appId: appKey,
      status: 'interactive_connect',
      sessionId,
      url: `/api/integrations/${provider.key}/connect/${sessionId}`,
    };
  };

  provider.getConnectionSession = (userId, providerKey, sessionId, agentId = null) => {
    if (providerKey !== provider.key) return null;
    const session = sessions.get(String(sessionId || '').trim());
    if (!session) return null;
    if (session.userId !== userId || String(session.agentId || '') !== String(agentId || '')) {
      return null;
    }
    return {
      id: session.id,
      provider: provider.key,
      appId: session.appKey,
      status: session.status,
      loginUrl: session.loginUrl || null,
      connectionId: session.connectionId || null,
      accountEmail: session.accountEmail || null,
      error: session.error || null,
      qr: null,
    };
  };

  provider.getUserConfig = ({ userId, agentId }) => {
    const scoped = resolveAgentId(Number(userId), agentId);
    const stored = storedConfig(Number(userId), scoped);
    const accountCount = connectedAccountCount(Number(userId), scoped);
    return {
      baseUrl: stored.baseUrl,
      configured: Boolean(stored.baseUrl),
      accountCount,
      hasConnectedAccount: accountCount > 0,
    };
  };

  provider.saveUserConfig = async ({ userId, agentId, config, signal }) => {
    const normalizedUserId = Number(userId);
    const scoped = resolveAgentId(normalizedUserId, agentId);
    const existing = storedConfig(normalizedUserId, scoped);
    const baseUrl = normalizeBaseUrl(parseConfig(config, existing).baseUrl);
    await fetchStatus(baseUrl, { signal });
    setProviderConfig(normalizedUserId, PROVIDER_KEY, { baseUrl }, scoped);
    if (existing.baseUrl && existing.baseUrl !== baseUrl) {
      await revokeUniqueAccounts(connectionRows(normalizedUserId, scoped), signal);
      db.prepare('DELETE FROM integration_connections WHERE user_id=? AND agent_id=? AND provider_key=?')
        .run(normalizedUserId, scoped, PROVIDER_KEY);
    }
    return provider.getUserConfig({ userId: normalizedUserId, agentId: scoped });
  };

  provider.clearUserConfig = async ({ userId, agentId }) => {
    const normalizedUserId = Number(userId);
    const scoped = resolveAgentId(normalizedUserId, agentId);
    await revokeUniqueAccounts(connectionRows(normalizedUserId, scoped));
    deleteProviderConfig(normalizedUserId, PROVIDER_KEY, scoped);
    db.prepare('DELETE FROM integration_connections WHERE user_id=? AND agent_id=? AND provider_key=?')
      .run(normalizedUserId, scoped, PROVIDER_KEY);
    return { cleared: true };
  };

  provider.summarizeForModel = (snapshot) => {
    if (!snapshot?.env?.configured) {
      return 'Nextcloud: setup is not complete yet. Tell the user to add their Nextcloud URL in Official Integrations.';
    }
    if (!snapshot.connection?.connected) {
      return 'Nextcloud: setup is ready, but no Nextcloud account is connected yet. Tell the user to open Official Integrations and sign in.';
    }
    return [
      'Nextcloud: connected. Use Nextcloud tools for the user\'s files, shares, calendars, and contacts on their instance.',
      'Prefer nextcloud_list_files and nextcloud_search_files for documents,',
      'nextcloud_list_events for schedule questions, and nextcloud_list_contacts for people.',
      'Use nextcloud_ocs_request only for other Nextcloud apps under /ocs/v2.php/.',
      'Talk chat stays in messaging, not these tools.',
    ].join(' ');
  };

  provider.shutdown = () => {
    clearInterval(pruneTimer);
    sessions.clear();
  };

  return provider;
}

module.exports = { createNextcloudProvider };
