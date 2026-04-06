'use strict';

const { describeEnvStatus, resolveNotionOAuthConfig } = require('../env');
const {
  appendQuery,
  createOAuthProvider,
  fetchJson,
} = require('../oauth_provider');

const NOTION_APPS = [
  {
    id: 'notion',
    label: 'Notion',
    description: 'Connect a Notion workspace or user account for future native docs and knowledge tools.',
  },
];

function createNotionProvider() {
  return createOAuthProvider({
    key: 'notion',
    label: 'Notion',
    description:
      'Official Notion OAuth account connections for workspace docs, pages, and knowledge workflows.',
    icon: 'notion',
    apps: NOTION_APPS,
    connectPrompt:
      'This sets up the official Notion account layer only. Built-in Notion-native tools are not shipped yet in this run.',
    getEnvStatus() {
      return describeEnvStatus(resolveNotionOAuthConfig(), {
        label: 'Notion',
      });
    },
    async beginOAuth({ state, app }) {
      const config = resolveNotionOAuthConfig();
      return {
        url: appendQuery('https://api.notion.com/v1/oauth/authorize', {
          owner: 'user',
          client_id: config.clientId,
          redirect_uri: config.redirectUri,
          response_type: 'code',
          state,
        }),
        appId: app.id,
      };
    },
    async finishOAuth({ code, app }) {
      const config = resolveNotionOAuthConfig();
      const basic = Buffer.from(`${config.clientId}:${config.clientSecret}`).toString(
        'base64',
      );
      const token = await fetchJson(
        'https://api.notion.com/v1/oauth/token',
        {
          method: 'POST',
          headers: {
            Authorization: `Basic ${basic}`,
          },
          json: {
            grant_type: 'authorization_code',
            code,
            redirect_uri: config.redirectUri,
          },
        },
        { serviceName: 'Notion' },
      );

      const owner = token?.owner || {};
      const user = owner?.type === 'user' ? owner.user || {} : {};
      const email = String(user?.person?.email || '').trim();
      const workspaceName = String(token?.workspace_name || '').trim();
      const workspaceId = String(token?.workspace_id || '').trim();
      const accountEmail = email || workspaceName || workspaceId;

      if (!accountEmail) {
        throw new Error('Notion OAuth did not return a stable account identifier.');
      }

      return {
        appId: app.id,
        accountEmail,
        credentials: {
          access_token: token.access_token,
          token_type: token.token_type,
          workspace_id: token.workspace_id,
          workspace_name: token.workspace_name,
          duplicated_template_id: token.duplicated_template_id,
          bot_id: token.bot_id,
        },
        scopes: [],
        metadata: {
          workspaceId: token?.workspace_id || null,
          workspaceName: token?.workspace_name || null,
          ownerType: owner?.type || null,
          userId: user?.id || null,
          userName: user?.name || null,
          avatarUrl: user?.avatar_url || null,
        },
      };
    },
  });
}

module.exports = {
  createNotionProvider,
};
