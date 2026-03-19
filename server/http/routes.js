'use strict';

const { requireAuth } = require('../middleware/auth');
const { setupTelnyxWebhook } = require('../routes/telnyx');
const { getVersionInfo } = require('../utils/version');

const routeRegistry = [
  { basePath: null, modulePath: '../routes/auth' },
  { basePath: '/api/settings', modulePath: '../routes/settings' },
  { basePath: '/api/agents', modulePath: '../routes/agents' },
  { basePath: '/api/messaging', modulePath: '../routes/messaging' },
  { basePath: '/api/mcp', modulePath: '../routes/mcp' },
  { basePath: '/api/skills', modulePath: '../routes/skills' },
  { basePath: '/api/store', modulePath: '../routes/store' },
  { basePath: '/api/memory', modulePath: '../routes/memory' },
  { basePath: '/api/scheduler', modulePath: '../routes/scheduler' },
  { basePath: '/api/browser', modulePath: '../routes/browser' },
  { basePath: '/api/recordings', modulePath: '../routes/recordings' },
  { basePath: '/api/mobile/health', modulePath: '../routes/mobile-health' }
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
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
  });

  app.get('/api/version', requireAuth, (req, res) => {
    res.json(getVersionInfo());
  });
}

module.exports = {
  registerApiRoutes,
  routeRegistry
};
