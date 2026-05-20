const { WebSocketServer } = require('ws');
const {
  DESKTOP_COMPANION_WS_PATH,
  FRAME_TYPE_VIDEO,
  MAX_DESKTOP_STREAM_FRAME_BYTES,
  parseBinaryFrame,
  parseDesktopMessage,
} = require('./protocol');
const {
  assertDesktopHelloAuth,
  isDesktopCompanionHello,
  normalizeDesktopHello,
} = require('./auth');

const UPGRADE_RATE_LIMIT_WINDOW_MS = 60 * 1000;
const UPGRADE_RATE_LIMIT_MAX_ATTEMPTS = 30;
const UPGRADE_RATE_LIMIT_ENTRY_TTL_MS = 10 * 60 * 1000;

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

function remoteAddressFromRequest(req) {
  const forwarded = req.headers?.['x-forwarded-for'];
  if (typeof forwarded === 'string' && forwarded.trim()) {
    return forwarded.split(',')[0].trim();
  }
  return req.socket?.remoteAddress || 'unknown';
}

function createUpgradeThrottleObserver() {
  const byRemote = new Map();

  function record(remoteAddress) {
    const remote = String(remoteAddress || 'unknown');
    const now = Date.now();
    const current = byRemote.get(remote) || { count: 0, lastAt: 0 };
    current.count += 1;
    current.lastAt = now;
    byRemote.set(remote, current);

    if (byRemote.size > 500) {
      const cutoff = now - UPGRADE_RATE_LIMIT_ENTRY_TTL_MS;
      for (const [key, value] of byRemote.entries()) {
        if (!value.lastAt || value.lastAt < cutoff) {
          byRemote.delete(key);
        }
      }
    }

    console.warn('[DesktopGateway] upgrade_rate_limited', {
      remoteAddress: remote,
      occurredAt: new Date(now).toISOString(),
    });
  }

  function snapshot() {
    return {
      generatedAt: new Date().toISOString(),
      byRemote: Array.from(byRemote.entries())
        .map(([remoteAddress, stats]) => ({
          remoteAddress,
          count: stats.count,
          lastAt: stats.lastAt ? new Date(stats.lastAt).toISOString() : null,
        }))
        .sort((a, b) => b.count - a.count)
        .slice(0, 200),
    };
  }

  return { record, snapshot };
}

function bindDesktopCompanionGateway(httpServer, app, sessionMiddleware, streamHub = null) {
  const wss = new WebSocketServer({
    noServer: true,
    maxPayload: MAX_DESKTOP_STREAM_FRAME_BYTES,
  });
  const upgradeAttempts = new Map();
  const upgradeThrottleObserver = createUpgradeThrottleObserver();

  if (app?.locals) {
    app.locals.getDesktopGatewayRateLimitSnapshot = () => upgradeThrottleObserver.snapshot();
  }

  function allowUpgradeAttempt(remoteAddress) {
    const key = String(remoteAddress || 'unknown');
    const now = Date.now();

    for (const [entryKey, stats] of upgradeAttempts.entries()) {
      if (!stats?.windowStart || stats.windowStart + UPGRADE_RATE_LIMIT_WINDOW_MS <= now) {
        upgradeAttempts.delete(entryKey);
      }
    }

    const current = upgradeAttempts.get(key);
    if (!current || now - current.windowStart >= UPGRADE_RATE_LIMIT_WINDOW_MS) {
      upgradeAttempts.set(key, { windowStart: now, count: 1 });
      return true;
    }
    if (current.count >= UPGRADE_RATE_LIMIT_MAX_ATTEMPTS) {
      return false;
    }
    current.count += 1;
    return true;
  }

  httpServer.on('upgrade', (req, socket, head) => {
    let url;
    try {
      url = new URL(req.url, 'http://localhost');
    } catch {
      return;
    }
    if (url.pathname !== DESKTOP_COMPANION_WS_PATH) {
      return;
    }

    const remoteAddress = remoteAddressFromRequest(req);
    if (!allowUpgradeAttempt(remoteAddress)) {
      upgradeThrottleObserver.record(remoteAddress);
      rejectUpgrade(socket, 429, 'Too Many Requests');
      return;
    }

    sessionMiddleware(req, {}, (err) => {
      if (err) {
        rejectUpgrade(socket, 500, 'Session Error');
        return;
      }
      if (!req.session?.userId) {
        rejectUpgrade(socket, 401, 'Unauthorized');
        return;
      }

      const registry = app?.locals?.desktopCompanionRegistry;
      if (!registry) {
        rejectUpgrade(socket, 503, 'Service Unavailable');
        return;
      }

      wss.handleUpgrade(req, socket, head, (ws) => {
        let initialized = false;
        const helloTimer = setTimeout(() => {
          if (!initialized) {
            try { ws.close(1008, 'Desktop companion hello timed out'); } catch {}
          }
        }, 5000);

        ws.once('message', (data) => {
          clearTimeout(helloTimer);
          try {
            const message = parseDesktopMessage(data);
            if (!isDesktopCompanionHello(message)) {
              throw Object.assign(new Error('Desktop companion hello is required.'), { status: 400 });
            }
            const hello = normalizeDesktopHello(message);
            assertDesktopHelloAuth({
              sessionUserId: req.session?.userId,
              hello,
            });
            const { device } = registry.registerConnection({
              userId: req.session.userId,
              sessionId: req.sessionID || null,
              ws,
              hello,
              remoteAddress,
              userAgent: req.headers['user-agent'] || null,
            });
            initialized = true;
            ws.send(JSON.stringify({
              type: 'hello',
              ok: true,
              userId: req.session.userId,
              device,
            }));
            ws.on('message', (nextData) => {
              const activeStreamHub = streamHub || app?.locals?.streamHub || null;
              if (
                activeStreamHub
                && Buffer.isBuffer(nextData)
                && nextData.length > 10
                && nextData[0] === FRAME_TYPE_VIDEO
              ) {
                const frame = parseBinaryFrame(nextData);
                if (frame) {
                  activeStreamHub.handleFrame(req.session.userId, device.deviceId, {
                    ...frame,
                    platform: 'desktop',
                  });
                }
                return;
              }
              let parsed;
              try {
                parsed = parseDesktopMessage(nextData);
              } catch {
                return;
              }
              if (!parsed || parsed.type !== 'event') return;
              if (parsed.event === 'statusChanged' || parsed.event === 'permissionsChanged') {
                registry.touchConnection(req.session.userId, device.deviceId, parsed.payload || {});
              }
            });
          } catch (error) {
            try {
              ws.send(JSON.stringify({
                type: 'hello',
                ok: false,
                error: error.message,
              }));
            } catch {}
            try {
              ws.close(1008, String(error.message || 'Desktop companion rejected').slice(0, 120));
            } catch {}
          }
        });
      });
    });
  });

  if (app?.locals) {
    app.locals.desktopCompanionGateway = {
      close: () => new Promise((resolve) => wss.close(() => resolve())),
    };
  }

  return wss;
}

module.exports = {
  bindDesktopCompanionGateway,
};
