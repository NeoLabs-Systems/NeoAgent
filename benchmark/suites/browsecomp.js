'use strict';

const { cloneRepoIfMissing, missingPrerequisiteResult, writeSuiteManifest } = require('./shared');

function buildBrowseCompSuite(config) {
  const suitePaths = config.suitePaths.browsecomp;
  return {
    id: 'browsecomp',
    label: 'BrowseComp',
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
        casesPath: suitePaths.casesPath,
      });
      return { suiteId: this.id, repoDir: suitePaths.repoDir };
    },

    async preflight() {
      return {
        runnable: false,
        reason: suitePaths.runnerCommand
          ? 'BrowseComp exact execution is delegated to an external runner command and must be configured against the official evaluator.'
          : 'BrowseComp needs an official evaluator runner command plus exact case extraction from openai/simple-evals.',
      };
    },

    async run(_context, model, preflight) {
      return [missingPrerequisiteResult(this, preflight.reason, model)];
    },
  };
}

module.exports = {
  buildBrowseCompSuite,
};
