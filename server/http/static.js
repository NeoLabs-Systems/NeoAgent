'use strict';

const fs = require('fs');
const path = require('path');
const express = require('express');
const { DATA_DIR } = require('../../runtime/paths');
const { requireAuth } = require('../middleware/auth');

const FLUTTER_WEB_DIR = path.join(__dirname, '..', 'public');

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

  app.use(express.static(FLUTTER_WEB_DIR, { index: false }));
  app.get(/^\/(?!api|screenshots|telnyx-audio).*/, serveFlutterApp);
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
  return res.sendFile(entry);
}

module.exports = {
  FLUTTER_WEB_DIR,
  registerStaticRoutes,
  serveFlutterApp
};
