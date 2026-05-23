'use strict';

const assert = require('assert');
const { test } = require('node:test');
const childProcess = require('child_process');

const VERSION_MODULE_PATH = require.resolve('./version');

function loadVersionModuleWithExecSync(execSync) {
  const originalExecSync = childProcess.execSync;
  delete require.cache[VERSION_MODULE_PATH];
  childProcess.execSync = execSync;
  try {
    return require('./version');
  } finally {
    childProcess.execSync = originalExecSync;
  }
}

test('getVersionInfo caches git metadata reads', () => {
  let callCount = 0;
  const { getVersionInfo } = loadVersionModuleWithExecSync((command) => {
    callCount += 1;
    if (command.includes('describe')) return 'v1.2.3\n';
    if (command.includes('rev-parse --short')) return 'abc123\n';
    if (command.includes('abbrev-ref')) return 'main\n';
    throw new Error(`unexpected command: ${command}`);
  });

  const first = getVersionInfo();
  const second = getVersionInfo();

  assert.equal(first.gitVersion, '1.2.3');
  assert.equal(first.gitSha, 'abc123');
  assert.equal(first.gitBranch, 'main');
  assert.equal(second.gitVersion, '1.2.3');
  assert.equal(callCount, 3);
});

