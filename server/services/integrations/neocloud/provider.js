'use strict';

const crypto = require('node:crypto');
const db = require('../../../db/database');
const { resolveAgentId } = require('../../agents/manager');
const { deleteProviderConfig, getProviderConfig, setProviderConfig } = require('../provider_config_store');
const { appendQuery, createOAuthProvider, fetchJson } = require('../oauth_provider');
const { getConnectionAccessMode } = require('../access');
const { resolvePublicBaseUrl } = require('../env');
const { decryptValue } = require('../secrets');
const { APP, PROVIDER_KEY, SCOPES, TOOLS } = require('./constants');
const {
  authenticated,
  bootstrap,
  executeTool,
  normalizeBaseUrl,
  parseScopes,
  revoke,
  text,
  token,
  userinfo,
} = require('./client');

const TOOL_SCOPES = new Map(TOOLS.map((tool) => [tool.name, tool.scope]));

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
      ? 'NeoCloud is ready for account connections.'
      : 'Add the NeoCloud server URL to enable file and signature tools.',
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

// The scopes the user granted on NeoCloud's consent page for this connection.
function grantedScopes(connection) {
  try {
    const stored = JSON.parse(connection?.scopes_json || '[]');
    if (Array.isArray(stored)) return new Set(stored.map(text).filter(Boolean));
  } catch {
    // Fall through to the empty grant.
  }
  return new Set();
}

function connectionAllowsTool(connection, tool) {
  if (!grantedScopes(connection).has(tool.scope)) return false;
  return tool.access === 'read' || getConnectionAccessMode(connection) !== 'read_only';
}

function filterToolDefinitions(tools, connections) {
  return tools.filter((tool) => connections.some((connection) => connectionAllowsTool(connection, tool)));
}

async function oauthClient(userId, agentId, signal) {
  const baseUrl = normalizeBaseUrl(storedConfig(userId, resolveAgentId(userId, agentId)).baseUrl);
  const redirectUri = callbackUrl();
  const boot = await bootstrap(baseUrl, redirectUri, { signal });
  return { baseUrl, clientId: text(boot.clientId), redirectUri: text(boot.redirectUri) || redirectUri };
}

