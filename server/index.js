require('dotenv').config();

const express = require('express');
const session = require('express-session');
const SQLiteStore = require('connect-sqlite3')(session);
const { createServer } = require('http');
const { Server: SocketIO } = require('socket.io');
const helmet = require('helmet');
const cors = require('cors');
const path = require('path');
const fs = require('fs');

const db = require('./db/database');
const { requireAuth, requireNoAuth } = require('./middleware/auth');
const { sanitizeError, detectPromptInjection } = require('./utils/security');

const app = express();
const httpServer = createServer(app);
const io = new SocketIO(httpServer, {
  cors: {
    origin: process.env.ALLOWED_ORIGINS ? process.env.ALLOWED_ORIGINS.split(',') : false,
    credentials: true
  }
});

if (!process.env.SESSION_SECRET) {
  console.warn('WARNING: SESSION_SECRET not set — using insecure default. Set it in .env before exposing this server.');
}

const PORT = process.env.PORT || 3060;
const DATA_DIR = path.join(__dirname, '../data');
if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });

// ── Middleware ──

app.use(helmet({
  // Disable headers that only make sense on HTTPS — this app runs on plain HTTP (Tailscale/localhost).
  strictTransportSecurity: false,   // HSTS: would force browser to upgrade HTTP→HTTPS permanently
  crossOriginOpenerPolicy: false,   // COOP: ignored on non-HTTPS origins, causes browser warning
  originAgentCluster: false,        // OAC: causes "previously placed in site-keyed cluster" warning on HTTP
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "'unsafe-inline'"],
      scriptSrcAttr: ["'unsafe-inline'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:", "blob:", "https://api.qrserver.com"],
      connectSrc: ["'self'", "ws:", "wss:"],
      fontSrc: ["'self'", "data:"],
      // Disable upgrade-insecure-requests — helmet adds this by default in v7+,
      // which causes browsers to upgrade HTTP subresource requests to HTTPS,
      // breaking plain-HTTP deployments (Tailscale, localhost).
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
    secure: false  // This server runs on plain HTTP (Tailscale / localhost); secure:true would block cookies over HTTP
  }
});

app.use(sessionMiddleware);

// Share session with Socket.IO
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
app.use('/api/store', require('./routes/store'));
app.use('/api/memory', require('./routes/memory'));
app.use('/api/scheduler', require('./routes/scheduler'));
app.use('/api/browser', require('./routes/browser'));

// ── Telnyx voice webhook (unauthenticated – called by Telnyx servers) ──
app.post('/api/telnyx/webhook', async (req, res) => {
  res.status(200).send('OK'); // Acknowledge immediately
  const manager = app.locals.messagingManager;
  if (manager) await manager.handleTelnyxWebhook(req.body).catch(err => console.error('[Telnyx webhook]', err.message));
});

// ── Telnyx generated audio files (served publicly so Telnyx can fetch them) ──
app.use('/telnyx-audio', express.static(path.join(DATA_DIR, 'telnyx-audio')));

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

app.use(express.static(path.join(__dirname, 'public')));

app.get('/', (req, res) => {
  if (req.session && req.session.userId) return res.redirect('/app');
  res.redirect('/login');
});

