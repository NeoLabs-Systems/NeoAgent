'use strict';

const session = require('express-session');
const Sqlite = require('better-sqlite3');
const SQLiteStore = require('better-sqlite3-session-store')(session);
const helmet = require('helmet');
const cors = require('cors');
const { DATA_DIR } = require('../../runtime/paths');
const { logRequestSummary } = require('../utils/logger');
const { getSessionSecret } = require('../services/account/session_secret');

const sessionsDb = new Sqlite(`${DATA_DIR}/sessions.db`);
const LEGACY_SESSION_EXPIRE_FALLBACK = 0;

function boolEnv(name, fallback = false) {
  const raw = String(process.env[name] || '').trim().toLowerCase();
  if (!raw) return fallback;
  return ['1', 'true', 'yes', 'on'].includes(raw);
}

function ensureSessionStoreSchema(db) {
  const table = db.prepare("SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'sessions'").get();
  if (!table) {
    db.exec('CREATE TABLE sessions (sid PRIMARY KEY, sess, expire)');
    return;
  }

  const columns = db.prepare('PRAGMA table_info(sessions)').all().map((row) => row.name);
  const expected = ['sid', 'sess', 'expire'];
  if (columns.length === expected.length && columns.every((name, index) => name === expected[index])) {
    return;
  }

  const hasSid = columns.includes('sid');
  const hasSess = columns.includes('sess');
  const expireColumn = columns.includes('expire') ? 'expire' : (columns.includes('expired') ? 'expired' : null);

  const legacyTableName = `sessions_legacy_${Date.now()}`;
  db.exec('BEGIN');
  try {
    db.exec(`ALTER TABLE sessions RENAME TO ${legacyTableName}`);
    db.exec('CREATE TABLE sessions (sid PRIMARY KEY, sess, expire)');

    if (hasSid && hasSess) {
      const expireExpr = expireColumn ? expireColumn : 'NULL';
      db.exec(`
        INSERT OR REPLACE INTO sessions (sid, sess, expire)
        SELECT sid, sess, COALESCE(${expireExpr}, ${LEGACY_SESSION_EXPIRE_FALLBACK}) AS expire
        FROM ${legacyTableName}
        WHERE sid IS NOT NULL
      `);
    }

    db.exec(`DROP TABLE ${legacyTableName}`);
    db.exec('COMMIT');
    console.warn('[Session] Normalized sessions table schema to (sid, sess, expire).');
  } catch (error) {
    try {
      db.exec('ROLLBACK');
    } catch (rollbackErr) {
      console.warn('[Session] Failed to rollback transaction:', rollbackErr?.message);
    }
    throw error;
  }
}

ensureSessionStoreSchema(sessionsDb);

function buildHelmetOptions({ secureCookies }) {
  const wsConnectSrc = secureCookies ? ['wss:'] : ['ws:', 'wss:'];
  const allowUnsafeEval = boolEnv('NEOAGENT_CSP_ALLOW_UNSAFE_EVAL', false);
  const allowExternalScriptCdn = boolEnv('NEOAGENT_CSP_ALLOW_EXTERNAL_SCRIPT_CDN', false);
  const allowExternalConnect = boolEnv('NEOAGENT_CSP_ALLOW_EXTERNAL_CONNECT', false);

  const scriptSrc = ["'self'", "'unsafe-inline'", 'blob:'];
  if (allowUnsafeEval) scriptSrc.push("'unsafe-eval'");
  if (allowExternalScriptCdn) {
    scriptSrc.push('https://cdn.jsdelivr.net', 'https://www.gstatic.com');
  }

  const connectSrc = ["'self'", ...wsConnectSrc];
  if (allowExternalConnect) {
    connectSrc.push('https://fonts.googleapis.com', 'https://fonts.gstatic.com', 'https://www.gstatic.com', 'https://api.qrserver.com');
  }

  return {
    strictTransportSecurity: false,
    crossOriginOpenerPolicy: false,
    originAgentCluster: false,
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        scriptSrc,
        scriptSrcAttr: ["'unsafe-inline'"],
        styleSrc: ["'self'", "'unsafe-inline'", 'https://fonts.googleapis.com'],
        imgSrc: ["'self'", 'data:', 'blob:', 'https://api.qrserver.com'],
        mediaSrc: ["'self'", 'data:', 'blob:'],
        connectSrc,
        fontSrc: ["'self'", 'data:', 'https://fonts.gstatic.com'],
        workerSrc: ["'self'", 'blob:'],
        formAction: ["'self'"],
        frameAncestors: ["'self'"],
        upgradeInsecureRequests: null
      }
    }
  };
}

