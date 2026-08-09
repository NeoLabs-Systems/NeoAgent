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
const { configuredDefaultLimits } = require('../services/ai/rate_limits');

const router = express.Router();
const ADMIN_DIR = path.join(__dirname, '..', 'admin');
const qrcode = require('qrcode');

const fs   = require('fs');

// Admin sessions last 30 days and roll on every request.
const ADMIN_SESSION_TTL = 30 * 24 * 60 * 60 * 1000;

// Rolling refresh: touch the session on every authenticated admin request
// so the 30-day window slides forward from the last activity.
router.use((req, res, next) => {
  if (req.session?.isAdmin) {
    req.session.cookie.maxAge = ADMIN_SESSION_TTL;
    req.session.touch();
  }
  next();
});

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

function establishAdminSession(req, res, responseBody) {
  const userId = req.session?.userId;
  const username = req.session?.username;
  req.session.regenerate((err) => {
    if (err) return res.status(500).json({ error: 'Session error' });
    if (userId != null) {
      req.session.userId = userId;
    }
    if (username) {
      req.session.username = username;
    }
    req.session.isAdmin = true;
    req.session.cookie.maxAge = ADMIN_SESSION_TTL;
    req.session.save((saveErr) => {
      if (saveErr) return res.status(500).json({ error: 'Session error' });
      res.json(responseBody);
    });
  });
}

router.get('/login', (req, res) => {
  if (req.session?.isAdmin) return res.redirect('/admin');
  res.sendFile(path.join(ADMIN_DIR, 'login.html'));
});

router.post('/api/login', loginLimiter, express.json(), async (req, res) => {
  const { username, password } = req.body || {};
  const expectedUsername = process.env.ADMIN_USERNAME;
  const expectedPassword = process.env.ADMIN_PASSWORD;
  if (!expectedUsername || !expectedPassword) {
    return res.status(503).json({ error: 'Admin interface is not configured. Set ADMIN_USERNAME and ADMIN_PASSWORD environment variables.' });
  }
  if (username !== expectedUsername || password !== expectedPassword) {
    return res.status(401).json({ error: 'Invalid credentials' });
  }
  // Check whether 2FA is enabled
  const adminTwoFactor = require('../services/account/admin_two_factor');
  const tfStatus = adminTwoFactor.getStatus();
  if (tfStatus.enabled) {
    // Park the session in a "password OK, waiting for TOTP" state
    req.session.adminPendingTwoFactor = true;
    delete req.session.adminPendingTwoFactorSetup;
    delete req.session.isAdmin;
    return req.session.save((err) => {
      if (err) return res.status(500).json({ error: 'Session error' });
      res.json({ ok: false, requiresTwoFactor: true });
    });
  }
  const setup = adminTwoFactor.beginSetup();
  const qrDataUrl = await qrcode.toDataURL(setup.otpauthUrl, { width: 200, margin: 2 });
  req.session.adminPendingTwoFactorSetup = true;
  delete req.session.adminPendingTwoFactor;
  delete req.session.isAdmin;
  return req.session.save((err) => {
    if (err) return res.status(500).json({ error: 'Session error' });
    res.json({
      ok: false,
      requiresTwoFactorSetup: true,
      setup: {
        manualKey: setup.manualKey,
        qrDataUrl,
      },
    });
  });
});

