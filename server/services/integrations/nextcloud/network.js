'use strict';

const { requireText, trimText: text } = require('../../../utils/text');
const { encodePathSegments, normalizeServerUrl } = require('../dav/paths');

function normalizeBaseUrl(value) {
  return normalizeServerUrl(value, 'Nextcloud URL');
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

function davFilesPath(username, remotePath) {
  const user = encodeURIComponent(requireText(username, 'username'));
  const encoded = encodePathSegments(remotePath);
  return `/remote.php/dav/files/${user}${encoded ? `/${encoded}` : ''}`;
}

function davTrashPath(username, itemPath) {
  const user = encodeURIComponent(requireText(username, 'username'));
  const encoded = encodePathSegments(itemPath);
  return `/remote.php/dav/trashbin/${user}${encoded ? `/${encoded}` : ''}`;
}

module.exports = {
  assertPathPrefix,
  davFilesPath,
  davTrashPath,
  normalizeBaseUrl,
  requireText,
  resolveInstanceUrl,
  text,
};
