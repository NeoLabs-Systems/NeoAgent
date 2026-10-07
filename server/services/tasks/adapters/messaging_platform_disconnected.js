'use strict';

const { normalizeTrimmedText } = require('../security');
const { summaryParts } = require('./shared');

module.exports = {
  type: 'messaging_platform_disconnected',
  label: 'Messaging Disconnected',
  configHint: '{ platform?: e.g. whatsapp }; fires when a connection stops and needs the user, such as a logout',
  async validateConfig(config = {}) {
    return { platform: normalizeTrimmedText(config.platform, 40).toLowerCase() };
  },
  summarize(config = {}) {
    return summaryParts('Messaging disconnected', [config.platform]);
  },
  event: {
    source: 'messaging',
    name: 'platform_disconnected',
    matches(config, event) {
      return !config.platform || config.platform === event.platform;
    },
    toPayload(event) {
      return {
        fingerprint: `platform_disconnected:${event.platform}:${event.occurredAt}`,
        timestamp: event.occurredAt,
        context: {
          triggerEvent: {
            provider: event.platform,
            event: 'platform_disconnected',
            reason: event.reason,
            occurredAt: event.occurredAt,
          },
        },
      };
    },
  },
};
