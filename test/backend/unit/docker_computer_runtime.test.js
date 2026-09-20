'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  TERMINAL_ENV_DOCKER,
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

test('TERMINAL_ENV selects the container runtime and defaults to QEMU', () => {
  assert.equal(parseTerminalEnv('docker'), TERMINAL_ENV_DOCKER);
  assert.equal(parseTerminalEnv('DOCKER'), TERMINAL_ENV_DOCKER);
  assert.equal(parseTerminalEnv('containers'), TERMINAL_ENV_DOCKER);
  assert.equal(parseTerminalEnv(''), TERMINAL_ENV_QEMU);
  assert.equal(parseTerminalEnv(undefined), TERMINAL_ENV_QEMU);
  assert.equal(parseTerminalEnv('nonsense'), TERMINAL_ENV_QEMU);
  assert.equal(
    getDeploymentPolicy({ TERMINAL_ENV: 'docker' }).runtimeDefaults.runtime_backend,
    'docker',
  );
});

test('the runtime factory builds the manager TERMINAL_ENV names', () => {
  const { createComputerVmManager } = require('../../../server/services/runtime/vm_manager');
  withTerminalEnv('docker', () => {
    assert.equal(createComputerVmManager().constructor.name, 'DockerVMManager');
  });
  withTerminalEnv(undefined, () => {
    assert.equal(createComputerVmManager().constructor.name, 'QemuVMManager');
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
