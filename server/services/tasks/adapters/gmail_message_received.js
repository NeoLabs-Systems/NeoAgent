'use strict';

const {
  ensureOwnedIntegrationConnection,
  normalizeBoolean,
  normalizeTrimmedText,
} = require('../security');

module.exports = {
  type: 'gmail_message_received',
  label: 'Gmail Message Received',
  providerKey: 'google_workspace',
  appKey: 'gmail',
  async validateConfig(config = {}, context = {}) {
    const connection = ensureOwnedIntegrationConnection(context.integrationManager, {
      userId: context.userId,
      agentId: context.agentId,
      connectionId: config.connectionId || config.connection_id,
      providerKey: 'google_workspace',
      appKey: 'gmail',
    });
    return {
      connectionId: connection.id,
      accountEmail: connection.account_email || null,
      query: normalizeTrimmedText(config.query, 500),
      unreadOnly: normalizeBoolean(config.unreadOnly ?? config.unread_only, false),
    };
  },
  summarize(config = {}) {
    const parts = ['Gmail'];
    if (config.accountEmail) parts.push(config.accountEmail);
    if (config.query) parts.push(`query: ${config.query}`);
    if (config.unreadOnly) parts.push('unread only');
    return parts.join(' · ');
  },
};
