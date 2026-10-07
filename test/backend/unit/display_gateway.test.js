'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const http = require('node:http');
const net = require('node:net');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');
const { WebSocket } = require('ws');

const { DISPLAY_WS_PATH, bindComputerDisplayGateway } = require('../../../server/services/runtime/display_gateway');

test('display gateway bridges an authorized viewer to the VM display socket', async (t) => {
  if (process.platform === 'win32') {
    t.skip('VNC runs on a UNIX socket only on POSIX hosts');
    return;
  }
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-display-'));
  const socketPath = path.join(root, 'vnc.sock');
  const vnc = net.createServer((socket) => {
    socket.write('RFB 003.008\n');
    socket.on('data', (chunk) => socket.write(Buffer.concat([Buffer.from('echo:'), chunk])));
  });
  await new Promise((resolve) => vnc.listen(socketPath, resolve));

  const runtimeManager = {
    resolveDisplaySession: (userId, token) => (userId === 7 && token === 'good' ? { token } : null),
    getDisplayTarget: () => ({ path: socketPath }),
    isDisplaySessionActive: () => true,
    touchComputerActivity() {},
    touchDisplaySession() {},
  };
  const app = { locals: { runtimeManager } };
  const server = http.createServer();
  bindComputerDisplayGateway(server, app, (req, _res, next) => {
    req.session = { userId: 7 };
    next();
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(async () => {
    await app.locals.computerDisplayGateway.close();
    await new Promise((resolve) => server.close(resolve));
    await new Promise((resolve) => vnc.close(resolve));
    fs.rmSync(root, { recursive: true, force: true });
  });
  const base = `ws://127.0.0.1:${server.address().port}${DISPLAY_WS_PATH}`;

  const rejected = new WebSocket(`${base}?token=bad`);
  const status = await new Promise((resolve) => rejected.once('unexpected-response', (_req, res) => resolve(res.statusCode)));
  assert.equal(status, 403);

  const viewer = new WebSocket(`${base}?token=good`, ['binary']);
  const received = [];
  const next = () => new Promise((resolve) => viewer.once('message', (data) => resolve(data.toString())));
  received.push(await next());
  viewer.send(Buffer.from('hello'));
  received.push(await next());
  viewer.close();
  assert.deepEqual(received, ['RFB 003.008\n', 'echo:hello']);
});