app.get('/api/health', requireAuth, (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// ── Service Initialization ──

const startServices = async () => {
  try {
    const { MemoryManager } = require('./services/memory/manager');
    const memoryManager = new MemoryManager();
    app.locals.memoryManager = memoryManager;

    const { MCPClient } = require('./services/mcp/client');
    const mcpClient = new MCPClient();
    app.locals.mcpClient = mcpClient;

    const { BrowserController } = require('./services/browser/controller');
    const browserController = new BrowserController();
    // Restore saved headless preference for the first user (single-user app)
    const headlessSetting = db.prepare('SELECT value FROM user_settings WHERE key = ? ORDER BY user_id LIMIT 1').get('headless_browser');
    if (headlessSetting) {
      const val = headlessSetting.value;
      browserController.headless = val !== 'false' && val !== false && val !== '0';
    }
    app.locals.browserController = browserController;

    const { AgentEngine } = require('./services/ai/engine');
    const agentEngine = new AgentEngine(io, { memoryManager, mcpClient, browserController, messagingManager: null /* set below */ });
    app.locals.agentEngine = agentEngine;

    const { MultiStepOrchestrator } = require('./services/ai/multiStep');
    const multiStep = new MultiStepOrchestrator(agentEngine, io);
    app.locals.multiStep = multiStep;

    const { MessagingManager } = require('./services/messaging/manager');
    const messagingManager = new MessagingManager(io);
    app.locals.messagingManager = messagingManager;
    // Inject messagingManager into the already-created agentEngine
    agentEngine.messagingManager = messagingManager;

    messagingManager.restoreConnections().catch(err => console.error('[Messaging] Restore error:', err.message));

    const users = db.prepare('SELECT id FROM users').all();
    for (const u of users) {
      mcpClient.loadFromDB(u.id).catch(err => console.error('[MCP] Auto-start error:', err.message));
    }

    // Per-user message queues: batch & combine messages while AI is busy
    const userQueues = {};
    app.locals.userQueues = userQueues;

    async function processMessage(userId, msg) {
      if (!userQueues[userId]) userQueues[userId] = { running: false, pending: [] };
      const q = userQueues[userId];

      if (q.running) {
        const last = q.pending[q.pending.length - 1];
        if (last && last.platform === msg.platform && last.chatId === msg.chatId) {
          last.content += '\n' + msg.content;
          last.messageId = msg.messageId;
        } else {
          q.pending.push({ ...msg });
        }
        return;
      }

      q.running = true;
      try {
        await messagingManager.markRead(userId, msg.platform, msg.chatId, msg.messageId).catch(() => { });
        await messagingManager.sendTyping(userId, msg.platform, msg.chatId, true).catch(() => { });
        const mediaNote = msg.localMediaPath
          ? `\nMedia attached at: ${msg.localMediaPath} (type: ${msg.mediaType}). You can reference or forward it with send_message media_path.`
          : '';
        // Detect and log prompt injection attempts from external sources
        if (detectPromptInjection(msg.content)) {
          console.warn(`[Security] Possible prompt injection attempt from ${msg.sender} on ${msg.platform}: ${msg.content.slice(0, 200)}`);
        }
        // Wrap external content in delimiters — prevents prompt injection from untrusted senders
        const isVoiceCall  = msg.platform === 'telnyx' && msg.mediaType === 'voice';
        const isDiscordGuild = msg.platform === 'discord' && msg.isGroup;

        // Channel context block for Discord guild/channel messages
        const discordContext = (isDiscordGuild && Array.isArray(msg.channelContext) && msg.channelContext.length)
          ? '\n\nRecent channel context (oldest → newest):\n' +
            msg.channelContext.map(m => `[${m.author}]: ${m.content}`).join('\n')
          : '';

        const prompt = isVoiceCall
          ? `You are on a live phone call. The caller (${msg.senderName || msg.sender}) said:
<caller_speech>
${msg.content}
</caller_speech>

Respond via send_message with platform="telnyx" and to="${msg.chatId}".
Rules for voice responses:
- Keep it brief and conversational — this will be spoken aloud via TTS.
- NO markdown, bullet points, bold, headers, or special formatting.
- Speak naturally. Never say things like "How can I assist you further?" — just stop when done.
- Always respond; never use [NO RESPONSE] on a live call.`
          : `You received a ${msg.platform} message from ${msg.senderName || msg.sender} (chat: ${msg.chatId}):\n<external_message>\n${msg.content}\n</external_message>${mediaNote}${discordContext}

Reply to this message using send_message with platform="${msg.platform}" and to="${msg.chatId}".
Text like a person: split across messages naturally when it fits the content. Never end with "anything else?" or close-out phrases — just stop when you're done.
You can also send images/files by setting media_path to a local file path.
If no reply is needed (e.g. the message is just an acknowledgement like "ok", "thanks", or you already said everything), call send_message with content "[NO RESPONSE]" to explicitly stay silent.`;
        const priorMessages = db.prepare(
          'SELECT role, content FROM messages WHERE user_id = ? AND platform_chat_id = ? ORDER BY created_at DESC LIMIT 30'
        ).all(userId, msg.chatId).reverse();
        const runOpts = { source: msg.platform, chatId: msg.chatId, priorMessages };
        if (msg.localMediaPath) runOpts.mediaAttachments = [{ path: msg.localMediaPath, type: msg.mediaType }];
        await agentEngine.run(userId, prompt, runOpts);
      } finally {
        await messagingManager.sendTyping(userId, msg.platform, msg.chatId, false).catch(() => { });
        q.running = false;
        if (q.pending.length > 0) {
          const next = q.pending.shift();
          processMessage(userId, next);
        }
      }
    }

    // Wire messaging → agent: incoming messages trigger agent
    messagingManager.registerHandler(async (userId, msg) => {
      // Discord handles its own access control (prefixed entry whitelist + mention gating)
      if (msg.platform !== 'discord') {
        // Whitelist check: if user has set a whitelist for this platform, block unknown senders
        const whitelistRow = db.prepare('SELECT value FROM user_settings WHERE user_id = ? AND key = ?')
          .get(userId, `platform_whitelist_${msg.platform}`);
        if (whitelistRow) {
          try {
            const whitelist = JSON.parse(whitelistRow.value);
            if (Array.isArray(whitelist) && whitelist.length > 0) {
              const normalize = (id) => (id || '').replace(/[^0-9]/g, '');
              const senderNorm = normalize(msg.sender || msg.chatId);
              const allowed = whitelist.some(n => normalize(n) === senderNorm);
              if (!allowed) {
                console.log(`[Messaging] Blocked ${msg.platform} message from ${msg.sender} (not in whitelist)`);
                io.to(`user:${userId}`).emit('messaging:blocked_sender', {
                  platform: msg.platform,
                  sender: msg.sender,
                  chatId: msg.chatId,
                  senderName: msg.senderName || null
                });
                return;
              }
            }
          } catch { /* malformed whitelist, allow through */ }
        }
      }

      const upsertSetting = db.prepare('INSERT OR REPLACE INTO user_settings (user_id, key, value) VALUES (?, ?, ?)');
      upsertSetting.run(userId, 'last_platform', msg.platform);
      upsertSetting.run(userId, 'last_chat_id', msg.chatId);

      await processMessage(userId, msg);
    });

    const { Scheduler } = require('./services/scheduler/cron');
    const scheduler = new Scheduler(io, agentEngine);
    app.locals.scheduler = scheduler;
    agentEngine.scheduler = scheduler;
    scheduler.start();

    const { setupWebSocket } = require('./services/websocket');
    setupWebSocket(io, { agentEngine, messagingManager, mcpClient, scheduler, memoryManager, app });

    app.locals.io = io;

    console.log('All services initialized');
  } catch (err) {
    console.error('Service init error:', err);
  }
};

// ── Global Error Handler ──

// Must be registered after all routes. Sanitizes error details so internal paths
// and stack traces are never exposed in API responses.
app.use((err, req, res, next) => { // eslint-disable-line no-unused-vars
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
  await startServices();
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