// Second-factor verification (called after a successful password login when 2FA is on)
router.post('/api/2fa/verify', loginLimiter, express.json(), async (req, res) => {
  if (!req.session?.adminPendingTwoFactor) {
    return res.status(400).json({ error: 'No pending 2FA verification' });
  }
  const { code } = req.body || {};
  try {
    const adminTwoFactor = require('../services/account/admin_two_factor');
    const valid = await adminTwoFactor.verifyCode(code);
    if (!valid) return res.status(401).json({ error: 'Invalid code — try again' });
    establishAdminSession(req, res, { ok: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/api/login/2fa/setup/enable', loginLimiter, express.json(), async (req, res) => {
  if (!req.session?.adminPendingTwoFactorSetup) {
    return res.status(400).json({ error: 'No pending 2FA setup' });
  }
  try {
    const adminTwoFactor = require('../services/account/admin_two_factor');
    const { recoveryCodes } = await adminTwoFactor.enable(req.body?.code);
    establishAdminSession(req, res, { ok: true, recoveryCodes });
  } catch (err) {
    res.status(err.statusCode || 500).json({ error: err.message });
  }
});

router.post('/api/logout', (req, res) => {
  if (req.session?.userId != null) {
    delete req.session.isAdmin;
    delete req.session.adminPendingTwoFactor;
    delete req.session.adminPendingTwoFactorSetup;
    return req.session.save((err) => {
      if (err) return res.status(500).json({ error: 'Session error' });
      res.json({ ok: true });
    });
  }
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
  if (process.env.OPENAI_COMPATIBLE_API_KEY && process.env.OPENAI_COMPATIBLE_BASE_URL) {
    configuredProviders.push('Custom OpenAI-compatible');
  }
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

const settingsLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many settings changes, slow down' },
});

const sqlLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 60,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many SQL queries, slow down' },
});

router.get('/api/config/email', requireAdminAuth, (req, res) => {
  const { getAdminEmailSettings } = require('../services/account/service_email_settings');
  res.json(getAdminEmailSettings());
});

router.put('/api/config/email', requireAdminAuth, settingsLimiter, express.json(), (req, res) => {
  try {
    const { updateAdminEmailSettings } = require('../services/account/service_email_settings');
    res.json({ ok: true, ...updateAdminEmailSettings(req.body) });
  } catch (err) {
    res.status(err.statusCode || 500).json({ error: err.message });
  }
});

// --- Access settings (signup toggle + API key) ---

router.get('/api/settings', requireAdminAuth, (req, res) => {
  const apiKey = process.env.ADMIN_API_KEY || '';
  const hint = apiKey.length > 8
    ? `${apiKey.slice(0, 4)}${'•'.repeat(4)}${apiKey.slice(-4)}`
    : apiKey ? '•'.repeat(apiKey.length) : '';
  const adminTwoFactor = require('../services/account/admin_two_factor');
  const tfStatus = adminTwoFactor.getStatus();
  res.json({
    signupEnabled: process.env.NEOAGENT_ALLOW_SIGNUP !== 'false',
    apiKeyConfigured: Boolean(apiKey),
    apiKeyHint: hint,
    twoFactor: tfStatus,
  });
});

// --- 2FA management ---

router.get('/api/settings/2fa', requireAdminAuth, (req, res) => {
  const adminTwoFactor = require('../services/account/admin_two_factor');
  res.json(adminTwoFactor.getStatus());
});

router.post('/api/settings/2fa/setup', requireAdminAuth, settingsLimiter, async (req, res) => {
  try {
    const adminTwoFactor = require('../services/account/admin_two_factor');
    const { otpauthUrl, manualKey } = adminTwoFactor.beginSetup();
    const qrcode = require('qrcode');
    const qrDataUrl = await qrcode.toDataURL(otpauthUrl, { width: 200, margin: 2 });
    res.json({ qrDataUrl, manualKey });
  } catch (err) {
    res.status(err.statusCode || 500).json({ error: err.message });
  }
});

router.post('/api/settings/2fa/enable', requireAdminAuth, settingsLimiter, express.json(), async (req, res) => {
  try {
    const adminTwoFactor = require('../services/account/admin_two_factor');
    const { recoveryCodes } = await adminTwoFactor.enable(req.body?.code);
    res.json({ ok: true, recoveryCodes });
  } catch (err) {
    res.status(err.statusCode || 500).json({ error: err.message });
  }
});

router.delete('/api/settings/2fa', requireAdminAuth, settingsLimiter, express.json(), async (req, res) => {
  try {
    const adminTwoFactor = require('../services/account/admin_two_factor');
    await adminTwoFactor.disable(req.body?.code);
    res.json({ ok: true });
  } catch (err) {
    res.status(err.statusCode || 500).json({ error: err.message });
  }
});

router.post('/api/settings/2fa/recovery-codes', requireAdminAuth, settingsLimiter, express.json(), async (req, res) => {
  try {
    const adminTwoFactor = require('../services/account/admin_two_factor');
    const { recoveryCodes } = await adminTwoFactor.regenerateCodes(req.body?.code);
    res.json({ ok: true, recoveryCodes });
  } catch (err) {
    res.status(err.statusCode || 500).json({ error: err.message });
  }
});

router.put('/api/settings/signup', requireAdminAuth, settingsLimiter, express.json(), (req, res) => {
  const enabled = req.body?.enabled !== false; // default true
  const value   = enabled ? 'true' : 'false';
  upsertEnvValue(ENV_FILE, 'NEOAGENT_ALLOW_SIGNUP', value);
  process.env.NEOAGENT_ALLOW_SIGNUP = value;
  res.json({ ok: true, signupEnabled: enabled });
});

router.post('/api/settings/apikey/rotate', requireAdminAuth, settingsLimiter, (req, res) => {
  const newKey = require('crypto').randomBytes(32).toString('hex');
  upsertEnvValue(ENV_FILE, 'ADMIN_API_KEY', newKey);
  process.env.ADMIN_API_KEY = newKey;
  // Return the key once — it will not be shown again
  res.json({ ok: true, apiKey: newKey });
});

router.delete('/api/settings/apikey', requireAdminAuth, settingsLimiter, (req, res) => {
  upsertEnvValue(ENV_FILE, 'ADMIN_API_KEY', '');
  delete process.env.ADMIN_API_KEY;
  res.json({ ok: true });
});

// --- Analytics ---

router.get('/api/analytics', requireAdminAuth, (req, res) => {
  const db = require('../db/database');
  const range = Math.min(Math.max(parseInt(req.query.range) || 30, 1), 365);
  const now = new Date().toISOString();
  const dayAgo  = new Date(Date.now() - 86_400_000).toISOString();
  const weekAgo = new Date(Date.now() - 7 * 86_400_000).toISOString();
  const rangeAgo = new Date(Date.now() - range * 86_400_000).toISOString();
  try {
    const totalRunsRow  = db.prepare('SELECT COUNT(*) AS n, COALESCE(SUM(total_tokens),0) AS t FROM agent_runs').get();
    const successRow    = db.prepare("SELECT COUNT(*) AS n FROM agent_runs WHERE status = 'completed'").get();
    const stats = {
      totalUsers:     db.prepare('SELECT COUNT(*) AS n FROM users').get().n,
      activeToday:    db.prepare('SELECT COUNT(*) AS n FROM users WHERE last_login > ?').get(dayAgo).n,
      newThisWeek:    db.prepare('SELECT COUNT(*) AS n FROM users WHERE created_at > ?').get(weekAgo).n,
      totalRuns:      totalRunsRow.n,
      runsToday:      db.prepare('SELECT COUNT(*) AS n FROM agent_runs WHERE created_at > ?').get(dayAgo).n,
      runsThisWeek:   db.prepare('SELECT COUNT(*) AS n FROM agent_runs WHERE created_at > ?').get(weekAgo).n,
      totalTokens:    totalRunsRow.t,
      tokensToday:    db.prepare("SELECT COALESCE(SUM(total_tokens),0) AS n FROM agent_runs WHERE created_at > ?").get(dayAgo).n,
      avgTokensPerRun: totalRunsRow.n > 0 ? Math.round(totalRunsRow.t / totalRunsRow.n) : 0,
      successRate:    totalRunsRow.n > 0 ? Math.round((successRow.n / totalRunsRow.n) * 100) : 0,
      activeSessions: db.prepare('SELECT COUNT(*) AS n FROM user_sessions WHERE revoked_at IS NULL AND expires_at > ?').get(now).n,
      totalStorage:   db.prepare('SELECT COALESCE(SUM(byte_size),0) AS n FROM artifacts').get().n,
    };

    // Time-series: runs + tokens per day for selected range
    const runsByDay = db.prepare(`
      SELECT date(created_at) AS date,
             COUNT(*) AS runs,
             COALESCE(SUM(total_tokens), 0) AS tokens
      FROM agent_runs
      WHERE created_at > ?
      GROUP BY date(created_at)
      ORDER BY date
    `).all(rangeAgo);

    // New users per day for selected range
    const usersByDay = db.prepare(`
      SELECT date(created_at) AS date, COUNT(*) AS newUsers
      FROM users
      WHERE created_at > ?
      GROUP BY date(created_at)
      ORDER BY date
    `).all(rangeAgo);

    // Model breakdown (top 10 by runs)
    const modelBreakdown = db.prepare(`
      SELECT COALESCE(model, 'unknown') AS model,
             COUNT(*) AS runs,
             COALESCE(SUM(total_tokens), 0) AS tokens
      FROM agent_runs
      WHERE created_at > ?
      GROUP BY model
      ORDER BY runs DESC
      LIMIT 10
    `).all(rangeAgo);

    // Run status breakdown
    const statusBreakdown = db.prepare(`
      SELECT status, COUNT(*) AS count
      FROM agent_runs
      GROUP BY status
      ORDER BY count DESC
    `).all();

    const topUsers = db.prepare(`
      SELECT u.id, u.username, u.display_name,
             COALESCE(r.runs,    0) AS runs,
             COALESCE(r.tokens,  0) AS tokens,
             COALESCE(a.storage, 0) AS storage
      FROM users u
      LEFT JOIN (
        SELECT user_id, COUNT(*) AS runs, COALESCE(SUM(total_tokens),0) AS tokens
        FROM agent_runs GROUP BY user_id
      ) r ON r.user_id = u.id
      LEFT JOIN (
        SELECT user_id, COALESCE(SUM(byte_size),0) AS storage
        FROM artifacts GROUP BY user_id
      ) a ON a.user_id = u.id
      ORDER BY tokens DESC LIMIT 10
    `).all();

    const recentRuns = db.prepare(`
      SELECT r.id, u.username, r.title, r.status, r.model, r.total_tokens,
             r.created_at, r.completed_at
      FROM agent_runs r
      JOIN users u ON u.id = r.user_id
      ORDER BY r.created_at DESC LIMIT 25
    `).all();

    res.json({ stats, runsByDay, usersByDay, modelBreakdown, statusBreakdown, topUsers, recentRuns });
  } catch (err) {
    res.status(500).json({ error: String(err.message || err) });
  }
});

// --- User management ---

router.get('/api/users', requireAdminAuth, (req, res) => {
  const db = require('../db/database');
  const q  = req.query.q ? `%${req.query.q}%` : null;
  try {
    const sql = `
      SELECT u.id, u.username, u.display_name, u.email, u.email_verified_at,
             u.created_at, u.last_login, u.rate_limit_4h, u.rate_limit_weekly,
             COALESCE(r.run_count,    0) AS run_count,
             COALESCE(a.storage_bytes,0) AS storage_bytes
      FROM users u
      LEFT JOIN (
        SELECT user_id, COUNT(*) AS run_count
        FROM agent_runs GROUP BY user_id
      ) r ON r.user_id = u.id
      LEFT JOIN (
        SELECT user_id, COALESCE(SUM(byte_size),0) AS storage_bytes
        FROM artifacts GROUP BY user_id
      ) a ON a.user_id = u.id
      ${q ? 'WHERE u.username LIKE ? OR u.email LIKE ?' : ''}
      ORDER BY u.created_at DESC LIMIT 200`;
    const users = q ? db.prepare(sql).all(q, q) : db.prepare(sql).all();
    res.json({ users });
  } catch (err) {
    res.status(500).json({ error: String(err.message || err) });
  }
});

router.delete('/api/users/:id', requireAdminAuth, (req, res) => {
  const { eraseUserData } = require('../services/account/erasure');
  const { id } = req.params;
  if (!id) return res.status(400).json({ error: 'Missing user id' });
  if (!/^\d+$/.test(id)) return res.status(400).json({ error: 'Invalid user id' });
  try {
    const result = eraseUserData(id, { runtimeManager: req.app.locals.runtimeManager });
    res.json(result);
  } catch (err) {
    if (err.code === 'NOT_FOUND') return res.status(404).json({ error: 'User not found' });
    if (err.code === 'INVALID_ID') return res.status(400).json({ error: 'Invalid user id' });
    res.status(500).json({ error: String(err.message || err) });
  }
});

router.delete('/api/users/:id/sessions', requireAdminAuth, (req, res) => {
  const db = require('../db/database');
  const { id } = req.params;
  try {
    db.prepare('UPDATE user_sessions SET revoked_at = ? WHERE user_id = ?').run(new Date().toISOString(), id);
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: String(err.message || err) });
  }
});

