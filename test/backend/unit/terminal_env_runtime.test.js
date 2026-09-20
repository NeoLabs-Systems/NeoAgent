'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  TERMINAL_ENV_DOCKER,
  TERMINAL_ENV_HOST,
  TERMINAL_ENV_QEMU,
  getDeploymentPolicy,
  parseTerminalEnv,
} = require('../../../server/utils/deployment');
const { VmStartTracker } = require('../../../server/services/runtime/vm_session');
const { dockerfileFor } = require('../../../server/services/runtime/guest_image');
const {
  DockerVMManager,
  containerName,
  homeVolumeName,
} = require('../../../server/services/runtime/docker_vm_manager');
const { GUEST_HOME } = require('../../../server/services/runtime/guest_paths');
const { DesktopCompanionRegistry } = require('../../../server/services/desktop/registry');

function withTerminalEnv(value, run) {
  const previous = process.env.TERMINAL_ENV;
  if (value === undefined) delete process.env.TERMINAL_ENV;
  else process.env.TERMINAL_ENV = value;
  try {
    return run();
  } finally {
    if (previous === undefined) delete process.env.TERMINAL_ENV;
    else process.env.TERMINAL_ENV = previous;
  }
}

test('TERMINAL_ENV selects the runtime and defaults to QEMU', () => {
  assert.equal(parseTerminalEnv('docker'), TERMINAL_ENV_DOCKER);
  assert.equal(parseTerminalEnv('DOCKER'), TERMINAL_ENV_DOCKER);
  assert.equal(parseTerminalEnv('containers'), TERMINAL_ENV_DOCKER);
  assert.equal(parseTerminalEnv('host'), TERMINAL_ENV_HOST);
  assert.equal(parseTerminalEnv('local'), TERMINAL_ENV_HOST);
  assert.equal(parseTerminalEnv('server'), TERMINAL_ENV_HOST);
  assert.equal(parseTerminalEnv(''), TERMINAL_ENV_QEMU);
  assert.equal(parseTerminalEnv(undefined), TERMINAL_ENV_QEMU);
  assert.equal(parseTerminalEnv('nonsense'), TERMINAL_ENV_QEMU);
  assert.equal(
    getDeploymentPolicy({ TERMINAL_ENV: 'docker' }).runtimeDefaults.runtime_backend,
    'docker',
  );
  // The host runtime is the only one that puts the agent on the server itself.
  assert.equal(getDeploymentPolicy({ TERMINAL_ENV: 'host' }).allowHostRuntime, true);
  assert.equal(getDeploymentPolicy({ TERMINAL_ENV: 'docker' }).allowHostRuntime, false);
  assert.equal(getDeploymentPolicy({}).allowHostRuntime, false);
});

test('the runtime factory builds the backend TERMINAL_ENV names', () => {
  const {
    createComputerBackend,
    createComputerVmManager,
  } = require('../../../server/services/runtime/backend_factory');
  withTerminalEnv('docker', () => {
    assert.equal(createComputerVmManager().constructor.name, 'DockerVMManager');
    assert.equal(createComputerBackend().constructor.name, 'LocalVmExecutionBackend');
  });
  withTerminalEnv(undefined, () => {
    assert.equal(createComputerVmManager().constructor.name, 'QemuVMManager');
    assert.equal(createComputerBackend().constructor.name, 'LocalVmExecutionBackend');
  });
  withTerminalEnv('host', () => {
    // Nothing to boot, so there is no guest manager to build.
    assert.equal(createComputerVmManager(), null);
    const backend = createComputerBackend({ desktopCompanionRegistry: new DesktopCompanionRegistry() });
    assert.equal(backend.constructor.name, 'LocalComputerBackend');
    // Only a guest VM owns a Linux desktop session to bring up and repair.
    assert.notEqual(backend.providesGuestDesktop, true);
  });
});

test('the host runtime reports itself ready but unisolated, with shell and files only', () => {
  withTerminalEnv('host', () => {
    const { createComputerBackend } = require('../../../server/services/runtime/backend_factory');
    const backend = createComputerBackend({ desktopCompanionRegistry: new DesktopCompanionRegistry() });
    const readiness = backend.vmManager.getReadiness();
    assert.equal(readiness.ready, true);
    assert.equal(readiness.isolated, false);
    assert.deepEqual(readiness.missing, []);
    assert.deepEqual(backend.getStatus('1').capabilities, ['shell', 'files']);
  });
});

