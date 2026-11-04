'use strict';

const { buildGuestGitEnv } = require('../../../integrations/github/git_proxy');

const handlers = {
  async execute_command(args, ctx) {
    const { agentId, deviceTarget, integrations, runId, runtime, signal, stepId, userId } = ctx;
    const runtimeManager = runtime();
    if (!runtimeManager) {
    return { error: 'Command execution is unavailable. No runtime manager found.' };
    }
    const timeout = args.timeout || (args.pty ? 20 * 60 * 1000 : 15 * 60 * 1000);
    const guestHost = runtimeManager.getGuestHostAddress(userId, { deviceTarget });
    const integrationManager = integrations();
    const execOptions = {
    cwd: args.cwd,
    timeout,
    env: guestHost && integrationManager
      ? buildGuestGitEnv({ integrationManager, userId, agentId, runId, guestHost, ttlMs: timeout })
      : null,
    stdinInput: args.stdin_input,
    pty: args.pty === true,
    inputs: Array.isArray(args.inputs) ? args.inputs : [],
    runId,
    stepId,
    signal,
    deviceTarget,
    };
    try {
    if (typeof runtimeManager.executeCliCommand === 'function') {
      return await runtimeManager.executeCliCommand(userId, args.command, execOptions);
    }
    // Legacy fallback — older runtime manager without CLI routing.
    if (typeof runtimeManager.executeCommand !== 'function') {
      return { error: 'Command execution is unavailable. VM runtime is required.' };
    }
    return { ...await runtimeManager.executeCommand(userId, args.command, execOptions), backend: 'vm' };
    } catch (err) {
    const message = String(err?.message || err);
    return {
      error: message,
      stderr: message,
      stdout: '',
      exitCode: null,
      timedOut: false,
      killed: false,
    };
    }
  },
};

module.exports = { handlers };
