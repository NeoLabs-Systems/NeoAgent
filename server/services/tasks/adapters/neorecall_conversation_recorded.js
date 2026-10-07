'use strict';

const { MINUTE_MS, connectionConfig, listFrom, summaryParts, timeCursor } = require('./shared');

const LOOKBACK_MINUTES = 24 * 60;

// A conversation counts once NeoRecall has closed it.
module.exports = {
  type: 'neorecall_conversation_recorded',
  label: 'NeoRecall Conversation Recorded',
  providerKey: 'neorecall',
  appKey: 'recall',
  configHint: '{ connectionId }',
  async validateConfig(config = {}, context = {}) {
    return connectionConfig(config, context, 'neorecall', 'recall');
  },
  summarize() {
    return summaryParts('NeoRecall conversations', []);
  },
  poll: {
    intervalMinutes: 10,
    cursor: 'ordered',
    baseline: 'now',
    async fetchRows({ tool, now }) {
      const result = await tool('neorecall_list_conversations', {
        from: new Date(now - LOOKBACK_MINUTES * MINUTE_MS).toISOString(),
        limit: 20,
      });
      return listFrom(result, ['items'])
        .filter((conversation) => conversation && conversation.state !== 'open')
        .map((conversation) => ({
          fingerprint: timeCursor(conversation.ended_at, conversation.id),
          timestamp: conversation.ended_at,
          context: {
            triggerEvent: {
              provider: 'neorecall',
              event: 'conversation_recorded',
              conversationId: conversation.id,
              startedAt: conversation.started_at,
              endedAt: conversation.ended_at,
              title: conversation.title || null,
              summary: conversation.summary || null,
              topics: Array.isArray(conversation.topics) ? conversation.topics : [],
              memoryWorthy: conversation.memory_worthy ?? null,
            },
          },
        }))
        .filter((row) => row.fingerprint)
        .sort((left, right) => left.fingerprint.localeCompare(right.fingerprint));
    },
  },
};
