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

const NOTION_VERSION = '2022-06-28';

const notionToolDefinitions = [
  {
    appId: 'notion',
    name: 'notion_search',
    description: 'Search pages and databases available to the connected Notion integration.',
    parameters: {
      type: 'object',
      properties: {
        query: { type: 'string', description: 'Search query text.' },
        filter: { type: 'object', description: 'Optional Notion search filter object.' },
        page_size: { type: 'number', description: 'Maximum results to return, default 10.' },
      },
    },
  },
  {
    appId: 'notion',
    name: 'notion_get_page',
    description: 'Retrieve a Notion page by ID.',
    parameters: {
      type: 'object',
      properties: {
        page_id: { type: 'string', description: 'Notion page ID.' },
      },
      required: ['page_id'],
    },
  },
  {
    appId: 'notion',
    name: 'notion_create_page',
    description: 'Create a Notion page under a page or database parent.',
    parameters: {
      type: 'object',
      properties: {
        parent: { type: 'object', description: 'Notion parent object, e.g. { "page_id": "..." } or { "database_id": "..." }.' },
        properties: { type: 'object', description: 'Notion page properties object.' },
        children: { type: 'array', items: { type: 'object' }, description: 'Optional block children.' },
      },
      required: ['parent', 'properties'],
    },
  },
  {
    appId: 'notion',
    name: 'notion_update_page',
    description: 'Update a Notion page properties, icon, cover, or archived state.',
    parameters: {
      type: 'object',
      properties: {
        page_id: { type: 'string', description: 'Notion page ID.' },
        properties: { type: 'object', description: 'Optional Notion page properties patch.' },
        archived: { type: 'boolean', description: 'Optional archive state.' },
        icon: { type: 'object', description: 'Optional Notion icon object.' },
        cover: { type: 'object', description: 'Optional Notion cover object.' },
      },
      required: ['page_id'],
    },
  },
  {
    appId: 'notion',
    name: 'notion_query_database',
    description: 'Query a Notion database or data source by ID.',
    parameters: {
      type: 'object',
      properties: {
        database_id: { type: 'string', description: 'Notion database/data source ID.' },
        filter: { type: 'object', description: 'Optional filter object.' },
        sorts: { type: 'array', items: { type: 'object' }, description: 'Optional sort objects.' },
        page_size: { type: 'number', description: 'Maximum results to return, default 10.' },
      },
      required: ['database_id'],
    },
  },
  {
    appId: 'notion',
    name: 'notion_get_block_children',
    description: 'List child blocks under a Notion block or page.',
    parameters: {
      type: 'object',
      properties: {
        block_id: { type: 'string', description: 'Notion block or page ID.' },
        page_size: { type: 'number', description: 'Maximum blocks to return, default 25.' },
      },
      required: ['block_id'],
    },
  },
  {
    appId: 'notion',
    name: 'notion_append_block_children',
    description: 'Append child blocks under a Notion block or page.',
    parameters: {
      type: 'object',
      properties: {
        block_id: { type: 'string', description: 'Notion block or page ID.' },
        children: { type: 'array', items: { type: 'object' }, description: 'Notion block children to append.' },
      },
      required: ['block_id', 'children'],
    },
  },
  {
    appId: 'notion',
    name: 'notion_update_block',
    description: 'Update a Notion block.',
    parameters: {
      type: 'object',
      properties: {
        block_id: { type: 'string', description: 'Notion block ID.' },
        body: { type: 'object', description: 'Notion block patch body.' },
      },
      required: ['block_id', 'body'],
    },
  },
  {
    appId: 'notion',
    name: 'notion_delete_block',
    description: 'Delete/archive a Notion block.',
    parameters: {
      type: 'object',
      properties: {
        block_id: { type: 'string', description: 'Notion block ID.' },
      },
      required: ['block_id'],
    },
  },
  {
    appId: 'notion',
    name: 'notion_api_request',
    description: 'Make an authenticated Notion API request for advanced Notion operations.',
    parameters: {
      type: 'object',
      properties: {
        method: { type: 'string', description: 'HTTP method: GET, POST, PATCH, or DELETE.' },
        path: { type: 'string', description: 'Notion API path, e.g. /v1/comments or /v1/users.' },
        query: { type: 'object', description: 'Optional query parameters.' },
        body: { type: 'object', description: 'Optional JSON body.' },
      },
      required: ['method', 'path'],
    },
  },
];

function requireText(value, label) {
  const text = String(value || '').trim();
  if (!text) throw new Error(`${label} is required.`);
  return text;
}

