'use strict';

const crypto = require('crypto');
const { google } = require('googleapis');
const { describeEnvStatus, resolveGoogleOAuthConfig } = require('../env');
const { decryptValue } = require('../secrets');
const { getConnectionAccessMode } = require('../access');
const { gmailToolDefinitions, executeGmailTool } = require('./gmail');
const { calendarToolDefinitions, executeCalendarTool } = require('./calendar');
const { driveToolDefinitions, executeDriveTool } = require('./drive');
const { docsToolDefinitions, executeDocsTool } = require('./docs');
const { sheetsToolDefinitions, executeSheetsTool } = require('./sheets');

const GOOGLE_ACCOUNT_IDENTITY_SCOPES = [
  'openid',
  'https://www.googleapis.com/auth/userinfo.email',
  'https://www.googleapis.com/auth/userinfo.profile',
];

const GOOGLE_WORKSPACE_APPS = [
  {
    id: 'gmail',
    label: 'Gmail',
    description: 'Search threads, read messages, send mail, and manage labels.',
    scopes: ['https://mail.google.com/'],
    toolDefinitions: gmailToolDefinitions,
    executor: executeGmailTool,
  },
  {
    id: 'calendar',
    label: 'Calendar',
    description: 'List events, create events, update events, and check free/busy.',
    scopes: ['https://www.googleapis.com/auth/calendar'],
    toolDefinitions: calendarToolDefinitions,
    executor: executeCalendarTool,
  },
  {
    id: 'drive',
    label: 'Drive',
    description: 'Search Drive, upload and download files, and create share links.',
    scopes: ['https://www.googleapis.com/auth/drive'],
    toolDefinitions: driveToolDefinitions,
    executor: executeDriveTool,
  },
  {
    id: 'docs',
    label: 'Docs',
    description: 'Read, create, append to, and replace text in Google Docs.',
    scopes: ['https://www.googleapis.com/auth/documents'],
    toolDefinitions: docsToolDefinitions,
    executor: executeDocsTool,
  },
  {
    id: 'sheets',
    label: 'Sheets',
    description: 'Read ranges, update values, append rows, and create spreadsheets.',
    scopes: ['https://www.googleapis.com/auth/spreadsheets'],
    toolDefinitions: sheetsToolDefinitions,
    executor: executeSheetsTool,
  },
];

const appById = new Map(GOOGLE_WORKSPACE_APPS.map((app) => [app.id, app]));

function withAccountSelectors(app, definition) {
  return {
    ...definition,
    description: `${definition.description} When multiple ${app.label} accounts are connected, set connection_id or account_email to choose which account to use.`,
    parameters: {
      ...(definition.parameters || { type: 'object', properties: {} }),
      type: 'object',
      properties: {
        ...((definition.parameters && definition.parameters.properties) || {}),
        connection_id: {
          type: 'number',
          description: `Optional connected ${app.label} account ID.`,
        },
        account_email: {
          type: 'string',
          description: `Optional connected ${app.label} account email.`,
        },
      },
      required: Array.isArray(definition.parameters?.required)
        ? definition.parameters.required.slice()
        : [],
    },
    appId: app.id,
  };
}

const googleWorkspaceToolDefinitions = GOOGLE_WORKSPACE_APPS.flatMap((app) =>
  app.toolDefinitions.map((definition) => withAccountSelectors(app, definition)),
);

const toolAppMap = new Map(
  googleWorkspaceToolDefinitions.map((tool) => [tool.name, tool.appId]),
);

function base64UrlSha256(value) {
  return crypto
    .createHash('sha256')
    .update(String(value || ''))
    .digest('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');
}

function createOAuthClient() {
  const config = resolveGoogleOAuthConfig();
  return {
    config,
    client: new google.auth.OAuth2(
      config.clientId,
      config.clientSecret,
      config.redirectUri,
    ),
  };
}

async function buildAuthorizedClient(connection) {
  const { client } = createOAuthClient();
  let credentials = {};
  try {
    credentials = JSON.parse(
      decryptValue(connection.credentials_json || '{}') || '{}',
    );
  } catch {
    credentials = {};
  }
  client.setCredentials(credentials);
  return client;
}

function getApp(appId) {
  return appById.get(String(appId || '').trim()) || null;
}

function getAppScopes(appId) {
  const app = getApp(appId);
  if (!app) {
    throw new Error(`Unknown Google Workspace app: ${appId}`);
  }
  return Array.from(new Set([...GOOGLE_ACCOUNT_IDENTITY_SCOPES, ...app.scopes]));
}

