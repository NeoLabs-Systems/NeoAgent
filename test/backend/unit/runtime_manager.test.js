'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { RuntimeManager } = require('../../../server/services/runtime/manager');

test('CLI commands always execute inside the unified cloud computer', async () => {
  const calls = [];
  const manager = Object.create(RuntimeManager.prototype);
  manager.computerBackend = {
    async executeCommand(userId, command, options) {
      calls.push({ userId, command, options });
      return { stdout: '/home/neo/workspace\n', stderr: '', exitCode: 0 };
    },
  };

  const result = await manager.executeCliCommand(7, 'pwd', { timeout: 1234 });

  assert.equal(result.backend, 'cloud-computer');
  assert.equal(result.stdout, '/home/neo/workspace\n');
  assert.deepEqual(calls, [{ userId: 7, command: 'pwd', options: { timeout: 1234 } }]);
});

test('interactive command options reach the same computer backend', async () => {
  const calls = [];
  const manager = Object.create(RuntimeManager.prototype);
  manager.computerBackend = {
    async executeCommand(userId, command, options) {
      calls.push({ userId, command, options });
      return { stdout: 'confirmed', stderr: '', exitCode: 0 };
    },
  };
  const options = { pty: true, inputs: ['yes\n'], timeout: 5000 };

  const result = await manager.executeCliCommand('7', 'confirm', options);

  assert.equal(result.backend, 'cloud-computer');
  assert.deepEqual(calls, [{ userId: '7', command: 'confirm', options }]);
});

test('a device target override routes one command without changing the saved provider', async () => {
  const calls = [];
  const manager = Object.create(RuntimeManager.prototype);
  manager.providerModes = new Map([['7', 'local']]);
  manager.computerBackend = {
    async executeCommand(userId, command) {
      calls.push({ backend: 'cloud', userId, command });
      return { stdout: 'cloud', stderr: '', exitCode: 0 };
    },
  };
  manager.localComputerBackend = {
    async executeCommand(userId, command) {
      calls.push({ backend: 'local', userId, command });
      return { stdout: 'local', stderr: '', exitCode: 0 };
    },
  };

  const overridden = await manager.executeCliCommand(7, 'pwd', {
    deviceTarget: 'cloud',
  });
  const inherited = await manager.executeCliCommand(7, 'pwd');

  assert.equal(overridden.backend, 'cloud-computer');
  assert.equal(inherited.backend, 'local-computer');
  assert.deepEqual(calls.map((entry) => entry.backend), ['cloud', 'local']);
  assert.equal(manager.getComputerProvider(7), 'local');
});

test('Android providers are stable per user so concurrent starts share one controller', async () => {
  const created = [];
  const manager = Object.create(RuntimeManager.prototype);
  manager.androidControllers = new Map();
  manager.createAndroidController = (userId) => {
    const controller = { userId };
    created.push(controller);
    return controller;
  };

  const [first, second, other] = await Promise.all([
    manager.getAndroidProviderForUser(7),
    manager.getAndroidProviderForUser('7'),
    manager.getAndroidProviderForUser(8),
  ]);

  assert.equal(first, second);
  assert.notEqual(first, other);
  assert.equal(created.length, 2);
});

test('browser, desktop, shell, and files share one computer backend', async () => {
  const backend = {
    getBrowserProviderForUser: async () => ({ kind: 'browser' }),
    requestGuest: async () => ({ path: '' }),
    vmManager: { getStatus: () => ({ state: 'ready' }) },
  };
  const manager = Object.create(RuntimeManager.prototype);
  manager.computerBackend = backend;
  manager.artifactStore = null;

  assert.deepEqual(await manager.getBrowserProviderForUser(7), { kind: 'browser' });
  assert.equal(manager.getDesktopProviderForUser(7).backend, backend);
  assert.deepEqual(await manager.requestComputer(7, 'GET', '/workspace/files'), { path: '' });
});

