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
const { readUpdateStatus, writeUpdateStatus } = require('../../../server/utils/update_status');
after(() => fs.rmSync(root, { recursive: true, force: true }));

function service(t, spawn) {
  t.mock.method(childProcess, 'spawn', spawn);
  // Checking asks GitHub; the tests answer "unreachable" instead.
  t.mock.method(childProcess, 'execFile', (command, args, options, callback) => callback(new Error('offline')));
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

test('accepted updates report running status and prevent duplicate jobs or channel changes', (t) => {
  writeUpdateStatus({ state: 'idle', runnerPid: null });
  const updates = service(t, (command, args, options) => {
    assert.ok(args.includes(path.resolve(__dirname, '../../../lib/cli/update_runner.js')));
    assert.equal(options.detached, true);
    assert.equal(options.cwd, path.resolve(__dirname, '../../..'));
    const result = child();
    process.nextTick(() => result.emit('spawn'));
    return result;
  });
  assert.equal(updates.start().job.state, 'running');
  assert.throws(() => updates.start(), { status: 409, code: 'UPDATE_RUNNING' });
  assert.throws(() => updates.setChannel('beta'), { status: 409 });
});

test('spawn errors are persisted and a retry is allowed', async (t) => {
  writeUpdateStatus({ state: 'idle', runnerPid: null });
  const updates = service(t, () => {
    const result = child();
    process.nextTick(() => result.emit('error', new Error('Cannot launch Node')));
    return result;
  });
  updates.start();
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(readUpdateStatus().state, 'failed');
  assert.match(readUpdateStatus().message, /Cannot launch Node/);
  assert.equal((await updates.setChannel('beta')).channel, 'beta');
});

test('systemd updates use an independent scope and preserve the installation environment', (t) => {
  const platform = Object.getOwnPropertyDescriptor(process, 'platform');
  Object.defineProperty(process, 'platform', { value: 'linux' });
  t.after(() => Object.defineProperty(process, 'platform', platform));
  const invocation = process.env.INVOCATION_ID;
  process.env.INVOCATION_ID = 'test-invocation';
  t.after(() => {
    if (invocation === undefined) delete process.env.INVOCATION_ID;
    else process.env.INVOCATION_ID = invocation;
  });
  writeUpdateStatus({ state: 'idle', runnerPid: null });
  const updates = service(t, (command, args) => {
    assert.equal(command, 'systemd-run');
    assert.deepEqual(args.slice(0, 4), ['--user', '--scope', '--quiet', '--collect']);
    assert.equal(args[4], process.execPath);
    const result = child();
    process.nextTick(() => result.emit('spawn'));
    return result;
  });
  updates.start();
});

test('containers and managed deployments cannot update themselves', async (t) => {
  writeUpdateStatus({ state: 'idle', runnerPid: null });
  const updates = service(t, () => { throw new Error('Should not spawn'); });
  process.env.NEOAGENT_CONTAINER_IMAGE = '1';
  t.after(() => { delete process.env.NEOAGENT_CONTAINER_IMAGE; });
  assert.equal(updates.status().blockedReason, 'container');
  assert.equal(updates.status().selfUpdate, false);
  assert.throws(() => updates.start(), { status: 409, code: 'UPDATE_CONTAINER' });
  assert.throws(() => updates.setChannel('stable'), { status: 409 });
  delete process.env.NEOAGENT_CONTAINER_IMAGE;
  process.env.NEOAGENT_DEPLOYMENT_MODE = 'managed';
  t.after(() => { delete process.env.NEOAGENT_DEPLOYMENT_MODE; });
  assert.equal(updates.status().blockedReason, 'managed');
  assert.throws(() => updates.start(), { status: 409, code: 'UPDATE_MANAGED' });
});

test('the status has the documented shape and an unknown channel is refused', async (t) => {
  writeUpdateStatus({ state: 'idle', runnerPid: null });
  const updates = service(t, () => { throw new Error('Should not spawn'); });
  const status = updates.status();
  assert.deepEqual(Object.keys(status.job).sort(), [
    'changelog', 'completedAt', 'logs', 'message', 'phase', 'progress', 'rolledBack',
    'startedAt', 'state', 'versionAfter', 'versionBefore',
  ]);
  assert.equal(status.available, null);
  assert.throws(() => updates.setChannel('nightly'), { status: 400, code: 'INVALID_CHANNEL' });
  assert.equal((await updates.setChannel('stable')).channel, 'stable');
});
