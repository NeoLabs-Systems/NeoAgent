'use strict';

// Filesystem layout inside the guest VM image. The guest user is `neo`, its home
// is the mount point of the data disk, and the agent works out of `workspace`.
// These are a contract between the bootstrap that builds the image, the backends
// that talk to it, and the tools that report paths back to the model.
const GUEST_HOME = '/home/neo';
const GUEST_WORKSPACE_DIR = `${GUEST_HOME}/workspace`;

// Guest tools speak workspace-relative paths; the model and the UI see absolute
// ones, so every boundary crossing goes through these two helpers.
function toGuestWorkspacePath(relativePath) {
  return `${GUEST_WORKSPACE_DIR}/${String(relativePath ?? '')}`;
}

function fromGuestWorkspacePath(value, fallback = '') {
  const normalized = String(value ?? fallback).trim().replace(/\\/g, '/');
  if (normalized === GUEST_WORKSPACE_DIR) return '';
  if (normalized.startsWith(`${GUEST_WORKSPACE_DIR}/`)) {
    return normalized.slice(GUEST_WORKSPACE_DIR.length + 1);
  }
  return normalized || fallback;
}

module.exports = {
  GUEST_HOME,
  GUEST_WORKSPACE_DIR,
  fromGuestWorkspacePath,
  toGuestWorkspacePath,
};
