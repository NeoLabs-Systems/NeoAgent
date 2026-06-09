'use strict';

const path = require('path');
const express = require('express');
const { spawn } = require('child_process');
const { requireAdminAuth } = require('../middleware/adminAuth');
const { getVersionInfo } = require('../utils/version');
const {
  readUpdateStatus,
  writeUpdateStatusFile: writeUpdateStatus,
} = require('../utils/update_status');
const {
  parseReleaseChannel,
  writeReleaseChannelToEnvFile,
  getReleaseChannelBranchPolicy,
  getReleaseChannelNpmPolicy,
} = require('../../runtime/release_channel');
const { APP_DIR, ENV_FILE, upsertEnvValue } = require('../../runtime/paths');
const { isManagedDeployment } = require('../utils/deployment');
const rateLimit = require('express-rate-limit');

const router = express.Router();
const ADMIN_DIR = path.join(__dirname, '..', 'admin');

const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  skipSuccessfulRequests: true,
  message: { error: 'Too many login attempts, try again later' },
});

const updateTriggerLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many update requests, try again later' },
});

// --- Auth ---

router.get('/login', (req, res) => {
  if (req.session?.isAdmin) return res.redirect('/admin');
  res.sendFile(path.join(ADMIN_DIR, 'login.html'));
});

router.post('/api/login', loginLimiter, express.json(), (req, res) => {
  const { username, password } = req.body || {};
  const expectedUsername = process.env.ADMIN_USERNAME || 'admin';
  const expectedPassword = process.env.ADMIN_PASSWORD || '';
  if (!expectedPassword) {
    return res.status(503).json({ error: 'Admin credentials not configured. Run `neoagent setup`.' });
  }
  if (username === expectedUsername && password === expectedPassword) {
    req.session.isAdmin = true;
    req.session.save((err) => {
      if (err) return res.status(500).json({ error: 'Session error' });
      res.json({ ok: true });
    });
  } else {
    res.status(401).json({ error: 'Invalid credentials' });
  }
});

router.post('/api/logout', (req, res) => {
  req.session.destroy(() => res.json({ ok: true }));
});

// --- Protected API ---

router.get('/api/logs', requireAdminAuth, (req, res) => {
  const logHistory = req.app.locals.logHistory || [];
  res.json({ logs: logHistory });
});

router.get('/api/version', requireAdminAuth, (req, res) => {
  const version = getVersionInfo();
  const status = readUpdateStatus();
  res.json({
    version: version.version,
    installedVersion: version.installedVersion,
    packageVersion: version.packageVersion,
    gitVersion: version.gitVersion,
    gitSha: version.gitSha,
    gitBranch: version.gitBranch,
    releaseChannel: status.releaseChannel || version.releaseChannel,
    deploymentMode: version.deploymentMode,
    deploymentProfile: version.deploymentProfile,
    allowSelfUpdate: version.allowSelfUpdate,
    updateStatus: {
      state: status.state,
      progress: status.progress,
      phase: status.phase,
      message: status.message,
    },
    uptime: process.uptime(),
    nodeVersion: process.version,
  });
});

router.get('/api/health', requireAdminAuth, async (req, res) => {
  const runtimeManager = req.app?.locals?.runtimeManager;
  const desktopRegistry = req.app?.locals?.desktopCompanionRegistry;
  const extensionRegistry = req.app?.locals?.browserExtensionRegistry;
  const results = [];

  results.push({ id: 'backend', label: 'Backend server', passed: true, detail: 'Running' });

  const version = getVersionInfo();
  results.push({
    id: 'version',
    label: 'Server version',
    passed: true,
    detail: version.version || version.packageVersion || 'Unknown',
  });

  try {
    const db = require('../db/database');
    db.prepare('SELECT 1').get();
    results.push({ id: 'database', label: 'Database', passed: true, detail: 'SQLite connected' });
  } catch (err) {
    results.push({ id: 'database', label: 'Database', passed: false, detail: String(err?.message || err).slice(0, 120) });
  }

  const updateStatus = readUpdateStatus();
  results.push({
    id: 'update',
    label: 'Update status',
    passed: updateStatus.state !== 'failed',
    detail: updateStatus.state === 'idle'
      ? 'No update running'
      : `${updateStatus.state} — ${updateStatus.message || ''}`.trim(),
  });

  const { getRuntimeValidation } = require('../services/runtime/validation');
  const runtimeValidation = getRuntimeValidation(runtimeManager);
  const runtimeReady = Boolean(runtimeValidation?.ready);
  results.push({
    id: 'vm_runtime',
    label: 'Cloud VM runtime',
    passed: runtimeReady,
    detail: runtimeReady ? 'Available' : String(runtimeValidation?.issues?.[0] || 'Not configured'),
  });

  if (desktopRegistry) {
    try {
      const connectedUsers = [];
      for (const socket of (req.app?.locals?.io?.sockets?.sockets?.values?.() || [])) {
        const uid = socket.request?.session?.userId;
        if (uid && !connectedUsers.includes(uid)) connectedUsers.push(uid);
      }
      results.push({
        id: 'desktop',
        label: 'Desktop companion',
        passed: true,
        detail: 'Registry available',
      });
    } catch {
      results.push({ id: 'desktop', label: 'Desktop companion', passed: false, detail: 'Registry error' });
    }
  }

  if (extensionRegistry) {
    results.push({ id: 'extension', label: 'Chrome extension registry', passed: true, detail: 'Available' });
  }

  const configuredProviders = [];
  if (process.env.ANTHROPIC_API_KEY) configuredProviders.push('Anthropic');
  if (process.env.OPENAI_API_KEY) configuredProviders.push('OpenAI');
  if (process.env.XAI_API_KEY) configuredProviders.push('xAI');
  if (process.env.GOOGLE_AI_KEY) configuredProviders.push('Google');
  if (process.env.OPENROUTER_API_KEY) configuredProviders.push('OpenRouter');
  results.push({
    id: 'ai_providers',
    label: 'AI providers',
    passed: configuredProviders.length > 0,
    detail: configuredProviders.length > 0
      ? configuredProviders.join(', ')
      : 'No providers configured',
  });

  if (process.env.DEEPGRAM_API_KEY) {
    results.push({ id: 'deepgram', label: 'Deepgram (voice)', passed: true, detail: 'API key configured' });
  }

  const allPassed = results.every((r) => r.passed);
  res.json({ passed: allPassed, results });
});

