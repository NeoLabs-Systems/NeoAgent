'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { WhatsAppPlatform } = require('../../../server/services/messaging/whatsapp');

test('WhatsApp markRead uses Baileys readMessages with a full message key', async () => {
  const calls = [];
  const platform = new WhatsAppPlatform();
  platform.sock = {
    async readMessages(keys) {
      calls.push(keys);
    },
  };

  await platform.markRead('49123456789@s.whatsapp.net', 'message-id-1');

  assert.deepEqual(calls, [[{
    remoteJid: '49123456789@s.whatsapp.net',
    id: 'message-id-1',
    fromMe: false,
  }]]);
});

test('WhatsApp markRead no-ops when readMessages is unavailable', async () => {
  const platform = new WhatsAppPlatform();
  platform.sock = {
    async sendReadReceipt() {
      throw new Error('legacy API should not be called');
    },
  };

  await platform.markRead('49123456789@s.whatsapp.net', 'message-id-1');
});

test('WhatsApp markRead no-ops without a message id', async () => {
  const platform = new WhatsAppPlatform();
  let called = false;
  platform.sock = {
    async readMessages() {
      called = true;
    },
  };

  await platform.markRead('49123456789@s.whatsapp.net', '');

  assert.equal(called, false);
});
