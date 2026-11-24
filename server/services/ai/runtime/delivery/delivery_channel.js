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

// What a progress line needs to find its way. A messaging run names its platform
// here, because the channel alone only says "messaging".
function progressDeliveryMetadata(triggerSource, options = {}) {
  return {
    ...(resolveDeliveryChannel(triggerSource) === 'messaging'
      ? { platform: options.source || null, chatId: options.chatId || null }
      : {}),
    ...(options.sessionBinding || {}),
  };
}

// Progress lines describe what the run's tools are doing, so on messaging they
// are for the owner's own chat: a group does not need the commentary, and someone
// else's chat has no business seeing the owner's tool activity.
function allowsProgressUpdates(triggerSource, options = {}) {
  const channel = resolveDeliveryChannel(triggerSource);
  // A call reports on the line itself (voice/live/session.js); a second narrator
  // would talk over it.
  if (channel === 'voice_live') return false;
  if (channel !== 'messaging') return true;
  return (options.audience || 'owner') === 'owner'
    && options.memoryAudience !== 'shared'
    && options.context?.socialIntelligence?.isGroup !== true;
}

module.exports = {
  allowsProgressUpdates,
  progressDeliveryMetadata,
  resolveDeliveryChannel,
  resolveDeliveryRecipient,
};
