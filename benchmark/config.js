'use strict';

const path = require('node:path');

const REPO_ROOT = path.resolve(__dirname, '..');

const DEFAULT_BENCHMARK_USER = Object.freeze({
  usernamePrefix: 'neoagent_benchmark_locomo',
  // Must pass evaluatePasswordStrength (server/services/account/password_policy.js):
  // "neoagent" is itself on the common-pattern blocklist, so it can't appear here.
  password: 'Kv9$mRt2Lp!Wq5',
  emailDomain: 'neoagent-benchmark.example.com',
});

function parseBoolean(value, fallback) {
  const normalized = String(value || '').trim().toLowerCase();
  if (!normalized) return fallback;
  if (['1', 'true', 'yes', 'on'].includes(normalized)) return true;
  if (['0', 'false', 'no', 'off'].includes(normalized)) return false;
  return fallback;
}

function parseNonNegativeInteger(value, fallback) {
  const parsed = Number.parseInt(value, 10);
  return Number.isInteger(parsed) && parsed >= 0 ? parsed : fallback;
}

function parsePositiveInteger(value, fallback) {
  const parsed = Number.parseInt(value, 10);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
}

function resolveBenchmarkConfig(overrides = {}) {
  const benchmarkDir = path.resolve(overrides.benchmarkDir || __dirname);
  const rootDir = path.resolve(overrides.rootDir || REPO_ROOT);
  const workDir = path.resolve(overrides.workDir || path.join(benchmarkDir, 'workdir'));
  const outputDir = path.resolve(overrides.outputDir || path.join(benchmarkDir, 'results'));

  const config = {
    rootDir,
    benchmarkDir,
    workDir,
    outputDir,
    serverBaseUrl: String(process.env.NEOAGENT_BENCHMARK_BASE_URL || 'http://127.0.0.1:3333').trim(),
    benchmarkUser: DEFAULT_BENCHMARK_USER,
    openRouter: {
      provider: 'openrouter',
      baseUrl: String(process.env.OPENROUTER_BASE_URL || 'https://openrouter.ai/api/v1').trim(),
      apiKey: String(process.env.OPENROUTER_API_KEY || '').trim(),
      priceTierCeiling: String(process.env.BENCHMARK_OPENROUTER_MAX_PRICE_TIER || 'cheap').trim().toLowerCase(),
      answerModelId: String(process.env.BENCHMARK_ANSWER_MODEL || '').trim(),
      judgeModelId: String(process.env.BENCHMARK_JUDGE_MODEL || '').trim(),
    },
    locomo: {
      sourceUrl: String(process.env.NEOAGENT_BENCHMARK_LOCOMO_URL
        || 'https://raw.githubusercontent.com/snap-research/locomo/main/data/locomo10.json').trim(),
      datasetPath: path.join(workDir, 'locomo', 'locomo10.json'),
      samples: parsePositiveInteger(process.env.BENCHMARK_LOCOMO_SAMPLES, 10),
      offset: parseNonNegativeInteger(process.env.BENCHMARK_LOCOMO_OFFSET, 0),
      qaPerSample: parseNonNegativeInteger(process.env.BENCHMARK_LOCOMO_QA_PER_SAMPLE, 0),
      memK: parsePositiveInteger(process.env.BENCHMARK_LOCOMO_MEM_K, 20),
    },
    concurrency: parsePositiveInteger(process.env.BENCHMARK_CONCURRENCY, 1),
    caseLimit: parseNonNegativeInteger(process.env.BENCHMARK_CASE_LIMIT, 0),
    allowDatasetDownload: parseBoolean(process.env.NEOAGENT_BENCHMARK_ALLOW_DOWNLOADS, true),
    outputs: {
      resultsJsonPath: path.join(outputDir, 'latest-results.json'),
      summaryJsonPath: path.join(outputDir, 'latest-summary.json'),
      summaryMarkdownPath: path.join(outputDir, 'latest-summary.md'),
      dashboardPngPath: path.join(rootDir, 'static', 'benchmarks', 'latest-dashboard.png'),
    },
  };

  return {
    ...config,
    ...overrides,
    rootDir,
    benchmarkDir,
    workDir,
    outputDir,
    locomo: { ...config.locomo, ...(overrides.locomo || {}) },
    openRouter: { ...config.openRouter, ...(overrides.openRouter || {}) },
  };
}

module.exports = {
  DEFAULT_BENCHMARK_USER,
  resolveBenchmarkConfig,
};