test('the host runtime warns instead of blocking, and only it warns', () => {
  const { getRuntimeValidation } = require('../../../server/services/runtime/validation');
  const hostManager = {
    computerBackend: { vmManager: { getReadiness: () => ({ ready: true, isolated: false, host: 'example-host' }) } },
  };
  withTerminalEnv('host', () => {
    const validation = getRuntimeValidation(hostManager);
    assert.equal(validation.ready, true);
    assert.deepEqual(validation.issues, []);
    assert.equal(validation.warnings.length, 1);
    assert.match(validation.warnings[0], /example-host/);
    assert.match(validation.warnings[0], /no isolation|not in an isolated computer/);
  });
  withTerminalEnv(undefined, () => {
    assert.deepEqual(getRuntimeValidation(hostManager).warnings, []);
  });
});

test('per-user Docker names never contain the user ID', () => {
  const userId = 'user@example.com';
  for (const name of [containerName(userId), homeVolumeName(userId)]) {
    assert.doesNotMatch(name, /user@example\.com/);
    assert.match(name, /^neoagent-[a-z]+-[0-9a-f]{24}$/);
  }
  assert.notEqual(containerName('1'), containerName('2'));
  assert.equal(containerName('1'), containerName('1'));
});

test('the guest image bakes in dependencies and keeps the guest home writable', () => {
  const dockerfile = dockerfileFor('browser_cli');
  assert.match(dockerfile, /npx playwright install --with-deps chromium/);
  assert.match(dockerfile, /touch \/var\/lib\/neoagent\/browser-runtime-ready/);
  assert.ok(dockerfile.includes(`chmod -R 0777 ${GUEST_HOME}`));
  assert.ok(dockerfile.includes('CMD ["node", "server/guest_agent.js"]'));
  // The CLI profile carries no browser, so it must not pull Chromium in.
  assert.doesNotMatch(dockerfileFor('cli'), /playwright/);
});

test('the Docker runtime reports itself unready without a Docker daemon', async () => {
  const manager = new DockerVMManager({
    imageBuilder: { getState: () => ({ dockerAvailable: false, imageBuilt: false, image: null }) },
  });
  const readiness = manager.getReadiness();
  assert.equal(readiness.ready, false);
  assert.deepEqual(readiness.missing, ['docker']);
  assert.equal(manager.getStatus('7').state, 'stopped');
  await assert.rejects(
    manager.prepareRuntime(),
    (error) => error.code === 'COMPUTER_RUNTIME_UNAVAILABLE' && error.status === 503,
  );
  await assert.rejects(
    manager.ensureVm('7'),
    (error) => error.code === 'COMPUTER_RUNTIME_UNAVAILABLE',
  );
  assert.equal(manager.getStatus('7').state, 'error');
});

test('a start is shared by concurrent callers and its failure becomes status', async () => {
  const tracker = new VmStartTracker();
  let starts = 0;
  const slowStart = () => {
    starts += 1;
    return new Promise((resolve) => setTimeout(() => resolve({ ok: true }), 20));
  };
  const [first, second] = await Promise.all([
    tracker.begin('u', slowStart),
    tracker.begin('u', slowStart),
  ]);
  assert.equal(starts, 1);
  assert.equal(first, second);
  assert.equal(tracker.status('u'), null);

  const capacity = Object.assign(new Error('No capacity.'), { code: 'COMPUTER_CAPACITY' });
  await assert.rejects(tracker.begin('u', () => Promise.reject(capacity)));
  assert.equal(tracker.status('u').state, 'capacity_wait');

  await assert.rejects(tracker.begin('u', () => Promise.reject(new Error('boom'))));
  assert.equal(tracker.status('u').state, 'error');
  assert.equal(tracker.status('u').error, 'boom');

  tracker.sleep('u');
  assert.equal(tracker.status('u').state, 'sleeping');
  tracker.clear('u');
  assert.equal(tracker.status('u'), null);
});
