'use strict';

const fs = require('fs');
const path = require('path');
const express = require('express');
const { DATA_DIR } = require('../../runtime/paths');
const { requireAuth } = require('../middleware/auth');

const FLUTTER_WEB_DIR = path.join(__dirname, '..', 'public');
const LANDING_DIR = path.join(__dirname, '..', '..', 'landing');
const BUILD_ID_PATH = path.join(FLUTTER_WEB_DIR, '.last_build_id');

function setNoStoreHeaders(res) {
  res.set('Cache-Control', 'no-store, no-cache, must-revalidate, proxy-revalidate');
  res.set('Pragma', 'no-cache');
  res.set('Expires', '0');
  res.set('Surrogate-Control', 'no-store');
  res.set('CDN-Cache-Control', 'no-store');
}

function readCurrentBuildId() {
  try {
    return fs.readFileSync(BUILD_ID_PATH, 'utf8').trim() || null;
  } catch {
    return null;
  }
}

function setFlutterStaticHeaders(res, filePath) {
  const relativePath = path.relative(FLUTTER_WEB_DIR, filePath).replaceAll('\\', '/');
  if (
    relativePath === 'index.html' ||
    relativePath === 'flutter_bootstrap.js' ||
    relativePath === 'flutter_service_worker.js' ||
    relativePath === 'version.json'
  ) {
    setNoStoreHeaders(res);
  }
}

function registerStaticRoutes(app) {
  app.use(
    '/telnyx-audio',
    express.static(path.join(DATA_DIR, 'telnyx-audio'), {
      index: false,
      setHeaders: (res, filePath) => {
        if (!filePath.match(/\.(mp3|wav|ogg|aac|m4a)$/i)) {
          res.status(403).end();
        }
      }
    })
  );

  app.use(
    '/screenshots',
    requireAuth,
    express.static(path.join(DATA_DIR, 'screenshots'))
  );

  app.get('/app-build.json', (req, res) => {
    setNoStoreHeaders(res);
    res.json({
      buildId: readCurrentBuildId(),
    });
  });

  const adminRouter = require('../routes/admin');
  app.use('/admin', adminRouter);

  // Flutter app at /app
  app.use(
    '/app',
    express.static(FLUTTER_WEB_DIR, {
      index: false,
      setHeaders: setFlutterStaticHeaders,
    })
  );
  app.get(/^\/app(\/.*)?$/, serveFlutterApp);

  // Landing page at /
  app.use(express.static(LANDING_DIR));
  app.get('/', (req, res) => res.sendFile(path.join(LANDING_DIR, 'index.html')));
}

function serveFlutterApp(req, res) {
  const entry = path.join(FLUTTER_WEB_DIR, 'index.html');
  if (!fs.existsSync(entry)) {
    return res
      .status(503)
      .send(
        'Flutter web build not found. Run "npm run flutter:build:web" to generate the bundled client.'
      );
  }
  setNoStoreHeaders(res);
  // Rewrite <base href="/"> to <base href="/app/"> so Flutter asset paths resolve correctly
  const html = fs.readFileSync(entry, 'utf8').replace('<base href="/">', '<base href="/app/">');
  res.set('Content-Type', 'text/html');
  return res.send(html);
}

module.exports = {
  FLUTTER_WEB_DIR,
  LANDING_DIR,
  registerStaticRoutes,
  serveFlutterApp
};
