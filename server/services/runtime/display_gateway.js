'use strict';

const { WebSocket, WebSocketServer } = require('ws');

const DISPLAY_WS_PATH = '/api/computer/display-ws';
const MAX_DISPLAY_FRAME_BYTES = 32 * 1024 * 1024;

function rejectUpgrade(socket, statusCode, message) {
  try {
    socket.write(`HTTP/1.1 ${statusCode} ${message}\r\nConnection: close\r\n\r\n`);
  } catch {}
  try { socket.destroy(); } catch {}
}

function bindComputerDisplayGateway(httpServer, app, sessionMiddleware) {
  const wss = new WebSocketServer({ noServer: true, maxPayload: MAX_DISPLAY_FRAME_BYTES });
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
      wss.handleUpgrade(req, socket, head, (client) => {
        const displayToken = url.searchParams.get('token');
        const displayUserId = req.session.userId;
        const upstream = new WebSocket(displaySession.target, ['binary'], {
          maxPayload: MAX_DISPLAY_FRAME_BYTES,
        });
        let upstreamReady = false;
        const pending = [];
        client.on('message', (data, isBinary) => {
          if (!runtimeManager.isDisplaySessionActive(displayUserId, displayToken, displaySession)) {
            client.close(1008, 'Computer control changed');
            return;
          }
          runtimeManager.touchComputerActivity(displayUserId);
          runtimeManager.touchDisplaySession(displaySession);
          if (!upstreamReady) {
            if (pending.length < 32) pending.push([data, isBinary]);
            return;
          }
          if (upstream.readyState === WebSocket.OPEN) upstream.send(data, { binary: isBinary });
        });
        upstream.once('open', () => {
          upstreamReady = true;
          for (const [data, isBinary] of pending.splice(0)) {
            if (upstream.readyState === WebSocket.OPEN) upstream.send(data, { binary: isBinary });
          }
        });
        upstream.on('message', (data, isBinary) => {
          if (client.readyState !== WebSocket.OPEN) return;
          runtimeManager.touchDisplaySession(displaySession);
          client.send(data, { binary: isBinary });
        });
        upstream.once('error', () => {
          if (client.readyState === WebSocket.OPEN) client.close(1011, 'Computer display unavailable');
        });
        client.once('close', () => {
          if (upstream.readyState === WebSocket.OPEN || upstream.readyState === WebSocket.CONNECTING) {
            upstream.close();
          }
        });
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
