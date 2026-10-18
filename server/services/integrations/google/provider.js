'use strict';

const { google } = require('googleapis');
const { createOAuthApp } = require('../oauth_app');
const { decryptValue } = require('../secrets');
const { gmailToolDefinitions, executeGmailTool } = require('./gmail');
const { calendarToolDefinitions, executeCalendarTool } = require('./calendar');
const { driveToolDefinitions, executeDriveTool } = require('./drive');
const { docsToolDefinitions, executeDocsTool } = require('./docs');
const { sheetsToolDefinitions, executeSheetsTool } = require('./sheets');
const { waitForAbortableResult } = require('../http');
const {
  buildConnectedAppSummary,
  describeIncompleteSetupForModel,
  formatAccountSummary,
  summarizeAppConnection,
  summarizeProviderConnection,
} = require('../connection_summary');
const { base64UrlSha256 } = require('../../../utils/security');

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

function createOAuthClient(config) {
  return new google.auth.OAuth2(config.clientId, config.clientSecret, config.redirectUri);
}

function attachAbortSignal(client, signal) {
  if (!signal) return client;
  const request = client.transporter.request.bind(client.transporter);
  client.transporter.request = (requestOptions = {}) => request({
    ...requestOptions,
    signal: requestOptions.signal || signal,
  });
  return client;
}

