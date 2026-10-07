'use strict';

const { normalizeTrimmedText } = require('../security');
const { summaryParts } = require('./shared');

const REACTION_PLATFORMS = Object.freeze(['discord', 'telegram', 'whatsapp']);

module.exports = {
  type: 'messaging_reaction_added',
  label: 'Reaction Added',
  configHint: `{ platform?: ${REACTION_PLATFORMS.join('|')}, emoji?, chatId? }; private chats with allowed people only`,
  async validateConfig(config = {}) {
    const platform = normalizeTrimmedText(config.platform, 40).toLowerCase();
    if (platform && !REACTION_PLATFORMS.includes(platform)) {
      throw new Error(`Platform must be one of: ${REACTION_PLATFORMS.join(', ')}.`);
    }
    return {
      platform,
      emoji: normalizeTrimmedText(config.emoji, 20),
      chatId: normalizeTrimmedText(config.chatId || config.chat_id, 200),
    };
  },
  summarize(config = {}) {
    return summaryParts('Reaction', [config.emoji, config.platform, config.chatId && `chat: ${config.chatId}`]);
  },
  event: {
    source: 'messaging',
    name: 'reaction_added',
    matches(config, event) {
      return (!config.platform || config.platform === event.platform)
        && (!config.emoji || config.emoji === event.emoji)
        && (!config.chatId || config.chatId === event.chatId);
    },
    toPayload(event) {
      return {
        fingerprint: `reaction:${event.platform}:${event.chatId}:${event.targetMessageId}:${event.sender}:${event.emoji}`,
        timestamp: event.timestamp,
        context: {
          triggerEvent: {
            provider: event.platform,
            event: 'reaction_added',
            chatId: event.chatId,
            sender: event.sender,
            senderName: event.senderName,
            targetMessageId: event.targetMessageId,
            emoji: event.emoji,
          },
        },
      };
    },
  },
};