// --- SQL editor (read-only SELECT only) ---

const SQL_BLOCKED = /\b(INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|ATTACH|DETACH|TRUNCATE|VACUUM|REINDEX|REPLACE|UPSERT|PRAGMA)\b/i;

router.post('/api/sql', requireAdminAuth, sqlLimiter, express.json(), (req, res) => {
  const { query } = req.body || {};
  if (!query || typeof query !== 'string') return res.status(400).json({ error: 'No query provided' });
  const trimmed = query.trim();
  if (!/^(SELECT|WITH)\b/i.test(trimmed)) return res.status(400).json({ error: 'Only SELECT (or WITH …) queries are allowed' });
  if (SQL_BLOCKED.test(trimmed))           return res.status(400).json({ error: 'Query contains a blocked SQL keyword' });
  try {
    const db = require('../db/database');
    const limited = [];
    for (const row of db.prepare(trimmed).iterate()) {
      limited.push(row);
      if (limited.length > 500) break;
    }
    const truncated = limited.length > 500;
    if (truncated) limited.pop();
    const columns = limited.length ? Object.keys(limited[0]) : [];
    res.json({ rows: limited, columns, truncated, total: truncated ? null : limited.length });
  } catch (err) {
    res.status(400).json({ error: String(err.message || err) });
  }
});