async function buildAuthorizedClient(connection, options = {}) {
  const client = createOAuthClient(
    googleOAuthApp.resolve({ userId: connection.user_id, agentId: connection.agent_id }),
  );
  let credentials = {};
  try {
    credentials = JSON.parse(
      decryptValue(connection.credentials_json || '{}') || '{}',
    );
  } catch {
    credentials = {};
  }
  client.setCredentials(credentials);
  // Capture any token refresh that happens during the request so the new
  // access_token + expiry_date are always available on client.credentials.
  // The library preserves refresh_token internally; this listener just ensures
  // client.credentials stays in sync when refreshes happen inside deep call stacks.
  client.on('tokens', (tokens) => {
    if (tokens.access_token) {
      client.setCredentials({
        ...client.credentials,
        ...tokens,
        refresh_token: tokens.refresh_token || client.credentials.refresh_token,
      });
    }
  });
  return attachAbortSignal(client, options.signal);
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

const googleOAuthApp = createOAuthApp({
  providerKey: 'google_workspace',
  label: 'Google Workspace',
  envPrefix: 'GOOGLE',
  // Enables all five APIs in one step, creating a project when there is none.
  consoleUrl: 'https://console.cloud.google.com/flows/enableapi?apiid=gmail.googleapis.com,calendar-json.googleapis.com,drive.googleapis.com,docs.googleapis.com,sheets.googleapis.com',
  notes: 'The console button enables the Gmail, Calendar, Drive, Docs and Sheets APIs. Then, under APIs & Services › Credentials, create an OAuth client ID of type Web application with the callback URL as an authorized redirect URI. Set the consent screen to In production: in Testing, Google signs accounts out every 7 days. Continue past the unverified-app warning when you connect.',
  scopes: getAllWorkspaceScopes(),
  alternatives: ['email', 'phone'],
});

async function executeGoogleWorkspaceTool(
  toolName,
  args,
  connection,
  executionOptions = {},
) {
  const auth = await buildAuthorizedClient(connection, executionOptions);
  const appId = toolAppMap.get(toolName);
  const app = getApp(appId);
  if (!app) {
    throw new Error(`Unknown tool: ${toolName}`);
  }
  const result = await waitForAbortableResult(
    app.executor(toolName, args, auth, executionOptions),
    executionOptions.signal,
  );
  if (result === null) {
    throw new Error(`Unknown tool: ${toolName}`);
  }
  return { result, credentials: auth.credentials };
}

const GMAIL_SWEEP_QUERY = 'newer_than:12m (is:important OR is:starred OR in:sent) '
  + '-category:promotions -category:social -category:updates -category:forums';
const GMAIL_SWEEP_THREAD_LIMIT = 100;
const GMAIL_SWEEP_MAX_PAGES = 20;
const GMAIL_SWEEP_CONCURRENCY = 4;
const GMAIL_SWEEP_BODY_CHARS = 2000;

// Imports the past year's important mail: threads the user marked, Gmail
// ranked important, or the user replied to. Threads already in memory are
// skipped, so a repeat sweep picks up the next ones instead.
async function collectGmailSweepDocuments(caller, collectedAt, skipObjectIds, onProgress) {
  const threadIds = [];
  let pageToken = null;
  for (let page = 0; page < GMAIL_SWEEP_MAX_PAGES; page += 1) {
    const response = await caller.call('google_workspace_gmail_api_request', {
      method: 'GET',
      path: '/gmail/v1/users/me/threads',
      query: {
        q: GMAIL_SWEEP_QUERY,
        maxResults: 100,
        ...(pageToken ? { pageToken } : {}),
      },
    });
    for (const thread of Array.isArray(response?.data?.threads) ? response.data.threads : []) {
      if (thread.id && !skipObjectIds.has(thread.id) && !threadIds.includes(thread.id)) {
        threadIds.push(thread.id);
      }
    }
    pageToken = response?.data?.nextPageToken || null;
    if (!pageToken || threadIds.length >= GMAIL_SWEEP_THREAD_LIMIT) break;
  }

  const documents = [];
  const queue = threadIds.slice(0, GMAIL_SWEEP_THREAD_LIMIT);
  const total = queue.length;
  let read = 0;
  onProgress(read, total);
  const worker = async () => {
    while (queue.length) {
      const threadId = queue.shift();
      const thread = await caller.call(
        'google_workspace_gmail_get_thread',
        { thread_id: threadId },
      );
      read += 1;
      onProgress(read, total);
      const messages = Array.isArray(thread?.messages) ? thread.messages : [];
      const last = messages[messages.length - 1];
      if (!last) continue;
      const subject = String(messages[0].subject || last.subject || 'Gmail thread').trim();
      const participants = [...new Set(messages.flatMap((message) => [message.from, message.to])
        .filter(Boolean))];
      const labelIds = [...new Set(messages.flatMap((message) => message.labelIds || []))];
      documents.push({
        externalObjectId: thread.id,
        sourceType: 'email',
        normalizedType: 'email',
        title: subject,
        content: [
          subject,
          participants.length ? `Participants: ${participants.join(', ')}` : '',
          last.date ? `Date: ${last.date}` : '',
          `Messages: ${messages.length}`,
          String(last.bodyText || thread.snippet || '').slice(0, GMAIL_SWEEP_BODY_CHARS),
        ].filter(Boolean).join('\n'),
        summary: thread.snippet || subject,
        sourceTimestamp: last.internalDate || last.date || collectedAt,
        salience: labelIds.includes('IMPORTANT') || labelIds.includes('STARRED') ? 8 : 7,
        payload: { id: thread.id, labelIds, messageCount: messages.length },
      });
    }
  };
  await Promise.all(Array.from({ length: GMAIL_SWEEP_CONCURRENCY }, worker));
  return documents;
}

// Collectors hand refreshed tokens back so ingestion can persist them.
function createGoogleToolCaller(connection, signal) {
  const caller = {
    credentials: null,
    async call(toolName, args) {
      const execution = await executeGoogleWorkspaceTool(toolName, args, connection, { signal });
      caller.credentials = execution.credentials || caller.credentials;
      return execution.result;
    },
  };
  return caller;
}

async function collectGoogleMemorySweep({
  connection,
  sourceTypes = [],
  skipObjectIds = new Set(),
  onProgress = () => {},
  signal = null,
}) {
  const appKey = String(connection?.app_key || '').trim();
  const collectedAt = new Date().toISOString();
  const caller = createGoogleToolCaller(connection, signal);
  const documents = appKey === 'gmail' && sourceTypes.includes('email')
    ? await collectGmailSweepDocuments(caller, collectedAt, skipObjectIds, onProgress)
    : [];
  return { documents, cursor: { collectedAt, appKey, sourceTypes }, credentials: caller.credentials };
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
    getEnvStatus(context = {}) {
      return googleOAuthApp.getEnvStatus(context);
    },
    ...googleOAuthApp.userConfigHandlers,
    getToolDefinitions(options = {}) {
      const connectedAppIds = new Set(options.connectedAppIds || []);
      return googleWorkspaceToolDefinitions.filter((tool) =>
        connectedAppIds.has(tool.appId),
      );
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

      const apps = GOOGLE_WORKSPACE_APPS.map((app) =>
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
    async beginOAuth({ state, codeVerifier, appKey, userId, agentId }) {
      const app = getApp(appKey);
      if (!app) {
        throw new Error(`Unknown Google Workspace app: ${appKey}`);
      }
      const config = googleOAuthApp.resolve({ userId, agentId });
      if (!config.configured) {
        throw new Error(googleOAuthApp.getEnvStatus({ userId, agentId }).summary);
      }
      const client = createOAuthClient(config);
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
    async finishOAuth({ code, codeVerifier, appKey, userId, agentId, signal }) {
      const app = getApp(appKey);
      if (!app) {
        throw new Error(`Unknown Google Workspace app: ${appKey}`);
      }
      const client = attachAbortSignal(
        createOAuthClient(googleOAuthApp.resolve({ userId, agentId })),
        signal,
      );
      const { tokens } = await waitForAbortableResult(
        client.getToken({
          code,
          codeVerifier,
        }),
        signal,
      );
      client.setCredentials(tokens);
      const oauth2 = google.oauth2({ version: 'v2', auth: client });
      const profile = await waitForAbortableResult(oauth2.userinfo.get(), signal);
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
    async disconnect(connectionRow, executionOptions = {}) {
      const auth = await buildAuthorizedClient(connectionRow, executionOptions);
      const refreshToken = auth.credentials.refresh_token;
      const accessToken = auth.credentials.access_token;
      if (refreshToken) {
        await waitForAbortableResult(
          auth.revokeToken(refreshToken),
          executionOptions.signal,
        ).catch((error) => {
          console.warn(
            `[Google Workspace] Failed to revoke refresh token for disconnect (connection ${connectionRow?.id || 'unknown'}): ${error?.message || error}`,
          );
        });
      } else if (accessToken) {
        await waitForAbortableResult(
          auth.revokeToken(accessToken),
          executionOptions.signal,
        ).catch((error) => {
          console.warn(
            `[Google Workspace] Failed to revoke access token for disconnect (connection ${connectionRow?.id || 'unknown'}): ${error?.message || error}`,
          );
        });
      }
    },
    async testConnection(connectionRow, executionOptions = {}) {
      const auth = await buildAuthorizedClient(connectionRow, executionOptions);
      const oauth2 = google.oauth2({ version: 'v2', auth });
      await waitForAbortableResult(
        oauth2.userinfo.get(),
        executionOptions.signal,
      );
      return { credentials: auth.credentials };
    },
    async executeTool(toolName, args, connectionRow, executionOptions = {}) {
      return executeGoogleWorkspaceTool(
        toolName,
        args,
        connectionRow,
        executionOptions,
      );
    },
    async collectMemorySweep(options) {
      return collectGoogleMemorySweep(options);
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
        return describeIncompleteSetupForModel(this.label, snapshot.env);
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
