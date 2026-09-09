'use strict';

const fs = require('fs');
const path = require('path');
const { MAX_READ_BYTES, MAX_UPLOAD_BYTES } = require('./constants');
const { davRequest, ocsRequest, parseCredentials } = require('./client');
const { parseDavResponses } = require('./dav');
const {
  davFilesPath,
  davTrashPath,
  hrefToRemotePath,
  normalizeBaseUrl,
  normalizeRemotePath,
  requireText,
  text,
} = require('./network');

const { FILE_TOOLS } = require('./files_tools');

const PROPFIND_BODY = `<?xml version="1.0"?>
<d:propfind xmlns:d="DAV:" xmlns:oc="http://owncloud.org/ns" xmlns:nc="http://nextcloud.org/ns">
  <d:prop>
    <d:displayname/>
    <d:getcontentlength/>
    <d:getcontenttype/>
    <d:getlastmodified/>
    <d:resourcetype/>
    <oc:fileid/>
    <nc:trashbin-deletion-time/>
    <nc:trashbin-original-filename/>
    <nc:trashbin-original-location/>
  </d:prop>
</d:propfind>`;

function destinationUrl(credentials, davPath) {
  return `${normalizeBaseUrl(credentials.baseUrl)}${davPath}`;
}

function summarizeEntry(entry, username, kind) {
  const prefix = kind === 'trash'
    ? `/remote.php/dav/trashbin/${username}/`
    : `/remote.php/dav/files/${username}/`;
  const remotePath = hrefToRemotePath(entry.href, prefix);
  return {
    path: remotePath,
    name: text(entry.displayName) || remotePath.split('/').filter(Boolean).pop() || '/',
    type: entry.isCollection ? 'folder' : 'file',
    size: entry.contentLength ? Number(entry.contentLength) : null,
    mimeType: text(entry.contentType) || null,
    lastModified: text(entry.lastModified) || null,
    fileId: text(entry.fileId) || null,
    deletedAt: text(entry.trashDeletedAt) || null,
    originalPath: text(entry.trashOriginalPath) || null,
  };
}

async function listDav(credentials, davPath, username, kind, options = {}) {
  const collectionPath = davPath.endsWith('/') ? davPath : `${davPath}/`;
  const { text: xml } = await davRequest(credentials, collectionPath, {
    method: 'PROPFIND',
    headers: { Depth: options.depth || '1', 'Content-Type': 'application/xml; charset=utf-8' },
    body: PROPFIND_BODY,
    signal: options.signal,
  });
  const selfPath = hrefToRemotePath(davPath, kind === 'trash'
    ? `/remote.php/dav/trashbin/${username}/`
    : `/remote.php/dav/files/${username}/`);
  return parseDavResponses(xml)
    .filter((entry) => entry.ok)
    .map((entry) => summarizeEntry(entry, username, kind))
    .filter((entry) => entry.path !== selfPath);
}

async function validateExistingReadableFilePath(filePath) {
  const normalized = text(filePath);
  if (!normalized) throw new Error('file_path is required.');
  if (normalized.split(/[\\/]+/).includes('..')) {
    throw new Error('file_path must not contain parent traversal segments.');
  }
  const resolved = path.resolve(normalized);
  const stats = await fs.promises.stat(resolved);
  if (!stats.isFile()) throw new Error('file_path must point to a readable file.');
  if (stats.size > MAX_UPLOAD_BYTES) {
    throw new Error(`file_path exceeds the ${MAX_UPLOAD_BYTES}-byte upload limit.`);
  }
  await fs.promises.access(resolved, fs.constants.R_OK);
  return { path: resolved, size: stats.size };
}

