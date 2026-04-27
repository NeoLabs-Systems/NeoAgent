'use strict';

const crypto = require('crypto');
const { describeEnvStatus, resolvePublicBaseUrl } = require('../env');
const { decryptValue } = require('../secrets');
const { getConnectionAccessMode } = require('../access');

const CODEX_AUTHORIZE_URL = 'https://chatgpt.com/oauth/authorize';
const CODEX_TOKEN_URL = 'https://chatgpt.com/api/login/oauth/token';
const CODEX_SCOPES = ['openid', 'profile', 'email', 'offline_access'];

function base64UrlSha256(value) {
  return crypto
    .createHash('sha256')
    .update(String(value || ''))
    .digest('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');
}

function generateCodeVerifier() {
  return base64UrlSha256(crypto.randomBytes(32));
}

function generateState() {
  return crypto.randomBytes(32).toString('hex');
}

function describeCodexEnvStatus() {
  return {
    configured: true,
    missing: [],
    summary: 'OpenAI Codex uses ChatGPT OAuth sign-in.',
  };
}

function sortConnections(rows) {
  return rows.slice().sort((left, right) => {
    const leftEmail = String(left.account_email || '').toLowerCase();
    const rightEmail = String(right.account_email || '').toLowerCase();
    if (leftEmail !== rightEmail) return leftEmail.localeCompare(rightEmail);
    return String(right.updated_at || '').localeCompare(String(left.updated_at || ''));
  });
}

function summarizeAccountRow(row, envStatus) {
  if (!envStatus.configured) {
    return {
      id: row?.id || null,
      status: 'env_not_configured',
      connected: false,
      accountEmail: row?.account_email || null,
      lastConnectedAt: row?.last_connected_at || null,
    };
  }

  if (!row) {
    return {
      id: null,
      status: 'not_connected',
      connected: false,
      accountEmail: null,
      lastConnectedAt: null,
      accessMode: 'read_write',
    };
  }

  return {
    id: row.id || null,
    status: row.status || 'not_connected',
    connected: row.status === 'connected',
    accountEmail: row.account_email || null,
    lastConnectedAt: row.last_connected_at || null,
    accessMode: getConnectionAccessMode(row),
  };
}

function summarizeAppConnection(app, connectionRows, envStatus) {
  const accounts = sortConnections(connectionRows).map((row) =>
    summarizeAccountRow(row, envStatus),
  );
  const connectedAccounts = accounts.filter((account) => account.connected);
  const latestConnectedAt = connectedAccounts
    .map((account) => account.lastConnectedAt)
    .filter(Boolean)
    .sort()
    .reverse()[0] || null;
  const status = !envStatus.configured
    ? 'env_not_configured'
    : connectedAccounts.length > 0
    ? 'connected'
    : accounts.some((account) => account.status === 'authorizing')
    ? 'authorizing'
    : 'not_connected';

  return {
    id: app.id,
    label: app.label,
    description: app.description,
    accounts,
    connection: {
      status,
      connected: connectedAccounts.length > 0,
      accountCount: connectedAccounts.length,
      accountEmail:
        connectedAccounts.length === 1
          ? connectedAccounts[0].accountEmail
          : null,
      lastConnectedAt: latestConnectedAt,
    },
    availableToolCount: 0,
  };
}

async function exchangeCodeForToken(code, codeVerifier, redirectUri) {
  const response = await fetch(CODEX_TOKEN_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      Accept: 'application/json',
    },
    body: new URLSearchParams({
      grant_type: 'authorization_code',
      client_id: 'codex',
      code,
      code_verifier: codeVerifier,
      redirect_uri: redirectUri,
    }).toString(),
  });

  if (!response.ok) {
    const errorText = await response.text().catch(() => 'Unknown error');
    throw new Error(`Codex token exchange failed: ${response.status} ${errorText}`);
  }

  return response.json();
}

