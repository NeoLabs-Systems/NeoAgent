'use strict';

const { TERMINAL_ENV_DOCKER, getDeploymentPolicy, getTerminalEnv } = require('../../utils/deployment');

function getRuntimeValidation(runtimeManager) {
  const policy = getDeploymentPolicy();
  const nodeEnvIsProd = String(process.env.NODE_ENV || '').trim().toLowerCase() === 'prod';
  const computerReadiness = runtimeManager?.computerBackend?.vmManager?.getReadiness?.() || null;
  const issues = [];

  if (policy.profile === 'prod' || nodeEnvIsProd) {
    if (!computerReadiness) {
      issues.push('prod profile requires the isolated cloud computer runtime.');
    } else if (!computerReadiness.ready) {
      issues.push(getTerminalEnv() === TERMINAL_ENV_DOCKER
        ? 'prod profile requires a reachable Docker daemon for the container computer runtime. Run neoagent repair.'
        : 'prod profile requires the CLI-managed QEMU computer runtime. Run neoagent repair.');
    }
  }

  return {
    ready: issues.length === 0,
    issues,
    vm: {
      computer: computerReadiness,
      android: null,
    },
    guestTokenConfigured: true,
    policy,
  };
}

module.exports = {
  getRuntimeValidation,
};
