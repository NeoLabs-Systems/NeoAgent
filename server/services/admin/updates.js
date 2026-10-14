'use strict';

const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
const { APP_DIR, LOG_DIR, ensureRuntimeDirs } = require('../../../runtime/paths');
const { getDeploymentPolicy } = require('../../utils/deployment');
const { readUpdateStatus, writeUpdateStatusFile } = require('../../utils/update_status');
const {
  parseReleaseChannel,
  writeReleaseChannelToEnvFile,
  getReleaseChannelBranchPolicy,
} = require('../../../runtime/release_channel');
const { createServiceLogger } = require('../../utils/logger');
const logger = createServiceLogger('Updates');

function assertUpdateAllowed() {
  const policy = getDeploymentPolicy();
  if (!policy.allowSelfUpdate) {
    const error = new Error(policy.managed
      ? 'Updates are managed by this deployment.'
      : 'This NeoAgent runs from a container image. Update it by pulling a newer image.');
    error.status = 403;
    throw error;
  }
  if (readUpdateStatus().state === 'running') {
    const error = new Error('An update is already running. Wait for it to finish before changing the channel or starting another update.');
    error.status = 409;
    throw error;
  }
}

async function startUpdate() {
  assertUpdateAllowed();
  ensureRuntimeDirs();
  writeUpdateStatusFile({
    state: 'running', progress: 1, phase: 'starting', message: 'Launching update job',
    startedAt: new Date().toISOString(), completedAt: null,
    versionBefore: null, versionAfter: null, runnerPid: process.pid,
    releaseChannel: null, targetBranch: null, changelog: [], logs: [],
  });
  let output;
  try {
    output = fs.openSync(path.join(LOG_DIR, 'update.log'), 'a', 0o600);
    const runner = path.join(APP_DIR, 'lib', 'cli', 'update_runner.js');
    // A detached process still belongs to its parent's systemd cgroup. Run in
    // a separate scope so stopping NeoAgent cannot kill its own updater.
    const inSystemd = process.platform === 'linux' && Boolean(process.env.INVOCATION_ID);
    const command = inSystemd ? 'systemd-run' : process.execPath;
    const args = inSystemd
      ? ['--user', '--scope', '--quiet', '--collect', process.execPath, runner]
      : [runner];
    const child = spawn(command, args, {
      cwd: APP_DIR, detached: true, stdio: ['ignore', output, output],
    });
    await new Promise((resolve, reject) => {
      child.once('error', reject);
      child.once('spawn', () => {
        if (readUpdateStatus().runnerPid === process.pid) {
          writeUpdateStatusFile({ runnerPid: child.pid });
        }
        resolve();
      });
    });
    child.unref();
    logger.info('Update job launched');
    return { success: true, ...readUpdateStatus() };
  } catch (error) {
    logger.error('Failed to launch update job:', error);
    writeUpdateStatusFile({
      state: 'failed', phase: 'failed', runnerPid: null,
      message: `Failed to launch update job: ${error.message}`,
      completedAt: new Date().toISOString(),
    });
    throw error;
  } finally {
    if (output !== undefined) fs.closeSync(output);
  }
}

function setUpdateChannel(requested) {
  assertUpdateAllowed();
  const releaseChannel = parseReleaseChannel(requested);
  if (!releaseChannel) {
    const error = new Error('Release channel must be "stable" or "beta".');
    error.status = 400;
    throw error;
  }
  writeReleaseChannelToEnvFile(releaseChannel);
  process.env.NEOAGENT_RELEASE_CHANNEL = releaseChannel;
  return { success: true, releaseChannel, targetBranch: getReleaseChannelBranchPolicy(releaseChannel) };
}

module.exports = { startUpdate, setUpdateChannel };
