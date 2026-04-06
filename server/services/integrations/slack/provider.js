'use strict';

const { describeEnvStatus, resolveSlackOAuthConfig } = require('../env');
const {
  appendQuery,
  createOAuthProvider,
  escapeScope,
  fetchJson,
} = require('../oauth_provider');

const SLACK_APPS = [
  {
    id: 'slack',
    label: 'Slack',
    description: 'Connect a Slack identity for future official workspace and messaging tools.',
    scopes: ['openid', 'profile', 'email'],
  },
];

function createSlackProvider() {
  return createOAuthProvider({
    key: 'slack',
    label: 'Slack',
    description:
      'Official Slack OAuth account connections for future workspace, channel, and messaging workflows.',
    icon: 'slack',
    apps: SLACK_APPS,
    connectPrompt:
      'Slack account connection is available here now. Built-in Slack-native tools are not shipped yet in this run.',
    getEnvStatus() {
      return describeEnvStatus(resolveSlackOAuthConfig(), {
        label: 'Slack',
      });
    },
    async beginOAuth({ state, app }) {
      const config = resolveSlackOAuthConfig();
      return {
        url: appendQuery('https://slack.com/openid/connect/authorize', {
          client_id: config.clientId,
          redirect_uri: config.redirectUri,
          response_type: 'code',
          scope: escapeScope(app.scopes),
          state,
          nonce: state,
        }),
        appId: app.id,
      };
    },
    async finishOAuth({ code, app }) {
      const config = resolveSlackOAuthConfig();
      const token = await fetchJson(
        'https://slack.com/api/openid.connect.token',
        {
          method: 'POST',
          form: {
            client_id: config.clientId,
            client_secret: config.clientSecret,
            code,
            grant_type: 'authorization_code',
            redirect_uri: config.redirectUri,
          },
        },
        { serviceName: 'Slack' },
      );

      const profile = await fetchJson(
        'https://slack.com/api/openid.connect.userInfo',
        {
          headers: {
            Authorization: `Bearer ${token.access_token}`,
          },
        },
        { serviceName: 'Slack' },
      );

      const slackUserId = String(profile?.['https://slack.com/user_id'] || '').trim();
      const accountEmail = String(
        profile?.email || slackUserId || profile?.sub || '',
      ).trim();
      if (!accountEmail) {
        throw new Error('Slack OAuth did not return a stable account identifier.');
      }

      return {
        appId: app.id,
        accountEmail,
        credentials: {
          access_token: token.access_token,
          id_token: token.id_token,
          refresh_token: token.refresh_token,
          expires_in: token.expires_in,
          token_type: token.token_type,
        },
        scopes: app.scopes,
        metadata: {
          name: profile?.name || null,
          email: profile?.email || null,
          image: profile?.picture || null,
          teamId: profile?.['https://slack.com/team_id'] || null,
          teamName: profile?.['https://slack.com/team_name'] || null,
          userId: profile?.['https://slack.com/user_id'] || null,
        },
      };
    },
  });
}

module.exports = {
  createSlackProvider,
};
