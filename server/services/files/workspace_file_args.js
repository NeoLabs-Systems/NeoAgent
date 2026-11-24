'use strict';

const path = require('path');
const { artifactIdFromReference } = require('./user_file_access');

// A tool that sends, uploads or reads a file the agent made needs it from the
// agent's own computer, where the agent works: a VM, a desktop, or this host.
// Tools name such arguments in their metadata (`fileArgs`). Before one runs,
// each named file is fetched from that computer and kept as an owned artifact,
// and the tool gets the artifact's path. A file that is already an artifact, or
// a URL, is left as it is.

function isAlreadyLocal(userId, reference, artifactStore) {
  if (/^[a-z][a-z0-9+.-]*:\/\//i.test(reference)) return true;
  try {
    if (artifactIdFromReference(reference)) return true;
  } catch {
    return true;
  }
  return Boolean(artifactStore.getArtifactForUserByStoragePath?.(userId, reference));
}

/**
 * Returns `{ args }` with each named file replaced by a local artifact path, or
 * `{ error }` naming the file that could not be read from the workspace.
 */
async function fetchWorkspaceFileArgs({ userId, args, fileArgs, workspace, artifactStore, deviceTarget, signal }) {
  if (!fileArgs?.length || !workspace?.downloadFile || !artifactStore?.createBufferArtifact) return { args };
  const fetched = { ...args };
  for (const name of fileArgs) {
    const reference = typeof fetched[name] === 'string' ? fetched[name].trim() : '';
    if (!reference || isAlreadyLocal(userId, reference, artifactStore)) continue;
    let file;
    try {
      file = await workspace.downloadFile(userId, reference, { deviceTarget, signal });
    } catch (error) {
      return { error: `${name} "${reference}" could not be read from your workspace: ${error.message}` };
    }
    const filename = file.filename || path.basename(reference);
    const extension = path.extname(filename).replace(/^\./, '');
    const artifact = await artifactStore.createBufferArtifact(userId, {
      kind: 'workspace-file',
      filenameBase: path.basename(filename, path.extname(filename)) || 'file',
      extension,
      originalFilename: filename,
      content: file.content,
      metadata: { source: 'workspace', workspacePath: file.path || reference },
      signal,
    });
    fetched[name] = artifact.storagePath;
  }
  return { args: fetched };
}

module.exports = { fetchWorkspaceFileArgs };
