'use strict';

const { getDeploymentPolicy } = require('../../utils/deployment');

function getRuntimeValidation(runtimeManager) {
  const policy = getDeploymentPolicy();
  const nodeEnvIsProd = String(process.env.NODE_ENV || '').trim().toLowerCase() === 'prod';
  const browserVmReadiness = runtimeManager?.browserBackend?.vmManager?.getReadiness?.() || null;
  const cliVmReadiness = runtimeManager?.cliBackend?.vmManager?.getReadiness?.() || null;
  const issues = [];

  if (policy.profile === 'prod' || nodeEnvIsProd) {
    if (!browserVmReadiness || !cliVmReadiness) {
      issues.push('prod profile requires working isolated container runtimes for browser and CLI.');
    } else if (!browserVmReadiness.dockerAvailable || !cliVmReadiness.dockerAvailable) {
      issues.push('prod profile requires Docker to be installed and running for the browser and CLI runtimes.');
    }
  }

  return {
    ready: issues.length === 0,
    issues,
    vm: {
      browser: browserVmReadiness,
      cli: cliVmReadiness,
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
