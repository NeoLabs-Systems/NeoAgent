'use strict';

const { fetchJson } = require('../oauth_provider');

function text(value) {
  return String(value || '').trim();
}

function isPrivateHost(host) {
  const value = String(host || '').toLowerCase();
  return value === 'localhost' || value === '::1' || value.startsWith('127.') || value.startsWith('10.') ||
    value.startsWith('192.168.') || /^172\.(1[6-9]|2\d|3[01])\./.test(value);
}

function normalizeBaseUrl(value) {
  const raw = text(value);
  if (!raw) throw new Error('NeoRecall backend URL is required.');
  const candidate = raw.includes('://') ? raw : `${isPrivateHost(raw.split('/')[0]) ? 'http' : 'https'}://${raw}`;
  let url;
  try {
    url = new URL(candidate);
  } catch {
    throw new Error('NeoRecall backend URL must be a valid HTTP or HTTPS URL.');
  }
  if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password || url.hash) {
    throw new Error('NeoRecall backend URL must be HTTP(S), without credentials or a fragment.');
  }
  url.pathname = url.pathname.replace(/\/+$/, '');
  return url.toString().replace(/\/+$/, '');
}

async function bootstrap(baseUrl, callbackUrl, options = {}) {
  return fetchJson(`${baseUrl}/api/oauth/companion/neoagent/bootstrap`, {
    method: 'POST', json: { redirectUri: callbackUrl, appName: 'NeoAgent' },
    signal: options.signal,
  }, { serviceName: 'NeoRecall companion bootstrap' });
}

async function token(baseUrl, form, options = {}) {
  return fetchJson(
    `${baseUrl}/oauth/token`,
    { method: 'POST', form, signal: options.signal },
    { serviceName: 'NeoRecall OAuth token' },
  );
}

async function revoke(credentials, options = {}) {
  const saved = credentials && typeof credentials === 'object' ? credentials : {};
  const baseUrl = normalizeBaseUrl(saved.baseUrl);
  const clientId = text(saved.client_id);
  if (!clientId) return;
  const tokens = [saved.refresh_token, saved.access_token].map(text).filter(Boolean);
  const outcomes = await Promise.allSettled(tokens.map((value) => fetchJson(`${baseUrl}/oauth/revoke`, {
    method: 'POST', form: { client_id: clientId, token: value },
    signal: options.signal,
  }, { serviceName: 'NeoRecall OAuth revocation' })));
  const failed = outcomes.find((outcome) => outcome.status === 'rejected');
  if (failed) throw failed.reason;
}

async function authenticated(credentials, options = {}) {
  const saved = credentials && typeof credentials === 'object' ? credentials : {};
  const baseUrl = normalizeBaseUrl(saved.baseUrl);
  if (text(saved.access_token) && Number(saved.expires_at_ms) > Date.now() + 60_000) {
    return { baseUrl, accessToken: saved.access_token, credentials: saved };
  }
  if (!text(saved.refresh_token) || !text(saved.client_id)) {
    throw new Error('NeoRecall refresh token is missing. Reconnect the NeoRecall account.');
  }
  const refreshed = await token(baseUrl, {
    grant_type: 'refresh_token', client_id: saved.client_id, refresh_token: saved.refresh_token,
  }, options);
  const next = {
    ...saved,
    access_token: text(refreshed.access_token),
    refresh_token: text(refreshed.refresh_token) || saved.refresh_token,
    expires_at_ms: Date.now() + Math.max(1, Number(refreshed.expires_in) || 3600) * 1000,
    scope: text(refreshed.scope) || saved.scope,
  };
  return { baseUrl, accessToken: next.access_token, credentials: next };
}

function required(value, name) {
  const normalized = text(value);
  if (!normalized) throw new Error(`${name} is required.`);
  return normalized;
}

function filteredQuery(args, names) {
  return names.reduce((query, name) => {
    if (args[name] !== undefined && args[name] !== null && args[name] !== '') query[name] = args[name];
    return query;
  }, {});
}

function appendApiQuery(path, query) {
  const params = new URLSearchParams();
  for (const [key, value] of Object.entries(query || {})) {
    if (value === undefined || value === null || value === '') continue;
    params.set(key, String(value));
  }
  const encoded = params.toString();
  return encoded ? `${path}?${encoded}` : path;
}

async function request(credentials, apiPath, options = {}) {
  const authorization = await authenticated(credentials, options);
  const response = await fetchJson(`${authorization.baseUrl}${apiPath}`, {
    headers: { Authorization: `Bearer ${authorization.accessToken}` },
    signal: options.signal,
  }, { serviceName: 'NeoRecall API' });
  return { result: response, credentials: authorization.credentials };
}

async function executeTool(toolName, args, credentials, options = {}) {
  let apiPath;
  switch (toolName) {
    case 'neorecall_search': {
      const kinds = Array.isArray(args.kinds) ? args.kinds.map(text).filter(Boolean).join(',') : undefined;
      apiPath = appendApiQuery('/api/v1/search', { q: required(args.query, 'query'), kinds, limit: args.limit });
      break;
    }
    case 'neorecall_list_memories':
      apiPath = appendApiQuery('/api/v1/memories', filteredQuery(args, ['type', 'topic', 'from', 'to', 'pinned', 'archived', 'limit']));
      break;
    case 'neorecall_get_memory':
      apiPath = `/api/v1/memories/${encodeURIComponent(required(args.memory_id, 'memory_id'))}`;
      break;
    case 'neorecall_list_mini_memories':
      apiPath = appendApiQuery('/api/v1/mini-memories', filteredQuery(args, ['kind', 'status', 'limit']));
      break;
    case 'neorecall_list_daily_summaries':
      apiPath = appendApiQuery('/api/v1/daily-summaries', filteredQuery(args, ['from', 'to', 'limit']));
      break;
    case 'neorecall_list_conversations':
      apiPath = appendApiQuery('/api/v1/conversations', filteredQuery(args, ['state', 'from', 'to', 'limit']));
      break;
    case 'neorecall_get_conversation':
      apiPath = `/api/v1/conversations/${encodeURIComponent(required(args.conversation_id, 'conversation_id'))}`;
      break;
    default:
      throw new Error(`Unsupported NeoRecall tool: ${toolName}`);
  }
  return request(credentials, apiPath, options);
}

module.exports = { bootstrap, executeTool, normalizeBaseUrl, revoke, text, token };
