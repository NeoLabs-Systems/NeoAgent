'use strict';

const {
  TERMINAL_ENV_DOCKER,
  TERMINAL_ENV_HOST,
  getDeploymentPolicy,
  getTerminalEnv,
} = require('../../utils/deployment');

const RUNTIME_UNAVAILABLE = Object.freeze({
  [TERMINAL_ENV_DOCKER]: 'The container computer runtime needs a reachable Docker daemon. Run neoagent repair.',
  [TERMINAL_ENV_HOST]: 'The host computer runtime is unavailable.',
});
const DEFAULT_RUNTIME_UNAVAILABLE = 'The QEMU computer runtime is not installed. Run neoagent repair.';

function getRuntimeValidation(runtimeManager) {
  const terminalEnv = getTerminalEnv();
  const computerReadiness = runtimeManager?.computerBackend?.vmManager?.getReadiness?.() || null;
  const issues = [];
  const warnings = [];

  // Every deployment needs a computer its agents can actually run on, so the
  // check is the same everywhere rather than gated on how the install is used.
  if (!computerReadiness) {
    issues.push('The computer runtime is not available.');
  } else if (!computerReadiness.ready) {
    issues.push(RUNTIME_UNAVAILABLE[terminalEnv] || DEFAULT_RUNTIME_UNAVAILABLE);
  }

  // TERMINAL_ENV=host is a deliberate operator choice, so it never blocks the
  // server. It does remove the boundary the other two runtimes provide, which
  // is worth saying out loud on every start.
  if (terminalEnv === TERMINAL_ENV_HOST) {
    warnings.push(
      `TERMINAL_ENV=host: every account's agent runs directly on ${computerReadiness?.host || 'this server'} `
      + "as the server's own OS user, with no isolation between accounts or from the host. "
      + 'Only sign in accounts you would trust with a shell on this machine.',
    );
  }

  return {
    ready: issues.length === 0,
    issues,
    warnings,
    vm: {
      computer: computerReadiness,
      android: null,
    },
    guestTokenConfigured: true,
    policy: getDeploymentPolicy(),
  };
}

module.exports = {
  getRuntimeValidation,
};
