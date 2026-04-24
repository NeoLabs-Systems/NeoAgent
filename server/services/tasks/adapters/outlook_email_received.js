'use strict';

const {
  ensureOwnedIntegrationConnection,
  normalizeBoolean,
  normalizeTrimmedText,
} = require('../security');

module.exports = {
  type: 'outlook_email_received',
  label: 'Outlook Email Received',
  providerKey: 'microsoft_365',
  appKey: 'outlook',
  async validateConfig(config = {}, context = {}) {
    const connection = ensureOwnedIntegrationConnection(context.integrationManager, {
      userId: context.userId,
      agentId: context.agentId,
      connectionId: config.connectionId || config.connection_id,
      providerKey: 'microsoft_365',
      appKey: 'outlook',
    });
    return {
      connectionId: connection.id,
      accountEmail: connection.account_email || null,
      folderId: normalizeTrimmedText(config.folderId || config.folder_id, 160),
      query: normalizeTrimmedText(config.query, 500),
      unreadOnly: normalizeBoolean(config.unreadOnly ?? config.unread_only, false),
    };
  },
  summarize(config = {}) {
    const parts = ['Outlook'];
    if (config.accountEmail) parts.push(config.accountEmail);
    if (config.folderId) parts.push(`folder: ${config.folderId}`);
    if (config.query) parts.push(`query: ${config.query}`);
    if (config.unreadOnly) parts.push('unread only');
    return parts.join(' · ');
  },
};
