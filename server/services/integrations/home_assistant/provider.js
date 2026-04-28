'use strict';

const crypto = require('crypto');
const net = require('net');
const ipaddr = require('ipaddr.js');
const { resolveAgentId } = require('../../agents/manager');
const {
  describeEnvStatus,
  resolveHomeAssistantOAuthConfig,
} = require('../env');
const {
  deleteProviderConfig,
  getProviderConfig,
  setProviderConfig,
} = require('../provider_config_store');
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

function trimText(value) {
  return String(value || '').trim();
}

function isTruthyEnv(name) {
  const value = String(process.env[name] || '').trim().toLowerCase();
  return value === '1' || value === 'true' || value === 'yes' || value === 'on';
}

function isLikelyLocalHostname(hostname) {
  const host = String(hostname || '').trim().toLowerCase();
  if (!host) return false;
  if (host === 'localhost' || host === 'host.docker.internal') return true;
  if (host.endsWith('.localhost')) return true;
  if (host.endsWith('.local') || host.endsWith('.lan') || host.endsWith('.internal')) {
    return true;
  }
  return false;
}

function isPrivateIpv4(hostname) {
  const parts = String(hostname || '').split('.').map((part) => Number(part));
  if (parts.length !== 4 || parts.some((part) => !Number.isInteger(part) || part < 0 || part > 255)) {
    return false;
  }
  const [a, b] = parts;
  if (a === 10) return true;
  if (a === 127) return true;
  if (a === 169 && b === 254) return true;
  if (a === 172 && b >= 16 && b <= 31) return true;
  if (a === 192 && b === 168) return true;
  if (a === 100 && b >= 64 && b <= 127) return true;
  if (a === 0) return true;
  return false;
}

function isPrivateIpv6(hostname) {
  const host = String(hostname || '').trim().replace(/^\[|\]$/g, '');
  if (!host) return false;
  try {
    const parsed = ipaddr.parse(host);
    if (parsed.kind() !== 'ipv6') return false;

    // Normalize IPv4-mapped IPv6 literals and enforce the same local/private rules.
    if (parsed.isIPv4MappedAddress()) {
      return isPrivateIpv4(parsed.toIPv4Address().toString());
    }

    const range = parsed.range();
    return range === 'loopback' || range === 'uniqueLocal' || range === 'linkLocal' || range === 'unspecified';
  } catch {
    return false;
  }
}

function isPrivateOrLocalIp(hostname) {
  const host = String(hostname || '').trim().replace(/^\[|\]$/g, '');
  const kind = net.isIP(host);
  if (kind === 4) return isPrivateIpv4(host);
  if (kind === 6) return isPrivateIpv6(host);
  return false;
}

function validateHomeAssistantBaseUrlSafety(parsedUrl) {
  const allowPrivate = isTruthyEnv('HOME_ASSISTANT_ALLOW_PRIVATE_BASE_URL');
  const host = String(parsedUrl.hostname || '').trim();
  const localHostname = isLikelyLocalHostname(host);
  const localIp = isPrivateOrLocalIp(host);
  const isLocalTarget = localHostname || localIp;

  if (isLocalTarget && !allowPrivate) {
    throw new Error(
      'Home Assistant base URL cannot target localhost/private network addresses unless HOME_ASSISTANT_ALLOW_PRIVATE_BASE_URL=1 is set on the server.',
    );
  }

  if (parsedUrl.protocol === 'http:' && !isLocalTarget) {
    throw new Error('Home Assistant base URL must use HTTPS for non-local hosts.');
  }
}

function normalizeBaseUrl(value) {
  const text = trimText(value);
  if (!text) return '';
  return text.replace(/\/$/, '');
}

function normalizeOptionalAbsoluteUrl(value, label) {
  const text = trimText(value);
  if (!text) return '';
  try {
    const parsed = new URL(text);
    if (!/^https?:$/.test(parsed.protocol)) {
      throw new Error(`${label} must use http or https.`);
    }
    return parsed.toString().replace(/\/$/, '');
  } catch {
    throw new Error(`${label} must be a valid absolute URL.`);
  }
}

function normalizeHomeAssistantBaseUrl(value) {
  const text = trimText(value);
  if (!text) return '';
  let parsed;
  try {
    parsed = new URL(text);
  } catch {
    throw new Error('Home Assistant base URL must be a valid absolute URL.');
  }
  if (!/^https?:$/.test(parsed.protocol)) {
    throw new Error('Home Assistant base URL must use http or https.');
  }
  validateHomeAssistantBaseUrlSafety(parsed);
  return parsed.toString().replace(/\/$/, '');
}

