'use strict';

const {
  TERMINAL_ENV_DOCKER,
  TERMINAL_ENV_HOST,
  getTerminalEnv,
} = require('../../utils/deployment');

// The one place that turns TERMINAL_ENV into a computer runtime. The server and
// the CLI both go through it, so a deployment never ends up with the server
// running containers while `neoagent repair` provisions a QEMU guest image.

// The guest technology behind an isolated computer, or null for TERMINAL_ENV=host,
// which runs on the server's own OS session and has no guest to manage.
function createComputerVmManager(options = {}) {
  switch (getTerminalEnv()) {
    case TERMINAL_ENV_HOST:
      return null;
    case TERMINAL_ENV_DOCKER: {
      const { DockerVMManager } = require('./docker_vm_manager');
      return new DockerVMManager(options);
    }
    default: {
      const { QemuVMManager } = require('./qemu_vm_manager');
      return new QemuVMManager(options);
    }
  }
}

// The execution backend every user's computer runs on. QEMU and Docker differ
// only in the guest they boot, so both take the same VM-backed backend; the host
// runtime reuses the desktop-companion backend with this process registered as
// the companion, which is the same path the desktop app already takes.
function createComputerBackend(options = {}) {
  if (getTerminalEnv() === TERMINAL_ENV_HOST) {
    const { LocalComputerBackend } = require('./backends/local-computer');
    const { HostCompanionRegistrar } = require('../desktop/host_companion');
    return new LocalComputerBackend({
      registry: options.desktopCompanionRegistry,
      artifactStore: options.artifactStore,
      companionRegistrar: new HostCompanionRegistrar({
        registry: options.desktopCompanionRegistry,
        workspaceManager: options.workspaceManager,
      }),
    });
  }
  const { LocalVmExecutionBackend } = require('./backends/local-vm');
  return new LocalVmExecutionBackend({
    runtimeProfile: 'browser_cli',
    vmManager: options.vmManager || createComputerVmManager(),
    artifactStore: options.artifactStore,
  });
}

module.exports = { createComputerBackend, createComputerVmManager };
