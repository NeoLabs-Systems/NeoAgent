'use strict';

const { normalizeTrimmedText } = require('../security');
const { connectionConfig, listFrom, requiredText, sortByTimestamp, summaryParts } = require('./shared');

module.exports = {
  type: 'slack_message_received',
  label: 'Slack Message Received',
  providerKey: 'slack',
  appKey: 'slack',
  configHint: '{ connectionId, channel: channel ID, sender?: user ID }',
  async validateConfig(config = {}, context = {}) {
    return {
      ...connectionConfig(config, context, 'slack', 'slack'),
      channel: requiredText(config.channel, 160, 'Slack channel is required.'),
      sender: normalizeTrimmedText(config.sender, 160),
    };
  },
  summarize(config = {}) {
    return summaryParts('Slack', [config.accountEmail, config.channel, config.sender && `sender: ${config.sender}`]);
  },
  poll: {
    intervalMinutes: 1,
    cursor: 'list',
    async fetchRows({ tool, config }) {
      const result = await tool('slack_get_conversation_history', {
        channel: config.channel,
        limit: 20,
      });
      return listFrom(result, ['messages'])
        .filter((item) => !config.sender || String(item.user || '') === String(config.sender))
        .map((item) => ({
          fingerprint: `slack:${config.connectionId}:${config.channel}:${item.ts}`,
          timestamp: item.ts || new Date().toISOString(),
          context: {
            triggerEvent: {
              provider: 'slack',
              channel: config.channel,
              sender: item.user || null,
              messageId: item.client_msg_id || item.ts,
              content: item.text || '',
            },
          },
        }))
        .sort(sortByTimestamp);
    },
  },
};
