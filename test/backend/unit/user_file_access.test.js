'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { afterEach, describe, it } = require('node:test');

const { resolveUserFileReference } = require('../../../server/services/files/user_file_access');
const { WorkspaceManager } = require('../../../server/services/workspace/manager');

const temporaryDirectories = [];

function createTemporaryDirectory() {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-file-access-'));
  temporaryDirectories.push(directory);
  return directory;
}

afterEach(() => {
  while (temporaryDirectories.length > 0) {
    fs.rmSync(temporaryDirectories.pop(), { recursive: true, force: true });
  }
});

describe('resolveUserFileReference', () => {
  it('allows regular files inside the authenticated user workspace', () => {
    const root = createTemporaryDirectory();
    const workspaceManager = new WorkspaceManager({
      rootDir: path.join(root, 'workspaces'),
    });
    const workspaceFile = workspaceManager.resolvePath('owner', 'uploads/photo.png');
    fs.mkdirSync(path.dirname(workspaceFile), { recursive: true });
    fs.writeFileSync(workspaceFile, 'image');

    const resolved = resolveUserFileReference({
      userId: 'owner',
      reference: 'uploads/photo.png',
      workspaceManager,
      artifactStore: null,
    });

    assert.equal(resolved, fs.realpathSync.native(workspaceFile));
  });

  it('rejects absolute host files outside the authenticated user workspace', () => {
    const root = createTemporaryDirectory();
    const workspaceManager = new WorkspaceManager({
      rootDir: path.join(root, 'workspaces'),
    });
    const hostFile = path.join(root, 'server-secret.txt');
    fs.writeFileSync(hostFile, 'secret');

    assert.throws(
      () => resolveUserFileReference({
        userId: 'owner',
        reference: hostFile,
        workspaceManager,
        artifactStore: null,
      }),
      /outside the per-user workspace/,
    );
  });

  it('rejects workspace symlinks that resolve outside the user workspace', () => {
    const root = createTemporaryDirectory();
    const workspaceManager = new WorkspaceManager({
      rootDir: path.join(root, 'workspaces'),
    });
    const hostFile = path.join(root, 'server-secret.txt');
    fs.writeFileSync(hostFile, 'secret');
    const symlinkPath = workspaceManager.resolvePath('owner', 'uploads/link.txt');
    fs.mkdirSync(path.dirname(symlinkPath), { recursive: true });
    fs.symlinkSync(hostFile, symlinkPath);

    assert.throws(
      () => resolveUserFileReference({
        userId: 'owner',
        reference: 'uploads/link.txt',
        workspaceManager,
        artifactStore: null,
      }),
      /outside the per-user workspace/,
    );
  });

  it('allows an owned artifact URL and rejects another user artifact', () => {
    const root = createTemporaryDirectory();
    const artifactPath = path.join(root, 'artifact.png');
    fs.writeFileSync(artifactPath, 'image');
    const artifactId = '6c8e594a-588a-4b46-aee1-bec82818de52';
    const artifactStore = {
      getArtifactForUser(userId, requestedId) {
        if (userId !== 'owner' || requestedId !== artifactId) return null;
        return { storage_path: artifactPath };
      },
      getArtifactForUserByStoragePath() {
        return null;
      },
    };

    const resolved = resolveUserFileReference({
      userId: 'owner',
      reference: `/api/artifacts/${artifactId}/content`,
      workspaceManager: null,
      artifactStore,
    });
    assert.equal(resolved, fs.realpathSync.native(artifactPath));

    assert.throws(
      () => resolveUserFileReference({
        userId: 'attacker',
        reference: `/api/artifacts/${artifactId}/content`,
        workspaceManager: null,
        artifactStore,
      }),
      /not found for this user/,
    );
  });
});