function normalizeUserHomeAssistantConfig(rawConfig) {
  const source = rawConfig && typeof rawConfig === 'object' ? rawConfig : {};
  return {
    baseUrl: normalizeBaseUrl(source.baseUrl),
    clientId: trimText(source.clientId),
    clientSecret: trimText(source.clientSecret),
    redirectUri: trimText(source.redirectUri),
  };
}

function resolveUserHomeAssistantConfig(userId, agentId = null) {
  const userConfig = normalizeUserHomeAssistantConfig(
    Number.isInteger(Number(userId)) && Number(userId) > 0
      ? getProviderConfig(Number(userId), 'home_assistant', agentId)
      : {},
  );
  const envConfig = resolveHomeAssistantOAuthConfig();
  return {
    baseUrl: userConfig.baseUrl || envConfig.baseUrl,
    clientId: userConfig.clientId || envConfig.clientId,
    clientSecret: userConfig.clientSecret || envConfig.clientSecret,
    redirectUri: userConfig.redirectUri || envConfig.redirectUri,
  };
}

function validateResolvedConfig(config) {
  const missing = [];
  if (!trimText(config.baseUrl)) missing.push('baseUrl');
  if (!trimText(config.clientId)) missing.push('clientId');
  if (!trimText(config.clientSecret)) missing.push('clientSecret');
  return {
    configured: missing.length === 0,
    missing,
  };
}

function resolveHomeAssistantConfigForUser(userId, agentId = null) {
  const merged = resolveUserHomeAssistantConfig(userId, agentId);
  const validatedBaseUrl = merged.baseUrl
    ? normalizeHomeAssistantBaseUrl(merged.baseUrl)
    : '';
  const validatedRedirectUri = merged.redirectUri
    ? normalizeOptionalAbsoluteUrl(
        merged.redirectUri,
        'Home Assistant OAuth redirect URI',
      )
    : '';
  const result = {
    baseUrl: validatedBaseUrl,
    clientId: trimText(merged.clientId),
    clientSecret: trimText(merged.clientSecret),
    redirectUri: validatedRedirectUri,
  };
  const status = validateResolvedConfig(result);
  return {
    ...result,
    configured: status.configured,
    missing: status.missing,
  };
}

function sanitizeHomeAssistantUserConfigForClient(rawConfig) {
  const config = normalizeUserHomeAssistantConfig(rawConfig);
  return {
    baseUrl: config.baseUrl,
    clientId: config.clientId,
    redirectUri: config.redirectUri,
    hasClientSecret: Boolean(config.clientSecret),
  };
}

function parseHomeAssistantConfigInput(input, existingConfig = {}) {
  const source = input && typeof input === 'object' ? input : {};
  const baseUrl = normalizeHomeAssistantBaseUrl(source.baseUrl);
  const clientId = trimText(source.clientId);
  const clientSecret =
    trimText(source.clientSecret) || trimText(existingConfig.clientSecret);
  const redirectUri = source.redirectUri
    ? normalizeOptionalAbsoluteUrl(
        source.redirectUri,
        'Home Assistant OAuth redirect URI',
      )
    : '';

  if (!baseUrl) {
    throw new Error('Home Assistant base URL is required.');
  }
  if (!clientId) {
    throw new Error('Home Assistant OAuth client ID is required.');
  }
  if (!clientSecret) {
    throw new Error('Home Assistant OAuth client secret is required.');
  }

  return {
    baseUrl,
    clientId,
    clientSecret,
    redirectUri,
  };
}

function saveHomeAssistantUserConfig(userId, agentId = null, input) {
  const normalizedUserId = Number(userId);
  if (!Number.isInteger(normalizedUserId) || normalizedUserId <= 0) {
    throw new Error('A valid user is required to save Home Assistant configuration.');
  }
  const scopedAgentId = resolveAgentId(normalizedUserId, agentId);
  const existingConfig = normalizeUserHomeAssistantConfig(
    getProviderConfig(normalizedUserId, 'home_assistant', scopedAgentId),
  );
  const config = parseHomeAssistantConfigInput(input, existingConfig);
  setProviderConfig(normalizedUserId, 'home_assistant', config, scopedAgentId);
  return sanitizeHomeAssistantUserConfigForClient(config);
}

