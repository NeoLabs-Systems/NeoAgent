'use strict';

const { createServer } = require('node:http');
const { once } = require('node:events');
const { Server } = require('socket.io');
const { io: createClient } = require('socket.io-client');

const { createTestApp } = require('./app');
const { createFakeAppLocals } = require('./fakes');

async function createSocketFixture() {
  const { app, sessionMiddleware } = createTestApp();
  const httpServer = createServer(app);
  const io = new Server(httpServer, {
    cors: { origin: true, credentials: true },
  });
  const { bindSocketSessions } = require('../../server/http/socket');
  const { setupWebSocket } = require('../../server/services/websocket');
  bindSocketSessions(io, sessionMiddleware);
  setupWebSocket(io, {
    ...createFakeAppLocals(),
    app,
  });
  httpServer.listen(0, '127.0.0.1');
  await once(httpServer, 'listening');
  const { port } = httpServer.address();
  return {
    app,
    io,
    httpServer,
    url: `http://127.0.0.1:${port}`,
    async close() {
      await new Promise((resolve) => io.close(resolve));
      await new Promise((resolve) => httpServer.close(resolve));
    },
  };
}

function connectSocket(url, cookie = '') {
  return createClient(url, {
    transports: ['websocket'],
    forceNew: true,
    extraHeaders: cookie ? { Cookie: cookie } : {},
    reconnection: false,
    timeout: 2000,
  });
}

module.exports = {
  connectSocket,
  createSocketFixture,
};
