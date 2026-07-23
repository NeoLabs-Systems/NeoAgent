const { WebSocketServer } = require('ws');
const { BROWSER_EXTENSION_WS_PATH } = require('./protocol');

const DEFAULT_UPGRADE_RATE_LIMIT_WINDOW_MS = 60 * 1000;
const DEFAULT_UPGRADE_RATE_LIMIT_MAX = 30;
const MAX_EXTENSION_MESSAGE_BYTES = 32 * 1024 * 1024;

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
  const wss = new WebSocketServer({
    noServer: true,
    maxPayload: MAX_EXTENSION_MESSAGE_BYTES,
  });
  const attemptsByIp = new Map();
  let closing = false;
  let closePromise = null;
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

  const handleUpgrade = (req, socket, head) => {
    let url;
    try {
      url = new URL(req.url, 'http://localhost');
    } catch {
      return;
    }
    if (url.pathname !== BROWSER_EXTENSION_WS_PATH) {
      return;
    }
    if (closing) {
      rejectUpgrade(socket, 503, 'Service Unavailable');
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
      try {
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
      } catch (error) {
        try { ws.close(1012, String(error?.message || 'Service unavailable').slice(0, 120)); } catch {}
      }
    });
  };
  httpServer.on('upgrade', handleUpgrade);

  app.locals.browserExtensionGateway = {
    close: () => {
      if (closePromise) return closePromise;
      closing = true;
      clearInterval(cleanupTimer);
      httpServer.removeListener('upgrade', handleUpgrade);
      for (const client of wss.clients) {
        try { client.terminate(); } catch {}
      }
      closePromise = new Promise((resolve) => {
        wss.close(() => resolve());
      });
      return closePromise;
    },
  };

  return wss;
}

module.exports = {
  bindBrowserExtensionGateway,
};
