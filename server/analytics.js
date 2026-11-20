'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { analyticsConfig } = require('./analytics-config');

const CLIENT_PATH = '/_neolabs/analytics.js';
const clientSource = fs.readFileSync(path.join(__dirname, 'analytics-client.js'), 'utf8');

function injectAnalytics(html) {
  return html.replace(/<\/head>/i, '<script defer src="' + CLIENT_PATH + '"></script>\n</head>');
}

function registerAnalyticsClient(app) {
  app.get(CLIENT_PATH, (_req, res, next) => {
    const config = analyticsConfig();
    if (!config) return next();
    const { endpoint, appKey } = config;
    const script = clientSource.replace('/* COUNTLY_CONFIG */ null', () => JSON.stringify({ endpoint, appKey }));
    res.set('Cache-Control', 'no-store');
    return res.type('application/javascript').send(script);
  });
}

function registerAnalytics(app, { appWebRoot, landingRoot }) {
  registerAnalyticsClient(app);

  app.use((req, res, next) => {
    if (req.method !== 'GET' && req.method !== 'HEAD') return next();
    const config = analyticsConfig();
    const appPage = /^\/app(?:\/.*)?$/.test(req.path) && !/\.[a-z0-9]+$/i.test(req.path.replace(/\/index\.html$/i, ''));
    const landingPage = req.path === '/' || req.path === '/index.html';
    if (!appPage && (!landingPage || !config)) return next();
    const entry = path.join(appPage ? appWebRoot : landingRoot, 'index.html');
    let html;
    try { html = fs.readFileSync(entry, 'utf8'); } catch (error) {
      if (error.code === 'ENOENT') return next();
      return next(error);
    }
    if (appPage) {
      html = html.replace('<base href="/">', '<base href="/app/">');
      if (!html.includes('/js/cookie-notice.js')) {
        html = html.replace(/<\/head>/i, '<script defer src="/js/cookie-notice.js"></script>\n</head>');
      }
    }
    if (config) html = injectAnalytics(html);
    res.set('Cache-Control', 'no-store');
    return res.type('html').send(html);
  });
}

module.exports = { registerAnalytics };
