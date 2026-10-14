'use strict';

const { normalizeBoolean, normalizeTrimmedText } = require('../security');
const { connectionConfig, listFrom, sortByTimestamp, summaryParts } = require('./shared');

module.exports = {
  type: 'outlook_email_received',
  label: 'Outlook Email Received',
  providerKey: 'microsoft_365',
  appKey: 'outlook',
  configHint: '{ connectionId, folderId?, query?: search text, unreadOnly?: boolean }',
  async validateConfig(config = {}, context = {}) {
    return {
      ...connectionConfig(config, context, 'microsoft_365', 'outlook'),
      folderId: normalizeTrimmedText(config.folderId || config.folder_id, 160),
      query: normalizeTrimmedText(config.query, 500),
      unreadOnly: normalizeBoolean(config.unreadOnly ?? config.unread_only, false),
    };
  },
  summarize(config = {}) {
    return summaryParts('Outlook', [
      config.accountEmail,
      config.folderId && `folder: ${config.folderId}`,
      config.query && `query: ${config.query}`,
      config.unreadOnly && 'unread only',
    ]);
  },
  poll: {
    intervalMinutes: 1,
    cursor: 'list',
    async fetchRows({ tool, config }) {
      const result = await tool('microsoft_365_outlook_list_messages', {
        folder_id: config.folderId || undefined,
        query: config.query || undefined,
        top: 20,
      });
      return listFrom(result, ['value'])
        .filter((item) => !config.unreadOnly || item.isRead === false)
        .map((item) => ({
          fingerprint: `outlook:${config.connectionId}:${item.id}`,
          timestamp: item.receivedDateTime || new Date().toISOString(),
          context: {
            triggerEvent: {
              provider: 'outlook',
              messageId: item.id,
              subject: item.subject || '',
              from: item.from?.emailAddress?.address || null,
            },
          },
        }))
        .sort(sortByTimestamp);
    },
  },
};
