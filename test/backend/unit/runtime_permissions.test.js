'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { afterEach, describe, it } = require('node:test');

const {
  ensurePrivateDirectory,
  ensurePrivateFile,
} = require('../../../runtime/paths');

const temporaryDirectories = [];

function permissionBits(filePath) {
  return fs.statSync(filePath).mode & 0o777;
}

afterEach(() => {
  while (temporaryDirectories.length > 0) {
    fs.rmSync(temporaryDirectories.pop(), { recursive: true, force: true });
  }
});

describe('runtime path permissions', { skip: process.platform === 'win32' }, () => {
  it('tightens existing runtime directories and files to owner-only access', () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-permissions-'));
    temporaryDirectories.push(root);
    const directory = path.join(root, 'runtime');
    fs.mkdirSync(directory, { mode: 0o755 });
    const filePath = path.join(directory, 'database.sqlite');
    fs.writeFileSync(filePath, 'data', { mode: 0o644 });

    ensurePrivateDirectory(directory);
    ensurePrivateFile(filePath);

    assert.equal(permissionBits(directory), 0o700);
    assert.equal(permissionBits(filePath), 0o600);
  });
});
