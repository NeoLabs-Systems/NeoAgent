'use strict';

const assert = require('node:assert/strict');
const http = require('node:http');
const { once } = require('node:events');
const { test } = require('node:test');
const WebSocket = require('ws');
const { bindWearableGateway } = require('../../../server/services/wearable/gateway');

async function sessionFor(platform) {
  const server = http.createServer();
  const app = { locals: {
    wearableService: {
      registerConnection: ({ hello }) => ({ deviceId: 'device', hello: { platform: hello.device.platform } }),
      touchConnection() {},
      unregisterConnection() {},
    },
    voiceRuntimeManager: {
      async openWearableSession({ sink }) {
        sink.send('audio', { audioBase64: 'YQ==' });
        sink.send('transcript', { role: 'assistant', content: 'Ready', final: true });
        return { id: 'session' };
      },
      async closeSession() {},
    },
  } };
  bindWearableGateway(server, app, (req, _res, next) => { req.session = { userId: 1 }; next(); });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const socket = new WebSocket(`ws://127.0.0.1:${server.address().port}/api/wearable/ws`);
  await once(socket, 'open');
  const messages = [];
  socket.on('message', (data) => {
    const message = JSON.parse(data);
    messages.push(message);
    if (message.type === 'wearable:hello') socket.send(JSON.stringify({ type: 'voice:session_open' }));
  });
  socket.send(JSON.stringify({ type: 'wearable:hello', device: { platform } }));
  const deadline = Date.now() + 2000;
  while (!messages.some((message) => message.type === 'voice:transcript')) {
    if (Date.now() > deadline) throw new Error('wearable transcript timed out');
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
  socket.close();
  await once(socket, 'close');
  await app.locals.wearableGateway.close();
  await new Promise((resolve) => server.close(resolve));
  return messages;
}

test('StickC receives transcripts but no speech audio, while the existing wearable keeps audio', async () => {
  const stick = await sessionFor('m5stickc-plus2');
  const amoled = await sessionFor('esp32-s3-amoled');
  assert.equal(stick.some((message) => message.type === 'voice:audio'), false);
  assert.equal(stick.find((message) => message.type === 'voice:transcript').content, 'Ready');
  assert.equal(amoled.some((message) => message.type === 'voice:audio'), true);
});
