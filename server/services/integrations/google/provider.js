'use strict';

const crypto = require('crypto');
const { google } = require('googleapis');
const { describeEnvStatus, resolveGoogleOAuthConfig } = require('../env');
const { gmailToolDefinitions, executeGmailTool } = require('./gmail');
const { calendarToolDefinitions, executeCalendarTool } = require('./calendar');
const { driveToolDefinitions, executeDriveTool } = require('./drive');
const { docsToolDefinitions, executeDocsTool } = require('./docs');
const { sheetsToolDefinitions, executeSheetsTool } = require('./sheets');

const GOOGLE_WORKSPACE_SCOPES = [
  'https://www.googleapis.com/auth/gmail.modify',
  'https://www.googleapis.com/auth/calendar',
  'https://www.googleapis.com/auth/drive',
  'https://www.googleapis.com/auth/documents',
  'https://www.googleapis.com/auth/spreadsheets',
];

const GOOGLE_WORKSPACE_APPS = [
  { id: 'gmail', label: 'Gmail' },
  { id: 'calendar', label: 'Calendar' },
  { id: 'drive', label: 'Drive' },
  { id: 'docs', label: 'Docs' },
  { id: 'sheets', label: 'Sheets' },
];

const googleWorkspaceToolDefinitions = [
  ...gmailToolDefinitions,
  ...calendarToolDefinitions,
  ...driveToolDefinitions,
  ...docsToolDefinitions,
  ...sheetsToolDefinitions,
];

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
    credentials = JSON.parse(connection.credentials_json || '{}');
  } catch {
    credentials = {};
  }
  client.setCredentials(credentials);
  return client;
}

function summarizeConnection(row, envStatus) {
  if (!envStatus.configured) {
    return {
      status: 'env_not_configured',
      connected: false,
      accountEmail: row?.account_email || null,
      lastConnectedAt: row?.last_connected_at || null,
    };
  }

  if (!row) {
    return {
      status: 'not_connected',
      connected: false,
      accountEmail: null,
      lastConnectedAt: null,
    };
  }

  const connected = row.status === 'connected';
  return {
    status: row.status || 'not_connected',
    connected,
    accountEmail: row.account_email || null,
    lastConnectedAt: row.last_connected_at || null,
  };
}

async function executeGoogleWorkspaceTool(toolName, args, connection) {
  const auth = await buildAuthorizedClient(connection);
  let result = await executeGmailTool(toolName, args, auth);
  if (result !== null) return { result, credentials: auth.credentials };

  result = await executeCalendarTool(toolName, args, auth);
  if (result !== null) return { result, credentials: auth.credentials };

  result = await executeDriveTool(toolName, args, auth);
  if (result !== null) return { result, credentials: auth.credentials };

  result = await executeDocsTool(toolName, args, auth);
  if (result !== null) return { result, credentials: auth.credentials };

  result = await executeSheetsTool(toolName, args, auth);
  if (result !== null) return { result, credentials: auth.credentials };

  return null;
}

function createGoogleWorkspaceProvider() {
  return {
    key: 'google_workspace',
    label: 'Google Workspace',
    description:
      'Official Gmail, Calendar, Drive, Docs, and Sheets access through one OAuth connection.',
    icon: 'google',
    apps: GOOGLE_WORKSPACE_APPS,
    scopes: GOOGLE_WORKSPACE_SCOPES,
    getEnvStatus() {
      return describeEnvStatus(resolveGoogleOAuthConfig());
    },
    getToolDefinitions() {
      return googleWorkspaceToolDefinitions;
    },
    supportsTool(toolName) {
      return googleWorkspaceToolDefinitions.some((tool) => tool.name === toolName);
    },
    buildSnapshot(connectionRow) {
      const env = this.getEnvStatus();
      return {
        id: this.key,
        label: this.label,
        description: this.description,
        icon: this.icon,
        apps: this.apps,
        env,
        connection: summarizeConnection(connectionRow, env),
        availableToolCount:
          env.configured && connectionRow?.status === 'connected'
            ? googleWorkspaceToolDefinitions.length
            : 0,
      };
    },
    async beginOAuth({ state, codeVerifier }) {
      const { config, client } = createOAuthClient();
      if (!config.configured) {
        throw new Error(
          `Missing Google OAuth configuration: ${config.missing.join(', ')}`,
        );
      }
      const codeChallenge = base64UrlSha256(codeVerifier);
      const url = client.generateAuthUrl({
        access_type: 'offline',
        prompt: 'consent',
        scope: GOOGLE_WORKSPACE_SCOPES,
        include_granted_scopes: true,
        state,
        code_challenge: codeChallenge,
        code_challenge_method: 'S256',
      });
      return { url };
    },
    async finishOAuth({ code, codeVerifier }) {
      const { client } = createOAuthClient();
      const { tokens } = await client.getToken({
        code,
        codeVerifier,
      });
      client.setCredentials(tokens);
      const gmail = google.gmail({ version: 'v1', auth: client });
      const profile = await gmail.users.getProfile({ userId: 'me' });
      return {
        accountEmail: profile.data.emailAddress || null,
        credentials: client.credentials,
        scopes: GOOGLE_WORKSPACE_SCOPES,
        metadata: {
          apps: GOOGLE_WORKSPACE_APPS.map((app) => app.id),
        },
      };
    },
    async disconnect(connectionRow) {
      const auth = await buildAuthorizedClient(connectionRow);
      const refreshToken = auth.credentials.refresh_token;
      const accessToken = auth.credentials.access_token;
      if (refreshToken) {
        await auth.revokeToken(refreshToken).catch(() => {});
      } else if (accessToken) {
        await auth.revokeToken(accessToken).catch(() => {});
      }
    },
    async executeTool(toolName, args, connectionRow) {
      return executeGoogleWorkspaceTool(toolName, args, connectionRow);
    },
    summarizeConnection(connectionRow) {
      const connection = this.buildSnapshot(connectionRow).connection;
      if (!connection.connected) {
        if (connection.status === 'env_not_configured') {
          return 'Google Workspace OAuth is not configured on the server.';
        }
        return 'Google Workspace is not connected.';
      }
      return `Google Workspace is connected for ${connection.accountEmail || 'the current account'}.`;
    },
  };
}

module.exports = {
  createGoogleWorkspaceProvider,
  GOOGLE_WORKSPACE_APPS,
  GOOGLE_WORKSPACE_SCOPES,
};
