'use strict';

const fs = require('fs');

const ARTIFACT_CONTENT_PATH_RE = /^\/api\/artifacts\/([^/?#]+)\/content(?:[?#].*)?$/;
const ARTIFACT_ID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function artifactIdFromReference(reference) {
  const match = ARTIFACT_CONTENT_PATH_RE.exec(reference);
  if (match) {
    try {
      return decodeURIComponent(match[1]);
    } catch {
      throw new Error('The artifact reference is malformed.');
    }
  }
  return ARTIFACT_ID_RE.test(reference) ? reference : null;
}

function assertUsableFile(filePath, label) {
  let realPath;
  let stats;
  try {
    realPath = fs.realpathSync.native(filePath);
    stats = fs.statSync(realPath);
  } catch {
    throw new Error(`${label} does not exist.`);
  }
  if (!stats.isFile()) {
    throw new Error(`${label} must reference a regular file.`);
  }
  return realPath;
}

function resolveUserFileReference({
  userId,
  reference,
  artifactStore,
  workspaceManager,
  label = 'File',
}) {
  const normalizedReference = String(reference || '').trim();
  if (!normalizedReference) {
    throw new Error(`${label} reference is required.`);
  }
  if (normalizedReference.includes('\0')) {
    throw new Error(`${label} reference is invalid.`);
  }

  const artifactId = artifactIdFromReference(normalizedReference);
  const artifact = artifactId && artifactStore
    ? artifactStore.getArtifactForUser(userId, artifactId)
    : null;
  if (artifactId) {
    if (!artifact) {
      throw new Error(`${label} artifact was not found for this user.`);
    }
    return assertUsableFile(artifact.storage_path, label);
  }

  if (
    artifactStore
    && typeof artifactStore.getArtifactForUserByStoragePath === 'function'
  ) {
    const storedArtifact = artifactStore.getArtifactForUserByStoragePath(
      userId,
      normalizedReference,
    );
    if (storedArtifact) {
      return assertUsableFile(storedArtifact.storage_path, label);
    }
  }

  if (/^[a-z][a-z0-9+.-]*:\/\//i.test(normalizedReference)) {
    throw new Error(`${label} must be a workspace path or owned artifact.`);
  }
  if (!workspaceManager) {
    throw new Error('Workspace file access is unavailable.');
  }
  const workspacePath = workspaceManager.resolvePath(userId, normalizedReference, label);
  return assertUsableFile(workspacePath, label);
}

module.exports = {
  artifactIdFromReference,
  resolveUserFileReference,
};
