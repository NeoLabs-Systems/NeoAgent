'use strict';

const assert = require('node:assert/strict');
const EventEmitter = require('node:events');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');

// Baileys stand-in: one fake socket per connect, driven by the test.
const sockets = [];
const baileysPath = require.resolve('baileys');
require.cache[baileysPath] = {
  id: baileysPath,
  filename: baileysPath,
  loaded: true,
  exports: {
    default: () => {
      const sock = { ev: new EventEmitter(), ended: false, end() { this.ended = true; } };
      sockets.push(sock);
      return sock;
    },
    useMultiFileAuthState: async () => ({ state: { creds: {}, keys: {} }, saveCreds: () => {} }),
    DisconnectReason: { loggedOut: 401, connectionClosed: 428 },
    makeCacheableSignalKeyStore: (keys) => keys,
    fetchLatestBaileysVersion: async () => ({ version: [2, 3000, 1], isLatest: true }),
    Browsers: { appropriate: () => ['NeoAgent', 'Chrome', '1'] },
  },
};

const { WhatsAppPlatform } = require('../../../server/services/messaging/whatsapp');

test('a revoked WhatsApp session is dropped completely so the next connect pairs from scratch', async () => {
  const authDir = fs.mkdtempSync(path.join(os.tmpdir(), 'wa-auth-'));
  fs.writeFileSync(path.join(authDir, 'creds.json'), '{"registered":true}');
  const platform = new WhatsAppPlatform({ authDir });
  const events = [];
  platform.on('logged_out', () => events.push('logged_out'));
  platform.on('disconnected', (info) => events.push(`disconnected:${info.shouldReconnect}`));

  await platform.connect();
  const revoked = sockets.at(-1);
  revoked.ev.emit('connection.update', {
    connection: 'close',
    lastDisconnect: { error: { output: { statusCode: 401 } } },
  });

  assert.deepEqual(events, ['disconnected:false', 'logged_out']);
  assert.equal(fs.existsSync(authDir), false);
  assert.equal(platform.sock, null);
  assert.equal(revoked.ended, true);
  // Nothing the dead socket still emits reaches the adapter.
  assert.equal(revoked.ev.listenerCount('creds.update'), 0);
  assert.equal(revoked.ev.listenerCount('connection.update'), 0);

  await platform.connect();
  sockets.at(-1).ev.emit('connection.update', { qr: 'fresh-pairing-code' });
  assert.equal(platform.getAuthInfo().qrCode, 'fresh-pairing-code');
  assert.equal(platform.getAuthInfo().status, 'awaiting_qr');
  await platform.disconnect();
  fs.rmSync(authDir, { recursive: true, force: true });
});
