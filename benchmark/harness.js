'use strict';

const { NeoAgentHttpClient } = require('./http_client');
const { fetchOpenRouterCatalog, estimateRunCost, selectBenchmarkModels } = require('./model_catalog');
const { writeReportArtifacts } = require('./reporting');
const { createSuites } = require('./suites');
const { ensureDir } = require('./utils');

class BenchmarkHarness {
  constructor(config, options = {}) {
    this.config = config;
    this.client = options.client || new NeoAgentHttpClient(config.serverBaseUrl);
    this.suites = Array.isArray(options.suites) ? options.suites : createSuites(config);
    this.fetchOpenRouterCatalog = options.fetchOpenRouterCatalog || fetchOpenRouterCatalog;
    this.getSupportedModels = options.getSupportedModels || (() => this.client.getSupportedModels());
    this.writeReportArtifacts = options.writeReportArtifacts || writeReportArtifacts;
    this.estimateRunCost = options.estimateRunCost || estimateRunCost;
  }

  async setup() {
    await ensureDir(this.config.workDir);
    await ensureDir(this.config.outputDir);
    await ensureDir(this.config.rootDir);
    const suiteResults = [];
    for (const suite of this.#selectedSuites()) {
      suiteResults.push({
        suiteId: suite.id,
        ...(await suite.setup?.(this.#buildContext()) || {}),
      });
    }
    return suiteResults;
  }

  async prepareModelProvider() {
    await this.client.putSettings({
      ai_provider_configs: {
        openrouter: {
          enabled: true,
          baseUrl: this.config.openRouter.baseUrl,
        },
      },
      smarter_model_selector: false,
    });
  }

  async resolveSelectedModels() {
    const modelDrivenSuites = this.#selectedSuites().filter((suite) => suite.modelDriven === true);
    if (!modelDrivenSuites.length) return [];
    await this.prepareModelProvider();
    const [appModels, rawOpenRouterModels] = await Promise.all([
      this.getSupportedModels(),
      this.fetchOpenRouterCatalog(this.config.openRouter).catch(() => []),
    ]);
    return selectBenchmarkModels({
      appModels,
      rawOpenRouterModels,
      explicitModelIds: this.config.openRouter.explicitModelIds,
      priceTierCeiling: this.config.openRouter.priceTierCeiling,
    });
  }

  async run() {
    await ensureDir(this.config.workDir);
    await ensureDir(this.config.outputDir);
    await this.client.ensureAuthenticated(this.config.auth);
    const selectedModels = await this.resolveSelectedModels();
    this.config.selectedModels = selectedModels;
    const results = [];

    for (const suite of this.#selectedSuites()) {
      const preflight = await suite.preflight?.(this.#buildContext()) || { runnable: true };
      if (suite.modelDriven) {
        for (const model of selectedModels) {
          if (!preflight.runnable) {
            results.push(...await suite.run(this.#buildContext(), model, preflight));
            continue;
          }
          results.push(...await suite.run(this.#buildContext(), model, preflight));
        }
        continue;
      }
      if (!preflight.runnable) {
        results.push(...await suite.run(this.#buildContext(), null, preflight));
        continue;
      }
      results.push(...await suite.run(this.#buildContext(), null, preflight));
    }

    const report = await this.writeReportArtifacts({
      results,
      config: this.config,
    });
    if (this.config.failOnBlockedSuite && report.summary.totals.blocked > 0) {
      const error = new Error('One or more benchmark suites were blocked.');
      error.summary = report.summary;
      throw error;
    }
    return {
      results,
      report,
    };
  }

  async report() {
    return this.writeReportArtifacts({
      results: [],
      config: this.config,
    });
  }

  #selectedSuites() {
    return this.suites.filter((suite) => {
      if (this.config.enabledSuites[suite.id] === false) return false;
      if (Array.isArray(this.config.suiteSelection) && this.config.suiteSelection.length > 0) {
        return this.config.suiteSelection.includes(suite.id);
      }
      return true;
    });
  }

  #buildContext() {
    return {
      config: this.config,
      client: this.client,
      estimateRunCost: this.estimateRunCost,
    };
  }
}

module.exports = {
  BenchmarkHarness,
};
