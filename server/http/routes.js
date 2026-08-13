'use strict';

const { requireAuth } = require('../middleware/auth');
const { getVersionInfo } = require('../utils/version');
const { getRuntimeValidation } = require('../services/runtime/validation');

const routeRegistry = [
  { basePath: '/api/public', modulePath: '../routes/public_status' },
  { basePath: '/api/setup', modulePath: '../routes/setup' },
  { basePath: '/api/runtime', modulePath: '../routes/runtime' },
  { basePath: '/api/computer', modulePath: '../routes/computer' },
  { basePath: '/api/cowork', modulePath: '../routes/cowork' },
  { basePath: null, modulePath: '../routes/auth' },
  { basePath: '/api/account', modulePath: '../routes/account' },
  { basePath: '/api/settings', modulePath: '../routes/settings' },
  { basePath: '/api/behavior', modulePath: '../routes/behavior' },
  { basePath: '/api/agent-profiles', modulePath: '../routes/agent_profiles' },
  { basePath: '/api/agents', modulePath: '../routes/agents' },
  { basePath: '/api/messaging', modulePath: '../routes/messaging' },
  { basePath: '/api/mcp', modulePath: '../routes/mcp' },
  { basePath: '/api/integrations', modulePath: '../routes/integrations' },
  { basePath: '/api/skills', modulePath: '../routes/skills' },
  { basePath: '/api/store', modulePath: '../routes/store' },
  { basePath: '/api/artifacts', modulePath: '../routes/artifacts' },
  { basePath: '/api/memory', modulePath: '../routes/memory' },
  { basePath: '/api/tasks', modulePath: '../routes/tasks' },
  { basePath: '/api/task-webhooks', modulePath: '../routes/task_webhooks' },
  { basePath: '/api/android', modulePath: '../routes/android' },
  { basePath: '/api/stream', modulePath: '../routes/stream' },
  { basePath: '/api/social-video', modulePath: '../routes/social_video' },
  { basePath: '/api/social-reach', modulePath: '../routes/social_reach' },
  { basePath: '/api/voice-assistant', modulePath: '../routes/voice_assistant' },
  { basePath: '/api/wearable', modulePath: '../routes/wearable' },
  { basePath: '/api/mobile/health', modulePath: '../routes/mobile-health' },
  { basePath: '/api/timeline', modulePath: '../routes/timeline' },
  { basePath: '/api/triggers', modulePath: '../routes/triggers' },
  { basePath: '/api/security', modulePath: '../routes/security' },
];

