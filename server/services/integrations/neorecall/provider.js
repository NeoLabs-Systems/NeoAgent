'use strict';

const crypto = require('node:crypto');
const db = require('../../../db/database');
const { resolveAgentId } = require('../../agents/manager');
const { deleteProviderConfig, getProviderConfig, setProviderConfig } = require('../provider_config_store');
const { appendQuery, createOAuthProvider, fetchJson } = require('../oauth_provider');
const { resolvePublicBaseUrl } = require('../env');
const { decryptValue } = require('../secrets');
const { APP, PROVIDER_KEY, SCOPES, TOOLS } = require('./constants');
const { bootstrap, executeTool, normalizeBaseUrl, revoke, text, token } = require('./client');

function callbackUrl() {
  return `${resolvePublicBaseUrl()}/api/integrations/oauth/callback`;
}

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
      ? 'NeoRecall is ready for account connections.'
      : 'Add the NeoRecall backend URL to enable personal recall tools.',
    setupMode: 'user',
  };
}

function connectedAccountCount(userId, agentId) {
  return db.prepare(`SELECT COUNT(*) count FROM integration_connections
    WHERE user_id=? AND agent_id=? AND provider_key=? AND status='connected'`)
    .get(userId, agentId, PROVIDER_KEY)?.count || 0;
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

function createNeoRecallProvider() {
  const provider = createOAuthProvider({
    key: PROVIDER_KEY,
    label: 'NeoRecall',
    description: 'Connect a self-hosted NeoRecall server so agents can search personal memories and transcript evidence on demand.',
    icon: 'neorecall',
    apps: [APP],
    toolDefinitions: TOOLS,
    connectPrompt: 'Add the NeoRecall backend URL once, then authorize read-only recall access with OAuth.',
    supportsMultipleAccounts: true,
    connectionMethod: 'user_config',
    requiresRefreshToken: true,
    getEnvStatus: envStatus,
    async beginOAuth({ state, codeVerifier, userId, agentId, signal }) {
      const baseUrl = normalizeBaseUrl(storedConfig(userId, resolveAgentId(userId, agentId)).baseUrl);
      const boot = await bootstrap(baseUrl, callbackUrl(), { signal });
      const challenge = crypto.createHash('sha256').update(String(codeVerifier)).digest('base64url');
      return {
        url: appendQuery(text(boot.authorizationEndpoint) || `${baseUrl}/oauth/authorize`, {
          response_type: 'code', client_id: boot.clientId, redirect_uri: text(boot.redirectUri) || callbackUrl(),
          state, code_challenge: challenge, code_challenge_method: 'S256',
          scope: Array.isArray(boot.scopes) ? boot.scopes.join(' ') : SCOPES.join(' '),
        }),
      };
    },
    async finishOAuth({ userId, agentId, code, codeVerifier, signal }) {
      const baseUrl = normalizeBaseUrl(storedConfig(userId, resolveAgentId(userId, agentId)).baseUrl);
      const boot = await bootstrap(baseUrl, callbackUrl(), { signal });
      const issued = await token(baseUrl, {
        grant_type: 'authorization_code', client_id: boot.clientId, code: text(code),
        redirect_uri: text(boot.redirectUri) || callbackUrl(), code_verifier: text(codeVerifier),
      }, { signal });
      const accessToken = text(issued.access_token);
      const refreshToken = text(issued.refresh_token);
      if (!accessToken || !refreshToken) throw new Error('NeoRecall did not return durable OAuth credentials.');
      const info = await fetchJson(`${baseUrl}/oauth/userinfo`, {
        headers: { Authorization: `Bearer ${accessToken}` },
        signal,
      }, { serviceName: 'NeoRecall userinfo' });
      const host = new URL(baseUrl).host;
      const accountEmail = text(info.email) || text(info.preferred_username) || `neorecall:${text(info.sub) || host}`;
      return {
        accountEmail,
        scopes: text(issued.scope).split(/\s+/).filter(Boolean),
        credentials: {
          baseUrl, client_id: text(boot.clientId), access_token: accessToken, refresh_token: refreshToken,
          scope: text(issued.scope), expires_at_ms: Date.now() + Math.max(1, Number(issued.expires_in) || 3600) * 1000,
        },
        metadata: { baseUrl, username: text(info.preferred_username), email: text(info.email) || null },
      };
    },
    executeTool(toolName, args, context) {
      return executeTool(toolName, args || {}, context.credentials, {
        signal: context.signal,
      });
    },
    disconnect(connection, executionOptions = {}) {
      return revoke(connectionCredentials(connection), {
        signal: executionOptions.signal || null,
      });
    },
  });

  provider.getUserConfig = ({ userId, agentId }) => {
    const scoped = resolveAgentId(Number(userId), agentId);
    const stored = storedConfig(Number(userId), scoped);
    const accountCount = connectedAccountCount(Number(userId), scoped);
    return { baseUrl: stored.baseUrl, configured: Boolean(stored.baseUrl), accountCount, hasConnectedAccount: accountCount > 0 };
  };
  provider.saveUserConfig = async ({ userId, agentId, config, signal }) => {
    const normalizedUserId = Number(userId);
    const scoped = resolveAgentId(normalizedUserId, agentId);
    const existing = storedConfig(normalizedUserId, scoped);
    const baseUrl = normalizeBaseUrl(parseConfig(config, existing).baseUrl);
    const health = await fetchJson(
      `${baseUrl}/health`,
      { method: 'GET', signal },
      { serviceName: 'NeoRecall health check' },
    );
    if (text(health?.status) !== 'ok' || text(health?.process) !== 'http') {
      throw new Error('The configured endpoint did not identify itself as a healthy NeoRecall HTTP service.');
    }
    const boot = await bootstrap(baseUrl, callbackUrl(), { signal });
    if (text(boot?.companion) !== 'neoagent' || !text(boot?.clientId)) {
      throw new Error('The NeoRecall server does not expose the NeoAgent companion OAuth contract.');
    }
    setProviderConfig(normalizedUserId, PROVIDER_KEY, { baseUrl }, scoped);
    if (existing.baseUrl && existing.baseUrl !== baseUrl) {
      await Promise.allSettled(connectionRows(normalizedUserId, scoped).map((row) => provider.disconnect(row)));
      db.prepare('DELETE FROM integration_connections WHERE user_id=? AND agent_id=? AND provider_key=?')
        .run(normalizedUserId, scoped, PROVIDER_KEY);
    }
    return provider.getUserConfig({ userId: normalizedUserId, agentId: scoped });
  };
  provider.clearUserConfig = async ({ userId, agentId }) => {
    const normalizedUserId = Number(userId);
    const scoped = resolveAgentId(normalizedUserId, agentId);
    await Promise.allSettled(connectionRows(normalizedUserId, scoped).map((row) => provider.disconnect(row)));
    deleteProviderConfig(normalizedUserId, PROVIDER_KEY, scoped);
    db.prepare('DELETE FROM integration_connections WHERE user_id=? AND agent_id=? AND provider_key=?')
      .run(normalizedUserId, scoped, PROVIDER_KEY);
    return { cleared: true };
  };
  provider.summarizeForModel = (snapshot) => !snapshot?.env?.configured
    ? 'NeoRecall: setup is not complete yet.'
    : !snapshot.connection?.connected
      ? 'NeoRecall: setup is ready, but no recall account is connected.'
      : 'NeoRecall: connected with token-free hybrid search and read-only access to memories, mini-memories, daily summaries, conversations, and transcript evidence. Use neorecall_search when the user asks to recall past events, discussions, people, facts, tasks, or promises.';
  return provider;
}

module.exports = { createNeoRecallProvider };
