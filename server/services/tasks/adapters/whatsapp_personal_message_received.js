'use strict';

const { normalizeBoolean, normalizeTrimmedText } = require('../security');
const { connectionConfig, requiredText, sortByTimestamp, summaryParts } = require('./shared');

function isGroupChat(chatId) {
  return String(chatId || '').endsWith('@g.us');
}

function messageEvent({ chatId, messageId, sender, senderTag, content, isGroup }) {
  return {
    provider: 'whatsapp_personal',
    chatId,
    messageId,
    sender: sender || null,
    senderTag: senderTag || null,
    content: content || '',
    isGroup,
  };
}

// The linked account pushes new messages as they arrive; the poll catches
// whatever arrived while the push listener was away.
module.exports = {
  type: 'whatsapp_personal_message_received',
  label: 'WhatsApp Personal Message Received',
  providerKey: 'whatsapp_personal',
  appKey: 'personal',
  configHint: '{ connectionId, chatId, sender?, ignoreGroups?: boolean }',
  async validateConfig(config = {}, context = {}) {
    return {
      ...connectionConfig(config, context, 'whatsapp_personal', 'personal'),
      chatId: requiredText(config.chatId || config.chat_id, 200, 'WhatsApp chat ID is required.'),
      sender: normalizeTrimmedText(config.sender, 200),
      ignoreGroups: normalizeBoolean(config.ignoreGroups ?? config.ignore_groups, false),
    };
  },
  summarize(config = {}) {
    return summaryParts('WhatsApp Personal', [
      config.accountEmail,
      config.chatId,
      config.sender && `sender: ${config.sender}`,
      config.ignoreGroups && 'ignore groups',
    ]);
  },
  poll: {
    intervalMinutes: 1,
    cursor: 'list',
    async fetchRows({ tool, config }) {
      const result = await tool('whatsapp_personal_get_messages', {
        chat_id: config.chatId,
        limit: 25,
      });
      const messages = Array.isArray(result?.messages) ? result.messages : [];
      return messages
        .filter((item) => item && item.fromMe !== true)
        .filter((item) => !config.sender || String(item.senderTag || item.sender || '') === String(config.sender))
        .filter((item) => !(config.ignoreGroups && isGroupChat(item.chatId)))
        .map((item) => ({
          fingerprint: `whatsapp:${config.connectionId}:${item.id}`,
          timestamp: item.timestamp || new Date().toISOString(),
          context: {
            triggerEvent: messageEvent({
              chatId: item.chatId,
              messageId: item.id,
              sender: item.sender,
              senderTag: item.senderTag,
              content: item.text,
              isGroup: isGroupChat(item.chatId),
            }),
          },
        }))
        .sort(sortByTimestamp);
    },
  },
  event: {
    source: 'whatsapp_personal',
    name: 'message',
    matches(config, event) {
      if (String(config.connectionId || '') !== String(event.connectionId || '')) return false;
      if (config.chatId && String(config.chatId) !== String(event.chatId)) return false;
      if (config.sender && String(config.sender) !== String(event.senderTag || event.sender || '')) return false;
      if (config.ignoreGroups && event.isGroup) return false;
      return true;
    },
    toPayload(event) {
      return {
        fingerprint: `whatsapp:${event.connectionId}:${event.messageId}`,
        timestamp: event.timestamp,
        context: {
          triggerEvent: messageEvent({
            chatId: event.chatId,
            messageId: event.messageId,
            sender: event.sender,
            senderTag: event.senderTag,
            content: event.text,
            isGroup: event.isGroup === true,
          }),
        },
      };
    },
  },
};
