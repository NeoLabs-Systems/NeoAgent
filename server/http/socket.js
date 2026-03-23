'use strict';

const { Server: SocketIO } = require('socket.io');

function createSocketServer(httpServer, { validateOrigin }) {
  console.log('[WS] Creating Socket.IO server');
  return new SocketIO(httpServer, {
    cors: {
      origin: validateOrigin,
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
