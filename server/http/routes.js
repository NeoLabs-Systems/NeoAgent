'use strict';

const { requireAuth } = require('../middleware/auth');
const { setupTelnyxWebhook } = require('../routes/telnyx');
const { getVersionInfo } = require('../utils/version');
const { getRuntimeValidation } = require('../services/runtime/validation');

const routeRegistry = [
  { basePath: '/api/runtime', modulePath: '../routes/runtime' },
  { basePath: null, modulePath: '../routes/auth' },
  { basePath: '/api/account', modulePath: '../routes/account' },
  { basePath: '/api/settings', modulePath: '../routes/settings' },
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
  { basePath: '/api/widgets', modulePath: '../routes/widgets' },
  { basePath: '/api/browser', modulePath: '../routes/browser' },
  { basePath: '/api/browser-extension', modulePath: '../routes/browser_extension' },
  { basePath: '/api/android', modulePath: '../routes/android' },
  { basePath: '/api/desktop', modulePath: '../routes/desktop' },
  { basePath: '/api/stream', modulePath: '../routes/stream' },
  { basePath: '/api/recordings', modulePath: '../routes/recordings' },
  { basePath: '/api/social-video', modulePath: '../routes/social_video' },
  { basePath: '/api/voice-assistant', modulePath: '../routes/voice_assistant' },
  { basePath: '/api/wearable', modulePath: '../routes/wearable' },
  { basePath: '/api/mobile/health', modulePath: '../routes/mobile-health' },
  { basePath: '/api/screen-history', modulePath: '../routes/screenHistory' },
  { basePath: '/api/triggers', modulePath: '../routes/triggers' }
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

  setupTelnyxWebhook(app);

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
    const desktopRegistry = req.app?.locals?.desktopCompanionRegistry;
    const extensionRegistry = req.app?.locals?.browserExtensionRegistry;
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

    // 4. Desktop companion (macOS app / remote device) connectivity + permissions.
    if (desktopRegistry) {
      try {
        const desktopStatus = desktopRegistry.getStatus(userId);
        const connected = Boolean(desktopStatus?.connected);
        results.push({
          id: 'desktop_connected',
          label: 'Desktop companion',
          passed: connected,
          detail: connected
            ? `${desktopStatus.onlineCount} device${desktopStatus.onlineCount !== 1 ? 's' : ''} connected`
            : 'No device connected — open the desktop app',
        });

        if (connected && Array.isArray(desktopStatus?.devices)) {
          const onlineDevice = desktopStatus.devices.find((d) => d.online && !d.revokedAt);
          const perms = onlineDevice?.permissions || {};
          const screenOk = Boolean(perms.screenCapture || perms.screen_capture);
          const inputOk = Boolean(perms.accessibility || perms.inputControl || perms.input_control);
          results.push({
            id: 'desktop_screen',
            label: 'Desktop — screen capture',
            passed: screenOk,
            detail: screenOk ? 'Granted' : 'Not granted — open System Settings › Privacy › Screen Recording',
          });
          results.push({
            id: 'desktop_input',
            label: 'Desktop — input control',
            passed: inputOk,
            detail: inputOk ? 'Granted' : 'Not granted — open System Settings › Privacy › Accessibility',
          });
        }
      } catch (err) {
        results.push({ id: 'desktop_connected', label: 'Desktop companion', passed: false, detail: String(err?.message || err).slice(0, 120) });
      }
    }

    // 5. Chrome extension connectivity.
    if (extensionRegistry) {
      try {
        const extStatus = extensionRegistry.getStatus(userId);
        const extConnected = Boolean(extStatus?.connected);
        results.push({
          id: 'chrome_extension',
          label: 'Chrome extension',
          passed: extConnected,
          detail: extConnected ? 'Connected' : 'Not connected — install the NeoAgent extension in Chrome',
        });
      } catch (err) {
        results.push({ id: 'chrome_extension', label: 'Chrome extension', passed: false, detail: String(err?.message || err).slice(0, 120) });
      }
    }

    const allPassed = results.every((r) => r.passed);
    res.json({ passed: allPassed, results });
  });

  // Targeted runtime self-tests — one check per endpoint so the UI can embed
  // results inline next to the relevant settings control.

  app.get('/api/system/test/cli', requireAuth, async (req, res) => {
    const userId = req.session?.userId;
    const runtimeManager = req.app?.locals?.runtimeManager;
    if (!runtimeManager || typeof runtimeManager.executeCommand !== 'function') {
      return res.json({ passed: false, backendUsed: 'vm', detail: 'Runtime not configured on this server.' });
    }
    // Note: executeCommand always routes through the VM backend regardless of
    // the cli_backend setting — desktop CLI routing is not yet implemented.
    try {
      const result = await runtimeManager.executeCommand(userId, 'echo "cli_test_ok"', { timeout: 15000 });
      const exitOk = result?.exitCode === 0;
      const outputOk = String(result?.stdout || '').includes('cli_test_ok');
      return res.json({
        passed: exitOk && outputOk,
        backendUsed: 'vm',
        detail: exitOk && outputOk
          ? 'Command executed successfully'
          : `Exit ${result?.exitCode ?? '?'}: ${String(result?.stderr || result?.stdout || '').slice(0, 120)}`,
      });
    } catch (err) {
      return res.json({ passed: false, backendUsed: 'vm', detail: String(err?.message || err).slice(0, 120) });
    }
  });

  app.get('/api/system/test/extension', requireAuth, (req, res) => {
    const userId = req.session?.userId;
    const extensionRegistry = req.app?.locals?.browserExtensionRegistry;
    if (!extensionRegistry) {
      return res.json({ passed: false, detail: 'Extension registry not available on this server.' });
    }
    try {
      const status = extensionRegistry.getStatus(userId);
      const connected = Boolean(status?.connected);
      return res.json({
        passed: connected,
        detail: connected ? 'Extension is connected and live' : 'Extension is not connected',
        tokenId: status?.activeTokenId || null,
        meta: status?.connectedMeta || null,
      });
    } catch (err) {
      return res.json({ passed: false, detail: String(err?.message || err).slice(0, 120) });
    }
  });

  app.get('/api/system/test/desktop', requireAuth, (req, res) => {
    const userId = req.session?.userId;
    const desktopRegistry = req.app?.locals?.desktopCompanionRegistry;
    if (!desktopRegistry) {
      return res.json({ passed: false, detail: 'Desktop registry not available on this server.' });
    }
    try {
      const status = desktopRegistry.getStatus(userId);
      const connected = Boolean(status?.connected);
      const devices = Array.isArray(status?.devices)
        ? status.devices.filter((d) => d.online && !d.revokedAt)
        : [];
      const selected = status?.selectedDeviceId || null;
      const activeDevice = selected
        ? devices.find((d) => d.deviceId === selected)
        : devices.length === 1 ? devices[0] : null;
      const perms = activeDevice?.permissions || {};
      const screenOk = Boolean(perms.screenCapture || perms.screen_capture);
      const inputOk = Boolean(perms.accessibility || perms.inputControl || perms.input_control);
      return res.json({
        passed: connected,
        connected,
        onlineCount: devices.length,
        selectedDeviceId: selected,
        activeDevice: activeDevice ? {
          deviceId: activeDevice.deviceId,
          label: activeDevice.label || activeDevice.hostname || activeDevice.deviceId,
          platform: activeDevice.platform || null,
          paused: activeDevice.paused || false,
          permissions: { screenCapture: screenOk, inputControl: inputOk },
        } : null,
        multipleOnline: devices.length > 1 && !activeDevice,
        detail: !connected
          ? 'No device connected'
          : devices.length > 1 && !activeDevice
            ? `${devices.length} devices online — select one in Desktop settings`
            : activeDevice?.paused
              ? `${activeDevice.label || 'Device'} is paused`
              : `${activeDevice?.label || 'Device'} connected`,
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