async function refreshAccessToken(refreshToken) {
  const response = await fetch(CODEX_TOKEN_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      Accept: 'application/json',
    },
    body: new URLSearchParams({
      grant_type: 'refresh_token',
      client_id: 'codex',
      refresh_token: refreshToken,
    }).toString(),
  });

  if (!response.ok) {
    throw new Error(`Codex token refresh failed: ${response.status}`);
  }

  return response.json();
}

function createCodexProvider() {
  const app = {
    id: 'codex',
    label: 'OpenAI Codex',
    description: 'ChatGPT/Codex subscription plan with GPT-5.5 and advanced reasoning.',
  };

  const provider = {
    key: 'codex',
    label: 'OpenAI Codex',
    description: 'ChatGPT/Codex subscription plan access.',
    icon: 'auto_awesome',
    apps: [{ id: 'codex', label: 'OpenAI Codex', description: 'ChatGPT/Codex subscription plan.' }],
    connectPrompt: 'Sign in with your ChatGPT/Codex subscription account.',
    getApp(appId) {
      return appId === 'codex' ? app : null;
    },
    getEnvStatus() {
      return describeCodexEnvStatus();
    },
    getToolDefinitions() {
      return [];
    },
    supportsTool() {
      return false;
    },
    buildSnapshot(connectionRows) {
      const env = this.getEnvStatus();
      const snapshot = summarizeAppConnection(app, connectionRows || [], env);
      return {
        id: this.key,
        label: this.label,
        description: this.description,
        icon: this.icon,
        apps: [snapshot],
        env,
        connection: snapshot.connection,
        availableToolCount: 0,
        connectPrompt: this.connectPrompt,
      };
    },
    async beginOAuth({ state, codeVerifier, appKey, userId }) {
      if (appKey !== 'codex') {
        throw new Error(`Unknown Codex app: ${appKey}`);
      }

      const normalizedState = state || generateState();
      const codeVerifierParam = codeVerifier || generateCodeVerifier();
      const publicUrl = resolvePublicBaseUrl();
      const redirectUri = `${publicUrl}/api/integrations/oauth/callback`;

      const authParams = new URLSearchParams({
        response_type: 'code',
        client_id: 'codex',
        redirect_uri: redirectUri,
        scope: CODEX_SCOPES.join(' '),
        state: normalizedState,
        code_challenge: base64UrlSha256(codeVerifierParam),
        code_challenge_method: 'S256',
      });

      const authUrl = `${CODEX_AUTHORIZE_URL}?${authParams.toString()}`;

      return {
        authUrl,
        state: normalizedState,
        codeVerifier: codeVerifierParam,
      };
    },
    async finishOAuth({ code, codeVerifier, appKey, userId, state }) {
      if (appKey !== 'codex') {
        throw new Error(`Unknown Codex app: ${appKey}`);
      }

      const publicUrl = resolvePublicBaseUrl();
      const redirectUri = `${publicUrl}/api/integrations/oauth/callback`;

      const tokenData = await exchangeCodeForToken(code, codeVerifier, redirectUri);

      let accessToken = tokenData.access_token;
      let refreshToken = tokenData.refresh_token;
      let expiresAt = null;

      if (tokenData.expires_in) {
        expiresAt = new Date(Date.now() + tokenData.expires_in * 1000).toISOString();
      }

      return {
        credentials: {
          access_token: accessToken,
          refresh_token: refreshToken,
          expires_at: expiresAt,
        },
        accountEmail: null,
      };
    },
    async disconnect(connectionRow) {
      return null;
    },
    async executeTool() {
      return null;
    },
    summarizeConnection(connectionRows) {
      const snapshot = this.buildSnapshot(connectionRows);
      if (!snapshot.connection?.connected) {
        return 'OpenAI Codex is not connected.';
      }
      return 'OpenAI Codex is connected.';
    },
    summarizeForModel() {
      return 'OpenAI Codex: using ChatGPT/Codex subscription plan.';
    },
  };

  return provider;
}

module.exports = {
  createCodexProvider,
  refreshAccessToken,
};