'use strict';

const net = require('net');
const { WebSocket, WebSocketServer } = require('ws');
const {
  createUpgradeLimiter,
  rejectUpgrade,
  remoteAddressFromRequest,
} = require('../../utils/ws_upgrade');

const DISPLAY_WS_PATH = '/api/computer/display-ws';
const MAX_DISPLAY_FRAME_BYTES = 32 * 1024 * 1024;

function bindComputerDisplayGateway(httpServer, app, sessionMiddleware) {
  const wss = new WebSocketServer({ noServer: true, maxPayload: MAX_DISPLAY_FRAME_BYTES });
  const allowUpgradeAttempt = createUpgradeLimiter();
  let closing = false;

  const handleUpgrade = (req, socket, head) => {
    let url;
    try {
      url = new URL(req.url, 'http://localhost');
    } catch {
      return;
    }
    if (url.pathname !== DISPLAY_WS_PATH) return;
    if (closing) {
      rejectUpgrade(socket, 503, 'Service Unavailable');
      return;
    }
    const remoteAddress = remoteAddressFromRequest(req);
    if (!allowUpgradeAttempt(remoteAddress)) {
      rejectUpgrade(socket, 429, 'Too Many Requests');
      return;
    }
    sessionMiddleware(req, {}, (error) => {
      if (error || !req.session?.userId) {
        rejectUpgrade(socket, error ? 500 : 401, error ? 'Session Error' : 'Unauthorized');
        return;
      }
      const runtimeManager = app?.locals?.runtimeManager;
      const displaySession = runtimeManager?.resolveDisplaySession(
        req.session.userId,
        url.searchParams.get('token'),
      );
      if (!displaySession) {
        rejectUpgrade(socket, 403, 'Forbidden');
        return;
      }
      const target = runtimeManager.getDisplayTarget(req.session.userId);
      if (!target) {
        rejectUpgrade(socket, 409, 'Computer Display Unavailable');
        return;
      }
      wss.handleUpgrade(req, socket, head, (client) => {
        const displayToken = url.searchParams.get('token');
        const displayUserId = req.session.userId;
        // QEMU serves raw RFB on a socket the guest cannot reach; this bridge is its only
        // websocket, so every frame passes the display-session checks above.
        const upstream = net.createConnection(target);
        upstream.setNoDelay(true);
        client.on('message', (data) => {
          if (!runtimeManager.isDisplaySessionActive(displayUserId, displayToken, displaySession)) {
            client.close(1008, 'Computer control changed');
            return;
          }
          runtimeManager.touchComputerActivity(displayUserId);
          runtimeManager.touchDisplaySession(displaySession);
          if (!upstream.destroyed) upstream.write(data);
        });
        upstream.on('data', (chunk) => {
          if (client.readyState !== WebSocket.OPEN) return;
          runtimeManager.touchDisplaySession(displaySession);
          client.send(chunk, { binary: true });
        });
        upstream.once('error', () => {
          if (client.readyState === WebSocket.OPEN) client.close(1011, 'Computer display unavailable');
        });
        client.once('close', () => upstream.destroy());
        upstream.once('close', () => {
          if (client.readyState === WebSocket.OPEN) client.close(1001, 'Computer display closed');
        });
      });
    });
  };

  httpServer.on('upgrade', handleUpgrade);
  app.locals.computerDisplayGateway = {
    close: async () => {
      closing = true;
      httpServer.removeListener('upgrade', handleUpgrade);
      for (const client of wss.clients) {
        try { client.terminate(); } catch {}
      }
      await new Promise((resolve) => wss.close(resolve));
    },
  };
  return wss;
}

module.exports = {
  DISPLAY_WS_PATH,
  bindComputerDisplayGateway,
};
