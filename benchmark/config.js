'use strict';

const path = require('node:path');

const REPO_ROOT = path.resolve(__dirname, '..');

// Set explicit OpenRouter models here to override automatic cheap-model selection.
const OPENROUTER_MODEL_IDS = Object.freeze([]);
const OPENROUTER_PRICE_TIER_CEILING = 'cheap';

const ENABLED_SUITES = Object.freeze({
  gaia: true,
  browsecomp: true,
  webarena: true,
  visualwebarena: true,
  swebench: true,
  neoagent_representative: true,
  neoagent_memory_retrieval: true,
});

const DEFAULT_BENCHMARK_USER = Object.freeze({
  username: 'neoagent_benchmark',
  password: 'NeoAgentBenchmark1!',
  email: 'neoagent-benchmark@example.com',
});

function parseCsv(value) {
  return String(value || '')
    .split(',')
    .map((entry) => entry.trim())
    .filter(Boolean);
}

function parseBoolean(value, fallback) {
  const normalized = String(value || '').trim().toLowerCase();
  if (!normalized) return fallback;
  if (['1', 'true', 'yes', 'on'].includes(normalized)) return true;
  if (['0', 'false', 'no', 'off'].includes(normalized)) return false;
  return fallback;
}

function parsePositiveInteger(value, fallback) {
  const parsed = Number.parseInt(value, 10);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
}

function buildSuitePaths(rootDir, benchmarkDir, outputDir, workDir) {
  return {
    gaia: {
      repoDir: path.join(workDir, 'gaia'),
      casesPath: process.env.NEOAGENT_BENCHMARK_GAIA_CASES_PATH || path.join(workDir, 'gaia', 'cases.jsonl'),
      manifestPath: path.join(workDir, 'gaia', 'manifest.json'),
      sourceUrl: 'https://huggingface.co/datasets/gaia-benchmark/GAIA',
      runnerCommand: String(process.env.NEOAGENT_BENCHMARK_GAIA_RUNNER || '').trim(),
    },
    browsecomp: {
      repoUrl: 'https://github.com/openai/simple-evals',
      repoDir: path.join(workDir, 'browsecomp'),
      casesPath: process.env.NEOAGENT_BENCHMARK_BROWSECOMP_CASES_PATH || path.join(workDir, 'browsecomp', 'cases.jsonl'),
      manifestPath: path.join(workDir, 'browsecomp', 'manifest.json'),
      sourceUrl: 'https://openai.com/index/browsecomp/',
      runnerCommand: String(process.env.NEOAGENT_BENCHMARK_BROWSECOMP_RUNNER || '').trim(),
    },
    webarena: {
      repoUrl: 'https://github.com/web-arena-x/webarena',
      repoDir: path.join(workDir, 'webarena'),
      manifestPath: path.join(workDir, 'webarena', 'manifest.json'),
      sourceUrl: 'https://webarena.dev/',
      runnerCommand: String(process.env.NEOAGENT_BENCHMARK_WEBARENA_RUNNER || '').trim(),
    },
    visualwebarena: {
      repoUrl: 'https://github.com/web-arena-x/visualwebarena',
      repoDir: path.join(workDir, 'visualwebarena'),
      manifestPath: path.join(workDir, 'visualwebarena', 'manifest.json'),
      sourceUrl: 'https://webarena.dev/',
      runnerCommand: String(process.env.NEOAGENT_BENCHMARK_VISUAL_WEBARENA_RUNNER || '').trim(),
    },
    swebench: {
      repoUrl: 'https://github.com/SWE-bench/SWE-bench',
      repoDir: path.join(workDir, 'swebench'),
      manifestPath: path.join(workDir, 'swebench', 'manifest.json'),
      sourceUrl: 'https://www.swebench.com/SWE-bench/',
      runnerCommand: String(process.env.NEOAGENT_BENCHMARK_SWEBENCH_RUNNER || '').trim(),
    },
    neoagent_representative: {
      casesPath: path.join(benchmarkDir, 'datasets', 'neoagent_representative_cases.json'),
      rubricPath: path.join(rootDir, 'test', 'evaluation', 'representative_tasks.json'),
    },
    neoagent_memory_retrieval: {
      datasetPath: path.join(benchmarkDir, 'datasets', 'neoagent_memory_retrieval.json'),
    },
    outputs: {
      resultsJsonPath: path.join(outputDir, 'latest-results.json'),
      summaryJsonPath: path.join(outputDir, 'latest-summary.json'),
      summaryMarkdownPath: path.join(outputDir, 'latest-summary.md'),
      dashboardPngPath: path.join(rootDir, 'static', 'benchmarks', 'latest-dashboard.png'),
    },
  };
}

