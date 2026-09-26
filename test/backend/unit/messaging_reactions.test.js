'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');
const { ChannelType } = require('discord.js');

const { WhatsAppPlatform } = require('../../../server/services/messaging/whatsapp');
const { TelegramPlatform } = require('../../../server/services/messaging/telegram');
const { DiscordPlatform } = require('../../../server/services/messaging/discord');

const OWN_JID = '49123456789@s.whatsapp.net';
const OPEN_DIRECT = { directPolicy: 'open' };
const CLOSED_DIRECT = { directPolicy: 'allowlist', directRules: [] };

function collect(platform) {
  const reactions = [];
  platform.on('reaction', (reaction) => reactions.push(reaction));
  return reactions;
}

function whatsappReaction(text, targetId = 'agent-msg-1') {
  return {
    key: { remoteJid: OWN_JID, fromMe: true, id: 'reaction-1' },
    messageTimestamp: 1_700_000_005,
    message: { reactionMessage: { text, key: { remoteJid: OWN_JID, id: targetId, fromMe: true } } },
  };
}

test('WhatsApp reports a reaction with the message it targets and skips removals', () => {
  const platform = new WhatsAppPlatform({ selfChatMode: true });
  const reactions = collect(platform);

  platform._emitReaction(whatsappReaction('😂'), { chatId: OWN_JID, sender: OWN_JID, pushName: 'Sam' });
  platform._emitReaction(whatsappReaction(''), { chatId: OWN_JID, sender: OWN_JID, pushName: 'Sam' });

  assert.equal(reactions.length, 1);
  assert.equal(reactions[0].emoji, '😂');
  assert.equal(reactions[0].targetMessageId, 'agent-msg-1');
  assert.equal(reactions[0].chatId, OWN_JID);
});

test('WhatsApp drops reactions from senders outside the direct allowlist without a blocked-sender notice', () => {
  const platform = new WhatsAppPlatform({ accessPolicy: CLOSED_DIRECT });
  const reactions = collect(platform);
  let blocked = 0;
  platform.on('blocked_sender', () => { blocked += 1; });

  platform._emitReaction(whatsappReaction('👍'), {
    chatId: '49987654321@s.whatsapp.net',
    sender: '49987654321@s.whatsapp.net',
    pushName: 'Stranger',
  });

  assert.equal(reactions.length, 0);
  assert.equal(blocked, 0);
});

test('WhatsApp sends a reaction and never reads its own echo back as the user', async () => {
  const platform = new WhatsAppPlatform({ selfChatMode: true });
  const sent = [];
  platform.status = 'connected';
  platform._connectedAt = 1_700_000_000;
  platform.sock = {
    user: { id: '49123456789:21@s.whatsapp.net' },
    async sendMessage(jid, payload) {
      sent.push({ jid, payload });
      return { key: { id: `out-${sent.length}` } };
    },
  };

  const text = await platform.sendMessage(OWN_JID, 'hi');
  await platform.sendReaction(OWN_JID, 'user-msg-1', '❤️');

  assert.equal(text.messageId, 'out-1');
  assert.deepEqual(sent[1].payload.react, {
    text: '❤️',
    key: { remoteJid: OWN_JID, id: 'user-msg-1', fromMe: false },
  });
  const echo = { key: { remoteJid: OWN_JID, fromMe: true, id: 'out-2' }, messageTimestamp: 1_700_000_010 };
  assert.equal(platform._shouldProcessInbound(echo, 'notify'), false);
});

test('Telegram reports private reactions and sends them with setMessageReaction', async () => {
  const platform = new TelegramPlatform({ accessPolicy: OPEN_DIRECT });
  const reactions = collect(platform);
  const calls = [];
  platform.status = 'connected';
  platform._bot = {
    telegram: {
      async setMessageReaction(...args) {
        calls.push(args);
        return true;
      },
    },
  };

  platform._handleReaction({
    update: {
      message_reaction: {
        chat: { id: 42, type: 'private' },
        user: { id: 42, first_name: 'Sam' },
        message_id: 7,
        date: 1_700_000_000,
        new_reaction: [{ type: 'emoji', emoji: '🔥' }],
      },
    },
  });
  platform._handleReaction({
    update: {
      message_reaction: {
        chat: { id: 42, type: 'private' },
        user: { id: 42, first_name: 'Sam' },
        message_id: 7,
        date: 1_700_000_001,
        new_reaction: [],
      },
    },
  });
  await platform.sendReaction('dm_42', '9', '👍');

  assert.equal(reactions.length, 1);
  assert.deepEqual(
    { chatId: reactions[0].chatId, target: reactions[0].targetMessageId, emoji: reactions[0].emoji },
    { chatId: 'dm_42', target: '7', emoji: '🔥' },
  );
  assert.deepEqual(calls, [['42', 9, [{ type: 'emoji', emoji: '👍' }]]]);
});

test('Discord reports direct-message reactions from people and ignores bots', async () => {
  const platform = new DiscordPlatform({ accessPolicy: OPEN_DIRECT });
  const reactions = collect(platform);
  const reaction = {
    partial: false,
    message: { id: 'msg-5', channel: { type: ChannelType.DM } },
    emoji: { toString: () => '😭' },
  };

  await platform._handleReaction(reaction, { id: 'u1', bot: false, username: 'sam' });
  await platform._handleReaction(reaction, { id: 'bot', bot: true, username: 'bot' });

  assert.equal(reactions.length, 1);
  assert.deepEqual(
    { chatId: reactions[0].chatId, target: reactions[0].targetMessageId, emoji: reactions[0].emoji },
    { chatId: 'dm_u1', target: 'msg-5', emoji: '😭' },
  );
});
