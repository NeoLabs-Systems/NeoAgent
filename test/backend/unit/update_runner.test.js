'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');
const source = fs.readFileSync(path.resolve(__dirname, '../../../lib/cli/update_runner.js'), 'utf8');

async function run(cmdUpdate) {
  let status = { state: 'running', logs: [] };
  const context = {
    process: { pid: 1234, exitCode: 0 },
    Date,
    require(name) {
      if (name === '../manager') return { cmdUpdate };
      if (name.endsWith('/release_channel')) return { readConfiguredReleaseChannel: () => 'stable' };
      if (name.endsWith('/logger')) return { formatLogArgs: (args) => args.join(' ') };
      if (name.endsWith('/update_status')) return {
        readUpdateStatus: () => status,
        writeUpdateStatusFile: (patch) => { status = { ...status, ...patch }; },
      };
      throw new Error(`Unexpected module: ${name}`);
    },
  };
  vm.runInNewContext(source, context);
  await new Promise((resolve) => setImmediate(resolve));
  return { status, exitCode: context.process.exitCode };
}

test('admin runner delegates to the CLI updater and persists progress, changes and verified completion', async () => {
  const result = await run(async (args, { onProgress }) => {
    assert.deepEqual(Array.from(args), ['stable']);
    onProgress({ progress: 15, phase: 'backup', message: 'Saving a backup', changelog: ['Improved updates'] });
    onProgress({ progress: 79, phase: 'verifying', message: 'Checking the restarted server' });
    return { message: 'Ready', versionBefore: '1.0.0', versionAfter: '1.1.0' };
  });
  assert.equal(result.status.state, 'completed');
  assert.equal(result.status.progress, 100);
  assert.equal(result.status.runnerPid, null);
  assert.equal(result.status.versionAfter, '1.1.0');
  assert.equal(result.status.logs.length, 2);
  assert.deepEqual(result.status.changelog, ['Improved updates']);
});

test('a failed update retains rollback diagnostics and never reports completion', async () => {
  const result = await run(async (args, { onProgress }) => {
    onProgress({ progress: 85, phase: 'rollback', message: 'Restoring the previous version' });
    throw new Error('Health check failed. The previous version is running again.');
  });
  assert.equal(result.exitCode, 1);
  assert.equal(result.status.state, 'failed');
  assert.equal(result.status.progress, 85);
  assert.equal(result.status.runnerPid, null);
  assert.match(result.status.message, /previous version is running again/);
  assert.equal(result.status.logs.length, 1);
});
