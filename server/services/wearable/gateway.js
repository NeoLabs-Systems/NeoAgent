'use strict';

const { WebSocketServer } = require('ws');
const { sanitizeError } = require('../../utils/security');
const {
  WEARABLE_WS_PATH,
  isSupportedClientMessageType,
  isWearableHello,
  parseWearableMessage,
} = require('./protocol');

const UPGRADE_WINDOW_MS = 60 * 1000;
const UPGRADE_MAX_ATTEMPTS = 30;
const HELLO_TIMEOUT_MS = 5000;

function rejectUpgrade(socket, statusCode, message) {
  try {
    socket.write(
      `HTTP/1.1 ${statusCode} ${message}\r\n` +
      'Connection: close\r\n' +
      '\r\n',
    );
  } catch {}
  try {
    socket.destroy();
  } catch {}
}

function remoteAddressFromRequest(req) {
  const forwarded = req.headers?.['x-forwarded-for'];
  if (typeof forwarded === 'string' && forwarded.trim()) {
    return forwarded.split(',')[0].trim();
  }
  return req.socket?.remoteAddress || 'unknown';
}

function createUpgradeLimiter() {
  const attempts = new Map();
  return (remoteAddress) => {
    const key = String(remoteAddress || 'unknown');
    const now = Date.now();
    for (const [entryKey, stats] of attempts.entries()) {
      if (!stats?.windowStart || stats.windowStart + UPGRADE_WINDOW_MS <= now) {
        attempts.delete(entryKey);
      }
    }
    const current = attempts.get(key);
    if (!current) {
      attempts.set(key, { windowStart: now, count: 1 });
      return true;
    }
    if (now - current.windowStart >= UPGRADE_WINDOW_MS) {
      attempts.set(key, { windowStart: now, count: 1 });
      return true;
    }
    if (current.count >= UPGRADE_MAX_ATTEMPTS) {
      return false;
    }
    current.count += 1;
    return true;
  };
}

function sendJson(ws, payload) {
  if (!ws || ws.readyState !== 1) return;
  ws.send(JSON.stringify(payload));
}

function asObject(value) {
  return value && typeof value === 'object' && !Array.isArray(value) ? value : {};
}

function toOptionalString(value, maxLength = 512) {
  if (value == null) return '';
  return String(value).trim().slice(0, maxLength);
}

function toBoundedInt(value, fallback, min, max) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(max, Math.max(min, Math.floor(parsed)));
}

function createWearableVoiceSink(ws, voiceRuntimeManager) {
  return {
    publishReady: async (session, extra = {}) => {
      sendJson(ws, {
        type: 'voice:session_ready',
        sessionId: session.id,
        ...extra,
      });
    },
    setState: async (session, state, extra = {}) => {
      sendJson(ws, {
        type: 'voice:assistant_state',
        sessionId: session.id,
        state,
        ...extra,
      });
    },
    publishTranscriptPartial: async (session, content) => {
      sendJson(ws, {
        type: 'voice:transcript_partial',
        sessionId: session.id,
        content,
      });
    },
    publishTranscriptFinal: async (session, content) => {
      sendJson(ws, {
        type: 'voice:transcript_final',
        sessionId: session.id,
        content,
      });
    },
    publishAssistantOutput: async (session, content, options = {}) => {
      await voiceRuntimeManager.deliverWearableAssistantOutput(ws, session.id, content, options);
    },
    interruptOutput: async (session) => {
      sendJson(ws, {
        type: 'voice:assistant_state',
        sessionId: session.id,
        state: 'interrupted',
      });
    },
    publishError: async (session, message, extra = {}) => {
      sendJson(ws, {
        type: 'voice:error',
        sessionId: session.id,
        error: message,
        ...extra,
      });
    },
    close: async (session, reason = 'closed') => {
      sendJson(ws, {
        type: 'voice:assistant_state',
        sessionId: session.id,
        state: 'closed',
        reason,
      });
    },
  };
}

function bindWearableGateway(httpServer, app, sessionMiddleware) {
  const wss = new WebSocketServer({ noServer: true });
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
              voiceRuntimeManager.closeSession(sessionId, 'wearable_socket_closed'),
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
                const resolvedSessionId = sessionId || null;
                const session = await voiceRuntimeManager.openWearableSession({
                  userId: req.session.userId,
                  agentId: payload.agentId || payload.agent_id || null,
                  sessionId: resolvedSessionId,
                  sink: createWearableVoiceSink(ws, voiceRuntimeManager),
                });
                activeSessionIds.add(session.id);
                break;
              }
              case 'voice:input_start':
                if (!sessionId) throw new Error('sessionId is required');
                await voiceRuntimeManager.beginInput(sessionId, {
                  mimeType: toOptionalString(payload.mimeType, 128),
                  turnId: toOptionalString(payload.turnId, 128),
                });
                break;
              case 'voice:audio_chunk': {
                if (!sessionId) throw new Error('sessionId is required');
                const audioBase64 = toOptionalString(payload.audioBase64, 800000);
                if (!audioBase64) throw new Error('audioBase64 is required');
                const sequence = toBoundedInt(payload.sequence, -1, -1, 1000000);
                if (sequence < 0) throw new Error('sequence is required');
                const turnId = toOptionalString(payload.turnId, 128);
                if (!turnId) throw new Error('turnId is required');
                const audioBytes = Buffer.from(audioBase64, 'base64');
                const appendResult = await voiceRuntimeManager.appendInputAudio(sessionId, audioBytes, {
                  mimeType: toOptionalString(payload.mimeType, 128),
                  turnId,
                  sequence,
                });
                sendJson(ws, {
                  type: 'voice:chunk_ack',
                  sessionId,
                  turnId,
                  sequence,
                  receivedThrough: appendResult?.receivedThrough ?? sequence,
                });
                break;
              }
              case 'voice:input_commit': {
                if (!sessionId) throw new Error('sessionId is required');
                await voiceRuntimeManager.commitInput(sessionId, {
                  turnId: toOptionalString(payload.turnId, 128),
                  finalSequence: toBoundedInt(payload.finalSequence, -1, -1, 1000000),
                  promptHint: toOptionalString(payload.promptHint, 2000),
                });
                break;
              }
              case 'voice:interrupt':
                if (!sessionId) throw new Error('sessionId is required');
                await voiceRuntimeManager.interruptSession(sessionId);
                break;
              case 'voice:session_close':
                if (!sessionId) throw new Error('sessionId is required');
                activeSessionIds.delete(sessionId);
                await voiceRuntimeManager.closeSession(sessionId, 'wearable_client_closed');
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