function createSessionMiddleware({ secureCookies, trustProxy }) {
  return session({
    store: new SQLiteStore({
      client: sessionsDb,
      expired: {
        clear: true,
        intervalMs: 15 * 60 * 1000,
      },
    }),
    secret: getSessionSecret(),
    name: 'neoagent.sid',
    proxy: trustProxy,
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

function applyHttpMiddleware(app, { secureCookies, trustProxy, sessionMiddleware, validateOrigin }) {
  const rawRecordingChunkBody = require('express').raw({ limit: '50mb', type: '*/*' });
  const jsonBody = require('express').json({
    limit: '10mb',
    verify: (req, _res, buf) => {
      if (buf && buf.length) req.rawBody = buf.toString('utf8');
    },
  });
  const urlencodedBody = require('express').urlencoded({ extended: true });
  const isRecordingChunkPath = (value = '') => {
    const path = `${value}`.split('?')[0];
    return /^\/api\/recordings\/[^/]+\/chunks$/i.test(path);
  };
  const isBrowserExtensionCorsPath = (value = '') => {
    const path = `${value}`.split('?')[0];
    return path === '/api/browser-extension/latest'
      || path === '/api/browser-extension/pairing/request'
      || /^\/api\/browser-extension\/pairing\/[^/]+\/claim$/i.test(path);
  };
  const requestPath = (req) => req.originalUrl || req.url || req.path || '';
  const applyOnlyToRecordingChunk = (handler) => (req, res, next) => (
    isRecordingChunkPath(requestPath(req)) ? handler(req, res, next) : next()
  );
  const skipRecordingChunk = (handler) => (req, res, next) => (
    isRecordingChunkPath(requestPath(req)) ? next() : handler(req, res, next)
  );

  if (trustProxy) {
    app.set('trust proxy', 1);
    console.log('[HTTP] trust proxy enabled for proxied deployment handling');
  }

  app.use(helmet(buildHelmetOptions({ secureCookies })));
  app.use(
    cors((req, callback) => {
      const requestPath = `${req.originalUrl || req.url || req.path || ''}`.split('?')[0];
      callback(null, {
        origin(origin, originCallback) {
          const allowBrowserExtensionOrigin = isBrowserExtensionCorsPath(requestPath);
          return validateOrigin(origin, originCallback, {
            allowChromeExtension: allowBrowserExtensionOrigin,
            allowMissingOrigin: allowBrowserExtensionOrigin,
          });
        },
        credentials: true,
      });
    })
  );
  app.use((req, res, next) => {
    const startedAt = Date.now();

    res.on('finish', () => {
      const durationMs = Date.now() - startedAt;
      if (res.statusCode >= 400) {
        const level = res.statusCode >= 500 ? 'error' : 'warn';
        logRequestSummary(level, req, `completed ${res.statusCode} in ${durationMs}ms`, {
          contentLength: res.getHeader('content-length') || null
        });
      }
    });

    res.on('close', () => {
      if (res.writableEnded) return;
      logRequestSummary('warn', req, 'connection closed before response finished', {
        durationMs: Date.now() - startedAt
      });
    });

    next();
  });
  app.use(applyOnlyToRecordingChunk(rawRecordingChunkBody));
  app.use(skipRecordingChunk(jsonBody));
  app.use(skipRecordingChunk(urlencodedBody));
  app.use(sessionMiddleware);
}

module.exports = {
  applyHttpMiddleware,
  createSessionMiddleware
};
