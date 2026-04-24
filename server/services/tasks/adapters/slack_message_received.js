'use strict';

const {
  ensureOwnedIntegrationConnection,
  normalizeTrimmedText,
} = require('../security');

module.exports = {
  type: 'slack_message_received',
  label: 'Slack Message Received',
  providerKey: 'slack',
  appKey: 'slack',
  async validateConfig(config = {}, context = {}) {
    const connection = ensureOwnedIntegrationConnection(context.integrationManager, {
      userId: context.userId,
      agentId: context.agentId,
      connectionId: config.connectionId || config.connection_id,
      providerKey: 'slack',
      appKey: 'slack',
    });
    const channel = normalizeTrimmedText(config.channel, 160);
    if (!channel) {
      throw new Error('Slack channel is required.');
    }
    return {
      connectionId: connection.id,
      accountEmail: connection.account_email || null,
      channel,
      sender: normalizeTrimmedText(config.sender, 160),
    };
  },
  summarize(config = {}) {
    const parts = ['Slack'];
    if (config.accountEmail) parts.push(config.accountEmail);
    if (config.channel) parts.push(config.channel);
    if (config.sender) parts.push(`sender: ${config.sender}`);
    return parts.join(' · ');
  },
};