router.get('/api/config', requireAdminAuth, (req, res) => {
  const safe = [
    'PORT', 'NODE_ENV', 'PUBLIC_URL', 'NEOAGENT_DEPLOYMENT_MODE',
    'NEOAGENT_PROFILE', 'NEOAGENT_RELEASE_CHANNEL', 'ALLOWED_ORIGINS',
    'SECURE_COOKIES', 'TRUST_PROXY', 'ADMIN_USERNAME',
  ];
  const config = {};
  for (const key of safe) {
    config[key] = process.env[key] || '';
  }
  res.json({ config });
});

router.post('/api/update', requireAdminAuth, updateTriggerLimiter, (req, res) => {
  if (isManagedDeployment()) {
    return res.status(403).json({ error: 'Updates are managed by this deployment.' });
  }
  const status = readUpdateStatus();
  if (status.state === 'running') {
    return res.status(409).json({ error: 'An update is already running' });
  }
  console.log('[Admin] Triggering update-runner...');
  const child = spawn(process.execPath, ['scripts/update-runner.js'], {
    detached: true,
    stdio: 'ignore',
    cwd: APP_DIR,
  });
  writeUpdateStatus({
    state: 'running',
    progress: 1,
    phase: 'starting',
    message: 'Launching update job',
    startedAt: new Date().toISOString(),
    completedAt: null,
    versionBefore: null,
    versionAfter: null,
    runnerPid: child.pid,
    changelog: [],
    logs: [],
  });
  child.once('error', (error) => {
    writeUpdateStatus({
      state: 'failed',
      progress: 100,
      phase: 'failed',
      message: `Failed to launch update job: ${error.message}`,
      completedAt: new Date().toISOString(),
      runnerPid: null,
    });
  });
  child.unref();
  res.json({ ok: true, message: 'Update triggered', pid: child.pid });
});

router.put('/api/update/channel', requireAdminAuth, (req, res) => {
  if (isManagedDeployment()) {
    return res.status(403).json({ error: 'Release channel changes are managed by this deployment.' });
  }
  const requested = req.body?.channel;
  const releaseChannel = parseReleaseChannel(requested);
  if (!releaseChannel) {
    return res.status(400).json({ error: 'Release channel must be "stable" or "beta".' });
  }
  writeReleaseChannelToEnvFile(releaseChannel);
  process.env.NEOAGENT_RELEASE_CHANNEL = releaseChannel;
  res.json({
    ok: true,
    releaseChannel,
    targetBranch: getReleaseChannelBranchPolicy(releaseChannel),
    npmDistTag: getReleaseChannelNpmPolicy(releaseChannel),
  });
});

// --- Providers ---

const PROVIDERS = [
  { key: 'ANTHROPIC_API_KEY',    label: 'Anthropic (Claude)',  type: 'key' },
  { key: 'OPENAI_API_KEY',       label: 'OpenAI',              type: 'key' },
  { key: 'XAI_API_KEY',          label: 'xAI (Grok)',          type: 'key' },
  { key: 'GOOGLE_AI_KEY',        label: 'Google (Gemini)',      type: 'key' },
  { key: 'MINIMAX_API_KEY',      label: 'MiniMax',             type: 'key' },
  { key: 'NVIDIA_API_KEY',       label: 'NVIDIA NIM',          type: 'key' },
  { key: 'OPENROUTER_API_KEY',   label: 'OpenRouter',          type: 'key' },
  { key: 'BRAVE_SEARCH_API_KEY', label: 'Brave Search',        type: 'key' },
  { key: 'DEEPGRAM_API_KEY',     label: 'Deepgram (Voice)',    type: 'key' },
  { key: 'OLLAMA_URL',           label: 'Ollama (Local)',       type: 'url' },
];

const ALLOWED_PROVIDER_KEYS = new Set(PROVIDERS.map((p) => p.key));

router.get('/api/providers', requireAdminAuth, (req, res) => {
  const result = PROVIDERS.map(({ key, label, type }) => {
    const value = process.env[key] || '';
    let hint = '';
    if (value) {
      hint = type === 'url'
        ? value
        : value.length > 8
          ? `${value.slice(0, 4)}${'•'.repeat(4)}${value.slice(-4)}`
          : '•'.repeat(value.length);
    }
    return { key, label, type, configured: Boolean(value), hint };
  });
  res.json({ providers: result });
});

router.put('/api/providers', requireAdminAuth, express.json(), (req, res) => {
  const { key, value } = req.body || {};
  if (!ALLOWED_PROVIDER_KEYS.has(key)) {
    return res.status(400).json({ error: 'Unknown provider key' });
  }
  const trimmed = String(value || '').trim();
  upsertEnvValue(ENV_FILE, key, trimmed);
  if (trimmed) {
    process.env[key] = trimmed;
  } else {
    delete process.env[key];
  }
  res.json({ ok: true });
});

// --- Static files ---

router.use(express.static(ADMIN_DIR));

router.get('*', requireAdminAuth, (req, res) => {
  res.sendFile(path.join(ADMIN_DIR, 'index.html'));
});

module.exports = router;
