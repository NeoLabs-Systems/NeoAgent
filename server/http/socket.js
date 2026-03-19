'use strict';

const { Server: SocketIO } = require('socket.io');

function createSocketServer(httpServer, { validateOrigin }) {
  return new SocketIO(httpServer, {
    cors: {
      origin: validateOrigin,
      credentials: true
    }
  });
}

function bindSocketSessions(io, sessionMiddleware) {
  io.use((socket, next) => {
    sessionMiddleware(socket.request, {}, next);
  });
}

module.exports = {
  bindSocketSessions,
  createSocketServer
};
