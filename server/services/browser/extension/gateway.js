const { WebSocketServer } = require('ws');
const { BROWSER_EXTENSION_WS_PATH } = require('./protocol');

function rejectUpgrade(socket, statusCode, message) {
  try {
    socket.write(
      `HTTP/1.1 ${statusCode} ${message}\r\n` +
      'Connection: close\r\n' +
      '\r\n',
    );
  } catch {}
  try { socket.destroy(); } catch {}
}

function bindBrowserExtensionGateway(httpServer, app) {
  const wss = new WebSocketServer({ noServer: true });

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
        remoteAddress: req.socket?.remoteAddress || null,
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
    close: () => new Promise((resolve) => wss.close(() => resolve())),
  };

  return wss;
}

module.exports = {
  bindBrowserExtensionGateway,
};
