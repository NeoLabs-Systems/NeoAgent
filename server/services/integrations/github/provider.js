'use strict';

const { describeEnvStatus, resolveGithubOAuthConfig } = require('../env');
const { decryptValue } = require('../secrets');
const { githubToolDefinitions, executeGithubTool } = require('./repos');
const { githubApiRequest } = require('./common');
const { preparePublicGithubCall } = require('./public_scope');
const { base64UrlSha256 } = require('../../../utils/security');
const { fetchJson } = require('../oauth_provider');
const { fetchResponseText } = require('../http');
const {
  buildConnectedAppSummary,
  formatAccountSummary,
  summarizeAppConnection,
  summarizeProviderConnection,
} = require('../connection_summary');

const GITHUB_ACCOUNT_IDENTITY_SCOPES = [
  'read:user',
  'user:email',
];

const GITHUB_DEFAULT_SCOPES = [
  'repo',
  'workflow',
  'read:org',
];

const GITHUB_APPS = [
  {
    id: 'repos',
    label: 'Repositories',
    description: 'Full repository management - issues, PRs, code, branches, and CI/CD workflows.',
    scopes: GITHUB_DEFAULT_SCOPES,
    toolDefinitions: githubToolDefinitions,
    executor: executeGithubTool,
  },
  {
    id: 'mentions',
    label: 'Mentions',
    description: 'Lets approved people @mention this account on issues and pull requests to ask the agent for help. Set who and where under Messaging.',
    scopes: GITHUB_DEFAULT_SCOPES,
    toolDefinitions: [],
  },
];

const appById = new Map(GITHUB_APPS.map((app) => [app.id, app]));

const toolAppMap = new Map(
  githubToolDefinitions.map((tool) => [tool.name, tool.appId || 'repos']),
);

function createOAuthClient() {
  const config = resolveGithubOAuthConfig();
  return {
    config,
  };
}

async function buildAuthorizedClient(connection) {
  let credentials = {};
  try {
    credentials = JSON.parse(
      decryptValue(connection.credentials_json || '{}') || '{}',
    );
  } catch {
    credentials = {};
  }
  return {
    token: credentials.access_token,
    credentials,
  };
}

function getApp(appId) {
  return appById.get(String(appId || '').trim()) || null;
}

function getAppScopes(appId) {
  const app = getApp(appId);
  if (!app) {
    throw new Error(`Unknown GitHub app: ${appId}`);
  }
  return Array.from(new Set([...GITHUB_ACCOUNT_IDENTITY_SCOPES, ...app.scopes]));
}

function getAllGithubScopes() {
  return Array.from(
    new Set([
      ...GITHUB_ACCOUNT_IDENTITY_SCOPES,
      ...GITHUB_APPS.flatMap((app) => app.scopes || []),
    ]),
  );
}

async function executeGithubRepoTool(toolName, args, connection, executionOptions = {}) {
  const auth = await buildAuthorizedClient(connection);
  auth.signal = executionOptions.signal || null;
  if (!auth.token) {
    throw new Error('GitHub access token is missing or expired. Please reconnect your GitHub account.');
  }
  const appId = toolAppMap.get(String(toolName || '').trim());
  const app = getApp(appId);
  if (!app) {
    throw new Error(`Unknown tool: ${toolName}`);
  }
  let toolArgs = args;
  if (executionOptions.publicScope) {
    const prepared = await preparePublicGithubCall(toolName, args, executionOptions.publicScope, auth);
    toolArgs = prepared.args;
    auth.requestGuard = prepared.requestGuard;
  }
  const result = await app.executor(toolName, toolArgs, auth);
  if (result === null) {
    throw new Error(`Unknown tool: ${toolName}`);
  }
  return { result, credentials: auth.credentials };
}

function getAppToolNames(appId) {
  const app = getApp(appId);
  return Array.isArray(app?.toolDefinitions)
    ? app.toolDefinitions.map((tool) => tool.name)
    : [];
}

