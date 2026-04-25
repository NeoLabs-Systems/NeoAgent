'use strict';

const crypto = require('crypto');
const {
  describeEnvStatus,
  resolveHomeAssistantOAuthConfig,
} = require('../env');
const {
  appendQuery,
  createOAuthProvider,
  fetchJson,
} = require('../oauth_provider');

const HOME_ASSISTANT_APPS = [
  {
    id: 'home_assistant',
    label: 'Home Assistant',
    description: 'Connect Home Assistant for entity state queries, service calls, and API access.',
    scopes: ['homeassistant'],
  },
];

const homeAssistantToolDefinitions = [
  {
    appId: 'home_assistant',
    name: 'home_assistant_get_config',
    access: 'read',
    description: 'Get Home Assistant configuration details for the connected instance.',
    parameters: { type: 'object', properties: {} },
  },
  {
    appId: 'home_assistant',
    name: 'home_assistant_list_states',
    access: 'read',
    description: 'List entity states from Home Assistant. Optional filters are applied client-side.',
    parameters: {
      type: 'object',
      properties: {
        domain: {
          type: 'string',
          description: 'Optional entity domain filter, for example light, climate, or switch.',
        },
        limit: {
          type: 'number',
          description: 'Optional max entities to return, default 100.',
        },
      },
    },
  },
  {
    appId: 'home_assistant',
    name: 'home_assistant_get_state',
    access: 'read',
    description: 'Get state for a single Home Assistant entity by entity_id.',
    parameters: {
      type: 'object',
      properties: {
        entity_id: { type: 'string', description: 'Entity ID, for example light.living_room.' },
      },
      required: ['entity_id'],
    },
  },
  {
    appId: 'home_assistant',
    name: 'home_assistant_call_service',
    access: 'write',
    description: 'Call a Home Assistant service such as light.turn_on or climate.set_temperature.',
    parameters: {
      type: 'object',
      properties: {
        domain: { type: 'string', description: 'Service domain, for example light, climate, or switch.' },
        service: { type: 'string', description: 'Service name, for example turn_on, turn_off, or set_temperature.' },
        service_data: { type: 'object', description: 'Optional Home Assistant service data payload.' },
      },
      required: ['domain', 'service'],
    },
  },
  {
    appId: 'home_assistant',
    name: 'home_assistant_api_request',
    access: 'dynamic_http_method',
    description: 'Make an authenticated Home Assistant REST API request for advanced operations.',
    parameters: {
      type: 'object',
      properties: {
        method: { type: 'string', description: 'HTTP method: GET, POST, PUT, PATCH, or DELETE.' },
        path: { type: 'string', description: 'API path under the configured instance, for example /api/history/period.' },
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

function homeAssistantUrl(baseUrl, path, query) {
  const normalizedBase = String(baseUrl || '').trim().replace(/\/$/, '');
  if (!normalizedBase) {
    throw new Error('HOME_ASSISTANT_BASE_URL is required.');
  }
  const url = new URL(
    String(path || '').startsWith('http')
      ? String(path)
      : `${normalizedBase}${String(path || '').startsWith('/') ? '' : '/'}${path}`,
  );
  if (new URL(normalizedBase).origin !== url.origin) {
    throw new Error('Home Assistant request URL must stay on HOME_ASSISTANT_BASE_URL origin.');
  }
  for (const [key, value] of Object.entries(query || {})) {
    if (value !== undefined && value !== null) url.searchParams.set(key, String(value));
  }
  return url.toString();
}

async function homeAssistantRequest(credentials, options = {}) {
  const config = resolveHomeAssistantOAuthConfig();
  const accessToken = String(credentials?.access_token || '').trim();
  if (!accessToken) {
    throw new Error('Home Assistant access token is missing. Reconnect this integration account.');
  }
  const method = String(options.method || 'GET').toUpperCase();
  return fetchJson(
    homeAssistantUrl(config.baseUrl, options.path, options.query),
    {
      method,
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
      ...(options.body === undefined ? {} : { json: options.body }),
    },
    { serviceName: 'Home Assistant' },
  );
}

async function executeHomeAssistantTool(toolName, args, { credentials }) {
  switch (toolName) {
    case 'home_assistant_get_config':
      return {
        result: await homeAssistantRequest(credentials, { path: '/api/config' }),
      };
    case 'home_assistant_list_states': {
      const states = await homeAssistantRequest(credentials, { path: '/api/states' });
      const domain = String(args.domain || '').trim().toLowerCase();
      const limit = Math.max(1, Math.min(Number(args.limit) || 100, 500));
      const filtered = Array.isArray(states)
        ? states.filter((item) => {
            if (!domain) return true;
            const entityId = String(item?.entity_id || '').toLowerCase();
            return entityId.startsWith(`${domain}.`);
          })
        : [];
      return {
        result: filtered.slice(0, limit),
      };
    }
    case 'home_assistant_get_state':
      return {
        result: await homeAssistantRequest(credentials, {
          path: `/api/states/${encodeURIComponent(requireText(args.entity_id, 'entity_id'))}`,
        }),
      };
    case 'home_assistant_call_service':
      return {
        result: await homeAssistantRequest(credentials, {
          method: 'POST',
          path: `/api/services/${encodeURIComponent(requireText(args.domain, 'domain'))}/${encodeURIComponent(requireText(args.service, 'service'))}`,
          body: args.service_data || {},
        }),
      };
    case 'home_assistant_api_request':
      return {
        result: await homeAssistantRequest(credentials, {
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

function resolveHomeAssistantEnvStatus() {
  const config = resolveHomeAssistantOAuthConfig();
  const missing = config.missing.slice();
  if (!config.baseUrl) {
    missing.push('HOME_ASSISTANT_BASE_URL');
  }
  return describeEnvStatus(
    {
      configured: missing.length === 0,
      missing,
    },
    { label: 'Home Assistant' },
  );
}

function normalizeCurrentUser(currentUser) {
  const payload = currentUser && typeof currentUser === 'object' ? currentUser : {};
  return {
    id: payload.id || null,
    name: payload.name || null,
    username: payload.username || null,
    email: payload.email || null,
    isOwner: Boolean(payload.is_owner),
  };
}

function stableAccountEmailLikeIdentifier(user, config) {
  const normalized = normalizeCurrentUser(user);
  const preferred = [normalized.email, normalized.username, normalized.id, normalized.name]
    .map((value) => String(value || '').trim())
    .find(Boolean);
  if (preferred) {
    return preferred;
  }
  const host = new URL(config.baseUrl).host;
  return `homeassistant@${host}`;
}

async function fetchCurrentUser(token) {
  const config = resolveHomeAssistantOAuthConfig();
  return fetchJson(
    homeAssistantUrl(config.baseUrl, '/api/auth/current_user'),
    {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${token}`,
      },
    },
    { serviceName: 'Home Assistant' },
  ).catch(() => null);
}

function createHomeAssistantProvider() {
  return createOAuthProvider({
    key: 'home_assistant',
    label: 'Home Assistant',
    description:
      'Official Home Assistant account connections for entity state reads, service control, and automation support.',
    icon: 'home_assistant',
    apps: HOME_ASSISTANT_APPS,
    toolDefinitions: homeAssistantToolDefinitions,
    connectPrompt:
      'Connect your Home Assistant account to let the agent read entity states and control services with structured tools.',
    getEnvStatus() {
      return resolveHomeAssistantEnvStatus();
    },
    async beginOAuth({ state, codeVerifier, app }) {
      const config = resolveHomeAssistantOAuthConfig();
      const codeChallenge = String(codeChallengeForVerifier(codeVerifier));
      return {
        url: appendQuery(homeAssistantUrl(config.baseUrl, '/auth/authorize'), {
          response_type: 'code',
          client_id: config.clientId,
          redirect_uri: config.redirectUri,
          state,
          scope: app.scopes.join(' '),
          code_challenge: codeChallenge,
          code_challenge_method: 'S256',
        }),
        appId: app.id,
      };
    },
    async finishOAuth({ code, codeVerifier, app }) {
      const config = resolveHomeAssistantOAuthConfig();
      const token = await fetchJson(
        homeAssistantUrl(config.baseUrl, '/auth/token'),
        {
          method: 'POST',
          form: {
            grant_type: 'authorization_code',
            client_id: config.clientId,
            client_secret: config.clientSecret,
            code,
            code_verifier: codeVerifier,
            redirect_uri: config.redirectUri,
          },
        },
        { serviceName: 'Home Assistant' },
      );

      const accessToken = String(token?.access_token || '').trim();
      if (!accessToken) {
        throw new Error('Home Assistant OAuth did not return an access token.');
      }

      const refreshToken = String(token?.refresh_token || '').trim();
      if (!refreshToken) {
        throw new Error('Home Assistant OAuth did not return a refresh token.');
      }

      const currentUser = await fetchCurrentUser(accessToken);
      const normalizedUser = normalizeCurrentUser(currentUser);
      const accountEmail = stableAccountEmailLikeIdentifier(normalizedUser, config);

      return {
        appId: app.id,
        accountEmail,
        credentials: {
          access_token: accessToken,
          refresh_token: refreshToken,
          token_type: token?.token_type || 'Bearer',
          expires_in: token?.expires_in || null,
          scope: token?.scope || app.scopes.join(' '),
        },
        scopes: Array.isArray(token?.scope)
          ? token.scope
          : String(token?.scope || app.scopes.join(' '))
              .split(/\s+/)
              .map((scope) => scope.trim())
              .filter(Boolean),
        metadata: {
          homeAssistantUrl: config.baseUrl,
          userId: normalizedUser.id,
          name: normalizedUser.name,
          username: normalizedUser.username,
          email: normalizedUser.email,
          isOwner: normalizedUser.isOwner,
        },
      };
    },
    executeTool: executeHomeAssistantTool,
  });
}

function base64UrlSha256(value) {
  return crypto
    .createHash('sha256')
    .update(String(value || ''))
    .digest('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');
}

function codeChallengeForVerifier(codeVerifier) {
  return base64UrlSha256(String(codeVerifier || ''));
}

module.exports = {
  createHomeAssistantProvider,
};
