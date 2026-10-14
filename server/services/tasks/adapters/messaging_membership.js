'use strict';

const { normalizeTrimmedText } = require('../security');
const { summaryParts } = require('./shared');

const MEMBERSHIP_PLATFORMS = Object.freeze(['discord', 'telegram', 'whatsapp', 'slack', 'matrix']);

// Joins and leaves share one config and payload: the platform, and optionally
// the one server, group, channel, or room to watch.
function membershipAdapter({ type, label, eventName, verb }) {
  return {
    type,
    label,
    configHint: `{ platform: ${MEMBERSHIP_PLATFORMS.join('|')}, spaceId?: Discord server, Telegram/WhatsApp group, Slack channel, or Matrix room ID }; each run receives the member, with chatId for the group and dmChatId to message them directly via send_message (Telegram only reaches people who started the bot; Matrix has no dmChatId)`,
    async validateConfig(config = {}) {
      const platform = normalizeTrimmedText(config.platform, 40).toLowerCase();
      if (!MEMBERSHIP_PLATFORMS.includes(platform)) {
        throw new Error(`Platform must be one of: ${MEMBERSHIP_PLATFORMS.join(', ')}.`);
      }
      return {
        platform,
        spaceId: normalizeTrimmedText(config.spaceId || config.space_id, 200),
      };
    },
    summarize(config = {}) {
      return summaryParts(`Member ${verb}`, [config.platform, config.spaceId && `in ${config.spaceId}`]);
    },
    event: {
      source: 'messaging',
      name: eventName,
      matches(config, event) {
        return config.platform === event.platform && (!config.spaceId || config.spaceId === event.spaceId);
      },
      toPayload(event) {
        return {
          fingerprint: `${eventName}:${event.platform}:${event.spaceId}:${event.memberId}:${event.occurredAt}`,
          timestamp: event.occurredAt,
          context: {
            triggerEvent: {
              provider: event.platform,
              event: eventName,
              spaceId: event.spaceId,
              spaceName: event.spaceName,
              chatId: event.chatId,
              memberId: event.memberId,
              memberName: event.memberName,
              dmChatId: event.dmChatId,
              occurredAt: event.occurredAt,
            },
          },
        };
      },
    },
  };
}

module.exports = {
  MEMBERSHIP_PLATFORMS,
  membershipAdapter,
};
