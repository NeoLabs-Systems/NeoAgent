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
    userScopes: [
      'channels:read',
      'channels:history',
      'groups:read',
      'groups:history',
      'im:read',
      'im:history',
      'mpim:read',
      'mpim:history',
      'chat:write',
      'users:read',
      'users:read.email',
      'files:read',
      'files:write',
      'search:read',
      'reactions:read',
      'reactions:write',
      'pins:read',
      'pins:write',
    ],
  },
];

const slackToolDefinitions = [
  {
    appId: 'slack',
    name: 'slack_list_conversations',
    access: 'read',
    description: 'List Slack channels, groups, IMs, or MPIMs visible to the connected user.',
    parameters: {
      type: 'object',
      properties: {
        types: { type: 'string', description: 'Conversation types, default public_channel,private_channel,im,mpim.' },
        limit: { type: 'number', description: 'Maximum conversations, default 50.' },
      },
    },
  },
  {
    appId: 'slack',
    name: 'slack_get_conversation_history',
    access: 'read',
    description: 'Read recent Slack conversation messages.',
    parameters: {
      type: 'object',
      properties: {
        channel: { type: 'string', description: 'Slack channel/conversation ID.' },
        limit: { type: 'number', description: 'Maximum messages, default 20.' },
      },
      required: ['channel'],
    },
  },
  {
    appId: 'slack',
    name: 'slack_post_message',
    access: 'write',
    description: 'Post a Slack message to a channel or conversation.',
    parameters: {
      type: 'object',
      properties: {
        channel: { type: 'string', description: 'Slack channel/conversation ID.' },
        text: { type: 'string', description: 'Plain-text message.' },
        thread_ts: { type: 'string', description: 'Optional parent message timestamp for a threaded reply.' },
      },
      required: ['channel', 'text'],
    },
  },
  {
    appId: 'slack',
    name: 'slack_search_messages',
    access: 'read',
    description: 'Search Slack messages.',
    parameters: {
      type: 'object',
      properties: {
        query: { type: 'string', description: 'Slack search query.' },
        count: { type: 'number', description: 'Maximum results, default 20.' },
      },
      required: ['query'],
    },
  },
  {
    appId: 'slack',
    name: 'slack_get_user_info',
    access: 'read',
    description: 'Get Slack user profile information.',
    parameters: {
      type: 'object',
      properties: {
        user: { type: 'string', description: 'Slack user ID.' },
      },
      required: ['user'],
    },
  },
  {
    appId: 'slack',
    name: 'slack_api_request',
    access: 'dynamic_http_method',
    description: 'Make an authenticated Slack Web API request for advanced Slack operations.',
    parameters: {
      type: 'object',
      properties: {
        method_name: { type: 'string', description: 'Slack Web API method name, e.g. conversations.info.' },
        http_method: { type: 'string', description: 'GET or POST, default POST.' },
        query: { type: 'object', description: 'Optional query parameters.' },
        body: { type: 'object', description: 'Optional JSON body.' },
      },
      required: ['method_name'],
    },
  },
];

function requireText(value, label) {
  const text = String(value || '').trim();
  if (!text) throw new Error(`${label} is required.`);
  return text;
}

async function slackApi(credentials, methodName, { httpMethod = 'POST', query, body } = {}) {
  const normalizedMethod = requireText(methodName, 'method_name');
  if (!/^[a-zA-Z0-9_.]+$/.test(normalizedMethod)) {
    throw new Error('method_name must be a Slack Web API method name.');
  }
  const normalizedHttpMethod = String(httpMethod || 'POST').toUpperCase();
  if (!['GET', 'POST'].includes(normalizedHttpMethod)) {
    throw new Error('http_method must be GET or POST.');
  }
  const url = new URL(`https://slack.com/api/${normalizedMethod}`);
  for (const [key, value] of Object.entries(query || {})) {
    if (value !== undefined && value !== null) url.searchParams.set(key, String(value));
  }
  return fetchJson(
    url.toString(),
    {
      method: normalizedHttpMethod,
      headers: { Authorization: `Bearer ${credentials.access_token}` },
      ...(body === undefined ? {} : { json: body }),
    },
    { serviceName: 'Slack' },
  );
}

