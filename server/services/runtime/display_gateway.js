'use strict';

const { WebSocket, WebSocketServer } = require('ws');
const { trace } = require('./trace');

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
      const requestedToken = String(url.searchParams.get('token') || '').slice(0, 8);
      if (!displaySession) {
        trace('display.ws.rejected', { user: req.session.userId, token: requestedToken, reason: 'unknown-session' });
        rejectUpgrade(socket, 403, 'Forbidden');
        return;
      }
      const target = runtimeManager.getDisplayTarget(req.session.userId);
      if (!target) {
        trace('display.ws.rejected', { user: req.session.userId, token: requestedToken, reason: 'no-computer' });
        rejectUpgrade(socket, 409, 'Computer Display Unavailable');
        return;
      }
      wss.handleUpgrade(req, socket, head, (client) => {
        const displayToken = url.searchParams.get('token');
        const displayUserId = req.session.userId;
        const upstream = new WebSocket(target, ['binary'], {
          maxPayload: MAX_DISPLAY_FRAME_BYTES,
        });
        let upstreamReady = false;
        const pending = [];
        const openedAt = Date.now();
        const bytes = { toGuest: 0, toViewer: 0, framesToViewer: 0 };
        let firstFrameLogged = false;
        trace('display.ws.open', {
          user: displayUserId,
          token: requestedToken,
          target,
          viewOnly: displaySession.viewOnly,
          viewers: wss.clients.size,
        });
        // A viewer that is open but receiving nothing is exactly the frozen-desktop report,
        // and it looks identical to a healthy idle one from outside.
        let lastFrames = 0;
        const heartbeat = setInterval(() => {
          trace('display.ws.flow', {
            user: displayUserId,
            token: requestedToken,
            framesSinceLast: bytes.framesToViewer - lastFrames,
            framesTotal: bytes.framesToViewer,
            ageMs: Date.now() - openedAt,
            clientOpen: client.readyState === WebSocket.OPEN,
            upstreamOpen: upstream.readyState === WebSocket.OPEN,
          });
          lastFrames = bytes.framesToViewer;
        }, 30000);
        heartbeat.unref?.();
        const closeTrace = (reason, detail) => trace('display.ws.close', {
          user: displayUserId,
          token: requestedToken,
          reason,
          detail,
          ageMs: Date.now() - openedAt,
          framesToViewer: bytes.framesToViewer,
          bytesToViewer: bytes.toViewer,
          bytesToGuest: bytes.toGuest,
        });
        client.on('message', (data, isBinary) => {
          if (!runtimeManager.isDisplaySessionActive(displayUserId, displayToken, displaySession)) {
            closeTrace('session-revoked');
            client.close(1008, 'Computer control changed');
            return;
          }
          bytes.toGuest += data?.length || 0;
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
          trace('display.ws.upstream-open', {
            user: displayUserId, token: requestedToken, target, afterMs: Date.now() - openedAt, queued: pending.length,
          });
          for (const [data, isBinary] of pending.splice(0)) {
            if (upstream.readyState === WebSocket.OPEN) upstream.send(data, { binary: isBinary });
          }
        });
        upstream.on('message', (data, isBinary) => {
          if (client.readyState !== WebSocket.OPEN) return;
          runtimeManager.touchDisplaySession(displaySession);
          bytes.toViewer += data?.length || 0;
          bytes.framesToViewer += 1;
          if (!firstFrameLogged) {
            firstFrameLogged = true;
            trace('display.ws.first-frame', {
              user: displayUserId, token: requestedToken, afterMs: Date.now() - openedAt, bytes: data?.length || 0,
            });
          }
          client.send(data, { binary: isBinary });
        });
        upstream.once('error', (error) => {
          closeTrace('upstream-error', error?.message);
          if (client.readyState === WebSocket.OPEN) client.close(1011, 'Computer display unavailable');
        });
        client.once('close', (code, reason) => {
          clearInterval(heartbeat);
          closeTrace('viewer-closed', `${code} ${String(reason || '')}`.trim());
          if (upstream.readyState === WebSocket.OPEN || upstream.readyState === WebSocket.CONNECTING) {
            upstream.close();
          }
        });
        upstream.once('close', (code, reason) => {
          closeTrace('upstream-closed', `${code} ${String(reason || '')}`.trim());
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
