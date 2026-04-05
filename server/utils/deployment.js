'use strict';

const DEPLOYMENT_MODE_SELF_HOSTED = 'self_hosted';
const DEPLOYMENT_MODE_MANAGED = 'managed';

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

function isManagedDeployment(env = process.env) {
  return getDeploymentMode(env) === DEPLOYMENT_MODE_MANAGED;
}

function getDeploymentInfo(env = process.env) {
  const mode = getDeploymentMode(env);
  return {
    mode,
    managed: mode === DEPLOYMENT_MODE_MANAGED,
    allowSelfUpdate: mode !== DEPLOYMENT_MODE_MANAGED,
  };
}

module.exports = {
  DEPLOYMENT_MODE_MANAGED,
  DEPLOYMENT_MODE_SELF_HOSTED,
  getDeploymentInfo,
  getDeploymentMode,
  isManagedDeployment,
  parseDeploymentMode,
};
