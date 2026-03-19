'use strict';

const session = require('express-session');
const SQLiteStore = require('connect-sqlite3')(session);
const helmet = require('helmet');
const cors = require('cors');
const { DATA_DIR } = require('../../runtime/paths');

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
  if (secureCookies) {
    app.set('trust proxy', 1);
  }

  app.use(helmet(buildHelmetOptions({ secureCookies })));
  app.use(
    cors({
      origin: validateOrigin,
      credentials: true
    })
  );
  app.use(require('express').json({ limit: '10mb' }));
  app.use(require('express').urlencoded({ extended: true }));
  app.use(sessionMiddleware);
}

module.exports = {
  applyHttpMiddleware,
  createSessionMiddleware
};
