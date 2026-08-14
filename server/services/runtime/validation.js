'use strict';

const { getDeploymentPolicy } = require('../../utils/deployment');

function getRuntimeValidation(runtimeManager) {
  const policy = getDeploymentPolicy();
  const nodeEnvIsProd = String(process.env.NODE_ENV || '').trim().toLowerCase() === 'prod';
  const computerReadiness = runtimeManager?.computerBackend?.vmManager?.getReadiness?.() || null;
  const issues = [];

  if (policy.profile === 'prod' || nodeEnvIsProd) {
    if (!computerReadiness) {
      issues.push('prod profile requires the isolated cloud computer runtime.');
    } else if (!computerReadiness.qemuAvailable) {
      issues.push('prod profile requires the CLI-managed QEMU computer runtime. Run neoagent repair.');
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

function assertRuntimeValidation(runtimeManager) {
  const validation = getRuntimeValidation(runtimeManager);
  if (!validation.ready) {
    throw new Error(validation.issues.join(' '));
  }
  return validation;
}

module.exports = {
  assertRuntimeValidation,
  getRuntimeValidation,
};