function notionUrl(path, query) {
  const url = new URL(
    String(path || '').startsWith('http')
      ? String(path)
      : `https://api.notion.com${String(path || '').startsWith('/') ? '' : '/'}${path}`,
  );
  if (url.hostname !== 'api.notion.com') {
    throw new Error('Notion API request URL must target api.notion.com.');
  }
  for (const [key, value] of Object.entries(query || {})) {
    if (value !== undefined && value !== null) url.searchParams.set(key, String(value));
  }
  return url.toString();
}

async function notionRequest(credentials, { method = 'GET', path, query, body }) {
  return fetchJson(
    notionUrl(path, query),
    {
      method: String(method || 'GET').toUpperCase(),
      headers: {
        Authorization: `Bearer ${credentials.access_token}`,
        'Notion-Version': NOTION_VERSION,
      },
      ...(body === undefined ? {} : { json: body }),
    },
    { serviceName: 'Notion' },
  );
}

async function executeNotionTool(toolName, args, { credentials }) {
  switch (toolName) {
    case 'notion_search':
      return {
        result: await notionRequest(credentials, {
          method: 'POST',
          path: '/v1/search',
          body: {
            query: String(args.query || '').trim() || undefined,
            filter: args.filter || undefined,
            page_size: Math.max(1, Math.min(Number(args.page_size) || 10, 100)),
          },
        }),
      };
    case 'notion_get_page':
      return {
        result: await notionRequest(credentials, {
          path: `/v1/pages/${encodeURIComponent(requireText(args.page_id, 'page_id'))}`,
        }),
      };
    case 'notion_create_page':
      return {
        result: await notionRequest(credentials, {
          method: 'POST',
          path: '/v1/pages',
          body: {
            parent: args.parent,
            properties: args.properties,
            children: Array.isArray(args.children) ? args.children : undefined,
          },
        }),
      };
    case 'notion_update_page':
      return {
        result: await notionRequest(credentials, {
          method: 'PATCH',
          path: `/v1/pages/${encodeURIComponent(requireText(args.page_id, 'page_id'))}`,
          body: {
            properties: args.properties || undefined,
            archived: args.archived,
            icon: args.icon,
            cover: args.cover,
          },
        }),
      };
    case 'notion_query_database':
      return {
        result: await notionRequest(credentials, {
          method: 'POST',
          path: `/v1/databases/${encodeURIComponent(requireText(args.database_id, 'database_id'))}/query`,
          body: {
            filter: args.filter || undefined,
            sorts: Array.isArray(args.sorts) ? args.sorts : undefined,
            page_size: Math.max(1, Math.min(Number(args.page_size) || 10, 100)),
          },
        }),
      };
    case 'notion_get_block_children':
      return {
        result: await notionRequest(credentials, {
          path: `/v1/blocks/${encodeURIComponent(requireText(args.block_id, 'block_id'))}/children`,
          query: { page_size: Math.max(1, Math.min(Number(args.page_size) || 25, 100)) },
        }),
      };
    case 'notion_append_block_children':
      return {
        result: await notionRequest(credentials, {
          method: 'PATCH',
          path: `/v1/blocks/${encodeURIComponent(requireText(args.block_id, 'block_id'))}/children`,
          body: { children: Array.isArray(args.children) ? args.children : [] },
        }),
      };
    case 'notion_update_block':
      return {
        result: await notionRequest(credentials, {
          method: 'PATCH',
          path: `/v1/blocks/${encodeURIComponent(requireText(args.block_id, 'block_id'))}`,
          body: args.body || {},
        }),
      };
    case 'notion_delete_block':
      return {
        result: await notionRequest(credentials, {
          method: 'DELETE',
          path: `/v1/blocks/${encodeURIComponent(requireText(args.block_id, 'block_id'))}`,
        }),
      };
    case 'notion_api_request':
      return {
        result: await notionRequest(credentials, {
          method: args.method,
          path: requireText(args.path, 'path'),
          query: args.query,
          body: args.body,
        }),
      };
    default:
      return null;
  }
}

function createNotionProvider() {
  return createOAuthProvider({
    key: 'notion',
    label: 'Notion',
    description:
      'Official Notion OAuth account connections for workspace docs, pages, and knowledge workflows.',
    icon: 'notion',
    apps: NOTION_APPS,
    toolDefinitions: notionToolDefinitions,
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
    executeTool: executeNotionTool,
  });
}

module.exports = {
  createNotionProvider,
};
