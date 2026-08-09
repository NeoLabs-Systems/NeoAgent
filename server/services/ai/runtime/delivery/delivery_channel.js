'use strict';

function resolveDeliveryChannel(triggerSource) {
  const source = String(triggerSource || 'web').trim().toLowerCase();
  if (source === 'messaging') return 'messaging';
  if (source === 'voice_live') return 'voice_live';
  return 'web';
}

function resolveDeliveryRecipient(triggerSource, options = {}) {
  if (resolveDeliveryChannel(triggerSource) === 'voice_live') {
    return String(
      options.voiceSessionId
      || options.sessionBinding?.sessionId
      || options.chatId
      || '',
    ).trim() || null;
  }
  return options.chatId || null;
}

module.exports = {
  resolveDeliveryChannel,
  resolveDeliveryRecipient,
};
