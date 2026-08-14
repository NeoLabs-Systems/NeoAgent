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

function createCloudComputerBackend(session, overrides = {}) {
  return {
    async getClientForUser() { return {}; },
    async requestGuest() { return { available: true }; },
    async executeCommand() {
      return { exitCode: 0, stdout: 'DESKTOP_READY\n', stderr: '' };
    },
    async getBrowserProviderForUser() {
      return { async launch() { return {}; } };
    },
    vmManager: {
      async ensureVm() { return session; },
      instances: new Map([['7', session]]),
      getStatus: () => ({ state: session.state, desktop: session.desktop || null }),
      hasTrackedVm: () => true,
      hasVm: () => true,
    },
    ...overrides,
  };
}

test('startComputer returns when QEMU is up and does not wait for the guest desktop', async () => {
  const session = {
    state: 'starting',
    startedAt: new Date().toISOString(),
    display: { websocketUrl: 'ws://127.0.0.1:16080' },
  };
  let guestWaitStarted = false;
  const manager = new RuntimeManager({
    computerBackend: createCloudComputerBackend(session, {
      async getClientForUser() {
        guestWaitStarted = true;
        await new Promise((resolve) => setTimeout(resolve, 150));
        session.state = 'ready';
        return {};
      },
    }),
  });

  const started = Date.now();
  const status = await manager.startComputer(7);
  const elapsed = Date.now() - started;

  assert.ok(elapsed < 80, `startComputer blocked for ${elapsed}ms`);
  assert.equal(status.state, 'starting');
  assert.equal(guestWaitStarted, true);
});

test('computer startup keeps repairing the desktop after the HTTP client disconnects', async () => {
  const session = {
    state: 'starting',
    startedAt: new Date().toISOString(),
    display: { websocketUrl: 'ws://127.0.0.1:16080' },
    desktop: null,
  };
  const controller = new AbortController();
  const manager = new RuntimeManager({
    computerBackend: createCloudComputerBackend(session, {
      async requestGuest() { throw new Error('not found'); },
      async executeCommand(_userId, _command, options = {}) {
        await new Promise((resolve) => setTimeout(resolve, 40));
        if (options.signal?.aborted) {
          const error = new Error('HTTP client disconnected.');
          error.name = 'AbortError';
          throw error;
        }
        session.desktop = { available: true, error: null };
        return { exitCode: 0, stdout: 'DESKTOP_READY\n', stderr: '' };
      },
    }),
  });

  await manager.startComputer(7, { signal: controller.signal });
  controller.abort();
  await new Promise((resolve) => setTimeout(resolve, 80));

  assert.equal(session.desktop?.available, true);
});

test('cloud desktop repair does not surface SysV enable chatter as the user-facing error', async () => {
  const session = {
    startedAt: new Date().toISOString(),
    desktop: null,
  };
  const manager = new RuntimeManager({
    computerBackend: {
      async getClientForUser() { return {}; },
      async requestGuest() { throw new Error('not found'); },
      async executeCommand() {
        return {
          exitCode: 1,
          stdout: '',
          stderr: [
            'Synchronizing state of lightdm.service with SysV service script with /usr/lib/systemd/systemd-sysv-install.',
            'Executing: /usr/lib/systemd/systemd-sysv-install enable lightdm',
          ].join('\n'),
        };
      },
      vmManager: {
        instances: new Map([['7', session]]),
        getStatus: () => ({ state: 'ready', desktop: session.desktop }),
        hasTrackedVm: () => true,
      },
    },
  });
  manager._emitStatus = () => {};

  const status = await manager.ensureComputer(7);
  assert.equal(session.desktop.available, false);
  assert.equal(session.desktop.error, 'The Linux graphical session is not running.');
  assert.doesNotMatch(String(status.desktop?.error || ''), /SysV|systemd-sysv-install/);
});

test('display sessions come up even when browser launch and workspace import fail', async () => {
  const session = {
    display: { websocketUrl: 'ws://127.0.0.1:16080' },
    instanceDir: '/tmp/neoagent-computer-test',
    startedAt: new Date().toISOString(),
    state: 'starting',
  };
  const computerBackend = {
    async getClientForUser() { return {}; },
    async requestGuest() { return { available: true }; },
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
      async ensureVm() { return session; },
      instances: new Map([['7', session]]),
      getStatus: () => ({ state: session.state, desktop: session.desktop }),
      hasTrackedVm: () => true,
      hasVm: () => true,
    },
  };
  const manager = new RuntimeManager({
    computerBackend,
    workspaceManager: {
      async getWorkspaceRoot() { return '/tmp/neoagent-workspace-test'; },
    },
  });

  const status = await manager.startComputer(7);
  assert.equal(status.state, 'starting');
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

test('a display session follows the computer instead of a fixed address', () => {
  const instances = new Map([['7', { display: { websocketUrl: 'ws://127.0.0.1:16080' } }]]);
  const vmManager = { instances, getStatus: () => ({ state: 'ready' }) };
  const manager = new RuntimeManager({
    computerBackend: { vmManager, touchActivity() {} },
  });

  const display = manager.createDisplaySession(7);
  const stored = manager.displaySessions.get(display.token);
  assert.equal(stored.target, undefined);
  assert.equal(manager.getDisplayTarget(7), 'ws://127.0.0.1:16080');

  // The computer restarts and listens somewhere else.
  instances.set('7', { display: { websocketUrl: 'ws://127.0.0.1:17099' } });
  assert.equal(manager.getDisplayTarget(7), 'ws://127.0.0.1:17099');

  instances.delete('7');
  assert.equal(manager.getDisplayTarget(7), null);
});

test('viewers are dropped when the computer they watch stops', () => {
  const vmManager = {
    instances: new Map([['7', { display: { websocketUrl: 'ws://127.0.0.1:16080' } }]]),
    getStatus: () => ({ state: 'ready' }),
  };
  const manager = new RuntimeManager({
    computerBackend: { vmManager, touchActivity() {} },
  });
  const display = manager.createDisplaySession(7);
  assert.ok(manager.resolveDisplaySession(7, display.token));

  vmManager.onVmStopped('7');
  assert.equal(manager.resolveDisplaySession(7, display.token), null);
});

test('a connected display session does not expire underneath the viewer', () => {
  const computerBackend = {
    vmManager: {
      instances: new Map([['7', { display: { websocketUrl: 'ws://127.0.0.1:16080' } }]]),
      getStatus: () => ({ state: 'ready' }),
    },
    touchActivity() {},
  };
  const manager = new RuntimeManager({ computerBackend });
  const display = manager.createDisplaySession(7);
  const internal = manager.displaySessions.get(display.token);

  internal.expiresAt = Date.now() - 1000;
  assert.equal(manager.resolveDisplaySession(7, display.token), null);

  const revived = manager.createDisplaySession(7);
  const live = manager.displaySessions.get(revived.token);
  live.expiresAt = Date.now() + 1000;
  manager.touchDisplaySession(live);
  assert.ok(live.expiresAt > Date.now() + 60_000);
  assert.equal(manager.isDisplaySessionActive(7, revived.token, live), true);
});
