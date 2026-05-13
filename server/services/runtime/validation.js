'use strict';

const { getDeploymentPolicy } = require('../../utils/deployment');

function getRuntimeValidation(runtimeManager) {
  const policy = getDeploymentPolicy();
  const nodeEnvIsProd = String(process.env.NODE_ENV || '').trim().toLowerCase() === 'prod';
  const vmReadiness = runtimeManager?.vmBackend?.vmManager?.getReadiness?.() || null;
  const issues = [];

  if (policy.profile === 'prod' || nodeEnvIsProd) {
    if (!vmReadiness?.ready) {
      if (!vmReadiness) {
        issues.push('prod profile requires a working local VM runtime.');
      } else {
        if (!vmReadiness.qemuAvailable) {
          issues.push(`prod profile requires QEMU (${vmReadiness.qemuBinary}) to be installed.`);
        }
        if (!vmReadiness.baseImageExists && !vmReadiness.downloadConfigured) {
          issues.push('prod profile requires a VM base image or a downloadable base image URL.');
        }
      }
    }
  }

  return {
    ready: issues.length === 0,
    issues,
    vm: vmReadiness,
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