async function executeFilesTool(toolName, args, credentials, options = {}) {
  const auth = parseCredentials(credentials);
  const signal = options.signal || null;
  const filePath = (remotePath) => davFilesPath(auth.username, remotePath);

  switch (toolName) {
    case 'nextcloud_list_files':
      return {
        result: await listDav(auth, filePath(args.path), auth.username, 'files', { signal }),
      };
    case 'nextcloud_search_files': {
      const limit = Math.max(1, Math.min(Number(args.limit) || 20, 100));
      const result = await ocsRequest(auth, '/ocs/v2.php/search/providers/files/search', {
        query: { term: requireText(args.query, 'query'), limit },
        signal,
        serviceName: 'Nextcloud search',
      });
      return { result };
    }
    case 'nextcloud_read_file': {
      const { response, buffer, text: body } = await davRequest(auth, filePath(args.path), {
        method: 'GET',
        signal,
        maxResponseBytes: MAX_READ_BYTES,
      });
      const contentType = response.headers.get('content-type') || '';
      if (/charset=utf-16/i.test(contentType) || buffer.includes(0)) {
        return {
          result: {
            path: normalizeRemotePath(args.path),
            binary: true,
            size: buffer.length,
            note: 'Use nextcloud_download_file for binary content.',
          },
        };
      }
      return {
        result: {
          path: normalizeRemotePath(args.path),
          mimeType: contentType || null,
          content: body,
          size: buffer.length,
        },
      };
    }
    case 'nextcloud_download_file': {
      const destination = path.resolve(requireText(args.destination_path, 'destination_path'));
      if (destination.split(/[\\/]+/).includes('..')) {
        throw new Error('destination_path must not contain parent traversal segments.');
      }
      const { buffer } = await davRequest(auth, filePath(args.path), { method: 'GET', signal });
      await fs.promises.mkdir(path.dirname(destination), { recursive: true });
      await fs.promises.writeFile(destination, buffer);
      return { result: { path: normalizeRemotePath(args.path), destination_path: destination, size: buffer.length } };
    }
    case 'nextcloud_upload_file': {
      const local = await validateExistingReadableFilePath(args.file_path);
      const body = await fs.promises.readFile(local.path);
      await davRequest(auth, filePath(args.path), {
        method: 'PUT',
        headers: { 'Content-Type': 'application/octet-stream' },
        body,
        signal,
      });
      return { result: { path: normalizeRemotePath(args.path), size: local.size } };
    }
    case 'nextcloud_write_file':
      await davRequest(auth, filePath(args.path), {
        method: 'PUT',
        headers: { 'Content-Type': 'text/plain; charset=utf-8' },
        body: String(args.content ?? ''),
        signal,
      });
      return { result: { path: normalizeRemotePath(args.path) } };
    case 'nextcloud_mkdir':
      await davRequest(auth, filePath(args.path), { method: 'MKCOL', signal });
      return { result: { path: normalizeRemotePath(args.path), type: 'folder' } };
    case 'nextcloud_move_file':
    case 'nextcloud_copy_file': {
      const destination = filePath(args.destination);
      await davRequest(auth, filePath(args.path), {
        method: toolName === 'nextcloud_move_file' ? 'MOVE' : 'COPY',
        headers: {
          Destination: destinationUrl(auth, destination),
          Overwrite: args.overwrite === true ? 'T' : 'F',
        },
        signal,
      });
      return {
        result: {
          path: normalizeRemotePath(args.destination),
          from: normalizeRemotePath(args.path),
        },
      };
    }
    case 'nextcloud_delete_file':
      await davRequest(auth, filePath(args.path), { method: 'DELETE', signal });
      return { result: { deleted: true, path: normalizeRemotePath(args.path) } };
    case 'nextcloud_list_shares': {
      const result = await ocsRequest(auth, '/ocs/v2.php/apps/files_sharing/api/v1/shares', {
        query: text(args.path) ? { path: `/${normalizeRemotePath(args.path)}` } : {},
        signal,
        serviceName: 'Nextcloud shares',
      });
      return { result };
    }
    case 'nextcloud_create_share': {
      const result = await ocsRequest(auth, '/ocs/v2.php/apps/files_sharing/api/v1/shares', {
        method: 'POST',
        form: {
          path: `/${normalizeRemotePath(args.path)}`,
          shareType: Number.isFinite(Number(args.share_type)) ? Number(args.share_type) : 3,
          shareWith: text(args.share_with) || undefined,
          permissions: Number.isFinite(Number(args.permissions)) ? Number(args.permissions) : 1,
          password: text(args.password) || undefined,
          expireDate: text(args.expire_date) || undefined,
          note: text(args.note) || undefined,
        },
        signal,
        serviceName: 'Nextcloud share create',
      });
      return { result };
    }
    case 'nextcloud_delete_share':
      await ocsRequest(auth, `/ocs/v2.php/apps/files_sharing/api/v1/shares/${encodeURIComponent(requireText(args.share_id, 'share_id'))}`, {
        method: 'DELETE',
        signal,
        serviceName: 'Nextcloud share delete',
      });
      return { result: { deleted: true, share_id: text(args.share_id) } };
    case 'nextcloud_list_trash':
      return {
        result: await listDav(auth, davTrashPath(auth.username, 'trash'), auth.username, 'trash', { signal }),
      };
    case 'nextcloud_restore_trash': {
      const trashPath = davTrashPath(auth.username, args.trash_path);
      const name = normalizeRemotePath(args.trash_path).split('/').filter(Boolean).pop();
      await davRequest(auth, trashPath, {
        method: 'MOVE',
        headers: {
          Destination: destinationUrl(auth, davTrashPath(auth.username, `restore/${name}`)),
        },
        signal,
      });
      return { result: { restored: true, trash_path: normalizeRemotePath(args.trash_path) } };
    }
    case 'nextcloud_ocs_request':
      return {
        result: await ocsRequest(auth, requireText(args.path, 'path'), {
          method: args.method,
          query: args.query && typeof args.query === 'object' ? args.query : {},
          json: args.body && typeof args.body === 'object' ? args.body : undefined,
          signal,
        }),
      };
    default:
      return null;
  }
}

module.exports = {
  FILE_TOOLS,
  executeFilesTool,
};
