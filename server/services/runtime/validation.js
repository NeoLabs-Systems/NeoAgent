'use strict';

const { getDeploymentPolicy } = require('../../utils/deployment');

function getRuntimeValidation(runtimeManager) {
  const policy = getDeploymentPolicy();
  const nodeEnvIsProd = String(process.env.NODE_ENV || '').trim().toLowerCase() === 'prod';
  const browserVmReadiness = runtimeManager?.browserBackend?.vmManager?.getReadiness?.() || null;
  const vmReadiness = browserVmReadiness || null;
  const issues = [];

  if (policy.profile === 'prod' || nodeEnvIsProd) {
    if (!browserVmReadiness) {
      issues.push('prod profile requires a working local VM runtime for browser/CLI.');
    } else if (!browserVmReadiness.ready) {
      if (!browserVmReadiness.qemuAvailable) {
        issues.push(`prod profile requires QEMU (${browserVmReadiness.qemuBinary}) to be installed for browser/CLI.`);
      }
      if (!browserVmReadiness.baseImageExists && !browserVmReadiness.downloadConfigured) {
        issues.push('prod profile requires a VM base image or a downloadable base image URL for browser/CLI.');
      }
    }
  }

  return {
    ready: issues.length === 0,
    issues,
    vm: {
      browser: vmReadiness,
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
