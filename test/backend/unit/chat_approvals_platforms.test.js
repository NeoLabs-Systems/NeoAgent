'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');
const { ChannelType } = require('discord.js');

const { DiscordPlatform } = require('../../../server/services/messaging/discord');
const { TelegramPlatform } = require('../../../server/services/messaging/telegram');

const OPTIONS = [
  { id: 'allow', label: 'Allow', emoji: '✅' },
  { id: 'always', label: 'Allow always', emoji: '🔁' },
  { id: 'deny', label: 'Disallow', emoji: '❌' },
];

function discord() {
  const platform = new DiscordPlatform({ token: 'x', userId: 1 });
  platform.status = 'connected';
  platform._client = {};
  const reacted = [];
  const deleted = [];
  const channel = {
    id: 'channel-1',
    type: ChannelType.GuildText,
    send: async (payload) => ({ id: 'prompt-1', payload, react: async (emoji) => reacted.push(emoji) }),
    messages: { delete: async (id) => deleted.push(id) },
  };
  platform._textChannel = async () => channel;
  return { platform, channel, reacted, deleted };
}

function reaction(platform, channel, emoji) {
  return {
    partial: false,
    emoji: { name: emoji, toString: () => emoji },
    message: {
      id: 'prompt-1',
      channel,
      guild: {
        id: 'guild-1',
        members: { fetch: async () => ({ roles: { cache: new Map([['role-1', {}]]) } }) },
      },
    },
  };
}

test('Discord adds a reaction per option without pinging anyone, and removes the prompt', async () => {
  const { platform, reacted, deleted } = discord();
  const { promptId } = await platform.sendApprovalPrompt('channel-1', { text: 'Allow @everyone?', options: OPTIONS });
  assert.equal(promptId, 'prompt-1');
  assert.deepEqual(reacted, ['✅', '🔁', '❌']);
  await platform.deleteApprovalPrompt('channel-1', promptId);
  assert.deepEqual(deleted, ['prompt-1']);
  assert.equal(platform._approvalPrompts.size, 0);
});

test('a Discord reaction on a prompt is an answer, not feedback', async () => {
  const { platform, channel } = discord();
  await platform.sendApprovalPrompt('channel-1', { text: 'x', options: OPTIONS });
  const answers = [];
  const feedback = [];
  platform.on('approval_response', (item) => answers.push(item));
  platform.on('reaction', (item) => feedback.push(item));

  await platform._handleReaction(reaction(platform, channel, '🔁'), { id: 'user-1', username: 'u' });
  assert.equal(answers[0].choiceId, 'always');
  assert.equal(answers[0].chatId, 'channel-1');
  assert.equal(answers[0].actor.sender, 'user-1');
  assert.equal(answers[0].actor.isGroup, true);
  assert.deepEqual(answers[0].actor.roleIds, ['role-1']);

  await platform._handleReaction(reaction(platform, channel, '🎉'), { id: 'user-1', username: 'u' });
  await platform._handleReaction(reaction(platform, channel, '✅'), { id: 'bot', bot: true });
  assert.equal(answers.length, 1);
  assert.deepEqual(feedback, []);
});

test('a Discord DM prompt answers under the chat id replies use', async () => {
  const { platform, channel } = discord();
  await platform.sendApprovalPrompt('dm_user-1', { text: 'x', options: OPTIONS });
  const answers = [];
  platform.on('approval_response', (item) => answers.push(item));
  const dm = { ...channel, type: ChannelType.DM };
  const event = reaction(platform, dm, '❌');
  event.message.guild = null;
  await platform._handleReaction(event, { id: 'user-1', username: 'u' });
  assert.equal(answers[0].chatId, 'dm_user-1');
  assert.equal(answers[0].actor.isGroup, false);
});

function telegram() {
  const platform = new TelegramPlatform({ token: 'x', userId: 1 });
  platform.status = 'connected';
  const calls = [];
  platform._bot = {
    telegram: {
      sendMessage: async (chatId, text, extra) => {
        calls.push({ chatId, text, extra });
        return { message_id: 42 };
      },
      deleteMessage: async (chatId, id) => calls.push({ deleted: [chatId, id] }),
    },
  };
  return { platform, calls };
}

function button(data, chat, from = { id: 7, first_name: 'Neo' }) {
  const answered = [];
  return {
    answered,
    ctx: {
      answerCbQuery: async () => answered.push(true),
      update: { callback_query: { data, from, message: { message_id: 42, chat } } },
    },
  };
}

test('Telegram sends buttons and deletes the prompt from the right chat', async () => {
  const { platform, calls } = telegram();
  const { promptId } = await platform.sendApprovalPrompt('dm_7', { text: 'Allow x?', options: OPTIONS });
  assert.equal(promptId, '42');
  assert.equal(calls[0].chatId, '7');
  assert.deepEqual(
    calls[0].extra.reply_markup.inline_keyboard[0].map((item) => item.callback_data),
    ['approval:allow', 'approval:always', 'approval:deny'],
  );
  await platform.deleteApprovalPrompt('dm_7', promptId);
  assert.deepEqual(calls[1].deleted, ['7', 42]);
});

test('a Telegram button press is an answer from whoever pressed it', async () => {
  const { platform } = telegram();
  const answers = [];
  platform.on('approval_response', (item) => answers.push(item));

  const direct = button('approval:deny', { id: 7, type: 'private' });
  await platform._handleApprovalButton(direct.ctx);
  assert.equal(direct.answered.length, 1);
  assert.equal(answers[0].chatId, 'dm_7');
  assert.equal(answers[0].choiceId, 'deny');
  assert.equal(answers[0].promptId, '42');

  const group = button('approval:allow', { id: -100, type: 'supergroup' }, { id: 9, first_name: 'G' });
  await platform._handleApprovalButton(group.ctx);
  assert.equal(answers[1].chatId, '-100');
  assert.equal(answers[1].actor.sender, '9');
  assert.equal(answers[1].actor.isGroup, true);

  const other = button('something-else', { id: 7, type: 'private' });
  await platform._handleApprovalButton(other.ctx);
  assert.equal(other.answered.length, 1, 'the spinner still clears');
  assert.equal(answers.length, 2);
});
