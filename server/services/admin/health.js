'use strict';

const db = require('../../db/database');
const { getVersionInfo } = require('../../utils/version');
const { readUpdateStatus } = require('../../utils/update_status');
const { getRuntimeValidation } = require('../runtime/validation');

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
    releaseChannel: status.releaseChannel || version.releaseChannel,
    deploymentMode: version.deploymentMode,
    allowSelfUpdate: version.allowSelfUpdate,
    updateStatus: {
      state: status.state,
      progress: status.progress,
      phase: status.phase,
      message: status.message,
    },
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
  const names = [];
  if (process.env.ANTHROPIC_API_KEY) names.push('Anthropic');
  if (process.env.OPENAI_API_KEY) names.push('OpenAI');
  if (process.env.OPENAI_COMPATIBLE_API_KEY && process.env.OPENAI_COMPATIBLE_BASE_URL) {
    names.push('Custom OpenAI-compatible');
  }
  if (process.env.XAI_API_KEY) names.push('xAI');
  if (process.env.GOOGLE_AI_KEY) names.push('Google');
  if (process.env.OPENROUTER_API_KEY) names.push('OpenRouter');
  return names;
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
      passed: updateStatus.state !== 'failed',
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
    results.push({ id: 'deepgram', label: 'Deepgram (voice)', passed: true, detail: 'API key configured' });
  }

  return { passed: results.every((result) => result.passed), results };
}

module.exports = { getServerVersion, runHealthChecks };
