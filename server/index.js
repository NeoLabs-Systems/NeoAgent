'use strict';

const {
  ENV_FILE,
  LEGACY_ENV_FILE,
  migrateLegacyRuntime,
  ensureRuntimeDirs
} = require('../runtime/paths');

const dotenv = require('dotenv');

migrateLegacyRuntime();
ensureRuntimeDirs();
dotenv.config({ path: LEGACY_ENV_FILE });
dotenv.config({ path: ENV_FILE, override: true });

const express = require('express');
const { createServer } = require('http');

const db = require('./db/database');
const { setupConsoleInterceptor } = require('./utils/logger');
const {
  configuredSessionSecret,
  isInsecureSessionSecret,
} = require('./services/account/session_secret');
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
const { bindBrowserExtensionGateway } = require('./services/browser/extension/gateway');
const { bindDesktopCompanionGateway } = require('./services/desktop/gateway');

function parseBooleanFlag(value, fallback = false) {
  const normalized = String(value || '').trim().toLowerCase();
  if (['1', 'true', 'yes', 'on'].includes(normalized)) return true;
  if (['0', 'false', 'no', 'off'].includes(normalized)) return false;
  return fallback;
}

const PORT = Number(process.env.PORT) || 3333;
const PUBLIC_URL = String(process.env.PUBLIC_URL || '').trim();
const PUBLIC_URL_IS_HTTPS = PUBLIC_URL.startsWith('https://');
const SECURE_COOKIES = parseBooleanFlag(
  process.env.SECURE_COOKIES,
  PUBLIC_URL_IS_HTTPS,
);
const TRUST_PROXY = parseBooleanFlag(
  process.env.TRUST_PROXY,
  SECURE_COOKIES || PUBLIC_URL_IS_HTTPS,
);

function logStartupConfig() {
  const flags = {
    SESSION_SECRET: Boolean(process.env.SESSION_SECRET),
    OPENAI_API_KEY: Boolean(process.env.OPENAI_API_KEY),
    DEEPGRAM_API_KEY: Boolean(process.env.DEEPGRAM_API_KEY),
    GOOGLE_OAUTH_CLIENT_ID: Boolean(process.env.GOOGLE_OAUTH_CLIENT_ID),
    GOOGLE_OAUTH_CLIENT_SECRET: Boolean(process.env.GOOGLE_OAUTH_CLIENT_SECRET),
    NOTION_OAUTH_CLIENT_ID: Boolean(process.env.NOTION_OAUTH_CLIENT_ID),
    NOTION_OAUTH_CLIENT_SECRET: Boolean(process.env.NOTION_OAUTH_CLIENT_SECRET),
    MICROSOFT_OAUTH_CLIENT_ID: Boolean(process.env.MICROSOFT_OAUTH_CLIENT_ID),
    MICROSOFT_OAUTH_CLIENT_SECRET: Boolean(process.env.MICROSOFT_OAUTH_CLIENT_SECRET),
    SLACK_OAUTH_CLIENT_ID: Boolean(process.env.SLACK_OAUTH_CLIENT_ID),
    SLACK_OAUTH_CLIENT_SECRET: Boolean(process.env.SLACK_OAUTH_CLIENT_SECRET),
    FIGMA_OAUTH_CLIENT_ID: Boolean(process.env.FIGMA_OAUTH_CLIENT_ID),
    FIGMA_OAUTH_CLIENT_SECRET: Boolean(process.env.FIGMA_OAUTH_CLIENT_SECRET),
  };

  console.log(`[Startup] Using env file: ${ENV_FILE}`);
  if (LEGACY_ENV_FILE !== ENV_FILE) {
    console.log(`[Startup] Legacy env fallback: ${LEGACY_ENV_FILE}`);
  }
  console.log('[Startup] Key availability:', flags);
  console.log('[Startup] HTTP runtime:', {
    publicUrl: PUBLIC_URL || null,
    secureCookies: SECURE_COOKIES,
    trustProxy: TRUST_PROXY,
  });
}

logStartupConfig();