test('computer control leases are exclusive and expire cleanly', () => {
  const manager = new RuntimeManager({
    computerBackend: {
      vmManager: { getStatus: () => ({ state: 'ready' }), hasTrackedVm: () => false },
    },
    localComputerBackend: {
      isConnected: () => true,
      vmManager: { getStatus: () => ({ state: 'ready' }), hasTrackedVm: () => false },
    },
  });
  manager.providerModes.set('7', 'cloud');

  const first = manager.acquireControl(7, 'agent', 'run-1');
  assert.equal(first.ownerType, 'agent');
  const shared = manager.acquireControl(7, 'agent', 'run-2');
  assert.equal(shared.ownerType, 'agent');
  assert.deepEqual(shared.ownerIds.sort(), ['run-1', 'run-2']);
  assert.throws(
    () => manager.acquireControl(7, 'user', 'session-1'),
    (error) => error.code === 'COMPUTER_CONTROL_CONFLICT',
  );
  assert.equal(manager.releaseControl(7, 'run-1'), true);
  assert.equal(manager.getControlLease(7).ownerType, 'agent');
  assert.equal(manager.releaseControl(7, 'run-2'), true);
  assert.equal(manager.acquireControl(7, 'teach', 'teach-1').ownerType, 'teach');
});

test('local and cloud computer leases do not block each other', () => {
  const manager = new RuntimeManager({
    computerBackend: {
      vmManager: { getStatus: () => ({ state: 'ready' }), hasTrackedVm: () => false },
    },
    localComputerBackend: {
      isConnected: () => true,
      vmManager: { getStatus: () => ({ state: 'ready' }), hasTrackedVm: () => false },
    },
  });
  manager.providerModes.set('7', 'cloud');

  const cloud = manager.acquireControl(7, 'agent', 'cowork-run', { provider: 'cloud' });
  const local = manager.acquireControl(7, 'agent', 'local-run', { provider: 'local' });
  assert.equal(cloud.provider, 'cloud');
  assert.equal(local.provider, 'local');
  assert.equal(manager.getControlLease(7, { provider: 'cloud' }).ownerId, 'cowork-run');
  assert.equal(manager.getControlLease(7, { provider: 'local' }).ownerId, 'local-run');
  assert.throws(
    () => manager.acquireControl(7, 'user', 'session-1', { provider: 'local' }),
    (error) => error.code === 'COMPUTER_CONTROL_CONFLICT'
      && /Local computer is controlled by agent/.test(error.message),
  );
});

test('display sessions come up even when browser launch and workspace import fail', async () => {
  const computerBackend = {
    async getClientForUser() { return {}; },
    async getBrowserProviderForUser() {
      return {
        async launch() {
          throw new Error('No DISPLAY');
        },
      };
    },
    async importWorkspaceArchive() {
      throw new Error('workspace import unavailable');
    },
    vmManager: {
      instances: new Map([['7', {
        display: { websocketUrl: 'ws://127.0.0.1:16080' },
        instanceDir: '/tmp/neoagent-computer-test',
        startedAt: new Date().toISOString(),
      }]]),
      getStatus: () => ({ state: 'ready' }),
    },
  };
  const manager = new RuntimeManager({
    computerBackend,
    workspaceManager: {
      async getWorkspaceRoot() { return '/tmp/neoagent-workspace-test'; },
    },
  });

  const status = await manager.startComputer(7);
  assert.equal(status.state, 'ready');
  manager.acquireControl(7, 'user', 'session-7');
  const display = manager.createDisplaySession(7);
  assert.equal(display.viewOnly, false);
  assert.match(display.viewUrl, /\/api\/computer\/display\//);
});

test('display sessions are user-scoped, lease-aware, and revoked on control changes', () => {
  const computerBackend = {
    vmManager: {
      instances: new Map([['7', { display: { websocketUrl: 'ws://127.0.0.1:16080' } }]]),
      getStatus: () => ({ state: 'ready' }),
    },
    touchActivity() {},
  };
  const manager = new RuntimeManager({ computerBackend });

  const observer = manager.createDisplaySession(7);
  assert.equal(observer.viewOnly, true);
  assert.equal(manager.resolveDisplaySession(8, observer.token), null);

  manager.acquireControl(7, 'user', 'session-7');
  assert.equal(manager.resolveDisplaySession(7, observer.token), null);
  const controlled = manager.createDisplaySession(7);
  const internal = manager.displaySessions.get(controlled.token);
  assert.equal(controlled.viewOnly, false);
  assert.equal(manager.isDisplaySessionActive(7, controlled.token, internal), true);

  manager.releaseControl(7, 'session-7');
  assert.equal(manager.isDisplaySessionActive(7, controlled.token, internal), false);
});