function buildModelStatusLines(appSnapshots) {
  return appSnapshots.map((appSnapshot) => {
    if (appSnapshot.connection.connected) {
      const toolNames = getAppToolNames(appSnapshot.id).join(', ');
      return toolNames
        ? `- ${appSnapshot.label}: ${formatAccountSummary(appSnapshot)}. Use built-in tools: ${toolNames}`
        : `- ${appSnapshot.label}: ${formatAccountSummary(appSnapshot)}.`;
    }

    if (appSnapshot.connection.status === 'authorizing') {
      return `- ${appSnapshot.label}: connection is still being authorized.`;
    }

    return `- ${appSnapshot.label}: not connected yet.`;
  });
}

function createGithubProvider() {
  return {
    key: 'github',
    label: 'GitHub',
    description: 'Official GitHub integration for repositories, issues, pull requests, code, branches, and CI/CD workflows.',
    icon: 'github',
    apps: GITHUB_APPS.map(({ id, label, description }) => ({
      id,
      label,
      description,
    })),
    getApp(appId) {
      return getApp(appId);
    },
    getToolAppId(toolName) {
      return toolAppMap.get(String(toolName || '').trim()) || null;
    },
    getEnvStatus() {
      return describeEnvStatus(resolveGithubOAuthConfig(), {
        label: 'GitHub',
      });
    },
    getToolDefinitions(options = {}) {
      const connectedAppIds = new Set(options.connectedAppIds || []);
      return githubToolDefinitions.filter((tool) =>
        connectedAppIds.has(tool.appId || 'repos'),
      );
    },
    supportsTool(toolName) {
      return toolAppMap.has(String(toolName || '').trim());
    },
    buildSnapshot(connectionRows) {
      const env = this.getEnvStatus();
      const byApp = new Map();
      for (const row of Array.isArray(connectionRows) ? connectionRows : []) {
        const appId = String(row.app_key || '').trim();
        if (!byApp.has(appId)) byApp.set(appId, []);
        byApp.get(appId).push(row);
      }

      const apps = GITHUB_APPS.map((app) =>
        summarizeAppConnection(app, byApp.get(app.id) || [], env),
      );
      const rollup = summarizeProviderConnection(apps, env);

      return {
        id: this.key,
        label: this.label,
        description: this.description,
        icon: this.icon,
        apps,
        env,
        connection: rollup.connection,
        availableToolCount: rollup.availableToolCount,
      };
    },
    async beginOAuth({ state, codeVerifier, appKey }) {
      const app = getApp(appKey);
      if (!app) {
        throw new Error(`Unknown GitHub app: ${appKey}`);
      }
      const { config } = createOAuthClient();
      if (!config.configured) {
        throw new Error(
          'GitHub still needs administrator setup before accounts can connect.',
        );
      }
      const codeChallenge = base64UrlSha256(codeVerifier);
      const scopes = getAllGithubScopes().join(' ');
      const params = new URLSearchParams({
        client_id: config.clientId,
        redirect_uri: config.redirectUri,
        scope: scopes,
        state,
        code_challenge: codeChallenge,
        code_challenge_method: 'S256',
      });
      const url = `https://github.com/login/oauth/authorize?${params.toString()}`;
      return { url, appId: app.id };
    },
    async finishOAuth({ code, codeVerifier, appKey, signal }) {
      const app = getApp(appKey);
      if (!app) {
        throw new Error(`Unknown GitHub app: ${appKey}`);
      }
      const { config } = createOAuthClient();

      const tokenData = await fetchJson(
        'https://github.com/login/oauth/access_token',
        {
          method: 'POST',
          form: {
            client_id: config.clientId,
            client_secret: config.clientSecret,
            code,
            code_verifier: codeVerifier,
            redirect_uri: config.redirectUri,
          },
          signal,
        },
        { serviceName: 'GitHub OAuth token exchange' },
      );
      if (tokenData?.error) {
        throw new Error(
          `GitHub OAuth error: ${tokenData.error_description || tokenData.error}`,
        );
      }

      const accessToken = tokenData.access_token;
      if (!accessToken) {
        throw new Error('GitHub OAuth did not return an access token.');
      }

      const userData = await fetchJson(
        'https://api.github.com/user',
        {
          headers: {
            'Authorization': `Bearer ${accessToken}`,
            'Accept': 'application/vnd.github.v3+json',
          },
          signal,
        },
        { serviceName: 'GitHub user profile' },
      );
      const accountEmail = String(userData.login || '').trim();
      if (!accountEmail) {
        throw new Error('GitHub API did not return a user login.');
      }

      return {
        appId: app.id,
        accountEmail,
        credentials: {
          access_token: accessToken,
          token_type: tokenData.token_type,
          scope: tokenData.scope,
        },
        scopes: tokenData.scope ? tokenData.scope.split(' ') : [],
        metadata: {
          appId: app.id,
          userId: userData.id,
        },
      };
    },
    async disconnect(connectionRow, executionOptions = {}) {
      if (!connectionRow?.credentials_json) return;
      try {
        const credentials = JSON.parse(decryptValue(connectionRow.credentials_json));
        const accessToken = String(credentials?.access_token || '').trim();
        if (!accessToken) return;

        const { config } = createOAuthClient();
        const clientId = String(config?.clientId || '').trim();
        const clientSecret = String(config?.clientSecret || '').trim();
        if (!clientId || !clientSecret) {
          console.warn('[GitHub] Disconnect revoke skipped because OAuth client credentials are missing.');
          return;
        }

        const basic = Buffer.from(`${clientId}:${clientSecret}`).toString('base64');
        const revokeUrl = `https://api.github.com/applications/${encodeURIComponent(clientId)}/token`;
        const { response: revokeResponse, text: revokeBody } = await fetchResponseText(
          revokeUrl,
          {
            method: 'DELETE',
            headers: {
              'Authorization': `Basic ${basic}`,
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              access_token: accessToken,
            }),
            signal: executionOptions.signal || null,
          },
          { serviceName: 'GitHub token revocation' },
        );

        if (!revokeResponse.ok) {
          console.warn(
            `[GitHub] Failed to revoke token for disconnect (connection ${connectionRow?.id || 'unknown'}): ${revokeResponse.status} ${revokeBody}`,
          );
        }
      } catch (error) {
        console.warn(
          `[GitHub] Failed to revoke token for disconnect (connection ${connectionRow?.id || 'unknown'}): ${error?.message || error}`,
        );
      }
    },
    async executeTool(toolName, args, connectionRow, executionOptions = {}) {
      return executeGithubRepoTool(toolName, args, connectionRow, executionOptions);
    },
    async testConnection(connectionRow, executionOptions = {}) {
      const auth = await buildAuthorizedClient(connectionRow);
      await githubApiRequest(auth, {
        method: 'GET',
        path: '/user',
        signal: executionOptions.signal || null,
      });
      return { credentials: auth.credentials };
    },
    summarizeConnection(connectionRows) {
      const snapshot = this.buildSnapshot(connectionRows);
      if (!snapshot.connection.connected) {
        if (snapshot.connection.status === 'env_not_configured') {
          return 'GitHub still needs administrator setup before accounts can connect.';
        }
        return 'GitHub is not connected.';
      }

      return snapshot.apps
        .filter((app) => app.connection.connected)
        .map((app) => {
          const accounts = app.accounts
            .filter((account) => account.connected)
            .map((account) => account.accountEmail || 'unknown account')
            .join(', ');
          return `${app.label}: ${accounts}`;
        })
        .join(' | ');
    },
    summarizeForModel(snapshot) {
      if (!snapshot?.env?.configured) {
        return `${this.label}: workspace setup is not complete yet. If the user wants to use it, tell them to open Official Integrations and ask an administrator to finish setup first.`;
      }

      const statusLines = buildModelStatusLines(snapshot.apps);

      if (!snapshot.connection.connected) {
        return [
          `${this.label}: workspace setup is ready, but no app accounts are connected yet. If the user wants to use it, tell them to connect an account in Official Integrations first.`,
          ...statusLines,
        ].join('\n');
      }

      return [
        `${this.label}: some app-specific native access is connected on this server in this run. Only the listed connected apps are available through built-in tools.`,
        `Connected apps: ${buildConnectedAppSummary(snapshot.apps)}`,
        ...statusLines,
      ].join('\n');
    },
  };
}

module.exports = {
  createGithubProvider,
  GITHUB_ACCOUNT_IDENTITY_SCOPES,
  GITHUB_APPS: GITHUB_APPS.map(
    ({ id, label, description, scopes }) => ({
      id,
      label,
      description,
      scopes: scopes.slice(),
    }),
  ),
};