function resolveBenchmarkConfig(overrides = {}) {
  const benchmarkDir = path.resolve(overrides.benchmarkDir || __dirname);
  const rootDir = path.resolve(overrides.rootDir || REPO_ROOT);
  const workDir = path.resolve(overrides.workDir || path.join(benchmarkDir, 'workdir'));
  const outputDir = path.resolve(overrides.outputDir || path.join(benchmarkDir, 'results'));
  const explicitModelIds = parseCsv(process.env.BENCHMARK_OPENROUTER_MODELS);
  const enabledSuites = { ...ENABLED_SUITES, ...(overrides.enabledSuites || {}) };
  const selectedSuites = parseCsv(process.env.BENCHMARK_SUITES);

  const config = {
    rootDir,
    benchmarkDir,
    workDir,
    outputDir,
    serverBaseUrl: String(process.env.NEOAGENT_BENCHMARK_BASE_URL || 'http://127.0.0.1:3333').trim(),
    auth: {
      username: String(process.env.NEOAGENT_BENCHMARK_USERNAME || DEFAULT_BENCHMARK_USER.username).trim(),
      password: String(process.env.NEOAGENT_BENCHMARK_PASSWORD || DEFAULT_BENCHMARK_USER.password),
      email: String(process.env.NEOAGENT_BENCHMARK_EMAIL || DEFAULT_BENCHMARK_USER.email).trim(),
    },
    openRouter: {
      provider: 'openrouter',
      baseUrl: String(process.env.OPENROUTER_BASE_URL || 'https://openrouter.ai/api/v1').trim(),
      apiKey: String(process.env.OPENROUTER_API_KEY || '').trim(),
      explicitModelIds: explicitModelIds.length ? explicitModelIds : [...OPENROUTER_MODEL_IDS],
      priceTierCeiling: String(process.env.BENCHMARK_OPENROUTER_MAX_PRICE_TIER || OPENROUTER_PRICE_TIER_CEILING).trim().toLowerCase(),
    },
    concurrency: parsePositiveInteger(process.env.BENCHMARK_CONCURRENCY, 1),
    caseLimit: parsePositiveInteger(process.env.BENCHMARK_CASE_LIMIT, 0),
    suiteSelection: selectedSuites,
    enabledSuites,
    suitePaths: buildSuitePaths(rootDir, benchmarkDir, outputDir, workDir),
    allowSetupDownloads: parseBoolean(process.env.NEOAGENT_BENCHMARK_ALLOW_DOWNLOADS, true),
    failOnBlockedSuite: parseBoolean(process.env.NEOAGENT_BENCHMARK_FAIL_ON_BLOCKED, false),
  };

  return {
    ...config,
    ...overrides,
    rootDir,
    benchmarkDir,
    workDir,
    outputDir,
    enabledSuites,
    suiteSelection: Array.isArray(overrides.suiteSelection) ? overrides.suiteSelection : config.suiteSelection,
    suitePaths: buildSuitePaths(rootDir, benchmarkDir, outputDir, workDir),
  };
}

module.exports = {
  DEFAULT_BENCHMARK_USER,
  ENABLED_SUITES,
  OPENROUTER_MODEL_IDS,
  OPENROUTER_PRICE_TIER_CEILING,
  resolveBenchmarkConfig,
};
