'use strict';

const { fetchJson } = require('../oauth_provider');
const { isPrivateHost } = require('../../../utils/cloud-security');
const { trimText: text } = require('../../../utils/text');

function normalizeBaseUrl(value) {
  const raw = text(value);
  if (!raw) throw new Error('NeoCloud server URL is required.');
  const candidate = raw.includes('://') ? raw : `${isPrivateHost(raw.split('/')[0]) ? 'http' : 'https'}://${raw}`;
  let url;
  try {
    url = new URL(candidate);
  } catch {
    throw new Error('NeoCloud server URL must be a valid HTTP or HTTPS URL.');
  }
  if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password || url.hash) {
    throw new Error('NeoCloud server URL must be HTTP(S), without credentials or a fragment.');
  }
  url.pathname = url.pathname.replace(/\/+$/, '');
  return url.toString().replace(/\/+$/, '');
}

function parseScopes(value) {
  return text(value).split(/\s+/).filter(Boolean);
}

async function bootstrap(baseUrl, callbackUrl, options = {}) {
  return fetchJson(`${baseUrl}/api/oauth/companion/neoagent/bootstrap`, {
    method: 'POST', json: { redirectUri: callbackUrl, appName: 'NeoAgent' },
    signal: options.signal,
  }, { serviceName: 'NeoCloud companion bootstrap' });
}

async function token(baseUrl, form, options = {}) {
  return fetchJson(
    `${baseUrl}/oauth/token`,
    { method: 'POST', form, signal: options.signal },
    { serviceName: 'NeoCloud OAuth token' },
  );
}

async function userinfo(baseUrl, accessToken, options = {}) {
  return fetchJson(`${baseUrl}/oauth/userinfo`, {
    headers: { Authorization: `Bearer ${accessToken}` },
    signal: options.signal,
  }, { serviceName: 'NeoCloud userinfo' });
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
  }, { serviceName: 'NeoCloud OAuth revocation' })));
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
    throw new Error('NeoCloud refresh token is missing. Reconnect the NeoCloud account.');
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

function appendApiQuery(path, query) {
  const params = new URLSearchParams();
  for (const [key, value] of Object.entries(query || {})) {
    if (value === undefined || value === null || value === '') continue;
    params.set(key, String(value));
  }
  const encoded = params.toString();
  return encoded ? `${path}?${encoded}` : path;
}

// Drops undefined/null/empty-string fields so NeoCloud applies its defaults.
function compact(body) {
  return Object.fromEntries(Object.entries(body)
    .filter(([, value]) => value !== undefined && value !== null && value !== ''));
}

function contentBody(args) {
  if (args.content === undefined && args.content_base64 === undefined) {
    throw new Error('content or content_base64 is required.');
  }
  return args.content_base64 !== undefined
    ? { contentBase64: String(args.content_base64) }
    : { content: String(args.content) };
}

function id(value, name) {
  return encodeURIComponent(required(value, name));
}

function signingRequestBody(args) {
  const hasDocument = args.document && typeof args.document === 'object';
  const fileId = text(args.file_id);
  if (Boolean(hasDocument) === Boolean(fileId)) {
    throw new Error('Pass exactly one of document or file_id.');
  }
  const signers = (Array.isArray(args.signers) ? args.signers : [])
    .map((signer) => compact({ name: text(signer?.name), email: text(signer?.email) }))
    .filter((signer) => signer.name);
  if (signers.length === 0) throw new Error('At least one signer with a name is required.');
  return compact({
    fileId: fileId || undefined,
    document: hasDocument
      ? {
        path: required(args.document.path, 'document.path'),
        title: required(args.document.title, 'document.title'),
        markdown: required(args.document.markdown, 'document.markdown'),
      }
      : undefined,
    title: text(args.title),
    signers,
    message: text(args.message),
    sendEmail: args.send_email === true,
    expiresInDays: args.expires_in_days,
    signingOrder: text(args.signing_order),
  });
}

