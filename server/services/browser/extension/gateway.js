const { WebSocketServer } = require('ws');
const { BROWSER_EXTENSION_WS_PATH } = require('./protocol');

const DEFAULT_UPGRADE_RATE_LIMIT_WINDOW_MS = 60 * 1000;
const DEFAULT_UPGRADE_RATE_LIMIT_MAX = 30;

function rejectUpgrade(socket, statusCode, message) {
  try {
    socket.write(
      `HTTP/1.1 ${statusCode} ${message}\r\n` +
      'Connection: close\r\n' +
      '\r\n',
    );
  } catch (err) {
    console.warn('[BrowserExtensionGateway] Failed to write rejection response:', err?.message);
  }
  try {
    socket.destroy();
  } catch (err) {
    console.warn('[BrowserExtensionGateway] Failed to destroy socket:', err?.message);
  }
}

function bindBrowserExtensionGateway(httpServer, app) {
  const wss = new WebSocketServer({ noServer: true });
  const attemptsByIp = new Map();
  const windowMs = Number(process.env.NEOAGENT_BROWSER_EXTENSION_UPGRADE_WINDOW_MS || DEFAULT_UPGRADE_RATE_LIMIT_WINDOW_MS);

  const cleanupTimer = setInterval(() => {
    const now = Date.now();
    for (const [ip, entry] of attemptsByIp.entries()) {
      if (!entry || (now - entry.windowStartedAt) > windowMs) {
        attemptsByIp.delete(ip);
      }
    }
  }, Math.max(1000, Math.floor(windowMs / 2)));
  if (typeof cleanupTimer.unref === 'function') cleanupTimer.unref();

  function isRateLimited(ip) {
    const now = Date.now();
    const maxAttempts = Number(process.env.NEOAGENT_BROWSER_EXTENSION_UPGRADE_MAX || DEFAULT_UPGRADE_RATE_LIMIT_MAX);

    const entry = attemptsByIp.get(ip);
    if (!entry || now - entry.windowStartedAt > windowMs) {
      attemptsByIp.set(ip, { windowStartedAt: now, count: 1 });
      return false;
    }

    entry.count += 1;
    return entry.count > maxAttempts;
  }

  httpServer.on('upgrade', (req, socket, head) => {
    let url;
    try {
      url = new URL(req.url, 'http://localhost');
    } catch {
      return;
    }
    if (url.pathname !== BROWSER_EXTENSION_WS_PATH) {
      return;
    }

    const remoteAddress = req.socket?.remoteAddress || 'unknown';
    if (isRateLimited(remoteAddress)) {
      rejectUpgrade(socket, 429, 'Too Many Requests');
      return;
    }

    const registry = app?.locals?.browserExtensionRegistry;
    if (!registry || typeof registry.validateToken !== 'function') {
      rejectUpgrade(socket, 503, 'Service Unavailable');
      return;
    }

    const token = url.searchParams.get('token') || req.headers['x-neoagent-extension-token'];
    const tokenRow = registry.validateToken(token);
    if (!tokenRow) {
      rejectUpgrade(socket, 401, 'Unauthorized');
      return;
    }

    wss.handleUpgrade(req, socket, head, (ws) => {
      registry.registerConnection(tokenRow, ws, {
        remoteAddress,
        userAgent: req.headers['user-agent'] || null,
      });
      ws.send(JSON.stringify({
        type: 'hello',
        ok: true,
        userId: tokenRow.user_id,
        tokenId: tokenRow.id,
      }));
    });
  });

  app.locals.browserExtensionGateway = {
    close: () => new Promise((resolve) => {
      clearInterval(cleanupTimer);
      wss.close(() => resolve());
    }),
  };

  return wss;
}

module.exports = {
  bindBrowserExtensionGateway,
};