function registerApiRoutes(app) {
  for (const route of routeRegistry) {
    const handler = require(route.modulePath);
    if (route.basePath) {
      app.use(route.basePath, handler);
    } else {
      app.use(handler);
    }
  }

  // Billing routes are mounted conditionally — only when billing is enabled.
  // The webhook must be mounted before express.json() consumes the raw body;
  // billing_webhook.js applies express.raw() inline for its own route.
  const { isBillingEnabled } = require('../services/billing/config');
  if (isBillingEnabled()) {
    app.use('/api/billing/webhook', require('../routes/billing_webhook'));
    app.use('/api/billing', require('../routes/billing'));
  } else {
    // The Flutter client probes this public endpoint to decide whether to show
    // billing. Return an explicit disabled state instead of generating a noisy
    // 404 on every client startup.
    app.get('/api/billing/plans', (_req, res) => {
      res.json({ enabled: false, plans: null });
    });
  }

  app.get('/api/health', requireAuth, (req, res) => {
    const runtimeValidation = getRuntimeValidation(req.app?.locals?.runtimeManager);
    const ready = Boolean(runtimeValidation && runtimeValidation.ready);
    const issueCount = Array.isArray(runtimeValidation?.issues)
      ? runtimeValidation.issues.length
      : 0;
    res.json({
      status: ready ? 'ok' : 'degraded',
      timestamp: new Date().toISOString(),
      runtime: {
        ready,
        issueCount,
        summary: ready
          ? 'Runtime validation passed.'
          : (issueCount > 0
              ? `${issueCount} runtime validation issue(s) detected.`
              : 'Runtime validation is unavailable.'),
      },
    });
  });

  app.get('/api/system/health-check', requireAuth, async (req, res) => {
    const userId = req.session?.userId;
    const runtimeManager = req.app?.locals?.runtimeManager;
    const results = [];

    // 1. Backend connectivity — trivially true if we got here.
    results.push({ id: 'backend', label: 'Backend server', passed: true, detail: 'Reachable' });

    // 2. Cloud VM runtime availability.
    const runtimeValidation = getRuntimeValidation(runtimeManager);
    const runtimeReady = Boolean(runtimeValidation?.ready);
    results.push({
      id: 'vm_runtime',
      label: 'Cloud VM runtime',
      passed: runtimeReady,
      detail: runtimeReady ? 'Available' : String(runtimeValidation?.issues?.[0] || 'Not configured'),
    });

    // 3. Cloud VM CLI execution — actually run a command.
    if (runtimeManager && typeof runtimeManager.executeCommand === 'function') {
      try {
        const cmdResult = await runtimeManager.executeCommand(userId, 'echo "health_check_ok"', { timeout: 15000 });
        const exitOk = cmdResult?.exitCode === 0;
        const outputOk = String(cmdResult?.stdout || '').includes('health_check_ok');
        results.push({
          id: 'vm_cli',
          label: 'Cloud VM — command execution',
          passed: exitOk && outputOk,
          detail: exitOk && outputOk
            ? 'Commands running'
            : `Exit ${cmdResult?.exitCode ?? '?'}: ${String(cmdResult?.stderr || cmdResult?.stdout || '').slice(0, 120)}`,
        });
      } catch (err) {
        results.push({ id: 'vm_cli', label: 'Cloud VM — command execution', passed: false, detail: String(err?.message || err).slice(0, 120) });
      }
    } else {
      results.push({ id: 'vm_cli', label: 'Cloud VM — command execution', passed: false, detail: 'VM runtime unavailable' });
    }

    const allPassed = results.every((r) => r.passed);
    res.json({ passed: allPassed, results });
  });

  // Targeted runtime self-tests — one check per endpoint so the UI can embed
  // results inline next to the relevant settings control.

  app.get('/api/system/test/cli', requireAuth, async (req, res) => {
    const userId = req.session?.userId;
    const runtimeManager = req.app?.locals?.runtimeManager;
    if (!runtimeManager || typeof runtimeManager.executeCliCommand !== 'function') {
      return res.json({ passed: false, backendUsed: 'vm', detail: 'Runtime not configured on this server.' });
    }
    try {
      const result = await runtimeManager.executeCliCommand(userId, 'echo "cli_test_ok"', { timeout: 15000 });
      const exitOk = result?.exitCode === 0;
      const outputOk = String(result?.stdout || '').includes('cli_test_ok');
      return res.json({
        passed: exitOk && outputOk,
        backendUsed: result?.backend || 'unknown',
        detail: exitOk && outputOk
          ? 'Command executed successfully'
          : `Exit ${result?.exitCode ?? '?'}: ${String(result?.stderr || result?.stdout || '').slice(0, 120)}`,
      });
    } catch (err) {
      return res.json({ passed: false, backendUsed: 'unknown', detail: String(err?.message || err).slice(0, 120) });
    }
  });

  app.get('/api/system/test/computer', requireAuth, (req, res) => {
    const userId = req.session?.userId;
    const runtimeManager = req.app?.locals?.runtimeManager;
    if (!runtimeManager) {
      return res.json({ passed: false, detail: 'Cloud computer runtime is unavailable.' });
    }
    try {
      const status = runtimeManager.getComputerStatus(userId);
      const passed = status.state === 'ready' || status.state === 'stopped';
      return res.json({
        passed,
        state: status.state,
        detail: passed ? `Cloud computer is ${status.state}.` : String(status.lastError || status.state),
      });
    } catch (err) {
      return res.json({ passed: false, detail: String(err?.message || err).slice(0, 120) });
    }
  });

  app.get('/api/version', requireAuth, (req, res) => {
    res.json(getVersionInfo());
  });
  console.log(`[HTTP] Registered ${routeRegistry.length + 3} routes`);
}

module.exports = {
  registerApiRoutes,
  routeRegistry
};
