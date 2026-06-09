'use strict';

const fs = require('node:fs');
const path = require('node:path');

const REPO_ROOT = path.resolve(__dirname, '../..');

const ROUTE_BASES = {
  account: '/api/account',
  agent_profiles: '/api/agent-profiles',
  agents: '/api/agents',
  android: '/api/android',
  artifacts: '/api/artifacts',
  auth: '',
  browser: '/api/browser',
  browser_extension: '/api/browser-extension',
  desktop: '/api/desktop',
  integrations: '/api/integrations',
  mcp: '/api/mcp',
  memory: '/api/memory',
  messaging: '/api/messaging',
  'mobile-health': '/api/mobile/health',
  recordings: '/api/recordings',
  runtime: '/api/runtime',
  screenHistory: '/api/screen-history',
  settings: '/api/settings',
  skills: '/api/skills',
  social_video: '/api/social-video',
  store: '/api/store',
  stream: '/api/stream',
  tasks: '/api/tasks',
  triggers: '/api/triggers',
  voice_assistant: '/api/voice-assistant',
  wearable: '/api/wearable',
  widgets: '/api/widgets',
};

const EXTRA_ROUTES = [
  'GET /api/health',
  'GET /api/system/health-check',
  'GET /api/system/test/cli',
  'GET /api/system/test/extension',
  'GET /api/system/test/desktop',
  'GET /api/version',
  'POST /api/telnyx/webhook',
];

function toExpressPath(base, routePath) {
  if (routePath === '/') return base || '/';
  return `${base}${routePath}`.replace(/\/+/g, '/');
}

function discoverApiRoutes() {
  const routes = new Set(EXTRA_ROUTES);
  for (const [moduleName, base] of Object.entries(ROUTE_BASES)) {
    const file = path.join(REPO_ROOT, 'server/routes', `${moduleName}.js`);
    if (!fs.existsSync(file)) continue;
    const source = fs.readFileSync(file, 'utf8');
    const regex = /router\.(get|post|put|patch|delete)\(\s*['"`]([^'"`]+)['"`]/g;
    let match;
    while ((match = regex.exec(source))) {
      const method = match[1].toUpperCase();
      const routePath = toExpressPath(base, match[2]);
      if (routePath.startsWith('/api/')) {
        routes.add(`${method} ${routePath}`);
      }
    }
  }
  return Array.from(routes).sort();
}

module.exports = {
  discoverApiRoutes,
};