function getAllWorkspaceScopes() {
  return Array.from(
    new Set([
      ...GOOGLE_ACCOUNT_IDENTITY_SCOPES,
      ...GOOGLE_WORKSPACE_APPS.flatMap((app) => app.scopes || []),
    ]),
  );
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
    availableToolCount:
      envStatus.configured && connectedAccounts.length > 0
        ? app.toolDefinitions.length
        : 0,
  };
}

async function executeGoogleWorkspaceTool(toolName, args, connection) {
  const auth = await buildAuthorizedClient(connection);
  const appId = toolAppMap.get(toolName);
  const app = getApp(appId);
  if (!app) {
    throw new Error(`Unknown tool: ${toolName}`);
  }
  const result = await app.executor(toolName, args, auth);
  if (result === null) {
    throw new Error(`Unknown tool: ${toolName}`);
  }
  return { result, credentials: auth.credentials };
}

async function collectGoogleMemoryDocuments({ connection, sourceTypes = [] }) {
  const appKey = String(connection?.app_key || '').trim();
  const documents = [];
  const collectedAt = new Date().toISOString();

  if (appKey === 'gmail' && sourceTypes.includes('email')) {
    const { result } = await executeGoogleWorkspaceTool(
      'google_workspace_gmail_search_threads',
      { query: 'newer_than:7d', max_results: 8 },
      connection,
    );
    for (const thread of Array.isArray(result?.threads) ? result.threads : []) {
      const subject = String(thread.subject || 'Gmail thread').trim();
      documents.push({
        externalObjectId: thread.id,
        sourceType: 'email',
        normalizedType: 'email',
        title: subject,
        content: [
          subject,
          thread.from ? `From: ${thread.from}` : '',
          thread.date ? `Date: ${thread.date}` : '',
          thread.snippet || '',
        ].filter(Boolean).join('\n'),
        summary: thread.snippet || subject,
        sourceTimestamp: thread.date || collectedAt,
        salience: Array.isArray(thread.labelIds) && thread.labelIds.includes('IMPORTANT') ? 8 : 5,
        payload: thread,
      });
    }
  }

  if (appKey === 'calendar' && sourceTypes.includes('calendar')) {
    const timeMin = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
    const timeMax = new Date(Date.now() + 14 * 24 * 60 * 60 * 1000).toISOString();
    const { result } = await executeGoogleWorkspaceTool(
      'google_workspace_calendar_list_events',
      { time_min: timeMin, time_max: timeMax, max_results: 12 },
      connection,
    );
    for (const event of Array.isArray(result?.events) ? result.events : []) {
      const title = String(event.summary || 'Calendar event').trim();
      documents.push({
        externalObjectId: event.id,
        sourceType: 'calendar',
        normalizedType: 'calendar',
        title,
        content: [
          title,
          event.start ? `Start: ${event.start}` : '',
          event.end ? `End: ${event.end}` : '',
          event.location ? `Location: ${event.location}` : '',
          event.description || '',
          Array.isArray(event.attendees) && event.attendees.length
            ? `Attendees: ${event.attendees.join(', ')}`
            : '',
        ].filter(Boolean).join('\n'),
        summary: [event.start, event.location, event.description].filter(Boolean).join(' | ') || title,
        sourceTimestamp: event.start || collectedAt,
        salience: 6,
        payload: event,
      });
    }
  }

  return {
    documents,
    cursor: {
      collectedAt,
      appKey,
      sourceTypes,
    },
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

function getAppToolNames(appId) {
  const app = getApp(appId);
  return Array.isArray(app?.toolDefinitions)
    ? app.toolDefinitions.map((tool) => tool.name)
    : [];
}

function formatAccountSummary(appSnapshot) {
  const emails = appSnapshot.accounts
    .filter((account) => account.connected)
    .map((account) => account.accountEmail || `connection ${account.id}`);

  if (emails.length === 0) return 'no connected accounts';
  if (emails.length === 1) return `connected as ${emails[0]}`;
  return `connected with ${emails.length} accounts: ${emails.join(', ')}`;
}

function buildModelStatusLines(appSnapshots) {
  return appSnapshots.map((appSnapshot) => {
    if (appSnapshot.connection.connected) {
      const toolNames = getAppToolNames(appSnapshot.id).join(', ');
      return `- ${appSnapshot.label}: ${formatAccountSummary(appSnapshot)}. Use built-in tools: ${toolNames}`;
    }

    if (appSnapshot.connection.status === 'authorizing') {
      return `- ${appSnapshot.label}: connection is still being authorized.`;
    }

    return `- ${appSnapshot.label}: not connected yet.`;
  });
}

function createGoogleWorkspaceProvider() {
  return {
    key: 'google_workspace',
    label: 'Google Workspace',
    description:
      'Official Gmail, Calendar, Drive, Docs, and Sheets integrations with app-specific accounts.',
    icon: 'google',
    requiresRefreshToken: true,
    apps: GOOGLE_WORKSPACE_APPS.map(({ id, label, description }) => ({
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
      return describeEnvStatus(resolveGoogleOAuthConfig(), {
        label: 'Google Workspace',
      });
    },
    getToolDefinitions(options = {}) {
      const connectedAppIds = new Set(options.connectedAppIds || []);
      return googleWorkspaceToolDefinitions.filter((tool) =>
        connectedAppIds.has(tool.appId),
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

      const apps = GOOGLE_WORKSPACE_APPS.map((app) =>
        summarizeAppConnection(app, byApp.get(app.id) || [], env),
      );
      const connectedApps = apps.filter((app) => app.connection.connected);
      const connectedAccounts = connectedApps.flatMap((app) =>
        app.accounts.filter((account) => account.connected),
      );

      return {
        id: this.key,
        label: this.label,
        description: this.description,
        icon: this.icon,
        apps,
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
        availableToolCount: apps.reduce(
          (total, app) => total + app.availableToolCount,
          0,
        ),
      };
    },
    async beginOAuth({ state, codeVerifier, appKey }) {
      const app = getApp(appKey);
      if (!app) {
        throw new Error(`Unknown Google Workspace app: ${appKey}`);
      }
      const { config, client } = createOAuthClient();
      if (!config.configured) {
        throw new Error(
          'Google Workspace still needs administrator setup before accounts can connect.',
        );
      }
      const codeChallenge = base64UrlSha256(codeVerifier);
      const url = client.generateAuthUrl({
        access_type: 'offline',
        prompt: 'consent',
        // Request the full workspace scope bundle so one durable Google grant can
        // back Gmail, Calendar, Drive, Docs, and Sheets for the same account.
        scope: getAllWorkspaceScopes(),
        include_granted_scopes: true,
        state,
        code_challenge: codeChallenge,
        code_challenge_method: 'S256',
      });
      return { url, appId: app.id };
    },
    async finishOAuth({ code, codeVerifier, appKey }) {
      const app = getApp(appKey);
      if (!app) {
        throw new Error(`Unknown Google Workspace app: ${appKey}`);
      }
      const { client } = createOAuthClient();
      const { tokens } = await client.getToken({
        code,
        codeVerifier,
      });
      client.setCredentials(tokens);
      const oauth2 = google.oauth2({ version: 'v2', auth: client });
      const profile = await oauth2.userinfo.get();
      const accountEmail = String(profile.data.email || '').trim();
      if (!accountEmail) {
        throw new Error('Google OAuth did not return an account email address.');
      }
      return {
        appId: app.id,
        accountEmail,
        credentials: client.credentials,
        scopes: Array.from(
          new Set(
            String(client.credentials.scope || '')
              .split(/\s+/)
              .map((scope) => scope.trim())
              .filter(Boolean),
          ),
        ),
        metadata: {
          appId: app.id,
        },
      };
    },
    async disconnect(connectionRow) {
      const auth = await buildAuthorizedClient(connectionRow);
      const refreshToken = auth.credentials.refresh_token;
      const accessToken = auth.credentials.access_token;
      if (refreshToken) {
        await auth.revokeToken(refreshToken).catch((error) => {
          console.warn(
            `[Google Workspace] Failed to revoke refresh token for disconnect (connection ${connectionRow?.id || 'unknown'}): ${error?.message || error}`,
          );
        });
      } else if (accessToken) {
        await auth.revokeToken(accessToken).catch((error) => {
          console.warn(
            `[Google Workspace] Failed to revoke access token for disconnect (connection ${connectionRow?.id || 'unknown'}): ${error?.message || error}`,
          );
        });
      }
    },
    async executeTool(toolName, args, connectionRow) {
      return executeGoogleWorkspaceTool(toolName, args, connectionRow);
    },
    async collectMemoryDocuments(options) {
      return collectGoogleMemoryDocuments(options);
    },
    summarizeConnection(connectionRows) {
      const snapshot = this.buildSnapshot(connectionRows);
      if (!snapshot.connection.connected) {
        if (snapshot.connection.status === 'env_not_configured') {
          return 'Google Workspace still needs administrator setup before accounts can connect.';
        }
        return 'Google Workspace is not connected.';
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
  createGoogleWorkspaceProvider,
  GOOGLE_ACCOUNT_IDENTITY_SCOPES,
  GOOGLE_WORKSPACE_APPS: GOOGLE_WORKSPACE_APPS.map(
    ({ id, label, description, scopes }) => ({
      id,
      label,
      description,
      scopes: scopes.slice(),
    }),
  ),
};
