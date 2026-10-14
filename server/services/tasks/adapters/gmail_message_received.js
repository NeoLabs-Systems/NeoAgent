'use strict';

const { normalizeBoolean, normalizeTrimmedText } = require('../security');
const { connectionConfig, summaryParts } = require('./shared');

module.exports = {
  type: 'gmail_message_received',
  label: 'Gmail Message Received',
  providerKey: 'google_workspace',
  appKey: 'gmail',
  configHint: '{ connectionId, query?: Gmail search, unreadOnly?: boolean }',
  async validateConfig(config = {}, context = {}) {
    return {
      ...connectionConfig(config, context, 'google_workspace', 'gmail'),
      query: normalizeTrimmedText(config.query, 500),
      unreadOnly: normalizeBoolean(config.unreadOnly ?? config.unread_only, false),
    };
  },
  summarize(config = {}) {
    return summaryParts('Gmail', [
      config.accountEmail,
      config.query && `query: ${config.query}`,
      config.unreadOnly && 'unread only',
    ]);
  },
  poll: {
    intervalMinutes: 1,
    cursor: 'list',
    async fetchRows({ tool, config }) {
      const queryParts = [];
      if (config.query) queryParts.push(config.query);
      if (config.unreadOnly) queryParts.push('is:unread');
      const result = await tool('google_workspace_gmail_api_request', {
        method: 'GET',
        path: '/gmail/v1/users/me/messages',
        query: {
          maxResults: 20,
          q: queryParts.join(' ').trim() || undefined,
        },
      });
      // The raw API request returns the HTTP response: { status, data }.
      const messages = Array.isArray(result?.data?.messages) ? result.data.messages : [];
      return messages
        .map((item) => ({
          fingerprint: `gmail:${config.connectionId}:${item.id}`,
          timestamp: new Date().toISOString(),
          context: { triggerEvent: { provider: 'gmail', messageId: item.id, threadId: item.threadId || null } },
        }))
        .sort((left, right) => left.fingerprint.localeCompare(right.fingerprint));
    },
  },
};
