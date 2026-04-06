'use strict';

const { getDeploymentPolicy } = require('../../utils/deployment');

function validateGuestToken(token) {
  const value = String(token || '').trim();
  if (!value) {
    return { valid: false, reason: 'NEOAGENT_VM_GUEST_TOKEN is missing.' };
  }
  if (value.length < 32) {
    return { valid: false, reason: 'NEOAGENT_VM_GUEST_TOKEN must be at least 32 characters long.' };
  }
  if (/^(change|replace|set|your|example|sample|placeholder|token|secret)[-_a-z0-9]*$/i.test(value)) {
    return { valid: false, reason: 'NEOAGENT_VM_GUEST_TOKEN looks like a placeholder value.' };
  }
  if (/change-this-guest-token-before-prod/i.test(value)) {
    return { valid: false, reason: 'NEOAGENT_VM_GUEST_TOKEN is using the insecure example placeholder.' };
  }
  if (/^(.)\1+$/.test(value)) {
    return { valid: false, reason: 'NEOAGENT_VM_GUEST_TOKEN must not be a repeated single character.' };
  }
  return { valid: true, reason: null };
}

function getRuntimeValidation(runtimeManager) {
  const policy = getDeploymentPolicy();
  const nodeEnvIsProd = String(process.env.NODE_ENV || '').trim().toLowerCase() === 'prod';
  const vmReadiness = runtimeManager?.vmBackend?.vmManager?.getReadiness?.() || null;
  const guestToken = String(runtimeManager?.vmBackend?.token || process.env.NEOAGENT_VM_GUEST_TOKEN || '').trim();
  const guestTokenValidation = validateGuestToken(guestToken);
  const issues = [];

  if (policy.profile === 'prod' || nodeEnvIsProd) {
    if (!vmReadiness?.ready) {
      issues.push('prod profile requires a configured local VM runtime (QEMU + base image).');
    }
    if (!guestTokenValidation.valid) {
      issues.push(`prod profile requires a secure NEOAGENT_VM_GUEST_TOKEN. ${guestTokenValidation.reason}`);
    }
  }

  return {
    ready: issues.length === 0,
    issues,
    vm: vmReadiness,
    guestTokenConfigured: guestTokenValidation.valid,
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
  validateGuestToken,
};
