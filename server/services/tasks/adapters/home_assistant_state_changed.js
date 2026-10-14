'use strict';

const { normalizeTrimmedText } = require('../security');
const { connectionConfig, optionalNumber, requiredText, summaryParts } = require('./shared');

const UNSETTLED_STATES = new Set(['unavailable', 'unknown']);

function matchesCondition(config, state) {
  if (config.toState) return state === config.toState;
  const numeric = Number(state);
  if (config.above !== null && !(numeric > config.above)) return false;
  if (config.below !== null && !(numeric < config.below)) return false;
  return true;
}

function hasCondition(config) {
  return Boolean(config.toState) || config.above !== null || config.below !== null;
}

// The checkpoint records whether the entity matched at its last change. With
// a condition the task runs when the entity starts matching, not on every
// reading while it stays there; without one, every change runs it.
module.exports = {
  type: 'home_assistant_state_changed',
  label: 'Home Assistant State Changed',
  providerKey: 'home_assistant',
  appKey: 'home_assistant',
  configHint: '{ connectionId, entityId: e.g. "binary_sensor.front_door", toState?: e.g. "on", above?: number, below?: number }; without a condition every state change fires',
  async validateConfig(config = {}, context = {}) {
    const entityId = requiredText(config.entityId || config.entity_id, 200, 'Home Assistant entity ID is required.');
    if (!/^[a-z_]+\.[a-z0-9_]+$/.test(entityId)) {
      throw new Error('Home Assistant entity ID must look like "light.kitchen".');
    }
    const toState = normalizeTrimmedText(config.toState || config.to_state, 100);
    const above = optionalNumber(config.above);
    const below = optionalNumber(config.below);
    if (toState && (above !== null || below !== null)) {
      throw new Error('Use either a target state or a numeric range, not both.');
    }
    return {
      ...connectionConfig(config, context, 'home_assistant', 'home_assistant'),
      entityId,
      toState,
      above,
      below,
    };
  },
  summarize(config = {}) {
    return summaryParts('Home Assistant', [
      config.entityId,
      config.toState && `to ${config.toState}`,
      config.above !== null && config.above !== undefined && `above ${config.above}`,
      config.below !== null && config.below !== undefined && `below ${config.below}`,
    ]);
  },
  poll: {
    intervalMinutes: 1,
    cursor: 'list',
    async fetchRows({ tool, config, checkpoint }) {
      const entity = await tool('home_assistant_get_state', { entity_id: config.entityId });
      const state = String(entity?.state ?? '');
      const changedAt = entity?.last_changed || entity?.last_updated;
      if (!state || !changedAt) return [];
      const matched = !UNSETTLED_STATES.has(state) && matchesCondition(config, state);
      const fingerprint = `${matched ? 'match' : 'idle'}:${config.entityId}:${changedAt}`;
      const stillMatching = hasCondition(config) && String(checkpoint).startsWith('match:');
      if (!matched || stillMatching) {
        return [{ fingerprint, timestamp: changedAt, silent: true }];
      }
      return [{
        fingerprint,
        timestamp: changedAt,
        context: {
          triggerEvent: {
            provider: 'home_assistant',
            event: 'state_changed',
            entityId: config.entityId,
            name: entity.attributes?.friendly_name || config.entityId,
            state,
            unit: entity.attributes?.unit_of_measurement || null,
            changedAt,
          },
        },
      }];
    },
  },
};
