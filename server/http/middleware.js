'use strict';

const session = require('express-session');
const SQLiteStore = require('better-sqlite3-session-store')(session);
const helmet = require('helmet');
const cors = require('cors');
const { logRequestSummary } = require('../utils/logger');
const { getSessionSecret } = require('../services/account/session_secret');

const sessionsDb = require('../db/sessions_db');
const LEGACY_SESSION_EXPIRE_FALLBACK = 0;
const SESSION_MAX_AGE_MS = 30 * 24 * 60 * 60 * 1000;

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
  const isDevelopment = String(process.env.NODE_ENV || '').trim() === 'development';
  // Flutter web (CanvasKit) requires external script/connect sources and wasm eval.
  // Keep strict overrides available via env for hardened deployments.
  const allowUnsafeEval = boolEnv('NEOAGENT_CSP_ALLOW_UNSAFE_EVAL', true);
  const allowExternalScriptCdn = boolEnv('NEOAGENT_CSP_ALLOW_EXTERNAL_SCRIPT_CDN', true);
  const allowExternalConnect = boolEnv('NEOAGENT_CSP_ALLOW_EXTERNAL_CONNECT', true);

  const scriptSrc = ["'self'", "'unsafe-inline'", 'blob:'];
  if (allowUnsafeEval) {
    scriptSrc.push("'unsafe-eval'", "'wasm-unsafe-eval'");
  }
  if (allowExternalScriptCdn) {
    scriptSrc.push('https://cdn.jsdelivr.net', 'https://www.gstatic.com');
  }

  const connectSrc = ["'self'", ...wsConnectSrc];
  if (allowExternalConnect) {
    connectSrc.push('https://fonts.googleapis.com', 'https://fonts.gstatic.com', 'https://www.gstatic.com', 'https://cdn.jsdelivr.net');
  }

  return {
    strictTransportSecurity: secureCookies
      ? { maxAge: Number(process.env.NEOAGENT_HSTS_MAX_AGE ?? 86400), includeSubDomains: false }
      : false,
    crossOriginOpenerPolicy: false,
    crossOriginResourcePolicy: { policy: 'same-site' },
    originAgentCluster: false,
    referrerPolicy: { policy: 'strict-origin-when-cross-origin' },
    permissionsPolicy: {
      features: {
        camera: ['self'],
        geolocation: ['self'],
        microphone: ['self'],
        payment: [],
        usb: [],
      },
    },
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        scriptSrc,
        scriptSrcAttr: ["'unsafe-inline'"],
        styleSrc: ["'self'", "'unsafe-inline'", 'https://fonts.googleapis.com'],
        imgSrc: ["'self'", 'data:', 'blob:'],
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
    rolling: true,
    saveUninitialized: false,
    cookie: {
      maxAge: SESSION_MAX_AGE_MS,
      httpOnly: true,
      sameSite: 'lax',
      secure: secureCookies
    }
  });
}

function attachRequestSignal(req, res, next) {
  const controller = new AbortController();
  const abort = () => {
    if (!res.writableEnded && !controller.signal.aborted) {
      const error = new Error('HTTP client disconnected.');
      error.name = 'AbortError';
      error.code = 'ABORT_ERR';
      controller.abort(error);
    }
  };
  const cleanup = () => {
    req.removeListener('aborted', abort);
    res.removeListener('close', abort);
    res.removeListener('finish', cleanup);
  };
  req.signal = controller.signal;
  req.once('aborted', abort);
  res.once('close', abort);
  res.once('finish', cleanup);
  next();
}

function applyHttpMiddleware(app, { secureCookies, trustProxy, sessionMiddleware, validateOrigin }) {
  const jsonBody = require('express').json({
    limit: '10mb',
    verify: (req, _res, buf) => {
      if (buf && buf.length) req.rawBody = buf.toString('utf8');
    },
  });
  const urlencodedBody = require('express').urlencoded({ extended: true });
  const isSocketIoCorsPath = (value = '') => {
    const path = `${value}`.split('?')[0];
    return path === '/socket.io/' || path === '/socket.io' || path.startsWith('/socket.io/');
  };
  const isStateChangingMethod = (method = '') => ['POST', 'PUT', 'PATCH', 'DELETE'].includes(String(method).toUpperCase());
  const extractOriginFromReferer = (referer = '') => {
    const value = String(referer || '').trim();
    if (!value) return '';
    try {
      return new URL(value).origin;
    } catch {
      return '';
    }
  };
  if (trustProxy) {
    app.set('trust proxy', 1);
    console.log('[HTTP] trust proxy enabled for proxied deployment handling');
  }

  app.use(helmet(buildHelmetOptions({ secureCookies })));
  app.use(attachRequestSignal);
  app.use(
    cors((req, callback) => {
      const requestPath = `${req.originalUrl || req.url || req.path || ''}`.split('?')[0];
      callback(null, {
        origin(origin, originCallback) {
          const allowSocketIoMissingOrigin = isSocketIoCorsPath(requestPath);
          const originOptions = {};
          if (allowSocketIoMissingOrigin) {
            originOptions.allowMissingOrigin = true;
          }
          return validateOrigin(origin, originCallback, originOptions);
        },
        credentials: true,
      });
    })
  );
  app.use((req, res, next) => {
    const path = `${req.originalUrl || req.url || req.path || ''}`.split('?')[0];
    if (path.startsWith('/api/')) {
      res.setHeader('Cache-Control', 'no-store, max-age=0');
      res.setHeader('Pragma', 'no-cache');
      res.setHeader('Expires', '0');
    }
    next();
  });
  app.use((req, res, next) => {
    const path = `${req.originalUrl || req.url || req.path || ''}`.split('?')[0];
    if (!path.startsWith('/api/')) return next();
    if (!isStateChangingMethod(req.method)) return next();

    const origin = String(req.get('origin') || '').trim() || extractOriginFromReferer(req.get('referer'));
    if (!origin) return next();

    return validateOrigin(origin, (error) => {
      if (error) {
        logRequestSummary('warn', req, 'blocked state-changing request due to invalid origin', { origin });
        return res.status(403).json({ error: 'Origin not allowed' });
      }
      return next();
    }, { allowMissingOrigin: false });
  });
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
  app.use(jsonBody);
  app.use(urlencodedBody);
  app.use(sessionMiddleware);
}

module.exports = {
  attachRequestSignal,
  applyHttpMiddleware,
  createSessionMiddleware
};
