'use strict';

const session = require('express-session');
const SQLiteStore = require('connect-sqlite3')(session);
const helmet = require('helmet');
const cors = require('cors');
const { DATA_DIR } = require('../../runtime/paths');
const { logRequestSummary } = require('../utils/logger');

function buildHelmetOptions({ secureCookies }) {
  const wsConnectSrc = secureCookies ? ['wss:'] : ['ws:', 'wss:'];

  return {
    strictTransportSecurity: false,
    crossOriginOpenerPolicy: false,
    originAgentCluster: false,
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        scriptSrc: [
          "'self'",
          "'unsafe-inline'",
          "'unsafe-eval'",
          'blob:',
          'https://cdn.jsdelivr.net',
          'https://www.gstatic.com'
        ],
        scriptSrcAttr: ["'unsafe-inline'"],
        styleSrc: ["'self'", "'unsafe-inline'", 'https://fonts.googleapis.com'],
        imgSrc: ["'self'", 'data:', 'blob:', 'https://api.qrserver.com'],
        connectSrc: [
          "'self'",
          'https://fonts.googleapis.com',
          'https://fonts.gstatic.com',
          'https://www.gstatic.com',
          'https://api.qrserver.com',
          ...wsConnectSrc
        ],
        fontSrc: ["'self'", 'data:', 'https://fonts.gstatic.com'],
        workerSrc: ["'self'", 'blob:'],
        formAction: ["'self'"],
        frameAncestors: ["'self'"],
        upgradeInsecureRequests: null
      }
    }
  };
}

function createSessionMiddleware({ secureCookies }) {
  return session({
    store: new SQLiteStore({ db: 'sessions.db', dir: DATA_DIR }),
    secret: process.env.SESSION_SECRET || 'neoagent-dev-secret-change-me',
    name: 'neoagent.sid',
    resave: false,
    saveUninitialized: false,
    cookie: {
      maxAge: 7 * 24 * 60 * 60 * 1000,
      httpOnly: true,
      sameSite: 'lax',
      secure: secureCookies
    }
  });
}

function applyHttpMiddleware(app, { secureCookies, sessionMiddleware, validateOrigin }) {
  const rawRecordingChunkBody = require('express').raw({ limit: '50mb', type: '*/*' });
  const jsonBody = require('express').json({ limit: '10mb' });
  const urlencodedBody = require('express').urlencoded({ extended: true });
  const isRecordingChunkPath = (value = '') => {
    const path = `${value}`.split('?')[0];
    return /^\/api\/recordings\/[^/]+\/chunks$/i.test(path);
  };

  if (secureCookies) {
    app.set('trust proxy', 1);
    console.log('[HTTP] trust proxy enabled because secure cookies are active');
  }

  app.use(helmet(buildHelmetOptions({ secureCookies })));
  app.use(
    cors({
      origin: validateOrigin,
      credentials: true
    })
  );
  app.use((req, res, next) => {
    const startedAt = Date.now();
    logRequestSummary('log', req, 'started');

    res.on('finish', () => {
      const durationMs = Date.now() - startedAt;
      const level = res.statusCode >= 500 ? 'error' : res.statusCode >= 400 ? 'warn' : 'log';
      logRequestSummary(level, req, `completed ${res.statusCode} in ${durationMs}ms`, {
        contentLength: res.getHeader('content-length') || null
      });
    });

    res.on('close', () => {
      if (res.writableEnded) return;
      logRequestSummary('warn', req, 'connection closed before response finished', {
        durationMs: Date.now() - startedAt
      });
    });

    next();
  });
  app.use((req, res, next) => {
    if (isRecordingChunkPath(req.originalUrl || req.url || req.path)) {
      return rawRecordingChunkBody(req, res, next);
    }
    return next();
  });
  app.use((req, res, next) => {
    if (isRecordingChunkPath(req.originalUrl || req.url || req.path)) {
      return next();
    }
    return jsonBody(req, res, next);
  });
  app.use((req, res, next) => {
    if (isRecordingChunkPath(req.originalUrl || req.url || req.path)) {
      return next();
    }
    return urlencodedBody(req, res, next);
  });
  app.use(sessionMiddleware);
}

module.exports = {
  applyHttpMiddleware,
  createSessionMiddleware
};
