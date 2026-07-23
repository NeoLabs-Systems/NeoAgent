'use strict';

const { decryptValue } = require('./secrets');
const { getConnectionAccessMode } = require('./access');
const { fetchResponseText } = require('./http');
const { isAbortError } = require('../../utils/abort');
const {
  abortableDelay,
  computeBackoffMs,
  getHttpStatus,
  isTransientIoError,
  retryAfterMilliseconds,
} = require('../../utils/retry');

const OAUTH_STATE_PATTERN = /^[a-f0-9]{32,128}$/i;
const RETRYABLE_INTEGRATION_METHODS = new Set(['GET', 'HEAD', 'OPTIONS']);
const MAX_INTEGRATION_RETRY_DELAY_MS = 10000;

function escapeScope(scopes) {
  return Array.from(new Set((scopes || []).filter(Boolean))).join(' ');
}

function appendQuery(url, params) {
  const resolved = new URL(url);
  for (const [key, value] of Object.entries(params || {})) {
    if (value === undefined || value === null) continue;
    const text = String(value).trim();
    if (!text) continue;
    resolved.searchParams.set(key, text);
  }
  return resolved.toString();
}

function sanitizeRemoteError(value) {
  return String(value || '')
    .slice(0, 1000)
    .replace(/\b(Bearer|Basic)\s+[A-Za-z0-9._~+/=-]+/gi, '$1 [redacted]')
    .replace(
      /\b(access_token|refresh_token|client_secret|authorization|token)\b\s*[:=]\s*["']?[^\s,"'}\]]+/gi,
      '$1=[redacted]',
    )
    .trim();
}

async function fetchJson(url, options = {}, context = {}) {
  const headers = {
    Accept: 'application/json',
    ...(options.headers || {}),
  };
  let body = options.body;

  if (options.json) {
    headers['Content-Type'] = 'application/json';
    body = JSON.stringify(options.json);
  } else if (options.form) {
    headers['Content-Type'] = 'application/x-www-form-urlencoded';
    body = new URLSearchParams(
      Object.entries(options.form).reduce((acc, [key, value]) => {
        if (value === undefined || value === null) return acc;
        acc[key] = String(value);
        return acc;
      }, {}),
    ).toString();
  }

  const method = String(options.method || 'GET').toUpperCase();
  const maxAttempts =
    options.retry === false || !RETRYABLE_INTEGRATION_METHODS.has(method)
      ? 1
      : 2;
  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    try {
      const { response, text } = await fetchResponseText(
        url,
        {
          method,
          headers,
          body,
          signal: options.signal,
          timeoutMs: options.timeoutMs,
          maxResponseBytes: options.maxResponseBytes,
        },
        context,
      );

      let data = null;
      try {
        data = text ? JSON.parse(text) : null;
      } catch {
        data = null;
      }

      const notOkSlackStyle =
        data &&
        typeof data === 'object' &&
        Object.prototype.hasOwnProperty.call(data, 'ok') &&
        data.ok === false;

      if (!response.ok || notOkSlackStyle) {
        const label = String(context.serviceName || 'OAuth provider').trim() || 'OAuth provider';
        const rawMessage =
          (data && (data.error_description || data.error || data.message)) ||
          text ||
          `${response.status} ${response.statusText}`;
        const error = new Error(
          `${label} request failed: ${sanitizeRemoteError(rawMessage)}`,
        );
        error.status = response.status;
        error.data = data;
        error.headers = response.headers;
        throw error;
      }

      return data;
    } catch (error) {
      if (isAbortError(error, options.signal) || attempt >= maxAttempts) throw error;
      const retryAfterMs = retryAfterMilliseconds(error.headers);
      const rateLimited =
        (getHttpStatus(error) === 403 && retryAfterMs !== null)
        || String(error.data?.error || '').toLowerCase() === 'ratelimited';
      if (!rateLimited && !isTransientIoError(error)) throw error;
      const delayMs = retryAfterMs ?? computeBackoffMs(attempt, 250, 2000);
      if (delayMs > MAX_INTEGRATION_RETRY_DELAY_MS) throw error;
      await abortableDelay(delayMs, options.signal);
    }
  }
  throw new Error('Integration request exhausted its retry attempts.');
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

function buildConnectedAppSummary(appSnapshots) {
  return appSnapshots
    .filter((app) => app.connection.connected)
    .map((app) => {
      const emails = app.accounts
        .filter((account) => account.connected)
        .map((account) => account.accountEmail || `connection ${account.id}`)
        .join(', ');
      return `${app.label}: ${emails}`;
    })
    .join(' | ');
}

function createOAuthProvider(options = {}) {
  const apps = (options.apps || []).map((app) => ({ ...app }));
  const appById = new Map(apps.map((app) => [app.id, app]));
  const toolDefinitions = (options.toolDefinitions || []).map((tool) => {
    const app = appById.get(tool.appId);
    const parameters = tool.parameters || { type: 'object', properties: {} };
    return {
      ...tool,
      description: app
        ? `${tool.description} When multiple ${app.label} accounts are connected, set connection_id or account_email to choose which account to use.`
        : tool.description,
      parameters: {
        ...parameters,
        type: 'object',
        properties: {
          ...(parameters.properties || {}),
          connection_id: {
            type: 'number',
            description: app
              ? `Optional connected ${app.label} account ID.`
              : 'Optional connected account ID.',
          },
          account_email: {
            type: 'string',
            description: app
              ? `Optional connected ${app.label} account email or identifier.`
              : 'Optional connected account email or identifier.',
          },
        },
        required: Array.isArray(parameters.required)
          ? parameters.required.slice()
          : [],
      },
    };
  });
  const toolAppMap = new Map(
    toolDefinitions
      .filter((tool) => tool.name && tool.appId)
      .map((tool) => [tool.name, tool.appId]),
  );

  function getApp(appId) {
    return appById.get(String(appId || '').trim()) || null;
  }

  function assertValidOAuthState(state) {
    const normalized = String(state || '').trim();
    if (!OAUTH_STATE_PATTERN.test(normalized)) {
      throw new Error('Invalid OAuth state format. Please restart the connection flow.');
    }
    return normalized;
  }

  const provider = {
    key: options.key,
    label: options.label,
    description: options.description,
    icon: options.icon,
    requiresRefreshToken: options.requiresRefreshToken === true,
    apps: apps.map(({ id, label, description }) => ({ id, label, description })),
    connectPrompt: options.connectPrompt || null,
    supportsMultipleAccounts: options.supportsMultipleAccounts !== false,
    connectionMethod: options.connectionMethod || 'oauth',
    getApp,
    getToolAppId(toolName) {
      return toolAppMap.get(String(toolName || '').trim()) || null;
    },
    getEnvStatus(context = {}) {
      return options.getEnvStatus(context);
    },
    getToolDefinitions(toolOptions = {}) {
      const connectedAppIds = new Set(toolOptions.connectedAppIds || []);
      return toolDefinitions.filter((tool) => connectedAppIds.has(tool.appId));
    },
    supportsTool(toolName) {
      return toolAppMap.has(String(toolName || '').trim());
    },
    buildSnapshot(connectionRows, context = {}) {
      const env = this.getEnvStatus(context);
      const byApp = new Map();
      for (const row of Array.isArray(connectionRows) ? connectionRows : []) {
        const appId = String(row.app_key || '').trim();
        if (!byApp.has(appId)) byApp.set(appId, []);
        byApp.get(appId).push(row);
      }

      const appSnapshots = apps.map((app) => {
        const snapshot = summarizeAppConnection(app, byApp.get(app.id) || [], env);
        snapshot.availableToolCount =
          env.configured && snapshot.connection.connected
            ? toolDefinitions.filter((tool) => tool.appId === app.id).length
            : 0;
        return snapshot;
      });
      const connectedApps = appSnapshots.filter((app) => app.connection.connected);
      const connectedAccounts = connectedApps.flatMap((app) =>
        app.accounts.filter((account) => account.connected),
      );

      return {
        id: this.key,
        label: this.label,
        description: this.description,
        icon: this.icon,
        apps: appSnapshots,
        env,
        connection: {
          status: !env.configured
            ? 'env_not_configured'
            : connectedAccounts.length > 0
            ? 'connected'
            : 'not_connected',
          connected: connectedAccounts.length > 0,
          accountEmail:
            connectedAccounts.length === 1
              ? connectedAccounts[0].accountEmail
              : null,
          accountCount: connectedAccounts.length,
          appCount: connectedApps.length,
          lastConnectedAt:
            connectedAccounts
              .map((account) => account.lastConnectedAt)
              .filter(Boolean)
              .sort()
              .reverse()[0] || null,
        },
        availableToolCount: appSnapshots.reduce(
          (total, app) => total + app.availableToolCount,
          0,
        ),
        connectPrompt: this.connectPrompt,
        supportsMultipleAccounts: this.supportsMultipleAccounts,
        connectionMethod: this.connectionMethod,
      };
    },
    async beginOAuth({ state, codeVerifier, appKey, userId, agentId, signal }) {
      const app = getApp(appKey);
      if (!app) {
        throw new Error(`Unknown ${this.label} app: ${appKey}`);
      }
      const normalizedState = assertValidOAuthState(state);
      const env = this.getEnvStatus({ userId, agentId });
      if (!env.configured) {
        throw new Error(env.summary);
      }
      return options.beginOAuth({
        state: normalizedState,
        codeVerifier,
        userId,
        agentId,
        app,
        env,
        signal,
      });
    },
    async finishOAuth({
      code,
      codeVerifier,
      appKey,
      userId,
      agentId,
      state,
      signal,
    }) {
      const app = getApp(appKey);
      if (!app) {
        throw new Error(`Unknown ${this.label} app: ${appKey}`);
      }
      const normalizedState = assertValidOAuthState(state);
      return options.finishOAuth({
        code,
        codeVerifier,
        userId,
        agentId,
        state: normalizedState,
        app,
        env: this.getEnvStatus({ userId, agentId }),
        signal,
      });
    },
    async disconnect(connectionRow, executionOptions = {}) {
      if (typeof options.disconnect === 'function') {
        return options.disconnect(connectionRow, executionOptions);
      }
      return null;
    },
    async executeTool(toolName, args, connectionRow, executionOptions = {}) {
      if (typeof options.executeTool !== 'function') {
        return null;
      }
      let credentials = {};
      try {
        credentials = JSON.parse(
          decryptValue(connectionRow.credentials_json || '{}') || '{}',
        );
      } catch {
        credentials = {};
      }
      let credentialsUpdated = false;
      const integrationContext = {
        appId: toolAppMap.get(String(toolName || '').trim()) || connectionRow.app_key,
        connection: connectionRow,
        credentials,
        env: this.getEnvStatus({
          userId: connectionRow?.user_id,
          agentId: connectionRow?.agent_id,
        }),
        signal: executionOptions.signal || null,
        updateCredentials(nextCredentials) {
          if (!nextCredentials || typeof nextCredentials !== 'object') return;
          integrationContext.credentials = nextCredentials;
          credentialsUpdated = true;
        },
      };
      const execution = await options.executeTool(
        toolName,
        args,
        integrationContext,
      );
      if (!execution || execution.credentials || !credentialsUpdated) {
        return execution;
      }
      return {
        ...execution,
        credentials: integrationContext.credentials,
      };
    },
    summarizeConnection(connectionRows) {
      const snapshot = this.buildSnapshot(connectionRows);
      if (!snapshot.connection.connected) {
        if (snapshot.connection.status === 'env_not_configured') {
          if (snapshot?.env?.setupMode === 'user') {
            return `${this.label} still needs per-user setup before accounts can connect.`;
          }
          return `${this.label} still needs administrator setup before accounts can connect.`;
        }
        return `${this.label} is not connected.`;
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
        if (snapshot?.env?.setupMode === 'user') {
          return `${this.label}: setup is user-managed and is not complete yet. If the user wants to use it, tell them to open Official Integrations and finish setup in their account first.`;
        }
        return `${this.label}: workspace setup is not complete yet. If the user wants to use it, tell them to open Official Integrations and ask an administrator to finish setup first.`;
      }

      const connectedApps = (snapshot.apps || []).filter((app) => app.connection.connected);
      if (!snapshot.connection?.connected) {
        return `${this.label}: setup is ready, but no accounts are connected yet. If the user wants to use it, tell them to connect an account in Official Integrations first.`;
      }

      const toolLines = connectedApps.map((app) => {
        const names = toolDefinitions
          .filter((tool) => tool.appId === app.id)
          .map((tool) => tool.name)
          .join(', ');
        return `- ${app.label}: ${names || 'no built-in tools'}`;
      });
      return [
        `${this.label}: native account access is connected in this run.`,
        `Connected apps: ${buildConnectedAppSummary(snapshot.apps)}`,
        ...toolLines,
      ].join('\n');
    },
  };

  return provider;
}

module.exports = {
  appendQuery,
  createOAuthProvider,
  escapeScope,
  fetchJson,
};
