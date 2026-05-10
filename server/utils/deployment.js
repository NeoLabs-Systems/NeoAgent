'use strict';

const DEPLOYMENT_MODE_SELF_HOSTED = 'self_hosted';
const DEPLOYMENT_MODE_MANAGED = 'managed';
const DEPLOYMENT_PROFILE_PRIVATE = 'private';
const DEPLOYMENT_PROFILE_PROD = 'prod';

function parseDeploymentMode(value) {
  const normalized = String(value || '').trim().toLowerCase();
  switch (normalized) {
    case 'managed':
    case 'saas':
    case 'hosted':
    case 'cloud':
      return DEPLOYMENT_MODE_MANAGED;
    case 'self':
    case 'selfhosted':
    case 'self_hosted':
    case 'self-hosted':
    case '':
      return DEPLOYMENT_MODE_SELF_HOSTED;
    default:
      return DEPLOYMENT_MODE_SELF_HOSTED;
  }
}

function getDeploymentMode(env = process.env) {
  return parseDeploymentMode(env.NEOAGENT_DEPLOYMENT_MODE);
}

function parseDeploymentProfile(value) {
  const normalized = String(value || '').trim().toLowerCase();
  switch (normalized) {
    case 'prod':
    case 'production':
    case 'multi':
    case 'multi-user':
    case 'multi_user':
      return DEPLOYMENT_PROFILE_PROD;
    case 'private':
    case 'personal':
    case 'single':
    case 'single-user':
    case 'single_user':
      return DEPLOYMENT_PROFILE_PRIVATE;
    case '':
      return DEPLOYMENT_PROFILE_PROD;
    default:
      return DEPLOYMENT_PROFILE_PROD;
  }
}

function getDeploymentProfile(env = process.env) {
  return parseDeploymentProfile(env.NEOAGENT_PROFILE);
}

function getDeploymentPolicy(env = process.env) {
  const profile = getDeploymentProfile(env);
  const mode = getDeploymentMode(env);
  const isProdProfile = profile === DEPLOYMENT_PROFILE_PROD;
  return {
    mode,
    profile,
    managed: mode === DEPLOYMENT_MODE_MANAGED,
    allowSelfUpdate: mode !== DEPLOYMENT_MODE_MANAGED,
    registrationOpen: isProdProfile,
    runtimeDefaults: {
      runtime_profile: isProdProfile ? 'secure-vm' : 'trusted-host',
      runtime_backend: isProdProfile ? 'vm' : 'host',
      browser_backend: 'vm',
      android_backend: isProdProfile ? 'vm' : 'host',
      mcp_backend: 'host-remote',
    },
    allowHostRuntime: !isProdProfile,
  };
}

function isManagedDeployment(env = process.env) {
  return getDeploymentMode(env) === DEPLOYMENT_MODE_MANAGED;
}

function getDeploymentInfo(env = process.env) {
  return getDeploymentPolicy(env);
}

module.exports = {
  DEPLOYMENT_MODE_MANAGED,
  DEPLOYMENT_MODE_SELF_HOSTED,
  DEPLOYMENT_PROFILE_PRIVATE,
  DEPLOYMENT_PROFILE_PROD,
  getDeploymentInfo,
  getDeploymentMode,
  getDeploymentPolicy,
  getDeploymentProfile,
  isManagedDeployment,
  parseDeploymentMode,
  parseDeploymentProfile,
};
