'use strict';

const { normalizeTrimmedText } = require('../security');
const { connectionConfig, listFrom, sortByTimestamp, summaryParts } = require('./shared');

module.exports = {
  type: 'neorecall_memory_created',
  label: 'NeoRecall Memory Created',
  providerKey: 'neorecall',
  appKey: 'recall',
  configHint: '{ connectionId, type?, topic?, query?: text the memory contains }',
  async validateConfig(config = {}, context = {}) {
    return {
      ...connectionConfig(config, context, 'neorecall', 'recall'),
      type: normalizeTrimmedText(config.type || config.memoryType, 100),
      topic: normalizeTrimmedText(config.topic, 100),
      query: normalizeTrimmedText(config.query, 200),
    };
  },
  summarize(config = {}) {
    return summaryParts('NeoRecall memories', [
      config.type && `type: ${config.type}`,
      config.topic && `topic: ${config.topic}`,
      config.query && `contains: ${config.query}`,
    ]);
  },
  poll: {
    intervalMinutes: 1,
    cursor: 'list',
    async fetchRows({ tool, config }) {
      const result = await tool('neorecall_list_memories', {
        type: config.type || undefined,
        topic: config.topic || undefined,
        limit: 30,
      });
      const query = String(config.query || '').toLowerCase();
      const createdAt = (item) => item.created_at || item.createdAt || item.timestamp || '';
      return listFrom(result, ['memories', 'items'])
        .filter((item) => item && item.id)
        .filter((item) => !query || JSON.stringify(item).toLowerCase().includes(query))
        .map((item) => ({
          fingerprint: `neorecall_memory:${config.connectionId}:${item.id}`,
          timestamp: createdAt(item) || new Date().toISOString(),
          context: {
            triggerEvent: {
              provider: 'neorecall',
              memoryId: item.id,
              type: item.type || null,
              title: item.title || '',
              content: item.summary || item.body || item.content || '',
              topics: Array.isArray(item.topics) ? item.topics : [],
            },
          },
        }))
        .sort(sortByTimestamp);
    },
  },
};
