'use strict';

const { Server: SocketIO } = require('socket.io');

function createSocketServer(httpServer, { validateOrigin }) {
  console.log('[WS] Creating Socket.IO server');
  return new SocketIO(httpServer, {
    pingInterval: Number(process.env.NEOAGENT_SOCKET_PING_INTERVAL_MS || 25000),
    pingTimeout: Number(process.env.NEOAGENT_SOCKET_PING_TIMEOUT_MS || 20000),
    connectTimeout: Number(process.env.NEOAGENT_SOCKET_CONNECT_TIMEOUT_MS || 10000),
    maxHttpBufferSize: Number(process.env.NEOAGENT_SOCKET_MAX_HTTP_BUFFER_BYTES || 8 * 1024 * 1024),
    cors: {
      origin(origin, callback) {
        return validateOrigin(origin, callback, { allowMissingOrigin: true });
      },
      credentials: true
    }
  });
}

function bindSocketSessions(io, sessionMiddleware) {
  io.use((socket, next) => {
    console.log(`[WS] Binding session for socket ${socket.id}`);
    sessionMiddleware(socket.request, {}, (err) => {
      if (err) {
        console.error(`[WS] Session binding failed for socket ${socket.id}:`, err);
        return next(err);
      }
      console.log(`[WS] Session bound for socket ${socket.id} user=${socket.request?.session?.userId || 'anonymous'}`);
      return next();
    });
  });
}

module.exports = {
  bindSocketSessions,
  createSocketServer
};
