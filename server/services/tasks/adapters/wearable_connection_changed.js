'use strict';

const { normalizeTrimmedText } = require('../security');
const { summaryParts } = require('./shared');

const TRANSITIONS = Object.freeze(['connected', 'disconnected']);

module.exports = {
  type: 'wearable_connection_changed',
  label: 'Wearable Connected or Disconnected',
  configHint: '{ transition: connected|disconnected }',
  async validateConfig(config = {}) {
    const transition = normalizeTrimmedText(config.transition, 20).toLowerCase() || 'disconnected';
    if (!TRANSITIONS.includes(transition)) {
      throw new Error('Wearable transition must be "connected" or "disconnected".');
    }
    return { transition };
  },
  summarize(config = {}) {
    return summaryParts('Wearable', [config.transition]);
  },
  event: {
    source: 'wearable',
    name: 'connection_changed',
    matches(config, event) {
      return config.transition === event.transition;
    },
    toPayload(event) {
      return {
        fingerprint: `wearable:${event.deviceId}:${event.transition}:${event.occurredAt}`,
        timestamp: event.occurredAt,
        context: {
          triggerEvent: {
            provider: 'wearable',
            event: event.transition,
            deviceId: event.deviceId,
            deviceLabel: event.deviceLabel,
          },
        },
      };
    },
  },
};
