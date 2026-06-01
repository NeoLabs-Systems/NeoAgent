'use strict';

const dns = require('dns').promises;
const net = require('net');

const HTTP_TIMEOUT_MS = 15000;
const ALLOWED_PORTS = new Set(['', '443', '8123']);

function trimText(value) {
  return String(value || '').trim();
}

function requireText(value, label) {
  const text = trimText(value);
  if (!text) throw new Error(`${label} is required.`);
  return text;
}

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

function ipv4ToNumber(address) {
  const parts = String(address || '').split('.').map((part) => Number(part));
  if (parts.length !== 4 || parts.some((part) => !Number.isInteger(part) || part < 0 || part > 255)) {
    return null;
  }
  return parts.reduce((acc, part) => ((acc << 8) + part) >>> 0, 0);
}

function ipv4InCidr(address, cidr, bits) {
  const value = ipv4ToNumber(address);
  const base = ipv4ToNumber(cidr);
  if (value === null || base === null) return false;
  const mask = bits === 0 ? 0 : (0xffffffff << (32 - bits)) >>> 0;
  return (value & mask) === (base & mask);
}

function isBlockedIpv4(address) {
  return [
    ['0.0.0.0', 8],
    ['10.0.0.0', 8],
    ['100.64.0.0', 10],
    ['127.0.0.0', 8],
    ['169.254.0.0', 16],
    ['172.16.0.0', 12],
    ['192.0.0.0', 24],
    ['192.0.2.0', 24],
    ['192.168.0.0', 16],
    ['198.18.0.0', 15],
    ['198.51.100.0', 24],
    ['203.0.113.0', 24],
    ['224.0.0.0', 4],
    ['240.0.0.0', 4],
  ].some(([cidr, bits]) => ipv4InCidr(address, cidr, bits));
}

function isBlockedIpv6(address) {
  const normalized = String(address || '').trim().toLowerCase();
  if (normalized.startsWith('::ffff:')) {
    return isBlockedIpv4(normalized.slice('::ffff:'.length));
  }
  return normalized === '::' ||
    normalized === '::1' ||
    normalized.startsWith('fc') ||
    normalized.startsWith('fd') ||
    normalized.startsWith('fe8') ||
    normalized.startsWith('fe9') ||
    normalized.startsWith('fea') ||
    normalized.startsWith('feb') ||
    normalized.startsWith('ff') ||
    normalized.startsWith('2001:db8:');
}

function isBlockedIpAddress(address) {
  const normalized = String(address || '').trim().replace(/^\[|\]$/g, '');
  const family = net.isIP(normalized);
  if (family === 4) return isBlockedIpv4(normalized);
  if (family === 6) return isBlockedIpv6(normalized);
  return true;
}

async function assertPublicHomeAssistantEndpoint(baseUrl) {
  const url = new URL(normalizeHomeAssistantBaseUrl(baseUrl));
  const hostname = String(url.hostname || '').replace(/^\[|\]$/g, '');
  if (net.isIP(hostname) && isBlockedIpAddress(hostname)) {
    throw new Error('Home Assistant URL must not point to a private, loopback, or link-local address.');
  }

  let addresses;
  try {
    addresses = await dns.lookup(hostname, { all: true, verbatim: true });
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
  await assertPublicHomeAssistantEndpoint(baseUrl);

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

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), HTTP_TIMEOUT_MS);
  let response;
  try {
    response = await fetch(buildHomeAssistantUrl(baseUrl, options.path, options.query), {
      method,
      headers,
      body,
      redirect: 'manual',
      signal: controller.signal,
    });
  } catch (error) {
    if (error?.name === 'AbortError') {
      throw new Error(`Home Assistant request timed out after ${HTTP_TIMEOUT_MS}ms.`);
    }
    throw error;
  } finally {
    clearTimeout(timer);
  }

  if (response.status >= 300 && response.status < 400) {
    throw new Error('Home Assistant redirected the API request; redirects are not followed.');
  }

  const text = await response.text();
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