// Maps a tool call to { method, path, json } on NeoCloud's /api/v1.
function toolRequest(toolName, args) {
  switch (toolName) {
    case 'neocloud_list_files':
      return { method: 'GET', path: appendApiQuery('/api/v1/files', { path: text(args.path) || '/' }) };
    case 'neocloud_search_files':
      return { method: 'GET', path: appendApiQuery('/api/v1/files/search', { q: required(args.query, 'query'), limit: args.limit }) };
    case 'neocloud_read_file':
      return { method: 'GET', path: `/api/v1/files/${id(args.file_id, 'file_id')}/content` };
    case 'neocloud_create_file':
      return {
        method: 'POST', path: '/api/v1/files',
        json: { path: required(args.path, 'path'), ...contentBody(args), overwrite: args.overwrite === true },
      };
    case 'neocloud_update_file':
      return {
        method: 'PUT', path: `/api/v1/files/${id(args.file_id, 'file_id')}/content`,
        json: compact({ ...contentBody(args), baseRevision: text(args.base_revision) }),
      };
    case 'neocloud_create_folder':
      return { method: 'POST', path: '/api/v1/folders', json: { path: required(args.path, 'path') } };
    case 'neocloud_move_file': {
      const json = compact({ name: text(args.name), parentPath: text(args.parent_path) });
      if (!json.name && !json.parentPath) throw new Error('name or parent_path is required.');
      return { method: 'PATCH', path: `/api/v1/files/${id(args.file_id, 'file_id')}`, json };
    }
    case 'neocloud_delete_file':
      return { method: 'DELETE', path: `/api/v1/files/${id(args.file_id, 'file_id')}` };
    case 'neocloud_create_pdf':
      return {
        method: 'POST', path: '/api/v1/documents/pdf',
        json: compact({
          path: required(args.path, 'path'), title: text(args.title),
          markdown: required(args.markdown, 'markdown'), overwrite: args.overwrite === true,
        }),
      };
    case 'neocloud_request_signatures':
      return { method: 'POST', path: '/api/v1/signing/requests', json: signingRequestBody(args) };
    case 'neocloud_list_signature_requests':
      return { method: 'GET', path: appendApiQuery('/api/v1/signing/requests', { status: text(args.status), limit: args.limit }) };
    case 'neocloud_get_signature_request':
      return { method: 'GET', path: `/api/v1/signing/requests/${id(args.request_id, 'request_id')}` };
    case 'neocloud_remind_signers':
      return { method: 'POST', path: `/api/v1/signing/requests/${id(args.request_id, 'request_id')}/remind` };
    case 'neocloud_new_signing_link':
      return {
        method: 'POST',
        path: `/api/v1/signing/requests/${id(args.request_id, 'request_id')}/signers/${id(args.signer_id, 'signer_id')}/link`,
      };
    case 'neocloud_cancel_signature_request':
      return { method: 'POST', path: `/api/v1/signing/requests/${id(args.request_id, 'request_id')}/cancel` };
    default:
      throw new Error(`Unsupported NeoCloud tool: ${toolName}`);
  }
}

async function executeTool(toolName, args, credentials, options = {}) {
  const call = toolRequest(toolName, args || {});
  const authorization = await authenticated(credentials, options);
  let response;
  try {
    response = await fetchJson(`${authorization.baseUrl}${call.path}`, {
      method: call.method,
      headers: { Authorization: `Bearer ${authorization.accessToken}` },
      json: call.json,
      signal: options.signal,
    }, { serviceName: 'NeoCloud API' });
  } catch (error) {
    // NeoCloud errors carry a stable code (ALREADY_EXISTS, CONFLICT, ...) the
    // model can act on, so keep it in the message.
    const code = text(error?.data?.code);
    if (code && !String(error.message).includes(code)) error.message = `${error.message} (${code})`;
    // NeoCloud rotates refresh tokens, so a refresh that preceded the failed
    // call must still be saved or the connection is lost.
    if (authorization.credentials === credentials || error?.name === 'AbortError') throw error;
    return {
      result: compact({ error: error.message, code, status: error.status }),
      credentials: authorization.credentials,
    };
  }
  return { result: response ?? { ok: true }, credentials: authorization.credentials };
}

module.exports = {
  authenticated,
  bootstrap,
  executeTool,
  normalizeBaseUrl,
  parseScopes,
  revoke,
  text,
  token,
  userinfo,
};
