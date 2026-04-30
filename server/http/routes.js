'use strict';

const { requireAuth } = require('../middleware/auth');
const { setupTelnyxWebhook } = require('../routes/telnyx');
const { getVersionInfo } = require('../utils/version');
const { getRuntimeValidation } = require('../services/runtime/validation');

const routeRegistry = [
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
  { basePath: '/api/recordings', modulePath: '../routes/recordings' },
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

  app.get('/api/version', requireAuth, (req, res) => {
    res.json(getVersionInfo());
  });
  console.log(`[HTTP] Registered ${routeRegistry.length + 3} routes`);
}

module.exports = {
  registerApiRoutes,
  routeRegistry
};
