'use strict';

const { normalizeTrimmedText } = require('../security');
const { connectionConfig, listFrom, requiredText, sortByTimestamp, summaryParts } = require('./shared');

module.exports = {
  type: 'teams_message_received',
  label: 'Teams Message Received',
  providerKey: 'microsoft_365',
  appKey: 'teams',
  configHint: '{ connectionId, chatId, sender?: user ID }',
  async validateConfig(config = {}, context = {}) {
    return {
      ...connectionConfig(config, context, 'microsoft_365', 'teams'),
      chatId: requiredText(config.chatId || config.chat_id, 200, 'Teams chat ID is required.'),
      sender: normalizeTrimmedText(config.sender, 200),
    };
  },
  summarize(config = {}) {
    return summaryParts('Teams', [
      config.accountEmail,
      config.chatId && `chat: ${config.chatId}`,
      config.sender && `sender: ${config.sender}`,
    ]);
  },
  poll: {
    intervalMinutes: 1,
    cursor: 'list',
    async fetchRows({ tool, config }) {
      const result = await tool('microsoft_365_teams_list_chat_messages', {
        chat_id: config.chatId,
        top: 20,
      });
      return listFrom(result, ['value'])
        .filter((item) => {
          const sender = item.from?.user?.id || item.from?.application?.id || '';
          return !config.sender || String(sender) === String(config.sender);
        })
        .map((item) => ({
          fingerprint: `teams:${config.connectionId}:${config.chatId}:${item.id}`,
          timestamp: item.createdDateTime || new Date().toISOString(),
          context: {
            triggerEvent: {
              provider: 'teams',
              chatId: config.chatId,
              messageId: item.id,
              sender: item.from?.user?.id || null,
              content: item.body?.content || '',
            },
          },
        }))
        .sort(sortByTimestamp);
    },
  },
};
