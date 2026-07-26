'use strict';

const assert = require('node:assert/strict');
const { EventEmitter } = require('node:events');
const { test } = require('node:test');

const {
  DesktopCompanionConnection,
} = require('../../../server/services/desktop/registry');
const { DesktopProvider } = require('../../../server/services/desktop/provider');

class FakeWebSocket extends EventEmitter {
  constructor() {
    super();
    this.readyState = 1;
    this.messages = [];
  }

  send(raw) {
    this.messages.push(JSON.parse(raw));
  }

  close() {
    this.readyState = 3;
    this.emit('close');
  }

  ping() {}
}

function createConnection() {
  const ws = new FakeWebSocket();
  const registry = {
    touchPresence() {},
    unregisterConnection() {},
  };
  return {
    ws,
    connection: new DesktopCompanionConnection({
      registry,
      ws,
      userId: 1,
      sessionId: 'session',
      deviceId: 'device',
      recordId: 'record',
      meta: {},
      timeoutMs: 5000,
      heartbeatIntervalMs: 0,
      heartbeatTimeoutMs: 0,
      presenceTouchIntervalMs: 0,
    }),
  };
}

test('aborting a desktop command tells the companion to cancel the real work', async () => {
  const { connection, ws } = createConnection();
  const controller = new AbortController();
  const pending = connection.sendCommand(
    'executeCommand',
    { command: 'long-running' },
    { signal: controller.signal },
  );
  const reason = new Error('caller cancelled desktop work');
  controller.abort(reason);

  await assert.rejects(pending, (error) => error === reason);
  assert.equal(connection.pending.size, 0);
  assert.equal(ws.messages.length, 2);
  assert.equal(ws.messages[1].command, 'cancelCommand');
  assert.equal(ws.messages[1].payload.commandId, ws.messages[0].id);
});

test('desktop command results preserve false payloads', async () => {
  const { connection, ws } = createConnection();
  const pending = connection.sendCommand('getStatus');
  const command = ws.messages[0];
  ws.emit('message', JSON.stringify({
    type: 'result',
    id: command.id,
    ok: true,
    payload: false,
  }));

  assert.equal(await pending, false);
});

test('a completed desktop command removes its abort listener', async () => {
  const { connection, ws } = createConnection();
  const controller = new AbortController();
  const pending = connection.sendCommand('observe', {}, { signal: controller.signal });
  const command = ws.messages[0];
  ws.emit('message', JSON.stringify({
    type: 'result',
    id: command.id,
    ok: true,
    payload: { success: true },
  }));

  assert.deepEqual(await pending, { success: true });
  controller.abort();
  assert.equal(ws.messages.length, 1);
  assert.equal(connection.pending.size, 0);
});

test('desktop provider derives screenshot type from bytes instead of companion metadata', async () => {
  const png = Buffer.from(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    'base64',
  );
  let artifactOptions = null;
  const provider = new DesktopProvider({
    userId: 'user-1',
    registry: {
      async dispatch() {
        return {
          success: true,
          contentType: 'image/jpeg',
          screenshotBase64: png.toString('base64'),
        };
      },
    },
    artifactStore: {
      async createBufferArtifact(_userId, options) {
        artifactOptions = options;
        return {
          artifactId: 'artifact-1',
          storagePath: '/tmp/desktop.png',
          url: '/api/artifacts/artifact-1/content',
        };
      },
    },
  });

  const result = await provider.screenshot();

  assert.equal(result.screenshotBase64, undefined);
  assert.equal(artifactOptions.contentType, 'image/png');
  assert.equal(artifactOptions.extension, 'png');
  assert.deepEqual(artifactOptions.content, png);
});
