'use strict';

function text(value) {
  return String(value || '').trim();
}

function requireText(value, label) {
  const normalized = text(value);
  if (!normalized) throw new Error(`${label} is required.`);
  return normalized;
}

function isPrivateHost(host) {
  const value = String(host || '').toLowerCase();
  return value === 'localhost' || value === '::1' || value.startsWith('127.')
    || value.startsWith('10.') || value.startsWith('192.168.')
    || /^172\.(1[6-9]|2\d|3[01])\./.test(value);
}

function normalizeBaseUrl(value) {
  const raw = text(value);
  if (!raw) throw new Error('Nextcloud URL is required.');
  const hostPart = raw.split('/')[0];
  const candidate = raw.includes('://')
    ? raw
    : `${isPrivateHost(hostPart) ? 'http' : 'https'}://${raw}`;
  let url;
  try {
    url = new URL(candidate);
  } catch {
    throw new Error('Nextcloud URL must be a valid HTTP or HTTPS URL.');
  }
  if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password || url.hash) {
    throw new Error('Nextcloud URL must be HTTP(S), without credentials or a fragment.');
  }
  url.pathname = url.pathname.replace(/\/+$/, '');
  url.search = '';
  return url.toString().replace(/\/+$/, '');
}

function resolveInstanceUrl(baseUrl, path) {
  const base = new URL(normalizeBaseUrl(baseUrl));
  const raw = requireText(path, 'path');
  if (!raw.startsWith('/')) {
    throw new Error('Nextcloud path must be absolute and start with /.');
  }
  const url = new URL(raw, base);
  if (url.origin !== base.origin) {
    throw new Error('Nextcloud path must stay on the connected instance origin.');
  }
  return url;
}

function assertPathPrefix(url, prefix, label) {
  const pathname = decodeURIComponent(url.pathname || '');
  if (!pathname.startsWith(prefix)) {
    throw new Error(`${label} must start with ${prefix}.`);
  }
  return url;
}

function normalizeRemotePath(value) {
  const raw = text(value).replace(/\\/g, '/');
  if (!raw || raw === '/') return '';
  const parts = raw.split('/').filter((part) => part && part !== '.');
  if (parts.some((part) => part === '..')) {
    throw new Error('Nextcloud path must not contain parent traversal segments.');
  }
  return parts.join('/');
}

function encodePathSegments(value) {
  return normalizeRemotePath(value).split('/').filter(Boolean).map(encodeURIComponent).join('/');
}

function davFilesPath(username, remotePath) {
  const user = encodeURIComponent(requireText(username, 'username'));
  const encoded = encodePathSegments(remotePath);
  return `/remote.php/dav/files/${user}${encoded ? `/${encoded}` : ''}`;
}

function davCalendarsPath(username, calendarPath) {
  const user = encodeURIComponent(requireText(username, 'username'));
  const encoded = encodePathSegments(calendarPath);
  return `/remote.php/dav/calendars/${user}${encoded ? `/${encoded}` : ''}`;
}

function davAddressbooksPath(username, bookPath) {
  const user = encodeURIComponent(requireText(username, 'username'));
  const encoded = encodePathSegments(bookPath);
  return `/remote.php/dav/addressbooks/${user}${encoded ? `/${encoded}` : ''}`;
}

function davTrashPath(username, itemPath) {
  const user = encodeURIComponent(requireText(username, 'username'));
  const encoded = encodePathSegments(itemPath);
  return `/remote.php/dav/trashbin/${user}${encoded ? `/${encoded}` : ''}`;
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
  assertPathPrefix,
  davAddressbooksPath,
  davCalendarsPath,
  davFilesPath,
  davTrashPath,
  encodePathSegments,
  hrefToRemotePath,
  isPrivateHost,
  normalizeBaseUrl,
  normalizeRemotePath,
  requireText,
  resolveInstanceUrl,
  text,
};