function createNeoCloudProvider() {
  const provider = createOAuthProvider({
    key: PROVIDER_KEY,
    label: 'NeoCloud',
    description: 'Connect a self-hosted NeoCloud server so agents can read and manage files, write PDFs and send documents for e-signature.',
    icon: 'neocloud',
    apps: [APP],
    toolDefinitions: TOOLS,
    filterToolDefinitions,
    connectPrompt: 'Add the NeoCloud server URL once, then sign in with OAuth and choose what NeoAgent may do.',
    supportsMultipleAccounts: true,
    connectionMethod: 'user_config',
    requiresRefreshToken: true,
    getEnvStatus: envStatus,
    async beginOAuth({ state, codeVerifier, userId, agentId, signal }) {
      const client = await oauthClient(userId, agentId, signal);
      const challenge = crypto.createHash('sha256').update(String(codeVerifier)).digest('base64url');
      // Authorize against the user-configured URL, not one bootstrap advertises:
      // the browser must reach the same host NeoAgent was set up with.
      return {
        url: appendQuery(`${client.baseUrl}/oauth/authorize`, {
          response_type: 'code', client_id: client.clientId, redirect_uri: client.redirectUri,
          state, code_challenge: challenge, code_challenge_method: 'S256', scope: SCOPES.join(' '),
        }),
      };
    },
    async finishOAuth({ userId, agentId, code, codeVerifier, signal }) {
      const client = await oauthClient(userId, agentId, signal);
      const issued = await token(client.baseUrl, {
        grant_type: 'authorization_code', client_id: client.clientId, code: text(code),
        redirect_uri: client.redirectUri, code_verifier: text(codeVerifier),
      }, { signal });
      const accessToken = text(issued.access_token);
      const refreshToken = text(issued.refresh_token);
      if (!accessToken || !refreshToken) throw new Error('NeoCloud did not return durable OAuth credentials.');
      const info = await userinfo(client.baseUrl, accessToken, { signal });
      const scopes = parseScopes(issued.scope || info.scope);
      if (scopes.length === 0) throw new Error('NeoCloud did not report which access was granted.');
      const host = new URL(client.baseUrl).host;
      const accountEmail = text(info.email) || text(info.preferred_username) || `neocloud:${text(info.sub) || host}`;
      return {
        accountEmail,
        scopes,
        credentials: {
          baseUrl: client.baseUrl, client_id: client.clientId, access_token: accessToken, refresh_token: refreshToken,
          scope: scopes.join(' '), expires_at_ms: Date.now() + Math.max(1, Number(issued.expires_in) || 3600) * 1000,
        },
        metadata: { baseUrl: client.baseUrl, username: text(info.preferred_username), email: text(info.email) || null },
      };
    },
    executeTool(toolName, args, context) {
      const scope = TOOL_SCOPES.get(toolName);
      if (scope && !grantedScopes(context.connection).has(scope)) {
        throw new Error(`This NeoCloud account did not grant ${scope}. Reconnect it and allow that access on NeoCloud's consent page.`);
      }
      return executeTool(toolName, args || {}, context.credentials, { signal: context.signal });
    },
    disconnect(connection, executionOptions = {}) {
      return revoke(connectionCredentials(connection), {
        signal: executionOptions.signal || null,
      });
    },
    async testConnection(context) {
      const authorization = await authenticated(context.credentials, { signal: context.signal });
      await userinfo(authorization.baseUrl, authorization.accessToken, { signal: context.signal });
      return { credentials: authorization.credentials };
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
    const health = await fetchJson(`${baseUrl}/api/health`, { method: 'GET', signal }, { serviceName: 'NeoCloud health check' });
    const version = await fetchJson(`${baseUrl}/api/version`, { method: 'GET', signal }, { serviceName: 'NeoCloud version check' });
    if (text(health?.status) !== 'ok' || text(version?.product) !== 'neocloud') {
      throw new Error('The configured endpoint did not identify itself as a healthy NeoCloud server.');
    }
    let boot;
    try {
      boot = await bootstrap(baseUrl, callbackUrl(), { signal });
    } catch (error) {
      const detail = text(error?.message) || 'companion bootstrap failed';
      throw new Error(
        `NeoCloud rejected NeoAgent OAuth setup (${detail}). `
        + 'Confirm NeoAgent PUBLIC_URL is reachable from this browser and uses '
        + 'HTTPS, or HTTP on a private/loopback address, ending at '
        + '/api/integrations/oauth/callback.',
      );
    }
    if (text(boot?.companion) !== 'neoagent' || !text(boot?.clientId)) {
      throw new Error('The NeoCloud server does not expose the NeoAgent companion OAuth contract.');
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
    ? 'NeoCloud: setup is not complete yet.'
    : !snapshot.connection?.connected
      ? 'NeoCloud: setup is ready, but no NeoCloud account is connected.'
      : [
        'NeoCloud: connected. It is the user\'s own cloud drive and e-signature service.',
        'Use neocloud_list_files, neocloud_search_files and neocloud_read_file to find and read their files,',
        'and the write tools to save files, folders and PDFs (neocloud_create_pdf turns Markdown into a PDF).',
        'For "write a quick contract and send me the links for my friend to sign", call neocloud_request_signatures',
        'once with document { path, title, markdown } and the signers (name, optional email); NeoCloud saves the PDF,',
        'adds the signature block and returns each signer\'s private url. Reply with every signer\'s name and url so',
        'the user can forward them; the links are private and are only returned once. Use',
        'neocloud_get_signature_request to check who has signed. Only the tools this account granted are offered.',
      ].join(' ');
  return provider;
}

module.exports = { createNeoCloudProvider };
