'use strict';

const DEPLOYMENT_MODE_SELF_HOSTED = 'self_hosted';
const DEPLOYMENT_MODE_MANAGED = 'managed';
const TERMINAL_ENV_QEMU = 'qemu';
const TERMINAL_ENV_DOCKER = 'docker';
const TERMINAL_ENV_HOST = 'host';

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

// Where every user's computer runs: a QEMU micro-VM (default), a per-user Docker
// container, or this server process itself. Only the first two isolate users
// from the host and from each other.
function parseTerminalEnv(value) {
  const normalized = String(value || '').trim().toLowerCase();
  switch (normalized) {
    case 'docker':
    case 'container':
    case 'containers':
      return TERMINAL_ENV_DOCKER;
    case 'host':
    case 'local':
    case 'server':
      return TERMINAL_ENV_HOST;
    default:
      return TERMINAL_ENV_QEMU;
  }
}

// True only where the agent genuinely runs on the server's own OS session.
function isHostTerminalEnv(env = process.env) {
  return getTerminalEnv(env) === TERMINAL_ENV_HOST;
}

function getTerminalEnv(env = process.env) {
  return parseTerminalEnv(env.TERMINAL_ENV);
}

function getAllowSignup(env = process.env) {
  const raw = String(env.NEOAGENT_ALLOW_SIGNUP ?? '').trim().toLowerCase();
  if (raw === 'false' || raw === '0' || raw === 'no') return false;
  return true;
}

function getDeploymentPolicy(env = process.env) {
  const mode = getDeploymentMode(env);
  return {
    mode,
    managed: mode === DEPLOYMENT_MODE_MANAGED,
    allowSelfUpdate: mode !== DEPLOYMENT_MODE_MANAGED,
    registrationOpen: getAllowSignup(env),
    runtimeDefaults: {
      runtime_profile: 'cloud-computer',
      runtime_backend: getTerminalEnv(env),
      computer_backend: 'cloud',
      android_backend: 'host',
      mcp_backend: 'host-remote',
    },
    allowHostRuntime: getTerminalEnv(env) === TERMINAL_ENV_HOST,
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
  TERMINAL_ENV_DOCKER,
  TERMINAL_ENV_HOST,
  TERMINAL_ENV_QEMU,
  getDeploymentInfo,
  getDeploymentMode,
  getDeploymentPolicy,
  getTerminalEnv,
  isHostTerminalEnv,
  isManagedDeployment,
  parseDeploymentMode,
  parseTerminalEnv,
};