async function executeSlackTool(toolName, args, { credentials }) {
  switch (toolName) {
    case 'slack_list_conversations':
      return {
        result: await slackApi(credentials, 'conversations.list', {
          httpMethod: 'GET',
          query: {
            types: String(args.types || 'public_channel,private_channel,im,mpim'),
            limit: Math.max(1, Math.min(Number(args.limit) || 50, 200)),
          },
        }),
      };
    case 'slack_get_conversation_history':
      return {
        result: await slackApi(credentials, 'conversations.history', {
          httpMethod: 'GET',
          query: {
            channel: requireText(args.channel, 'channel'),
            limit: Math.max(1, Math.min(Number(args.limit) || 20, 200)),
          },
        }),
      };
    case 'slack_post_message':
      return {
        result: await slackApi(credentials, 'chat.postMessage', {
          body: {
            channel: requireText(args.channel, 'channel'),
            text: requireText(args.text, 'text'),
            thread_ts: args.thread_ts || undefined,
          },
        }),
      };
    case 'slack_search_messages':
      return {
        result: await slackApi(credentials, 'search.messages', {
          httpMethod: 'GET',
          query: {
            query: requireText(args.query, 'query'),
            count: Math.max(1, Math.min(Number(args.count) || 20, 100)),
          },
        }),
      };
    case 'slack_get_user_info':
      return {
        result: await slackApi(credentials, 'users.info', {
          httpMethod: 'GET',
          query: { user: requireText(args.user, 'user') },
        }),
      };
    case 'slack_api_request':
      if (process.env.NEOAGENT_ENABLE_SLACK_DYNAMIC_API_REQUEST !== 'true') {
        throw new Error('slack_api_request is disabled by default. Set NEOAGENT_ENABLE_SLACK_DYNAMIC_API_REQUEST=true to enable it.');
      }
      return {
        result: await slackApi(credentials, requireText(args.method_name, 'method_name'), {
          httpMethod: args.http_method || 'POST',
          query: args.query,
          body: args.body,
        }),
      };
    default:
      return null;
  }
}

function createSlackProvider() {
  return createOAuthProvider({
    key: 'slack',
    label: 'Slack',
    description:
      'Official Slack OAuth account connections for future workspace, channel, and messaging workflows.',
    icon: 'slack',
    apps: SLACK_APPS,
    toolDefinitions: slackToolDefinitions,
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
        url: appendQuery('https://slack.com/oauth/v2/authorize', {
          client_id: config.clientId,
          redirect_uri: config.redirectUri,
          user_scope: escapeScope(app.userScopes),
          state,
        }),
        appId: app.id,
      };
    },
    async finishOAuth({ code, app }) {
      const config = resolveSlackOAuthConfig();
      const token = await fetchJson(
        'https://slack.com/api/oauth.v2.access',
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

      const userToken = token?.authed_user?.access_token || token.access_token;
      const authTest = await slackApi({ access_token: userToken }, 'auth.test', {
        httpMethod: 'GET',
      });
      const profile = authTest?.user_id
        ? await slackApi({ access_token: userToken }, 'users.info', {
            httpMethod: 'GET',
            query: { user: authTest.user_id },
          }).catch(() => null)
        : null;
      const user = profile?.user || {};
      const accountEmail = String(
        user?.profile?.email || authTest?.user || authTest?.user_id || '',
      ).trim();
      if (!accountEmail) {
        throw new Error('Slack OAuth did not return a stable account identifier.');
      }

      return {
        appId: app.id,
        accountEmail,
        credentials: {
          access_token: userToken,
          bot_access_token: token.access_token,
          token_type: token.token_type,
          team: token.team || null,
          enterprise: token.enterprise || null,
          authed_user: token.authed_user || null,
        },
        scopes: app.userScopes,
        metadata: {
          name: user?.real_name || user?.name || authTest?.user || null,
          email: user?.profile?.email || null,
          image: user?.profile?.image_192 || null,
          teamId: authTest?.team_id || token?.team?.id || null,
          teamName: authTest?.team || token?.team?.name || null,
          userId: authTest?.user_id || null,
        },
      };
    },
    executeTool: executeSlackTool,
  });
}

module.exports = {
  createSlackProvider,
};
