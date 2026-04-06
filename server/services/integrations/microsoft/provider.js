'use strict';

const { describeEnvStatus, resolveMicrosoftOAuthConfig } = require('../env');
const {
  appendQuery,
  createOAuthProvider,
  escapeScope,
  fetchJson,
} = require('../oauth_provider');

const MICROSOFT_BASE_SCOPES = ['openid', 'profile', 'email', 'offline_access', 'User.Read'];

const MICROSOFT_APPS = [
  {
    id: 'outlook',
    label: 'Outlook',
    description: 'Connect Outlook mail access for future Microsoft 365 native tools.',
    scopes: [...MICROSOFT_BASE_SCOPES, 'Mail.Read'],
  },
  {
    id: 'calendar',
    label: 'Calendar',
    description: 'Connect Outlook Calendar access for future Microsoft 365 scheduling tools.',
    scopes: [...MICROSOFT_BASE_SCOPES, 'Calendars.Read'],
  },
  {
    id: 'onedrive',
    label: 'OneDrive',
    description: 'Connect OneDrive file access for future Microsoft 365 document tools.',
    scopes: [...MICROSOFT_BASE_SCOPES, 'Files.Read'],
  },
  {
    id: 'teams',
    label: 'Teams',
    description: 'Connect Microsoft Teams chat access for future collaboration tools.',
    scopes: [...MICROSOFT_BASE_SCOPES, 'Chat.Read'],
  },
];

function getMicrosoftEndpoints() {
  const config = resolveMicrosoftOAuthConfig();
  const tenant = encodeURIComponent(config.tenantId);
  return {
    config,
    authorizeUrl: `https://login.microsoftonline.com/${tenant}/oauth2/v2.0/authorize`,
    tokenUrl: `https://login.microsoftonline.com/${tenant}/oauth2/v2.0/token`,
  };
}

function createMicrosoftProvider() {
  return createOAuthProvider({
    key: 'microsoft_365',
    label: 'Microsoft 365',
    description:
      'Official Microsoft 365 OAuth account connections for Outlook, Calendar, OneDrive, and Teams.',
    icon: 'microsoft',
    apps: MICROSOFT_APPS,
    connectPrompt:
      'This wires Microsoft 365 account connections into Official Integrations now. Native Outlook, Calendar, OneDrive, and Teams tools can be layered on later.',
    getEnvStatus() {
      return describeEnvStatus(resolveMicrosoftOAuthConfig(), {
        label: 'Microsoft 365',
      });
    },
    async beginOAuth({ state, app }) {
      const { config, authorizeUrl } = getMicrosoftEndpoints();
      return {
        url: appendQuery(authorizeUrl, {
          client_id: config.clientId,
          redirect_uri: config.redirectUri,
          response_type: 'code',
          response_mode: 'query',
          scope: escapeScope(app.scopes),
          state,
          prompt: 'select_account',
        }),
        appId: app.id,
      };
    },
    async finishOAuth({ code, app }) {
      const { config, tokenUrl } = getMicrosoftEndpoints();
      const token = await fetchJson(
        tokenUrl,
        {
          method: 'POST',
          form: {
            client_id: config.clientId,
            client_secret: config.clientSecret,
            grant_type: 'authorization_code',
            code,
            redirect_uri: config.redirectUri,
            scope: escapeScope(app.scopes),
          },
        },
        { serviceName: 'Microsoft 365' },
      );

      const profile = await fetchJson(
        'https://graph.microsoft.com/v1.0/me?$select=id,displayName,mail,userPrincipalName',
        {
          headers: {
            Authorization: `Bearer ${token.access_token}`,
          },
        },
        { serviceName: 'Microsoft 365' },
      );

      const accountEmail = String(
        profile?.mail || profile?.userPrincipalName || profile?.displayName || profile?.id || '',
      ).trim();
      if (!accountEmail) {
        throw new Error('Microsoft 365 OAuth did not return a stable account identifier.');
      }

      return {
        appId: app.id,
        accountEmail,
        credentials: {
          access_token: token.access_token,
          refresh_token: token.refresh_token,
          expires_in: token.expires_in,
          scope: token.scope,
          token_type: token.token_type,
        },
        scopes: app.scopes,
        metadata: {
          id: profile?.id || null,
          displayName: profile?.displayName || null,
          mail: profile?.mail || null,
          userPrincipalName: profile?.userPrincipalName || null,
        },
      };
    },
  });
}

module.exports = {
  createMicrosoftProvider,
};
