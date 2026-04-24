'use strict';

const {
  ensureOwnedIntegrationConnection,
  normalizeTrimmedText,
} = require('../security');

module.exports = {
  type: 'teams_message_received',
  label: 'Teams Message Received',
  providerKey: 'microsoft_365',
  appKey: 'teams',
  async validateConfig(config = {}, context = {}) {
    const connection = ensureOwnedIntegrationConnection(context.integrationManager, {
      userId: context.userId,
      agentId: context.agentId,
      connectionId: config.connectionId || config.connection_id,
      providerKey: 'microsoft_365',
      appKey: 'teams',
    });
    const chatId = normalizeTrimmedText(config.chatId || config.chat_id, 200);
    if (!chatId) {
      throw new Error('Teams chat ID is required.');
    }
    return {
      connectionId: connection.id,
      accountEmail: connection.account_email || null,
      chatId,
      sender: normalizeTrimmedText(config.sender, 200),
    };
  },
  summarize(config = {}) {
    const parts = ['Teams'];
    if (config.accountEmail) parts.push(config.accountEmail);
    if (config.chatId) parts.push(`chat: ${config.chatId}`);
    if (config.sender) parts.push(`sender: ${config.sender}`);
    return parts.join(' · ');
  },
};
