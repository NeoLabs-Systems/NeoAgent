'use strict';

const {
  ensureOwnedIntegrationConnection,
  normalizeTrimmedText,
} = require('../security');

module.exports = {
  type: 'neorecall_memory_created',
  label: 'NeoRecall Memory Created',
  providerKey: 'neorecall',
  appKey: 'recall',
  async validateConfig(config = {}, context = {}) {
    const connection = ensureOwnedIntegrationConnection(context.integrationManager, {
      userId: context.userId,
      agentId: context.agentId,
      connectionId: config.connectionId || config.connection_id,
      providerKey: 'neorecall',
      appKey: 'recall',
    });
    return {
      connectionId: connection.id,
      accountEmail: connection.account_email || null,
      type: normalizeTrimmedText(config.type || config.memoryType, 100),
      topic: normalizeTrimmedText(config.topic, 100),
      query: normalizeTrimmedText(config.query, 200),
    };
  },
  summarize(config = {}) {
    const parts = ['NeoRecall memories'];
    if (config.type) parts.push(`type: ${config.type}`);
    if (config.topic) parts.push(`topic: ${config.topic}`);
    if (config.query) parts.push(`contains: ${config.query}`);
    return parts.join(' · ');
  },
};
