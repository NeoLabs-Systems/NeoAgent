const { ENV_FILE, DATA_DIR, APP_DIR, migrateLegacyRuntime, ensureRuntimeDirs } = require('../runtime/paths');
require('dotenv').config({ path: ENV_FILE });
migrateLegacyRuntime();
ensureRuntimeDirs();

const express = require('express');
const session = require('express-session');
const SQLiteStore = require('connect-sqlite3')(session);
const { createServer } = require('http');
const { Server: SocketIO } = require('socket.io');
const helmet = require('helmet');
const cors = require('cors');
const path = require('path');

const db = require('./db/database');
const { requireAuth, requireNoAuth } = require('./middleware/auth');
const { sanitizeError } = require('./utils/security');
const { setupConsoleInterceptor } = require('./utils/logger');
const { setupTelnyxWebhook } = require('./routes/telnyx');
const { startServices } = require('./services/manager');
const packageJson = require('../package.json');

const app = express();
const httpServer = createServer(app);
const io = new SocketIO(httpServer, {
  cors: {
    origin: process.env.ALLOWED_ORIGINS ? process.env.ALLOWED_ORIGINS.split(',') : false,
    credentials: true
  }
});

// ── Console Log Interceptor ──
setupConsoleInterceptor(io);

if (!process.env.SESSION_SECRET) {
  console.warn('WARNING: SESSION_SECRET not set — using insecure default. Set it in .env before exposing this server.');
}

const PORT = process.env.PORT || 3333;

// ── Middleware ──

const SECURE_COOKIES = process.env.SECURE_COOKIES === 'true';
if (SECURE_COOKIES) {
  app.set('trust proxy', 1);
}

const wsConnectSrc = SECURE_COOKIES ? ['wss:'] : ['ws:', 'wss:'];

app.use(helmet({
  strictTransportSecurity: false,
  crossOriginOpenerPolicy: false,
  originAgentCluster: false,
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "'unsafe-inline'", "https://cdn.jsdelivr.net"],
      scriptSrcAttr: ["'unsafe-inline'"],
      styleSrc: ["'self'", "'unsafe-inline'", "https://fonts.googleapis.com"],
      imgSrc: ["'self'", "data:", "blob:", "https://api.qrserver.com"],
      connectSrc: ["'self'", "https://fonts.googleapis.com", "https://fonts.gstatic.com", ...wsConnectSrc],
      fontSrc: ["'self'", "data:", "https://fonts.gstatic.com"],
      formAction: ["'self'"],
      frameAncestors: ["'self'"],
      upgradeInsecureRequests: null
    }
  }
}));

app.use(cors({
  origin: process.env.ALLOWED_ORIGINS ? process.env.ALLOWED_ORIGINS.split(',') : false,
  credentials: true
}));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

const sessionMiddleware = session({
  store: new SQLiteStore({ db: 'sessions.db', dir: DATA_DIR }),
  secret: process.env.SESSION_SECRET || 'neoagent-dev-secret-change-me',
  name: 'neoagent.sid',
  resave: false,
  saveUninitialized: false,
  cookie: {
    maxAge: 7 * 24 * 60 * 60 * 1000,
    httpOnly: true,
    sameSite: 'lax',
    secure: SECURE_COOKIES
  }
});

app.use(sessionMiddleware);

io.use((socket, next) => {
  sessionMiddleware(socket.request, {}, next);
});

// ── Routes ──

app.use(require('./routes/auth'));
app.use('/api/settings', require('./routes/settings'));
app.use('/api/agents', require('./routes/agents'));
app.use('/api/messaging', require('./routes/messaging'));
app.use('/api/mcp', require('./routes/mcp'));
app.use('/api/skills', require('./routes/skills'));
app.use('/api/protocols', require('./routes/protocols'));
app.use('/api/store', require('./routes/store'));
app.use('/api/memory', require('./routes/memory'));
app.use('/api/scheduler', require('./routes/scheduler'));
app.use('/api/browser', require('./routes/browser'));
app.use('/api/mobile/health', require('./routes/mobile-health'));

// ── Telnyx voice webhook ──
setupTelnyxWebhook(app);

app.use('/telnyx-audio', express.static(path.join(DATA_DIR, 'telnyx-audio'), {
  index: false,
  setHeaders: (res, filePath) => {
    if (!filePath.match(/\.(mp3|wav|ogg|aac|m4a)$/i)) {
      res.status(403).end();
    }
  }
}));

app.use('/screenshots', requireAuth, express.static(path.join(DATA_DIR, 'screenshots')));

// ── Pages ──

app.get('/login', requireNoAuth, (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'login.html'));
});

app.get('/app', requireAuth, (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'app.html'));
});

app.get('/app/*', requireAuth, (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'app.html'));
});

app.get('/app.html', requireAuth, (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'app.html'));
});
app.get('/js/app.js', requireAuth, (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'js', 'app.js'));
});

app.use(express.static(path.join(__dirname, 'public')));

app.get('/', (req, res) => {
  if (req.session && req.session.userId) return res.redirect('/app');
  res.redirect('/login');
});

app.get('/api/health', requireAuth, (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.get('/api/version', requireAuth, (req, res) => {
  let version = packageJson.version;
  let gitSha = null;
  try {
    const { execSync } = require('child_process');
    version = execSync('git describe --tags --always --dirty', {
      cwd: APP_DIR,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore']
    }).trim().replace(/^v/, '') || packageJson.version;
    gitSha = execSync('git rev-parse --short HEAD', {
      cwd: APP_DIR,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore']
    }).trim();
  } catch {
    gitSha = process.env.GIT_SHA || null;
  }

  res.json({
    name: packageJson.name,
    version,
    packageVersion: packageJson.version,
    gitSha
  });
});

// ── Service Initialization ──
// Handled by services/manager.js

// ── Global Error Handler ──

app.use((err, req, res, next) => {
  console.error('[Unhandled error]', err);
  const status = err.status || err.statusCode || 500;
  const message = sanitizeError(err);
  if (req.path.startsWith('/api/')) {
    return res.status(status).json({ error: message });
  }
  res.status(status).send('Something went wrong.');
});

httpServer.listen(PORT, async () => {
  console.log(`NeoAgent running on http://localhost:${PORT}`);
  await startServices(app, io);
});

// ── Graceful Shutdown ──

process.on('SIGINT', async () => {
  console.log('Shutting down...');
  if (app.locals.scheduler) app.locals.scheduler.stop();
  if (app.locals.mcpClient) await app.locals.mcpClient.shutdown().catch(() => { });
  if (app.locals.browserController) await app.locals.browserController.closeBrowser().catch(() => { });
  db.close();
  process.exit(0);
});

process.on('SIGTERM', () => {
  process.emit('SIGINT');
});

module.exports = { app, io, httpServer };
