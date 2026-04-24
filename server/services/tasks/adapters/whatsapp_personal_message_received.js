'use strict';

const {
  ensureOwnedIntegrationConnection,
  normalizeBoolean,
  normalizeTrimmedText,
} = require('../security');

module.exports = {
  type: 'whatsapp_personal_message_received',
  label: 'WhatsApp Personal Message Received',
  providerKey: 'whatsapp_personal',
  appKey: 'personal',
  async validateConfig(config = {}, context = {}) {
    const connection = ensureOwnedIntegrationConnection(context.integrationManager, {
      userId: context.userId,
      agentId: context.agentId,
      connectionId: config.connectionId || config.connection_id,
      providerKey: 'whatsapp_personal',
      appKey: 'personal',
    });
    const chatId = normalizeTrimmedText(config.chatId || config.chat_id, 200);
    if (!chatId) {
      throw new Error('WhatsApp chat ID is required.');
    }
    return {
      connectionId: connection.id,
      accountEmail: connection.account_email || null,
      chatId,
      sender: normalizeTrimmedText(config.sender, 200),
      ignoreGroups: normalizeBoolean(config.ignoreGroups ?? config.ignore_groups, false),
    };
  },
  summarize(config = {}) {
    const parts = ['WhatsApp Personal'];
    if (config.accountEmail) parts.push(config.accountEmail);
    if (config.chatId) parts.push(config.chatId);
    if (config.sender) parts.push(`sender: ${config.sender}`);
    if (config.ignoreGroups) parts.push('ignore groups');
    return parts.join(' · ');
  },
};
