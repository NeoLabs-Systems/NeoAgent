'use strict';

const { describeEnvStatus, resolveFigmaOAuthConfig } = require('../env');
const {
  appendQuery,
  createOAuthProvider,
  escapeScope,
  fetchJson,
} = require('../oauth_provider');

const FIGMA_APPS = [
  {
    id: 'figma',
    label: 'Figma',
    description: 'Connect a Figma account for future official design and file tools.',
    scopes: ['current_user:read'],
  },
];

function normalizeFigmaUser(profile) {
  const payload = profile?.user || profile || {};
  return {
    id: payload?.id || payload?.user_id || payload?.handle || null,
    email: payload?.email || null,
    handle: payload?.handle || payload?.login || null,
    name: payload?.name || payload?.handle || null,
    imgUrl: payload?.img_url || payload?.avatar_url || null,
  };
}

function createFigmaProvider() {
  return createOAuthProvider({
    key: 'figma',
    label: 'Figma',
    description:
      'Official Figma OAuth account connections for future design file and collaboration workflows.',
    icon: 'figma',
    apps: FIGMA_APPS,
    connectPrompt:
      'This enables the official Figma account layer now. Native Figma tools are not shipped yet in this run.',
    getEnvStatus() {
      return describeEnvStatus(resolveFigmaOAuthConfig(), {
        label: 'Figma',
      });
    },
    async beginOAuth({ state, app }) {
      const config = resolveFigmaOAuthConfig();
      return {
        url: appendQuery('https://www.figma.com/oauth', {
          client_id: config.clientId,
          redirect_uri: config.redirectUri,
          response_type: 'code',
          scope: escapeScope(app.scopes),
          state,
        }),
        appId: app.id,
      };
    },
    async finishOAuth({ code, app }) {
      const config = resolveFigmaOAuthConfig();
      const token = await fetchJson(
        'https://api.figma.com/v1/oauth/token',
        {
          method: 'POST',
          form: {
            client_id: config.clientId,
            client_secret: config.clientSecret,
            redirect_uri: config.redirectUri,
            code,
            grant_type: 'authorization_code',
          },
        },
        { serviceName: 'Figma' },
      );

      const profile = await fetchJson(
        'https://api.figma.com/v1/me',
        {
          headers: {
            Authorization: `Bearer ${token.access_token}`,
          },
        },
        { serviceName: 'Figma' },
      );

      const user = normalizeFigmaUser(profile);
      const accountEmail = String(user.email || user.handle || user.id || '').trim();
      if (!accountEmail) {
        throw new Error('Figma OAuth did not return a stable account identifier.');
      }

      return {
        appId: app.id,
        accountEmail,
        credentials: {
          access_token: token.access_token,
          refresh_token: token.refresh_token,
          expires_in: token.expires_in,
          token_type: token.token_type,
          scope: token.scope,
        },
        scopes: app.scopes,
        metadata: {
          id: user.id,
          email: user.email,
          handle: user.handle,
          name: user.name,
          avatarUrl: user.imgUrl,
        },
      };
    },
  });
}

module.exports = {
  createFigmaProvider,
};
