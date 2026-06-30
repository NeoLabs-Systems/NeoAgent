'use strict';

const {
  ensureOwnedIntegrationConnection,
  normalizeBoolean,
  normalizeTrimmedText,
} = require('../security');

module.exports = {
  type: 'neomail_email_received',
  label: 'NeoMail Email Received',
  providerKey: 'neomail',
  appKey: 'mailbox',
  async validateConfig(config = {}, context = {}) {
    const connection = ensureOwnedIntegrationConnection(context.integrationManager, {
      userId: context.userId,
      agentId: context.agentId,
      connectionId: config.connectionId || config.connection_id,
      providerKey: 'neomail',
      appKey: 'mailbox',
    });
    return {
      connectionId: connection.id,
      accountEmail: connection.account_email || null,
      mailAccountId: normalizeTrimmedText(
        config.mailAccountId || config.mail_account_id,
        120,
      ),
      folder: normalizeTrimmedText(config.folder, 200),
      query: normalizeTrimmedText(config.query, 500),
      unreadOnly: normalizeBoolean(
        config.unreadOnly ?? config.unread_only,
        false,
      ),
    };
  },
  summarize(config = {}) {
    const parts = ['NeoMail'];
    if (config.accountEmail) parts.push(config.accountEmail);
    if (config.mailAccountId) parts.push(`mailbox: ${config.mailAccountId}`);
    if (config.folder) parts.push(`folder: ${config.folder}`);
    if (config.query) parts.push(`query: ${config.query}`);
    if (config.unreadOnly) parts.push('unread only');
    return parts.join(' · ');
  },
};
