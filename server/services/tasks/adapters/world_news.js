'use strict';

const {
  ensureOwnedIntegrationConnection,
  normalizeTrimmedText,
} = require('../security');
const { NEWS_CATEGORIES } = require('../../integrations/news/provider');

module.exports = {
  type: 'world_news',
  label: 'World News',
  providerKey: 'news',
  appKey: 'headlines',
  async validateConfig(config = {}, context = {}) {
    const connection = ensureOwnedIntegrationConnection(context.integrationManager, {
      userId: context.userId,
      agentId: context.agentId,
      connectionId: config.connectionId || config.connection_id,
      providerKey: 'news',
      appKey: 'headlines',
    });

    const category = normalizeTrimmedText(config.category, 30).toLowerCase() || 'world';
    if (!NEWS_CATEGORIES.includes(category)) {
      throw new Error(`News category must be one of: ${NEWS_CATEGORIES.join(', ')}.`);
    }

    return {
      connectionId: connection.id,
      accountEmail: connection.account_email || null,
      category,
      query: normalizeTrimmedText(config.query || config.topics, 180),
      lang: normalizeTrimmedText(config.lang, 2).toLowerCase() || 'en',
      country: normalizeTrimmedText(config.country, 2).toLowerCase(),
      checkIntervalMinutes: Math.max(
        15,
        Math.min(Number(config.checkIntervalMinutes || config.check_interval_minutes) || 30, 720),
      ),
    };
  },
  summarize(config = {}) {
    const parts = ['World news'];
    if (config.category && config.category !== 'world') parts.push(config.category);
    if (config.query) parts.push(config.query);
    return parts.join(' · ');
  },
};
