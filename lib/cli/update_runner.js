'use strict';

// The admin UI uses the same backup, installation, rollback and health checks
// as `neoagent update`. This process must outlive the server it restarts.
const { readUpdateStatus, writeUpdateStatusFile } = require('../../server/utils/update_status');
const { formatLogArgs } = require('../../server/utils/logger');
const { readConfiguredReleaseChannel } = require('../../runtime/release_channel');

async function main() {
  writeUpdateStatusFile({ runnerPid: process.pid });
  const { cmdUpdate } = require('../manager');
  const result = await cmdUpdate([readConfiguredReleaseChannel()], {
    onProgress(patch) {
      const status = readUpdateStatus();
      writeUpdateStatusFile({
        ...patch,
        state: 'running',
        runnerPid: process.pid,
        logs: [...status.logs, `${new Date().toISOString()} ${patch.message}`].slice(-220),
      });
    },
  });
  writeUpdateStatusFile({
    ...result,
    state: 'completed',
    progress: 100,
    phase: 'completed',
    completedAt: new Date().toISOString(),
    runnerPid: null,
  });
}

main().catch((error) => {
  writeUpdateStatusFile({
    state: 'failed',
    phase: 'failed',
    message: formatLogArgs([error.message]),
    completedAt: new Date().toISOString(),
    runnerPid: null,
  });
  process.exitCode = 1;
});
