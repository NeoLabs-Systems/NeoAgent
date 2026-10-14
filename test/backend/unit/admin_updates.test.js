'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { EventEmitter } = require('node:events');
const { test, after } = require('node:test');
const childProcess = require('node:child_process');

const root = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-admin-update-'));
process.env.NEOAGENT_HOME = root;
process.env.NEOAGENT_ENV_FILE = path.join(root, '.env');
process.env.NEOAGENT_DATA_DIR = path.join(root, 'data');
process.env.NEOAGENT_AGENT_DATA_DIR = path.join(root, 'agent-data');
delete process.env.NEOAGENT_CONTAINER_IMAGE;
delete process.env.NEOAGENT_DEPLOYMENT_MODE;
const { readUpdateStatus, writeUpdateStatusFile } = require('../../../server/utils/update_status');
after(() => fs.rmSync(root, { recursive: true, force: true }));

function service(t, spawn) {
  t.mock.method(childProcess, 'spawn', spawn);
  const modulePath = require.resolve('../../../server/services/admin/updates');
  delete require.cache[modulePath];
  return require(modulePath);
}

function child() {
  const result = new EventEmitter();
  result.pid = process.pid;
  result.unref = () => {};
  return result;
}

test('accepted updates report running status and prevent duplicate jobs or channel changes', async (t) => {
  writeUpdateStatusFile({ state: 'idle', runnerPid: null });
  const updates = service(t, (command, args, options) => {
    assert.ok(args.includes(path.resolve(__dirname, '../../../lib/cli/update_runner.js')));
    assert.equal(options.detached, true);
    assert.equal(options.cwd, path.resolve(__dirname, '../../..'));
    const result = child();
    process.nextTick(() => result.emit('spawn'));
    return result;
  });
  assert.equal((await updates.startUpdate()).state, 'running');
  await assert.rejects(updates.startUpdate(), { status: 409 });
  assert.throws(() => updates.setUpdateChannel('beta'), { status: 409 });
});

test('spawn errors are persisted and a retry is allowed', async (t) => {
  writeUpdateStatusFile({ state: 'idle', runnerPid: null });
  const updates = service(t, () => {
    const result = child();
    process.nextTick(() => result.emit('error', new Error('Cannot launch Node')));
    return result;
  });
  await assert.rejects(updates.startUpdate(), /Cannot launch Node/);
  assert.equal(readUpdateStatus().state, 'failed');
  assert.match(readUpdateStatus().message, /Cannot launch Node/);
  assert.equal(updates.setUpdateChannel('beta').releaseChannel, 'beta');
});

test('systemd updates use an independent scope and preserve the installation environment', async (t) => {
  const platform = Object.getOwnPropertyDescriptor(process, 'platform');
  Object.defineProperty(process, 'platform', { value: 'linux' });
  t.after(() => Object.defineProperty(process, 'platform', platform));
  const invocation = process.env.INVOCATION_ID;
  process.env.INVOCATION_ID = 'test-invocation';
  t.after(() => {
    if (invocation === undefined) delete process.env.INVOCATION_ID;
    else process.env.INVOCATION_ID = invocation;
  });
  writeUpdateStatusFile({ state: 'idle', runnerPid: null });
  const updates = service(t, (command, args) => {
    assert.equal(command, 'systemd-run');
    assert.deepEqual(args.slice(0, 4), ['--user', '--scope', '--quiet', '--collect']);
    assert.equal(args[4], process.execPath);
    const result = child();
    process.nextTick(() => result.emit('spawn'));
    return result;
  });
  await updates.startUpdate();
});

test('configured channel and deployment flags stay current within the version cache', (t) => {
  const { getVersionInfo } = require('../../../server/utils/version');
  writeUpdateStatusFile({ state: 'completed', runnerPid: null, releaseChannel: 'stable' });
  const updates = service(t, () => { throw new Error('Should not spawn'); });
  updates.setUpdateChannel('stable');
  assert.equal(getVersionInfo().releaseChannel, 'stable');
  updates.setUpdateChannel('beta');
  assert.equal(getVersionInfo().releaseChannel, 'beta');
  process.env.NEOAGENT_CONTAINER_IMAGE = '1';
  t.after(() => { delete process.env.NEOAGENT_CONTAINER_IMAGE; });
  assert.equal(getVersionInfo().containerImage, true);
  assert.equal(getVersionInfo().allowSelfUpdate, false);
  assert.throws(() => updates.setUpdateChannel('stable'), { status: 403 });
});
