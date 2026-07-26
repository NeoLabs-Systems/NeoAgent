'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { WhatsAppPlatform } = require('../../../server/services/messaging/whatsapp');

test('WhatsApp unmentioned group messages reach access policy and allowed groups', () => {
  const groupId = '120363123456789012@g.us';
  const groupMessage = {
    key: {
      fromMe: false,
      remoteJid: groupId,
      participant: '49123456789@s.whatsapp.net',
      id: 'message-1',
    },
    pushName: 'Neo',
    message: { conversation: 'hello group' },
  };
  const context = {
    chatId: groupId,
    isGroup: true,
    sender: groupMessage.key.participant,
    pushName: groupMessage.pushName,
  };

  const blockedPlatform = new WhatsAppPlatform();
  const blockedEvents = [];
  blockedPlatform.on('blocked_sender', (event) => blockedEvents.push(event));
  const blockedDecision = blockedPlatform._checkMessageAccess(groupMessage, context);

  assert.equal(blockedDecision.allowed, false);
  assert.equal(blockedEvents.length, 1);
  assert.deepEqual(blockedEvents[0].suggestions.map((item) => item.rule), [
    {
      scope: 'phone_number',
      value: '49123456789',
      spaceScope: 'group',
      spaceValue: groupId,
      spaceLabel: groupId,
    },
    { scope: 'phone_number', value: '49123456789' },
    { scope: 'group', value: groupId },
  ]);

  const allowedPlatform = new WhatsAppPlatform({
    accessPolicy: {
      sharedPolicy: 'allowlist',
      sharedSpaceRules: [{ scope: 'group', value: groupId }],
    },
  });
  const allowedDecision = allowedPlatform._checkMessageAccess(groupMessage, context);

  assert.equal(allowedDecision.allowed, true);
});
