'use strict';

// The admin UI runs the same update as `neoagent update`: same backup,
// install, rollback and health check. This process outlives the server it
// restarts, and reports through the status file the UI polls.

const { appendUpdateLog, writeUpdateStatus } = require('../../server/utils/update_status');
const { readConfiguredReleaseChannel } = require('../../runtime/release_channel');
const { withToolPath } = require('./service_path');

// Before the manager loads: it reads the environment once.
process.env.PATH = withToolPath().PATH;

async function main() {
  writeUpdateStatus({ runnerPid: process.pid });
  const { cmdUpdate } = require('../manager');
  const result = await cmdUpdate([readConfiguredReleaseChannel()], {
    onProgress(patch) {
      writeUpdateStatus({ ...patch, state: 'running', runnerPid: process.pid });
      if (patch.message) appendUpdateLog(patch.message);
    },
  });
  writeUpdateStatus({
    ...result,
    state: 'completed',
    progress: 100,
    phase: 'completed',
    completedAt: new Date().toISOString(),
    runnerPid: null,
  });
}

main().catch((error) => {
  writeUpdateStatus({
    state: 'failed',
    phase: 'failed',
    message: String(error.message || error),
    rolledBack: error.code === 'UPDATE_ROLLED_BACK',
    completedAt: new Date().toISOString(),
    runnerPid: null,
  });
  process.exitCode = 1;
});
