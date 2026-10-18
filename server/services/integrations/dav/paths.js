'use strict';

const { isPrivateHost } = require('../../../utils/cloud-security');
const { trimText: text } = require('../../../utils/text');

// Server URLs and the paths inside a WebDAV home (files, calendars, address
// books), shared by every DAV-backed integration. Paths never climb out of the
// home they start in.

// A DAV server's base URL: HTTPS unless it is on a private network, never
// carrying credentials, query or fragment.
function normalizeServerUrl(value, label) {
  const raw = text(value);
  if (!raw) throw new Error(`${label} is required.`);
  const hostPart = raw.split('/')[0];
  const candidate = raw.includes('://')
    ? raw
    : `${isPrivateHost(hostPart) ? 'http' : 'https'}://${raw}`;
  let url;
  try {
    url = new URL(candidate);
  } catch {
    throw new Error(`${label} must be a valid HTTP or HTTPS URL.`);
  }
  if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password || url.hash) {
    throw new Error(`${label} must be HTTP(S), without credentials or a fragment.`);
  }
  url.pathname = url.pathname.replace(/\/+$/, '');
  url.search = '';
  return url.toString().replace(/\/+$/, '');
}

function normalizeRemotePath(value) {
  const raw = text(value).replace(/\\/g, '/');
  if (!raw || raw === '/') return '';
  const parts = raw.split('/').filter((part) => part && part !== '.');
  if (parts.some((part) => part === '..')) {
    throw new Error('Path must not contain parent traversal segments.');
  }
  return parts.join('/');
}

function encodePathSegments(value) {
  return normalizeRemotePath(value).split('/').filter(Boolean).map(encodeURIComponent).join('/');
}

function hrefToRemotePath(href, prefix) {
  const raw = text(href);
  if (!raw) return '';
  let pathname;
  try {
    pathname = raw.startsWith('http://') || raw.startsWith('https://')
      ? new URL(raw).pathname
      : raw;
  } catch {
    pathname = raw;
  }
  const decoded = decodeURIComponent(pathname).replace(/\/+$/, '') || '/';
  const marker = (prefix.endsWith('/') ? prefix.slice(0, -1) : prefix).replace(/\/+$/, '');
  if (decoded === marker) return '';
  if (decoded.startsWith(`${marker}/`)) {
    return normalizeRemotePath(decoded.slice(marker.length + 1));
  }
  return normalizeRemotePath(decoded.replace(/^\/+/, ''));
}

module.exports = {
  encodePathSegments,
  normalizeServerUrl,
  hrefToRemotePath,
  normalizeRemotePath,
};
