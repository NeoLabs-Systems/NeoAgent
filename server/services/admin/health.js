'use strict';

const db = require('../../db/database');
const { getVersionInfo } = require('../../utils/version');
const { readUpdateStatus } = require('../../utils/update_status');
const { getRuntimeValidation } = require('../runtime/validation');
const { listProviders } = require('./providers');

const RECENT_FAILURE_MS = 24 * 60 * 60 * 1000;
// Keys in the provider list that are not AI models or only override a URL.
const NON_AI_PROVIDER_KEYS = new Set(['BRAVE_SEARCH_API_KEY', 'DEEPGRAM_API_KEY', 'OPENAI_BASE_URL', 'ANTHROPIC_BASE_URL', 'XAI_BASE_URL', 'OPENAI_COMPATIBLE_BASE_URL']);

// Non-secret runtime settings, shown read-only on the admin page.
const ENVIRONMENT_KEYS = [
  'PORT',
  'NODE_ENV',
  'PUBLIC_URL',
  'NEOAGENT_DEPLOYMENT_MODE',
  'NEOAGENT_RELEASE_CHANNEL',
  'ALLOWED_ORIGINS',
  'SECURE_COOKIES',
  'TRUST_PROXY',
];

function getServerVersion() {
  const version = getVersionInfo();
  const status = readUpdateStatus();
  return {
    version: version.version,
    installedVersion: version.installedVersion,
    packageVersion: version.packageVersion,
    gitVersion: version.gitVersion,
    gitSha: version.gitSha,
    gitBranch: version.gitBranch,
    releaseChannel: version.releaseChannel,
    deploymentMode: version.deploymentMode,
    allowSelfUpdate: version.allowSelfUpdate,
    containerImage: version.containerImage,
    updateStatus: { state: status.state, phase: status.phase, message: status.message },
    uptime: process.uptime(),
    nodeVersion: process.version,
    environment: Object.fromEntries(ENVIRONMENT_KEYS.map((key) => [key, process.env[key] || ''])),
  };
}

function checkDatabase() {
  try {
    db.prepare('SELECT 1').get();
    return { id: 'database', label: 'Database', passed: true, detail: 'SQLite connected' };
  } catch (err) {
    return { id: 'database', label: 'Database', passed: false, detail: String(err?.message || err).slice(0, 120) };
  }
}

function configuredProviderNames() {
  return listProviders().providers
    .filter((provider) => provider.configured && !NON_AI_PROVIDER_KEYS.has(provider.key))
    .map((provider) => provider.label);
}

// An old failed run is history, not a fault: only a recent one is flagged.
function updateFailedRecently(status) {
  if (status.state !== 'failed') return false;
  const finished = Date.parse(status.completedAt || status.updatedAt || '');
  return Number.isFinite(finished) && Date.now() - finished < RECENT_FAILURE_MS;
}

function runHealthChecks(runtimeManager) {
  const version = getVersionInfo();
  const updateStatus = readUpdateStatus();
  const runtimeValidation = getRuntimeValidation(runtimeManager);
  const runtimeReady = Boolean(runtimeValidation?.ready);
  const providers = configuredProviderNames();

  const results = [
    { id: 'backend', label: 'Backend server', passed: true, detail: 'Running' },
    {
      id: 'version',
      label: 'Server version',
      passed: true,
      detail: version.version || version.packageVersion || 'Unknown',
    },
    checkDatabase(),
    {
      id: 'update',
      label: 'Update status',
      passed: !updateFailedRecently(updateStatus),
      detail: updateStatus.state === 'idle'
        ? 'No update running'
        : `${updateStatus.state} — ${updateStatus.message || ''}`.trim(),
    },
    {
      id: 'vm_runtime',
      label: 'Cloud VM runtime',
      passed: runtimeReady,
      detail: runtimeReady ? 'Available' : String(runtimeValidation?.issues?.[0] || 'Not configured'),
    },
    {
      id: 'ai_providers',
      label: 'AI providers',
      passed: providers.length > 0,
      detail: providers.length > 0 ? providers.join(', ') : 'No providers configured',
    },
  ];
  if (process.env.DEEPGRAM_API_KEY) {
    results.push({ id: 'deepgram', label: 'Deepgram (transcription)', passed: true, detail: 'API key configured' });
  }

  return { passed: results.every((result) => result.passed), results };
}

module.exports = { getServerVersion, runHealthChecks };
