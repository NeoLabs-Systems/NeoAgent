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
  configHint: '{ connectionId, query?: keywords, category?: world|nation|business|technology|science|health|sports|entertainment|general, lang?: "en", country?: "de", checkIntervalMinutes?: 15-720 }; each run receives the new headlines and should decide from the prompt whether they are worth notifying about',
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
  poll: {
    // News APIs have small daily quotas, so each task polls on its own interval.
    intervalMinutes: (config) => Number(config.checkIntervalMinutes) || 30,
    cursor: 'list',
    async fetchRows({ tool, config, checkpoint }) {
      const feed = await tool('news_get_headlines', {
        query: config.query || undefined,
        category: config.category,
        lang: config.lang,
        country: config.country || undefined,
        max: 10,
      });
      const articles = (Array.isArray(feed?.articles) ? feed.articles : [])
        .filter((article) => article.id && article.publishedAt)
        .map((article) => ({
          ...article,
          fingerprint: `news:${config.connectionId}:${article.publishedAt}:${article.id}`,
        }))
        .sort((left, right) => left.fingerprint.localeCompare(right.fingerprint));
      // Fingerprints start with the publish time, so anything ordered after the
      // checkpoint is new even when the checkpointed article left the feed.
      const fresh = articles.filter((article) => !checkpoint || article.fingerprint > checkpoint);
      if (!fresh.length) return [];

      const latest = fresh[fresh.length - 1];
      return [{
        fingerprint: latest.fingerprint,
        timestamp: latest.publishedAt,
        context: {
          triggerEvent: {
            provider: 'news',
            eventType: 'headlines',
            count: fresh.length,
            articles: fresh.map(({ fingerprint, id, ...article }) => article),
          },
        },
      }];
    },
  },
};
