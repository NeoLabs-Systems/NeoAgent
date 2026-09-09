'use strict';

const { fetchJson } = require('../oauth_provider');
const { fetchResponseBuffer } = require('../../network/http');
const { USER_AGENT } = require('./constants');
const {
  assertPathPrefix,
  normalizeBaseUrl,
  requireText,
  resolveInstanceUrl,
  text,
} = require('./network');

function authorizationHeader(username, appPassword) {
  const token = Buffer.from(
    `${requireText(username, 'username')}:${requireText(appPassword, 'app password')}`,
    'utf8',
  ).toString('base64');
  return `Basic ${token}`;
}

function parseCredentials(raw) {
  const saved = raw && typeof raw === 'object' ? raw : {};
  return {
    baseUrl: normalizeBaseUrl(saved.baseUrl),
    username: requireText(saved.username, 'Nextcloud username'),
    appPassword: requireText(saved.appPassword, 'Nextcloud app password'),
  };
}

function unwrapOcs(data) {
  const meta = data?.ocs?.meta;
  const status = Number(meta?.statuscode);
  if (meta && Number.isFinite(status) && status >= 400) {
    throw new Error(text(meta.message) || `Nextcloud OCS request failed (${status}).`);
  }
  return data?.ocs && Object.prototype.hasOwnProperty.call(data.ocs, 'data')
    ? data.ocs.data
    : data;
}

async function instanceRequest(baseUrl, path, options = {}) {
  const url = resolveInstanceUrl(baseUrl, path);
  if (options.prefix) {
    assertPathPrefix(url, options.prefix, options.label || 'Nextcloud path');
  }
  if (options.query && typeof options.query === 'object') {
    for (const [key, value] of Object.entries(options.query)) {
      if (value === undefined || value === null || value === '') continue;
      url.searchParams.set(key, String(value));
    }
  }

  const headers = {
    'User-Agent': USER_AGENT,
    ...(options.headers || {}),
  };
  const { response, body } = await fetchResponseBuffer(url.toString(), {
    method: String(options.method || 'GET').toUpperCase(),
    headers,
    body: options.body,
    redirect: 'manual',
    signal: options.signal,
    timeoutMs: options.timeoutMs,
    maxResponseBytes: options.maxResponseBytes,
    serviceName: options.serviceName || 'Nextcloud',
    timeoutCode: 'INTEGRATION_HTTP_TIMEOUT',
    tooLargeCode: 'INTEGRATION_RESPONSE_TOO_LARGE',
  });
  if (response.status >= 300 && response.status < 400) {
    throw new Error('Nextcloud redirected the request; redirects are not followed.');
  }
  return { response, buffer: body, text: body.toString('utf8'), url: url.toString() };
}

async function authenticatedRequest(credentials, path, options = {}) {
  const auth = parseCredentials(credentials);
  return instanceRequest(auth.baseUrl, path, {
    ...options,
    headers: {
      Authorization: authorizationHeader(auth.username, auth.appPassword),
      ...(options.headers || {}),
    },
  });
}

async function fetchStatus(baseUrl, options = {}) {
  const data = await fetchJson(
    `${normalizeBaseUrl(baseUrl)}/status.php`,
    {
      method: 'GET',
      headers: { 'User-Agent': USER_AGENT, Accept: 'application/json' },
      signal: options.signal,
    },
    { serviceName: 'Nextcloud status' },
  );
  if (!text(data?.version) || data?.installed === false) {
    throw new Error('The URL did not identify itself as a Nextcloud server.');
  }
  return data;
}

async function fetchUser(credentials, options = {}) {
  const { response, text: body } = await authenticatedRequest(credentials, '/ocs/v2.php/cloud/user', {
    method: 'GET',
    headers: { Accept: 'application/json', 'OCS-APIRequest': 'true' },
    prefix: '/ocs/v2.php/',
    label: 'Nextcloud OCS path',
    signal: options.signal,
    serviceName: 'Nextcloud user',
  });
  if (!response.ok) {
    throw new Error(`Nextcloud rejected the account credentials (${response.status}).`);
  }
  let data = null;
  try {
    data = body ? JSON.parse(body) : null;
  } catch {
    data = null;
  }
  const user = unwrapOcs(data) || {};
  return {
    id: text(user.id),
    displayName: text(user['display-name'] || user.displayname || user.displayName),
    email: text(user.email),
  };
}

async function ocsRequest(credentials, path, options = {}) {
  const method = String(options.method || 'GET').toUpperCase();
  if (!['GET', 'POST', 'PUT', 'PATCH', 'DELETE'].includes(method)) {
    throw new Error('Nextcloud OCS method must be GET, POST, PUT, PATCH, or DELETE.');
  }
  const headers = {
    Accept: 'application/json',
    'OCS-APIRequest': 'true',
    ...(options.headers || {}),
  };
  let body = options.body;
  if (options.json !== undefined) {
    headers['Content-Type'] = 'application/json';
    body = JSON.stringify(options.json);
  } else if (options.form) {
    headers['Content-Type'] = 'application/x-www-form-urlencoded';
    body = new URLSearchParams(
      Object.entries(options.form).reduce((acc, [key, value]) => {
        if (value === undefined || value === null) return acc;
        acc[key] = String(value);
        return acc;
      }, {}),
    ).toString();
  }
  const { response, text: bodyText } = await authenticatedRequest(credentials, path, {
    method,
    headers,
    body,
    query: options.query,
    prefix: '/ocs/v2.php/',
    label: 'Nextcloud OCS path',
    signal: options.signal,
    serviceName: options.serviceName || 'Nextcloud OCS',
  });
  let data = null;
  try {
    data = bodyText ? JSON.parse(bodyText) : null;
  } catch {
    data = bodyText;
  }
  if (!response.ok) {
    const message = data && typeof data === 'object'
      ? data.ocs?.meta?.message || data.message || data.error
      : bodyText;
    throw new Error(`Nextcloud OCS request failed: ${text(message) || `${response.status} ${response.statusText}`}`);
  }
  return unwrapOcs(data);
}

async function davRequest(credentials, path, options = {}) {
  const method = String(options.method || 'PROPFIND').toUpperCase();
  const { response, text: bodyText, buffer, url } = await authenticatedRequest(credentials, path, {
    method,
    headers: {
      Accept: options.accept || 'application/xml, text/xml, */*',
      ...(options.headers || {}),
    },
    body: options.body,
    prefix: '/remote.php/dav/',
    label: 'Nextcloud WebDAV path',
    signal: options.signal,
    maxResponseBytes: options.maxResponseBytes,
    serviceName: options.serviceName || 'Nextcloud WebDAV',
  });
  if (options.okStatuses && options.okStatuses.includes(response.status)) {
    return { response, text: bodyText, buffer, url };
  }
  if (!response.ok) {
    throw new Error(`Nextcloud WebDAV request failed (${response.status}): ${text(bodyText).slice(0, 300)}`);
  }
  return { response, text: bodyText, buffer, url };
}

module.exports = {
  authenticatedRequest,
  davRequest,
  fetchStatus,
  fetchUser,
  instanceRequest,
  ocsRequest,
  parseCredentials,
};