// --- Providers ---

const PROVIDERS = [
  { key: 'ANTHROPIC_API_KEY',           label: 'Anthropic (Claude)',          type: 'key' },
  { key: 'OPENAI_API_KEY',              label: 'OpenAI',                      type: 'key' },
  {
    key: 'OPENAI_COMPATIBLE_API_KEY',
    label: 'Custom OpenAI-compatible token',
    type: 'key',
  },
  {
    key: 'OPENAI_COMPATIBLE_BASE_URL',
    label: 'Custom OpenAI-compatible base URL',
    type: 'url',
  },
  { key: 'XAI_API_KEY',                 label: 'xAI (Grok)',                  type: 'key' },
  { key: 'GOOGLE_AI_KEY',               label: 'Google (Gemini)',              type: 'key' },
  { key: 'MINIMAX_API_KEY',             label: 'MiniMax',                     type: 'key' },
  { key: 'NVIDIA_API_KEY',              label: 'NVIDIA NIM',                  type: 'key' },
  { key: 'OPENROUTER_API_KEY',          label: 'OpenRouter',                  type: 'key' },
  { key: 'BRAVE_SEARCH_API_KEY',        label: 'Brave Search',                type: 'key' },
  { key: 'DEEPGRAM_API_KEY',            label: 'Deepgram (Voice)',             type: 'key' },
  { key: 'GITHUB_COPILOT_ACCESS_TOKEN', label: 'GitHub Copilot',              type: 'key' },
  { key: 'OPENAI_CODEX_ACCESS_TOKEN',   label: 'OpenAI Codex',                type: 'key' },
  { key: 'OLLAMA_URL',                  label: 'Ollama (Local)',               type: 'url' },
  { key: 'OPENAI_BASE_URL',             label: 'OpenAI Base URL override',    type: 'url' },
  { key: 'ANTHROPIC_BASE_URL',          label: 'Anthropic Base URL override', type: 'url' },
  { key: 'XAI_BASE_URL',               label: 'xAI Base URL override',       type: 'url' },
];

