'use strict';

const dns = require('dns').promises;
const net = require('net');
const { isPrivateHost } = require('../../../utils/cloud-security');
const { requireText, trimText } = require('../../../utils/text');
const {
  fetchResponseText,
  waitForAbortableResult,
} = require('../http');

const ALLOWED_PORTS = new Set(['', '443', '8123']);

function normalizeHomeAssistantBaseUrl(value) {
  const raw = requireText(value, 'Home Assistant URL');
  let parsed;
  try {
    parsed = new URL(raw);
  } catch {
    throw new Error('Home Assistant URL must be a valid absolute HTTPS URL.');
  }

  if (parsed.protocol !== 'https:') {
    throw new Error('Home Assistant URL must use HTTPS.');
  }
  if (parsed.username || parsed.password) {
    throw new Error('Home Assistant URL must not include credentials.');
  }
  if (!ALLOWED_PORTS.has(parsed.port)) {
    throw new Error('Home Assistant URL must use port 443 or 8123.');
  }
  parsed.hash = '';
  parsed.search = '';
  parsed.pathname = parsed.pathname.replace(/\/+$/, '');
  return parsed.toString().replace(/\/$/, '');
}

function isBlockedIpAddress(address) {
  const normalized = String(address || '').trim().replace(/^\[|\]$/g, '');
  if (!net.isIP(normalized)) return true;
  return isPrivateHost(normalized);
}

async function assertPublicHomeAssistantEndpoint(baseUrl, options = {}) {
  const url = new URL(normalizeHomeAssistantBaseUrl(baseUrl));
  const hostname = String(url.hostname || '').replace(/^\[|\]$/g, '');
  if (net.isIP(hostname) && isBlockedIpAddress(hostname)) {
    throw new Error('Home Assistant URL must not point to a private, loopback, or link-local address.');
  }

  let addresses;
  try {
    addresses = await waitForAbortableResult(
      dns.lookup(hostname, { all: true, verbatim: true }),
      options.signal,
    );
  } catch (error) {
    throw new Error(`Could not resolve Home Assistant host: ${error?.message || 'DNS lookup failed'}`);
  }

  if (!Array.isArray(addresses) || addresses.length === 0) {
    throw new Error('Could not resolve Home Assistant host.');
  }
  if (addresses.some((entry) => isBlockedIpAddress(entry.address))) {
    throw new Error('Home Assistant URL resolves to a private, loopback, or reserved address.');
  }
}

function buildHomeAssistantUrl(baseUrl, path, query = {}) {
  const base = new URL(normalizeHomeAssistantBaseUrl(baseUrl));
  const url = new URL(requireText(path, 'path'), base);
  if (url.origin !== base.origin || !url.pathname.startsWith('/api/')) {
    throw new Error('Home Assistant API path must stay on the connected origin and start with /api/.');
  }
  for (const [key, value] of Object.entries(query || {})) {
    if (value === undefined || value === null) continue;
    const text = String(value).trim();
    if (!text) continue;
    url.searchParams.set(key, text);
  }
  return url.toString();
}

async function homeAssistantRequest(credentials, options = {}) {
  const baseUrl = normalizeHomeAssistantBaseUrl(credentials.baseUrl);
  const token = requireText(credentials.token, 'Home Assistant token');
  await assertPublicHomeAssistantEndpoint(baseUrl, { signal: options.signal });

  const method = String(options.method || 'GET').trim().toUpperCase();
  if (!['GET', 'POST', 'PUT', 'PATCH', 'DELETE'].includes(method)) {
    throw new Error('Unsupported Home Assistant API method.');
  }

  const headers = { Accept: 'application/json', Authorization: `Bearer ${token}` };
  let body;
  if (options.body !== undefined && options.body !== null) {
    headers['Content-Type'] = 'application/json';
    body = JSON.stringify(options.body);
  }

  const { response, text } = await fetchResponseText(
    buildHomeAssistantUrl(baseUrl, options.path, options.query),
    {
      method,
      headers,
      body,
      redirect: 'manual',
      signal: options.signal,
    },
    { serviceName: 'Home Assistant' },
  );

  if (response.status >= 300 && response.status < 400) {
    throw new Error('Home Assistant redirected the API request; redirects are not followed.');
  }

  let data = null;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = text;
  }

  if (!response.ok) {
    const message = data && typeof data === 'object'
      ? data.message || data.error || `${response.status} ${response.statusText}`
      : text || `${response.status} ${response.statusText}`;
    throw new Error(`Home Assistant request failed: ${String(message).trim()}`);
  }

  return data;
}

module.exports = {
  assertPublicHomeAssistantEndpoint,
  buildHomeAssistantUrl,
  homeAssistantRequest,
  isBlockedIpAddress,
  normalizeHomeAssistantBaseUrl,
  requireText,
  trimText,
};