if (!configuredSessionSecret()) {
  console.warn(
    'WARNING: SESSION_SECRET not set — using a process-local random fallback. Set it in .env before exposing this server.'
  );
} else if (isInsecureSessionSecret()) {
  console.warn(
    'WARNING: SESSION_SECRET uses a known placeholder value. Replace it with a random secret before exposing this server.'
  );
}

const app = express();
const httpServer = createServer(app);
const io = createSocketServer(httpServer, { validateOrigin });
app.locals.httpRuntimeConfig = {
  secureCookies: SECURE_COOKIES,
  trustProxy: TRUST_PROXY,
  publicUrl: PUBLIC_URL || null,
};
const sessionMiddleware = createSessionMiddleware({
  secureCookies: SECURE_COOKIES,
  trustProxy: TRUST_PROXY,
});
const activeSockets = new Set();

setupConsoleInterceptor(io);
applyHttpMiddleware(app, {
  secureCookies: SECURE_COOKIES,
  trustProxy: TRUST_PROXY,
  sessionMiddleware,
  validateOrigin
});
bindSocketSessions(io, sessionMiddleware);
registerApiRoutes(app);
registerStaticRoutes(app);
registerErrorHandler(app);
bindBrowserExtensionGateway(httpServer, app);
bindDesktopCompanionGateway(httpServer, app, sessionMiddleware);

let shuttingDown = false;
let shutdownExitCode = 0;

httpServer.on('connection', (socket) => {
  activeSockets.add(socket);
  socket.on('close', () => activeSockets.delete(socket));
});

function closeSocketServer(ioServer, timeoutMs = 5000) {
  return new Promise((resolve) => {
    if (!ioServer) {
      resolve();
      return;
    }

    let finished = false;

    const finish = () => {
      if (finished) return;
      finished = true;
      clearTimeout(forceTimer);
      resolve();
    };

    const forceTimer = setTimeout(() => {
      try {
        ioServer.disconnectSockets(true);
      } catch (err) {
        console.error('[Shutdown] Socket.IO force disconnect error:', err.message);
      }
      console.warn('[Shutdown] Socket.IO close timed out; forcing client disconnects.');
      finish();
    }, timeoutMs);

    forceTimer.unref?.();

    try {
      ioServer.disconnectSockets(true);
      ioServer.close(() => finish());
    } catch (err) {
      console.error('[Shutdown] Socket.IO close error:', err.message);
      finish();
    }
  });
}

function closeHttpServer(server, sockets, timeoutMs = 5000) {
  return new Promise((resolve) => {
    let finished = false;

    const finish = () => {
      if (finished) return;
      finished = true;
      clearTimeout(forceTimer);
      resolve();
    };

    const forceTimer = setTimeout(() => {
      if (typeof server.closeAllConnections === 'function') {
        server.closeAllConnections();
      }

      for (const socket of sockets) {
        socket.destroy();
      }

      if (sockets.size > 0) {
        console.warn(`[Shutdown] Forced ${sockets.size} open socket(s) closed.`);
      }

      finish();
    }, timeoutMs);

    forceTimer.unref?.();

    try {
      server.close((err) => {
        if (err && err.code !== 'ERR_SERVER_NOT_RUNNING') {
          console.error('[Shutdown] HTTP server close error:', err.message);
        }
        finish();
      });

      if (typeof server.closeIdleConnections === 'function') {
        server.closeIdleConnections();
      }
    } catch (err) {
      if (err.code !== 'ERR_SERVER_NOT_RUNNING') {
        console.error('[Shutdown] HTTP server close threw:', err.message);
      }
      finish();
    }
  });
}

async function shutdown(exitCode = 0) {
  shutdownExitCode = Math.max(shutdownExitCode, exitCode);
  if (shuttingDown) return;
  shuttingDown = true;

  console.log('Shutting down...');

  await stopServices(app);
  await Promise.allSettled([
    closeSocketServer(io),
    closeHttpServer(httpServer, activeSockets),
  ]);

  db.close();
  process.exit(shutdownExitCode);
}

httpServer.listen(PORT, () => {
  console.log(`NeoAgent running on http://localhost:${PORT}`);
  startServices(app, io).catch(async (err) => {
    console.error('[Startup] Service initialization failed:', err);
    await shutdown(1);
  });
});

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

module.exports = { app, io, httpServer };
