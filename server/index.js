'use strict';

const {
  ENV_FILE,
  migrateLegacyRuntime,
  ensureRuntimeDirs
} = require('../runtime/paths');

require('dotenv').config({ path: ENV_FILE });
migrateLegacyRuntime();
ensureRuntimeDirs();

const express = require('express');
const { createServer } = require('http');

const db = require('./db/database');
const { setupConsoleInterceptor } = require('./utils/logger');
const { validateOrigin } = require('./config/origins');
const {
  applyHttpMiddleware,
  createSessionMiddleware
} = require('./http/middleware');
const { createSocketServer, bindSocketSessions } = require('./http/socket');
const { registerApiRoutes } = require('./http/routes');
const { registerStaticRoutes } = require('./http/static');
const { registerErrorHandler } = require('./http/errors');
const { startServices, stopServices } = require('./services/manager');

const PORT = Number(process.env.PORT) || 3333;
const SECURE_COOKIES = process.env.SECURE_COOKIES === 'true';

if (!process.env.SESSION_SECRET) {
  console.warn(
    'WARNING: SESSION_SECRET not set — using insecure default. Set it in .env before exposing this server.'
  );
}

const app = express();
const httpServer = createServer(app);
const io = createSocketServer(httpServer, { validateOrigin });
const sessionMiddleware = createSessionMiddleware({ secureCookies: SECURE_COOKIES });

setupConsoleInterceptor(io);
applyHttpMiddleware(app, {
  secureCookies: SECURE_COOKIES,
  sessionMiddleware,
  validateOrigin
});
bindSocketSessions(io, sessionMiddleware);
registerApiRoutes(app);
registerStaticRoutes(app);
registerErrorHandler(app);

let shuttingDown = false;

async function shutdown() {
  if (shuttingDown) return;
  shuttingDown = true;

  console.log('Shutting down...');

  await stopServices(app);

  try {
    await new Promise((resolve) => httpServer.close(resolve));
  } catch {
    // ignore close races during shutdown
  }

  db.close();
  process.exit(0);
}

httpServer.listen(PORT, async () => {
  console.log(`NeoAgent running on http://localhost:${PORT}`);
  await startServices(app, io);
});

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

module.exports = { app, io, httpServer };
