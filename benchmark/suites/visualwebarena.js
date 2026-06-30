'use strict';

const { cloneRepoIfMissing, commandExists, missingPrerequisiteResult, writeSuiteManifest } = require('./shared');

function buildVisualWebArenaSuite(config) {
  const suitePaths = config.suitePaths.visualwebarena;
  return {
    id: 'visualwebarena',
    label: 'VisualWebArena',
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
          reason: 'VisualWebArena requires Docker-backed benchmark infrastructure, and Docker is not installed on this machine.',
        };
      }
      return {
        runnable: false,
        reason: suitePaths.runnerCommand
          ? 'VisualWebArena exact execution is delegated to an external runner command and must be configured against the official environment.'
          : 'VisualWebArena requires an official benchmark environment and runner command.',
      };
    },

    async run(_context, model, preflight) {
      if (model?.supportsVision !== true) {
        return [missingPrerequisiteResult(this, 'This OpenRouter model is not confirmed to support image input.', model)];
      }
      return [missingPrerequisiteResult(this, preflight.reason, model)];
    },
  };
}

module.exports = {
  buildVisualWebArenaSuite,
};
