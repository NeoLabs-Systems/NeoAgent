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
    scopes: [
      'current_user:read',
      'file_content:read',
      'file_metadata:read',
      'file_comments:read',
      'file_comments:write',
      'library_content:read',
      'library_assets:read',
      'file_dev_resources:read',
      'file_dev_resources:write',
    ],
  },
];

const figmaToolDefinitions = [
  {
    appId: 'figma',
    name: 'figma_get_me',
    access: 'read',
    description: 'Get the current Figma user.',
    parameters: { type: 'object', properties: {} },
  },
  {
    appId: 'figma',
    name: 'figma_get_file',
    access: 'read',
    description: 'Read a Figma file JSON document.',
    parameters: {
      type: 'object',
      properties: {
        file_key: { type: 'string', description: 'Figma file key.' },
        ids: { type: 'string', description: 'Optional comma-separated node IDs.' },
        depth: { type: 'number', description: 'Optional traversal depth.' },
      },
      required: ['file_key'],
    },
  },
  {
    appId: 'figma',
    name: 'figma_get_file_nodes',
    access: 'read',
    description: 'Read specific nodes from a Figma file.',
    parameters: {
      type: 'object',
      properties: {
        file_key: { type: 'string', description: 'Figma file key.' },
        ids: { type: 'string', description: 'Comma-separated node IDs.' },
      },
      required: ['file_key', 'ids'],
    },
  },
  {
    appId: 'figma',
    name: 'figma_get_file_images',
    access: 'read',
    description: 'Render Figma nodes to image URLs.',
    parameters: {
      type: 'object',
      properties: {
        file_key: { type: 'string', description: 'Figma file key.' },
        ids: { type: 'string', description: 'Comma-separated node IDs.' },
        format: { type: 'string', description: 'jpg, png, svg, or pdf. Default png.' },
        scale: { type: 'number', description: 'Optional image scale.' },
      },
      required: ['file_key', 'ids'],
    },
  },
  {
    appId: 'figma',
    name: 'figma_get_comments',
    access: 'read',
    description: 'List comments on a Figma file.',
    parameters: {
      type: 'object',
      properties: {
        file_key: { type: 'string', description: 'Figma file key.' },
      },
      required: ['file_key'],
    },
  },
  {
    appId: 'figma',
    name: 'figma_post_comment',
    access: 'write',
    description: 'Post a Figma file comment.',
    parameters: {
      type: 'object',
      properties: {
        file_key: { type: 'string', description: 'Figma file key.' },
        message: { type: 'string', description: 'Comment message.' },
        client_meta: { type: 'object', description: 'Optional Figma comment position metadata.' },
      },
      required: ['file_key', 'message'],
    },
  },
  {
    appId: 'figma',
    name: 'figma_api_request',
    access: 'dynamic_http_method',
    description: 'Make an authenticated Figma REST API request for advanced file, comment, library, variable, webhook, and dev resource operations.',
    parameters: {
      type: 'object',
      properties: {
        method: { type: 'string', description: 'HTTP method: GET, POST, PUT, PATCH, or DELETE.' },
        path: { type: 'string', description: 'Figma API path, e.g. /v1/files/{key}.' },
        query: { type: 'object', description: 'Optional query parameters.' },
        body: { type: 'object', description: 'Optional JSON body.' },
      },
      required: ['method', 'path'],
    },
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

function requireText(value, label) {
  const text = String(value || '').trim();
  if (!text) throw new Error(`${label} is required.`);
  return text;
}

function figmaUrl(path, query) {
  const url = new URL(
    String(path || '').startsWith('http')
      ? String(path)
      : `https://api.figma.com${String(path || '').startsWith('/') ? '' : '/'}${path}`,
  );
  if (url.hostname !== 'api.figma.com') {
    throw new Error('Figma API request URL must target api.figma.com.');
  }
  for (const [key, value] of Object.entries(query || {})) {
    if (value !== undefined && value !== null) url.searchParams.set(key, String(value));
  }
  return url.toString();
}

async function figmaRequest(credentials, { method = 'GET', path, query, body }) {
  return fetchJson(
    figmaUrl(path, query),
    {
      method: String(method || 'GET').toUpperCase(),
      headers: { Authorization: `Bearer ${credentials.access_token}` },
      ...(body === undefined ? {} : { json: body }),
    },
    { serviceName: 'Figma' },
  );
}

async function executeFigmaTool(toolName, args, { credentials }) {
  switch (toolName) {
    case 'figma_get_me':
      return { result: await figmaRequest(credentials, { path: '/v1/me' }) };
    case 'figma_get_file':
      return {
        result: await figmaRequest(credentials, {
          path: `/v1/files/${encodeURIComponent(requireText(args.file_key, 'file_key'))}`,
          query: {
            ids: args.ids || undefined,
            depth: args.depth || undefined,
          },
        }),
      };
    case 'figma_get_file_nodes':
      return {
        result: await figmaRequest(credentials, {
          path: `/v1/files/${encodeURIComponent(requireText(args.file_key, 'file_key'))}/nodes`,
          query: { ids: requireText(args.ids, 'ids') },
        }),
      };
    case 'figma_get_file_images':
      return {
        result: await figmaRequest(credentials, {
          path: `/v1/images/${encodeURIComponent(requireText(args.file_key, 'file_key'))}`,
          query: {
            ids: requireText(args.ids, 'ids'),
            format: String(args.format || 'png'),
            scale: args.scale || undefined,
          },
        }),
      };
    case 'figma_get_comments':
      return {
        result: await figmaRequest(credentials, {
          path: `/v1/files/${encodeURIComponent(requireText(args.file_key, 'file_key'))}/comments`,
        }),
      };
    case 'figma_post_comment':
      return {
        result: await figmaRequest(credentials, {
          method: 'POST',
          path: `/v1/files/${encodeURIComponent(requireText(args.file_key, 'file_key'))}/comments`,
          body: {
            message: requireText(args.message, 'message'),
            client_meta: args.client_meta || undefined,
          },
        }),
      };
    case 'figma_api_request':
      return {
        result: await figmaRequest(credentials, {
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

function createFigmaProvider() {
  return createOAuthProvider({
    key: 'figma',
    label: 'Figma',
    description:
      'Official Figma OAuth account connections for future design file and collaboration workflows.',
    icon: 'figma',
    apps: FIGMA_APPS,
    toolDefinitions: figmaToolDefinitions,
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
      const basic = Buffer.from(`${config.clientId}:${config.clientSecret}`).toString(
        'base64',
      );
      const token = await fetchJson(
        'https://api.figma.com/v1/oauth/token',
        {
          method: 'POST',
          headers: {
            Authorization: `Basic ${basic}`,
          },
          form: {
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
    executeTool: executeFigmaTool,
  });
}

module.exports = {
  createFigmaProvider,
};