const ALLOWED_PROVIDER_KEYS = new Set(PROVIDERS.map((p) => p.key));
const PROVIDER_BY_KEY = new Map(PROVIDERS.map((provider) => [provider.key, provider]));

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
  const provider = PROVIDER_BY_KEY.get(key);
  if (!ALLOWED_PROVIDER_KEYS.has(key) || !provider) {
    return res.status(400).json({ error: 'Unknown provider key' });
  }
  const trimmed = String(value || '').trim().replace(/[\r\n]/g, '');
  if (provider.type === 'url' && trimmed) {
    try {
      const url = new URL(trimmed);
      if (!['http:', 'https:'].includes(url.protocol) || !url.hostname) {
        return res.status(400).json({ error: 'Provider URL must use HTTP or HTTPS' });
      }
      if (url.username || url.password) {
        return res.status(400).json({ error: 'Provider URL must not contain embedded credentials' });
      }
    } catch {
      return res.status(400).json({ error: 'Provider URL must be a valid HTTP or HTTPS URL' });
    }
  }
  upsertEnvValue(ENV_FILE, key, trimmed);
  if (trimmed) {
    process.env[key] = trimmed;
  } else {
    delete process.env[key];
  }
  res.json({ ok: true });
});

// --- General server config ---

function parseEnvBool(key, defaultVal) {
  const v = (process.env[key] || '').toLowerCase();
  return v ? ['1', 'true', 'yes', 'on'].includes(v) : defaultVal;
}

function parseEnvInt(key, defaultVal) {
  const n = parseInt(process.env[key] || '', 10);
  return Number.isFinite(n) ? n : defaultVal;
}

function cleanLine(v) {
  return String(v ?? '').trim().replace(/[\r\n]/g, '');
}

function persistEnv(key, value) {
  const strVal = String(value);
  upsertEnvValue(ENV_FILE, key, strVal);
  if (strVal === '') {
    delete process.env[key];
  } else {
    process.env[key] = strVal;
  }
}

router.get('/api/config/general', requireAdminAuth, (req, res) => {
  res.json({
    settings: {
      publicUrl: process.env.PUBLIC_URL || '',
      secureCookies: parseEnvBool('SECURE_COOKIES', false),
      neoagentProfile: process.env.NEOAGENT_PROFILE || '',
      allowedOrigins: process.env.ALLOWED_ORIGINS || '',
      meshtasticEnabled: parseEnvBool('MESHTASTIC_ENABLED', true),
      memoryIngestionIntervalMs: parseEnvInt('NEOAGENT_MEMORY_INGESTION_INTERVAL_MS', 600000),
    },
  });
});

