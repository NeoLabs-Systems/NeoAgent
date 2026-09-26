'use strict';

const { WebSocketServer } = require('ws');
const { sanitizeError } = require('../../utils/security');
const { createVoiceSink } = require('../voice/voice_transport');
const { asObject, toOptionalString } = require('../../utils/text');
const {
  createUpgradeLimiter,
  rejectUpgrade,
  remoteAddressFromRequest,
} = require('../../utils/ws_upgrade');
const {
  WEARABLE_WS_PATH,
  isSupportedClientMessageType,
  isWearableHello,
  parseWearableMessage,
} = require('./protocol');

const HELLO_TIMEOUT_MS = 5000;

function sendJson(ws, payload) {
  if (!ws || ws.readyState !== 1) return;
  ws.send(JSON.stringify(payload));
}

function bindWearableGateway(httpServer, app, sessionMiddleware) {
  const wss = new WebSocketServer({ noServer: true, maxPayload: 1 * 1024 * 1024 });
  const allowUpgradeAttempt = createUpgradeLimiter();

  httpServer.on('upgrade', (req, socket, head) => {
    let url;
    try {
      url = new URL(req.url, 'http://localhost');
    } catch {
      return;
    }
    if (url.pathname !== WEARABLE_WS_PATH) {
      return;
    }
    const remoteAddress = remoteAddressFromRequest(req);
    if (!allowUpgradeAttempt(remoteAddress)) {
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
      const wearableService = app?.locals?.wearableService;
      const voiceRuntimeManager = app?.locals?.voiceRuntimeManager;
      if (!wearableService || !voiceRuntimeManager) {
        rejectUpgrade(socket, 503, 'Service Unavailable');
        return;
      }

      wss.handleUpgrade(req, socket, head, (ws) => {
        ws.isAlive = true;
        ws.on('pong', () => {
          ws.isAlive = true;
        });

        let initialized = false;
        let deviceId = '';
        const activeSessionIds = new Set();
        const helloTimer = setTimeout(() => {
          if (!initialized) {
            try {
              ws.close(1008, 'Wearable hello timed out');
            } catch {}
          }
        }, HELLO_TIMEOUT_MS);

        const teardown = async () => {
          clearTimeout(helloTimer);
          if (deviceId) {
            wearableService.unregisterConnection(req.session.userId, deviceId);
          }
          await Promise.allSettled(
            Array.from(activeSessionIds).map((sessionId) =>
              voiceRuntimeManager.closeSession(
                sessionId,
                'wearable_socket_closed',
                req.session.userId,
              ),
            ),
          );
        };

        ws.on('close', () => {
          void teardown();
        });

        ws.on('message', async (data) => {
          try {
            const message = parseWearableMessage(data);
            if (!initialized) {
              if (!isWearableHello(message)) {
                throw new Error('wearable:hello is required before other messages.');
              }
              const connection = wearableService.registerConnection({
                userId: req.session.userId,
                ws,
                remoteAddress,
                userAgent: req.headers['user-agent'] || null,
                hello: message,
              });
              initialized = true;
              deviceId = connection.deviceId;
              sendJson(ws, {
                type: 'wearable:hello',
                ok: true,
                deviceId,
                userId: req.session.userId,
                serverTime: new Date().toISOString(),
              });
              return;
            }

            if (!isSupportedClientMessageType(message.type)) {
              throw new Error(`Unsupported wearable message type "${message.type}".`);
            }
            wearableService.touchConnection(req.session.userId, deviceId);
            const payload = asObject(message);
            const sessionId = toOptionalString(payload.sessionId, 128);

            switch (message.type) {
              case 'voice:session_open': {
                const session = await voiceRuntimeManager.openWearableSession({
                  userId: req.session.userId,
                  agentId: payload.agentId || payload.agent_id || null,
                  sessionId: sessionId || null,
                  sink: createVoiceSink((event, data) => sendJson(ws, { type: event, ...data })),
                });
                activeSessionIds.add(session.id);
                break;
              }
              case 'voice:audio': {
                if (!sessionId) throw new Error('sessionId is required');
                const audioBase64 = toOptionalString(payload.audioBase64, 800000);
                if (!audioBase64) throw new Error('audioBase64 is required');
                voiceRuntimeManager.appendAudio(sessionId, Buffer.from(audioBase64, 'base64'), req.session.userId);
                break;
              }
              case 'voice:input_start':
                if (!sessionId) throw new Error('sessionId is required');
                voiceRuntimeManager.startInput(sessionId, req.session.userId);
                break;
              case 'voice:input_end':
                if (!sessionId) throw new Error('sessionId is required');
                voiceRuntimeManager.endInput(sessionId, req.session.userId);
                break;
              case 'voice:interrupt':
                if (!sessionId) throw new Error('sessionId is required');
                voiceRuntimeManager.interruptOutput(sessionId, req.session.userId);
                break;
              case 'voice:session_close':
                if (!sessionId) throw new Error('sessionId is required');
                activeSessionIds.delete(sessionId);
                await voiceRuntimeManager.closeSession(
                  sessionId,
                  'wearable_client_closed',
                  req.session.userId,
                );
                break;
              default:
                break;
            }
          } catch (error) {
            sendJson(ws, {
              type: 'voice:error',
              error: sanitizeError(error),
            });
          }
        });
      });
    });
  });

  const heartbeat = setInterval(() => {
    for (const ws of wss.clients) {
      if (ws.isAlive === false) {
        try {
          ws.terminate();
        } catch {}
        continue;
      }
      ws.isAlive = false;
      try {
        ws.ping();
      } catch {}
    }
  }, 30000);
  heartbeat.unref?.();

  if (app?.locals) {
    app.locals.wearableGateway = {
      close: () =>
        new Promise((resolve) => {
          clearInterval(heartbeat);
          wss.close(() => resolve());
        }),
    };
  }

  return wss;
}

module.exports = {
  bindWearableGateway,
};
