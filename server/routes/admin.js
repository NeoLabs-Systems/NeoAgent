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

router.get('/login', (req, res) => {
  if (req.session?.isAdmin) return res.redirect('/admin');
  res.sendFile(path.join(ADMIN_DIR, 'login.html'));
});

router.post('/api/login', loginLimiter, express.json(), async (req, res) => {
  const { username, password } = req.body || {};
  const expectedUsername = process.env.ADMIN_USERNAME || 'admin';
  const expectedPassword = process.env.ADMIN_PASSWORD || 'admin';
  if (username !== expectedUsername || password !== expectedPassword) {
    return res.status(401).json({ error: 'Invalid credentials' });
  }
  // Check whether 2FA is enabled
  const adminTwoFactor = require('../services/account/admin_two_factor');
  const tfStatus = adminTwoFactor.getStatus();
  if (tfStatus.enabled) {
    // Park the session in a "password OK, waiting for TOTP" state
    req.session.adminPendingTwoFactor = true;
    delete req.session.isAdmin;
    return req.session.save((err) => {
      if (err) return res.status(500).json({ error: 'Session error' });
      res.json({ ok: false, requiresTwoFactor: true });
    });
  }
  req.session.isAdmin = true;
  req.session.cookie.maxAge = ADMIN_SESSION_TTL;
  req.session.save((err) => {
    if (err) return res.status(500).json({ error: 'Session error' });
    res.json({ ok: true });
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
    req.session.adminPendingTwoFactor = false;
    req.session.isAdmin = true;
    req.session.cookie.maxAge = ADMIN_SESSION_TTL;
    req.session.save((err) => {
      if (err) return res.status(500).json({ error: 'Session error' });
      res.json({ ok: true });
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
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
  const db = require('../db/database');
  const { DATA_DIR } = require('../../runtime/paths');
  const { id } = req.params;
  if (!id) return res.status(400).json({ error: 'Missing user id' });
  try {
    // Collect artifact paths before deletion
    const artifacts = db.prepare('SELECT storage_path FROM artifacts WHERE user_id = ?').all(id);

    const erase = db.transaction((uid) => {
      db.prepare('DELETE FROM conversation_messages WHERE conversation_id IN (SELECT id FROM conversations WHERE user_id = ?)').run(uid);
      db.prepare('DELETE FROM conversations WHERE user_id = ?').run(uid);
      db.prepare('DELETE FROM agent_steps WHERE run_id IN (SELECT id FROM agent_runs WHERE user_id = ?)').run(uid);
      db.prepare('DELETE FROM agent_runs WHERE user_id = ?').run(uid);
      db.prepare('DELETE FROM messages WHERE user_id = ?').run(uid);
      db.prepare('DELETE FROM memories WHERE user_id = ?').run(uid);
      db.prepare('DELETE FROM integration_connections WHERE user_id = ?').run(uid);
      db.prepare('DELETE FROM platform_connections WHERE user_id = ?').run(uid);
      db.prepare('DELETE FROM mcp_servers WHERE user_id = ?').run(uid);
      db.prepare('DELETE FROM user_settings WHERE user_id = ?').run(uid);
      db.prepare('DELETE FROM user_sessions WHERE user_id = ?').run(uid);
      db.prepare('DELETE FROM desktop_companion_devices WHERE user_id = ?').run(uid);
      db.prepare('DELETE FROM scheduled_tasks WHERE user_id = ?').run(uid);
      db.prepare('DELETE FROM recording_sessions WHERE user_id = ?').run(uid);
      db.prepare('DELETE FROM screen_history WHERE user_id = ?').run(uid);
      db.prepare('DELETE FROM agents WHERE user_id = ?').run(uid);
      db.prepare('DELETE FROM artifacts WHERE user_id = ?').run(uid);
      db.prepare('DELETE FROM users WHERE id = ?').run(uid);
    });
    erase(id);

    // Clean up artifact files on disk
    for (const artifact of artifacts) {
      try {
        const abs = path.isAbsolute(artifact.storage_path)
          ? artifact.storage_path
          : path.join(DATA_DIR, artifact.storage_path);
        fs.rmSync(abs, { force: true });
      } catch {}
    }
    try { fs.rmSync(path.join(DATA_DIR, 'artifacts', id), { recursive: true, force: true }); } catch {}

    res.json({ ok: true });
  } catch (err) {
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
    const rows = db.prepare(trimmed).all();
    const limited = rows.slice(0, 500);
    const columns = limited.length ? Object.keys(limited[0]) : [];
    res.json({ rows: limited, columns, truncated: rows.length > 500, total: rows.length });
  } catch (err) {
    res.status(400).json({ error: String(err.message || err) });
  }
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
  const trimmed = String(value || '').trim().replace(/[\r\n]/g, '');
  upsertEnvValue(ENV_FILE, key, trimmed);
  if (trimmed) {
    process.env[key] = trimmed;
  } else {
    delete process.env[key];
  }
  res.json({ ok: true });
});

// --- Global default rate limits ---

router.get('/api/config/rate-limits', requireAdminAuth, (req, res) => {
  res.json({
    rate_limit_4h: process.env.NEOAGENT_RATE_LIMIT_4H ? parseInt(process.env.NEOAGENT_RATE_LIMIT_4H, 10) : null,
    rate_limit_weekly: process.env.NEOAGENT_RATE_LIMIT_WEEKLY ? parseInt(process.env.NEOAGENT_RATE_LIMIT_WEEKLY, 10) : null,
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
  try {
    const models = await getSupportedModels(null, null);
    const disabledStr = process.env.NEOAGENT_DISABLED_MODELS || '';
    const disabledModels = disabledStr ? disabledStr.split(',').map(s => s.trim()).filter(Boolean) : [];
    res.json({ models, disabledModels });
  } catch (err) {
    res.status(500).json({ error: String(err.message || err) });
  }
});

router.put('/api/models/config', requireAdminAuth, express.json(), (req, res) => {
  const { disabledModels } = req.body || {};
  if (!Array.isArray(disabledModels)) return res.status(400).json({ error: 'disabledModels must be an array' });
  const value = disabledModels.join(',');
  upsertEnvValue(ENV_FILE, 'NEOAGENT_DISABLED_MODELS', value);
  process.env.NEOAGENT_DISABLED_MODELS = value;
  res.json({ ok: true });
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

// --- Static files ---

router.use(express.static(ADMIN_DIR));

router.get('*', requireAdminAuth, (req, res) => {
  res.sendFile(path.join(ADMIN_DIR, 'index.html'));
});

module.exports = router;
