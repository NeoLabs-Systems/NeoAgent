'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const { SENDER_IDENTITY_NOTE } = require('../../../server/services/messaging/sender_identity');
const { buildIncomingPrompt } = require('../../../server/services/messaging/automation');
const { buildVoiceMessagingPrompt } = require('../../../server/services/voice/runtime');

const msg = {
  platform: 'discord',
  isGroup: false,
  chatId: 'dm_1530986428673298462',
  sender: '1530986428673298462',
  senderDisplayName: 'neo',
  content: 'check the server status',
};

test('messaging prompt presents sender_identity as harness data, not sender text', () => {
  const prompt = buildIncomingPrompt(msg);
  assert.match(prompt, /sender_id: 1530986428673298462/);
  assert.ok(prompt.includes(SENDER_IDENTITY_NOTE));
  assert.doesNotMatch(prompt, /user-provided/);
});

test('voice prompt shares the same sender identity block and note', () => {
  const prompt = buildVoiceMessagingPrompt({ ...msg, mediaType: 'audio' });
  assert.match(prompt, /sender_id: 1530986428673298462/);
  assert.ok(prompt.includes(SENDER_IDENTITY_NOTE));
});
