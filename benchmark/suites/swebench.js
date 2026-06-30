'use strict';

const { cloneRepoIfMissing, commandExists, missingPrerequisiteResult, writeSuiteManifest } = require('./shared');

function buildSweBenchSuite(config) {
  const suitePaths = config.suitePaths.swebench;
  return {
    id: 'swebench',
    label: 'SWE-bench',
    benchmarkType: 'public',
    modelDriven: true,
    sourceUrl: suitePaths.sourceUrl,

    async setup() {
      if (config.allowSetupDownloads) {
        await cloneRepoIfMissing(suitePaths.repoUrl, suitePaths.repoDir);
      }
      await writeSuiteManifest(suitePaths.manifestPath, {
        suiteId: this.id,
        sourceUrl: suitePaths.sourceUrl,
        repoUrl: suitePaths.repoUrl,
        repoDir: suitePaths.repoDir,
        runnerCommand: suitePaths.runnerCommand || null,
      });
      return { suiteId: this.id, repoDir: suitePaths.repoDir };
    },

    async preflight() {
      const dockerInstalled = await commandExists('docker');
      if (!dockerInstalled) {
        return {
          runnable: false,
          reason: 'SWE-bench exact execution requires Docker, and Docker is not installed on this machine.',
        };
      }
      return {
        runnable: false,
        reason: suitePaths.runnerCommand
          ? 'SWE-bench exact execution is delegated to an external runner command and must be configured against the official environment.'
          : 'SWE-bench needs an official runner command plus Dockerized benchmark infrastructure.',
      };
    },

    async run(_context, model, preflight) {
      return [missingPrerequisiteResult(this, preflight.reason, model)];
    },
  };
}

module.exports = {
  buildSweBenchSuite,
};