function getHomeAssistantUserConfig(userId, agentId = null) {
  const normalizedUserId = Number(userId);
  if (!Number.isInteger(normalizedUserId) || normalizedUserId <= 0) {
    return sanitizeHomeAssistantUserConfigForClient({});
  }
  return sanitizeHomeAssistantUserConfigForClient(
    getProviderConfig(
      normalizedUserId,
      'home_assistant',
      resolveAgentId(normalizedUserId, agentId),
    ),
  );
}

function requireText(value, label) {
  const text = String(value || '').trim();
  if (!text) throw new Error(`${label} is required.`);
  return text;
}

function homeAssistantUrl(baseUrl, path, query) {
  const normalizedBase = String(baseUrl || '').trim().replace(/\/$/, '');
  if (!normalizedBase) {
    throw new Error('Home Assistant base URL is required.');
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
  const config = resolveHomeAssistantConfigForUser(
    options.userId,
    options.agentId,
  );
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

async function executeHomeAssistantTool(toolName, args, { connection, credentials }) {
  switch (toolName) {
    case 'home_assistant_get_config':
      return {
        result: await homeAssistantRequest(credentials, {
          path: '/api/config',
          userId: connection?.user_id,
          agentId: connection?.agent_id,
        }),
      };
    case 'home_assistant_list_states': {
      const states = await homeAssistantRequest(credentials, {
        path: '/api/states',
        userId: connection?.user_id,
        agentId: connection?.agent_id,
      });
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
          userId: connection?.user_id,
          agentId: connection?.agent_id,
        }),
      };
    case 'home_assistant_call_service':
      return {
        result: await homeAssistantRequest(credentials, {
          method: 'POST',
          path: `/api/services/${encodeURIComponent(requireText(args.domain, 'domain'))}/${encodeURIComponent(requireText(args.service, 'service'))}`,
          body: args.service_data || {},
          userId: connection?.user_id,
          agentId: connection?.agent_id,
        }),
      };
    case 'home_assistant_api_request':
      return {
        result: await homeAssistantRequest(credentials, {
          method: args.method,
          path: requireText(args.path, 'path'),
          query: args.query,
          body: args.body,
          userId: connection?.user_id,
          agentId: connection?.agent_id,
        }),
      };
    default:
      return null;
  }
}

function resolveHomeAssistantEnvStatus(userId, agentId = null) {
  try {
    const config = resolveHomeAssistantConfigForUser(userId, agentId);
    return {
      configured: config.configured,
      missing: config.missing,
      summary: config.configured
        ? 'Home Assistant is ready for account connections.'
        : 'Complete your personal Home Assistant setup to connect an account.',
      setupMode: 'user',
    };
  } catch (error) {
    return {
      configured: false,
      missing: ['baseUrl'],
      summary: `Home Assistant setup is invalid: ${error?.message || 'unknown error'}`,
      setupMode: 'user',
    };
  }
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

async function fetchCurrentUser(token, userId, agentId = null) {
  const config = resolveHomeAssistantConfigForUser(userId, agentId);
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
    getEnvStatus(context = {}) {
      return resolveHomeAssistantEnvStatus(context.userId, context.agentId);
    },
    async beginOAuth({ state, codeVerifier, app, userId, agentId }) {
      const config = resolveHomeAssistantConfigForUser(userId, agentId);
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
    async finishOAuth({ code, codeVerifier, app, userId, agentId }) {
      const config = resolveHomeAssistantConfigForUser(userId, agentId);
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

      const currentUser = await fetchCurrentUser(accessToken, userId, agentId);
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
    getUserConfig({ userId, agentId }) {
      return getHomeAssistantUserConfig(userId, agentId);
    },
    saveUserConfig({ userId, agentId, config }) {
      return saveHomeAssistantUserConfig(userId, agentId, config);
    },
    clearUserConfig({ userId, agentId }) {
      const normalizedUserId = Number(userId);
      if (!Number.isInteger(normalizedUserId) || normalizedUserId <= 0) {
        throw new Error('A valid user is required to clear Home Assistant configuration.');
      }
      deleteProviderConfig(
        normalizedUserId,
        'home_assistant',
        resolveAgentId(normalizedUserId, agentId),
      );
      return { cleared: true };
    },
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
  getHomeAssistantUserConfig,
  saveHomeAssistantUserConfig,
  createHomeAssistantProvider,
};