router.put('/api/config/general', requireAdminAuth, settingsLimiter, express.json(), (req, res) => {
  try {
    const b = req.body || {};
    const publicUrl = cleanLine(b.publicUrl);
    if (publicUrl) {
      try { new URL(publicUrl); } catch {
        return res.status(400).json({ error: 'publicUrl must be a valid URL.' });
      }
    }
    const profile = cleanLine(b.neoagentProfile);
    if (profile && !['prod', 'private'].includes(profile)) {
      return res.status(400).json({ error: 'neoagentProfile must be "prod" or "private".' });
    }
    const allowedOrigins = cleanLine(b.allowedOrigins);
    const intervalMs = parseInt(b.memoryIngestionIntervalMs, 10);
    if (!Number.isFinite(intervalMs) || intervalMs < 1000) {
      return res.status(400).json({ error: 'memoryIngestionIntervalMs must be ≥ 1000.' });
    }
    if (typeof b.secureCookies !== 'boolean') {
      return res.status(400).json({ error: 'secureCookies must be a boolean.' });
    }
    if (typeof b.meshtasticEnabled !== 'boolean') {
      return res.status(400).json({ error: 'meshtasticEnabled must be a boolean.' });
    }

    persistEnv('PUBLIC_URL', publicUrl);
    persistEnv('SECURE_COOKIES', b.secureCookies ? 'true' : 'false');
    persistEnv('NEOAGENT_PROFILE', profile);
    persistEnv('ALLOWED_ORIGINS', allowedOrigins);
    persistEnv('MESHTASTIC_ENABLED', b.meshtasticEnabled ? 'true' : 'false');
    persistEnv('NEOAGENT_MEMORY_INGESTION_INTERVAL_MS', String(intervalMs));

    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --- VM runtime config ---

router.get('/api/config/vm', requireAdminAuth, (req, res) => {
  res.json({
    settings: {
      vmBaseImageUrl: process.env.NEOAGENT_VM_BASE_IMAGE_URL || '',
      vmBaseImage: process.env.NEOAGENT_VM_BASE_IMAGE || '',
      vmMemoryMb: parseEnvInt('NEOAGENT_VM_MEMORY_MB', 4096),
      vmCpus: parseEnvInt('NEOAGENT_VM_CPUS', 2),
    },
  });
});

router.put('/api/config/vm', requireAdminAuth, settingsLimiter, express.json(), (req, res) => {
  try {
    const b = req.body || {};
    const vmBaseImageUrl = cleanLine(b.vmBaseImageUrl);
    const vmBaseImage = cleanLine(b.vmBaseImage);
    const vmMemoryMb = parseInt(b.vmMemoryMb, 10);
    const vmCpus = parseInt(b.vmCpus, 10);

    if (vmBaseImageUrl) {
      try { new URL(vmBaseImageUrl); } catch {
        return res.status(400).json({ error: 'vmBaseImageUrl must be a valid URL.' });
      }
    }
    if (!Number.isFinite(vmMemoryMb) || vmMemoryMb < 512) {
      return res.status(400).json({ error: 'vmMemoryMb must be ≥ 512.' });
    }
    if (!Number.isFinite(vmCpus) || vmCpus < 1) {
      return res.status(400).json({ error: 'vmCpus must be ≥ 1.' });
    }

    persistEnv('NEOAGENT_VM_BASE_IMAGE_URL', vmBaseImageUrl);
    persistEnv('NEOAGENT_VM_BASE_IMAGE', vmBaseImage);
    persistEnv('NEOAGENT_VM_MEMORY_MB', String(vmMemoryMb));
    persistEnv('NEOAGENT_VM_CPUS', String(vmCpus));

    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --- OAuth integrations config ---

const OAUTH_INTEGRATIONS = [
  {
    key: 'google',
    label: 'Google Workspace',
    fields: [
      { name: 'clientId',     env: 'GOOGLE_OAUTH_CLIENT_ID',     secret: false },
      { name: 'clientSecret', env: 'GOOGLE_OAUTH_CLIENT_SECRET', secret: true  },
      { name: 'redirectUri',  env: 'GOOGLE_OAUTH_REDIRECT_URI',  secret: false },
    ],
  },
  {
    key: 'notion',
    label: 'Notion',
    fields: [
      { name: 'clientId',     env: 'NOTION_OAUTH_CLIENT_ID',     secret: false },
      { name: 'clientSecret', env: 'NOTION_OAUTH_CLIENT_SECRET', secret: true  },
      { name: 'redirectUri',  env: 'NOTION_OAUTH_REDIRECT_URI',  secret: false },
    ],
  },
  {
    key: 'microsoft',
    label: 'Microsoft 365',
    fields: [
      { name: 'clientId',     env: 'MICROSOFT_OAUTH_CLIENT_ID',     secret: false },
      { name: 'clientSecret', env: 'MICROSOFT_OAUTH_CLIENT_SECRET', secret: true  },
      { name: 'redirectUri',  env: 'MICROSOFT_OAUTH_REDIRECT_URI',  secret: false },
      { name: 'tenantId',     env: 'MICROSOFT_OAUTH_TENANT_ID',     secret: false },
    ],
  },
  {
    key: 'slack',
    label: 'Slack',
    fields: [
      { name: 'clientId',     env: 'SLACK_OAUTH_CLIENT_ID',     secret: false },
      { name: 'clientSecret', env: 'SLACK_OAUTH_CLIENT_SECRET', secret: true  },
      { name: 'redirectUri',  env: 'SLACK_OAUTH_REDIRECT_URI',  secret: false },
    ],
  },
  {
    key: 'figma',
    label: 'Figma',
    fields: [
      { name: 'clientId',     env: 'FIGMA_OAUTH_CLIENT_ID',     secret: false },
      { name: 'clientSecret', env: 'FIGMA_OAUTH_CLIENT_SECRET', secret: true  },
      { name: 'redirectUri',  env: 'FIGMA_OAUTH_REDIRECT_URI',  secret: false },
    ],
  },
  {
    key: 'github',
    label: 'GitHub',
    fields: [
      { name: 'clientId',     env: 'GITHUB_OAUTH_CLIENT_ID',     secret: false },
      { name: 'clientSecret', env: 'GITHUB_OAUTH_CLIENT_SECRET', secret: true  },
      { name: 'redirectUri',  env: 'GITHUB_OAUTH_REDIRECT_URI',  secret: false },
    ],
  },
  {
    key: 'spotify',
    label: 'Spotify',
    fields: [
      { name: 'clientId',     env: 'SPOTIFY_OAUTH_CLIENT_ID',     secret: false },
      { name: 'clientSecret', env: 'SPOTIFY_OAUTH_CLIENT_SECRET', secret: true  },
      { name: 'redirectUri',  env: 'SPOTIFY_OAUTH_REDIRECT_URI',  secret: false },
    ],
  },
  {
    key: 'trello',
    label: 'Trello',
    fields: [
      { name: 'apiKey', env: 'TRELLO_API_KEY', secret: false },
    ],
  },
];

const OAUTH_ENV_KEYS = new Set(
  OAUTH_INTEGRATIONS.flatMap((i) => i.fields.map((f) => f.env))
);

router.get('/api/config/integrations', requireAdminAuth, (req, res) => {
  const integrations = OAUTH_INTEGRATIONS.map(({ key, label, fields }) => {
    const fieldData = fields.map(({ name, env, secret }) => {
      const value = process.env[env] || '';
      if (secret) {
        return { name, secret: true, configured: Boolean(value) };
      }
      return { name, secret: false, value };
    });
    const configured = fields.every(({ env }) => Boolean(process.env[env]));
    return { key, label, configured, fields: fieldData };
  });

  // Deepgram service settings (not secret, grouped here)
  const deepgram = {
    baseUrl: process.env.DEEPGRAM_BASE_URL || '',
    model: process.env.DEEPGRAM_MODEL || '',
    language: process.env.DEEPGRAM_LANGUAGE || '',
  };

  res.json({ integrations, deepgram });
});

router.put('/api/config/integrations', requireAdminAuth, settingsLimiter, express.json(), (req, res) => {
  try {
    const b = req.body || {};

    // OAuth integrations
    const patches = b.integrations || {};
    for (const [intKey, fieldValues] of Object.entries(patches)) {
      const integration = OAUTH_INTEGRATIONS.find((i) => i.key === intKey);
      if (!integration) continue;
      for (const [fieldName, value] of Object.entries(fieldValues)) {
        const fieldDef = integration.fields.find((f) => f.name === fieldName);
        if (!fieldDef) continue;
        const cleaned = cleanLine(value);
        if (fieldDef.secret && cleaned === '') continue; // blank = no-change for secrets
        persistEnv(fieldDef.env, cleaned);
      }
    }

    // Deepgram config
    if (b.deepgram) {
      persistEnv('DEEPGRAM_BASE_URL', cleanLine(b.deepgram.baseUrl));
      persistEnv('DEEPGRAM_MODEL', cleanLine(b.deepgram.model));
      persistEnv('DEEPGRAM_LANGUAGE', cleanLine(b.deepgram.language));
    }

    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --- Stripe / billing setup config ---

router.get('/api/config/billing-setup', requireAdminAuth, (req, res) => {
  const secretKey = process.env.STRIPE_SECRET_KEY || '';
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET || '';
  res.json({
    settings: {
      billingEnabled: parseEnvBool('NEOAGENT_BILLING_ENABLED', false),
      stripePublishableKey: process.env.STRIPE_PUBLISHABLE_KEY || '',
      stripeSecretKeyConfigured: Boolean(secretKey),
      stripeSecretKeyHint: secretKey.length > 8
        ? `${secretKey.slice(0, 7)}${'•'.repeat(4)}${secretKey.slice(-4)}`
        : secretKey ? '•'.repeat(secretKey.length) : '',
      stripeWebhookSecretConfigured: Boolean(webhookSecret),
      trialDays: parseEnvInt('BILLING_TRIAL_DAYS', 14),
    },
  });
});

router.put('/api/config/billing-setup', requireAdminAuth, settingsLimiter, express.json(), (req, res) => {
  try {
    const b = req.body || {};
    if (typeof b.billingEnabled !== 'boolean') {
      return res.status(400).json({ error: 'billingEnabled must be a boolean.' });
    }
    const publishableKey = cleanLine(b.stripePublishableKey);
    const secretKey = cleanLine(b.stripeSecretKey || '');
    const webhookSecret = cleanLine(b.stripeWebhookSecret || '');
    const trialDays = parseInt(b.trialDays, 10);
    if (!Number.isFinite(trialDays) || trialDays < 0) {
      return res.status(400).json({ error: 'trialDays must be ≥ 0.' });
    }

    persistEnv('NEOAGENT_BILLING_ENABLED', b.billingEnabled ? 'true' : 'false');
    persistEnv('STRIPE_PUBLISHABLE_KEY', publishableKey);
    if (secretKey) persistEnv('STRIPE_SECRET_KEY', secretKey);
    if (webhookSecret) persistEnv('STRIPE_WEBHOOK_SECRET', webhookSecret);
    persistEnv('BILLING_TRIAL_DAYS', String(trialDays));

    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --- Global default rate limits ---

router.get('/api/config/rate-limits', requireAdminAuth, (req, res) => {
  const defaults = configuredDefaultLimits();
  res.json({
    rate_limit_4h: defaults.fourHour,
    rate_limit_weekly: defaults.weekly,
  });
});

router.put('/api/config/rate-limits', requireAdminAuth, express.json(), (req, res) => {
  const { rate_limit_4h, rate_limit_weekly } = req.body || {};
  const parse = (v) => (v !== null && v !== undefined && v !== '' ? parseInt(v, 10) : null);
  const v4h = parse(rate_limit_4h);
  const vWeekly = parse(rate_limit_weekly);
  upsertEnvValue(ENV_FILE, 'NEOAGENT_RATE_LIMIT_4H', v4h !== null ? String(v4h) : '');
  upsertEnvValue(ENV_FILE, 'NEOAGENT_RATE_LIMIT_WEEKLY', vWeekly !== null ? String(vWeekly) : '');
  process.env.NEOAGENT_RATE_LIMIT_4H = v4h !== null ? String(v4h) : '';
  process.env.NEOAGENT_RATE_LIMIT_WEEKLY = vWeekly !== null ? String(vWeekly) : '';
  res.json({ ok: true });
});

// --- Models ---

router.get('/api/models', requireAdminAuth, async (req, res) => {
  const { getSupportedModels } = require('../services/ai/models');
  const { reconcileModelVisibility } = require('../services/ai/model_visibility');
  try {
    const models = await getSupportedModels(null, null, { signal: req.signal });
    // Syncs newly-discovered / retired models into the tracked list and
    // applies the default enable/disable policy for anything new.
    const disabledModels = reconcileModelVisibility(models.map((m) => m.id));
    res.json({ models, disabledModels });
  } catch (err) {
    res.status(500).json({ error: String(err.message || err) });
  }
});

router.put('/api/models/config', requireAdminAuth, express.json(), (req, res) => {
  const { setDisabledModelIds } = require('../services/ai/model_visibility');
  const { disabledModels } = req.body || {};
  if (!Array.isArray(disabledModels)) return res.status(400).json({ error: 'disabledModels must be an array' });
  const saved = setDisabledModelIds(disabledModels);
  res.json({ ok: true, disabledModels: saved });
});

router.get('/api/users/:id/rate-limits', requireAdminAuth, (req, res) => {
  const db = require('../db/database');
  const { id } = req.params;
  try {
    const row = db.prepare('SELECT rate_limit_4h, rate_limit_weekly FROM users WHERE id = ?').get(id);
    if (!row) return res.status(404).json({ error: 'User not found' });
    res.json({ limits: row });
  } catch (err) {
    res.status(500).json({ error: String(err.message || err) });
  }
});

router.put('/api/users/:id/rate-limits', requireAdminAuth, express.json(), (req, res) => {
  const db = require('../db/database');
  const { id } = req.params;
  const { rate_limit_4h, rate_limit_weekly } = req.body || {};
  try {
    db.prepare('UPDATE users SET rate_limit_4h = ?, rate_limit_weekly = ? WHERE id = ?').run(
      rate_limit_4h ?? null,
      rate_limit_weekly ?? null,
      id
    );
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: String(err.message || err) });
  }
});

// --- Billing admin routes (only when billing is enabled) ---

(function registerBillingRoutes() {
  const { isBillingEnabled } = require('../services/billing/config');
  if (!isBillingEnabled()) return;

  const billingPlans = require('../services/billing/plans');
  const billingSubscriptions = require('../services/billing/subscriptions');

  // Plans CRUD
  router.get('/api/billing/plans', requireAdminAuth, (req, res) => {
    try {
      res.json({ plans: billingPlans.listPlans({ includeInactive: true }) });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  router.post('/api/billing/plans', requireAdminAuth, express.json(), (req, res) => {
    try {
      const plan = billingPlans.createPlan(req.body);
      res.status(201).json({ plan });
    } catch (err) {
      res.status(400).json({ error: err.message });
    }
  });

  router.put('/api/billing/plans/:id', requireAdminAuth, express.json(), (req, res) => {
    try {
      const plan = billingPlans.updatePlan(req.params.id, req.body);
      if (!plan) return res.status(404).json({ error: 'Plan not found.' });
      res.json({ plan });
    } catch (err) {
      res.status(400).json({ error: err.message });
    }
  });

  router.delete('/api/billing/plans/:id', requireAdminAuth, (req, res) => {
    try {
      billingPlans.deletePlan(req.params.id);
      res.json({ ok: true });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  // Subscription browser (all users)
  router.get('/api/billing/subscriptions', requireAdminAuth, (req, res) => {
    try {
      const db = require('../db/database');
      const limit = Math.min(parseInt(req.query.limit || '50', 10), 200);
      const offset = parseInt(req.query.offset || '0', 10);
      const status = req.query.status || null;

      const where = status ? "WHERE s.status = ?" : "";
      const params = status ? [status, limit, offset] : [limit, offset];

      const rows = db.prepare(`
        SELECT s.*, u.username, u.email, u.display_name,
               p.name AS plan_name, p.price_cents, p.currency
        FROM user_subscriptions s
        JOIN users u ON u.id = s.user_id
        JOIN billing_plans p ON p.id = s.plan_id
        ${where}
        ORDER BY s.updated_at DESC
        LIMIT ? OFFSET ?
      `).all(...params);

      const total = db.prepare(
        `SELECT COUNT(*) AS n FROM user_subscriptions s ${where}`,
      ).get(...(status ? [status] : [])).n;

      res.json({ subscriptions: rows, total, limit, offset });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  // Per-user subscription management
  router.get('/api/billing/users/:id/subscription', requireAdminAuth, (req, res) => {
    const userId = parseInt(req.params.id, 10);
    if (isNaN(userId)) return res.status(400).json({ error: 'Invalid user id.' });
    try {
      const sub = billingSubscriptions.getActiveSubscription(userId);
      res.json({ subscription: sub });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  router.post('/api/billing/users/:id/subscription', requireAdminAuth, express.json(), (req, res) => {
    const userId = parseInt(req.params.id, 10);
    if (isNaN(userId)) return res.status(400).json({ error: 'Invalid user id.' });
    try {
      const { planId, status } = req.body;
      if (!planId) return res.status(400).json({ error: 'planId is required.' });
      const sub = billingSubscriptions.adminSetSubscription(userId, planId, status);
      res.json({ subscription: sub });
    } catch (err) {
      res.status(err.statusCode || 500).json({ error: err.message });
    }
  });

  router.delete('/api/billing/users/:id/subscription', requireAdminAuth, (req, res) => {
    const userId = parseInt(req.params.id, 10);
    if (isNaN(userId)) return res.status(400).json({ error: 'Invalid user id.' });
    try {
      billingSubscriptions.adminCancelSubscription(userId);
      res.json({ ok: true });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });
})();

// --- API 404 guard (must come before static files) ---
// Prevents unregistered /api/* routes (e.g. billing when disabled) from
// falling through to the HTML catch-all and returning a false 200.

router.all('/api/*path', (req, res) => {
  res.status(404).json({ error: 'Not found.' });
});

// --- Static files ---

router.use(express.static(ADMIN_DIR));

router.get('{*path}', requireAdminAuth, (req, res) => {
  res.sendFile(path.join(ADMIN_DIR, 'index.html'));
});

module.exports = router;
