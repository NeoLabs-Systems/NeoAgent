'use strict';

const { TERMINAL_ENV_DOCKER, getTerminalEnv } = require('../../utils/deployment');

// The one place that turns TERMINAL_ENV into a computer runtime. Both the server
// and the CLI go through it so a deployment never ends up with the server running
// containers while `neoagent repair` provisions a QEMU guest image.
function createComputerVmManager(options = {}) {
  if (getTerminalEnv() === TERMINAL_ENV_DOCKER) {
    const { DockerVMManager } = require('./docker_vm_manager');
    return new DockerVMManager(options);
  }
  const { QemuVMManager } = require('./qemu_vm_manager');
  return new QemuVMManager(options);
}

module.exports = { createComputerVmManager };
