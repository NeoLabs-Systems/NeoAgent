'use strict';

const MODULE_IDS = Object.freeze([
  'turn_taking',
  'social_memory',
  'norms',
  'persona',
  'theory_of_mind',
  'social_signals',
  'social_observability',
]);

const DEFAULT_MODULE_CONFIG = Object.freeze({
  enabled: true,
  holdBackStrength: 0.72,
  cooldownSeconds: 45,
  requireAddressHint: false,
  deliveryStyle: 'natural_bubbles',
  maxBubbles: 4,
  bubbleGapMs: 650,
  decisionModelPreference: 'cheap',
  memoryRetentionDays: 120,
  normsRefreshMessageGap: 18,
  observabilityIntervalMinutes: 360,
});

function cloneDefaults() {
  return {
    enabled: DEFAULT_MODULE_CONFIG.enabled,
    modules: {
      turn_taking: { enabled: true },
      social_memory: { enabled: true },
      norms: { enabled: true },
      persona: { enabled: true },
      theory_of_mind: { enabled: true },
      social_signals: { enabled: true },
      social_observability: { enabled: true },
    },
    holdBackStrength: DEFAULT_MODULE_CONFIG.holdBackStrength,
    cooldownSeconds: DEFAULT_MODULE_CONFIG.cooldownSeconds,
    requireAddressHint: DEFAULT_MODULE_CONFIG.requireAddressHint,
    deliveryStyle: DEFAULT_MODULE_CONFIG.deliveryStyle,
    maxBubbles: DEFAULT_MODULE_CONFIG.maxBubbles,
    bubbleGapMs: DEFAULT_MODULE_CONFIG.bubbleGapMs,
    decisionModelPreference: DEFAULT_MODULE_CONFIG.decisionModelPreference,
    memoryRetentionDays: DEFAULT_MODULE_CONFIG.memoryRetentionDays,
    normsRefreshMessageGap: DEFAULT_MODULE_CONFIG.normsRefreshMessageGap,
    observabilityIntervalMinutes: DEFAULT_MODULE_CONFIG.observabilityIntervalMinutes,
    platformOverrides: {},
    groupOverrides: {},
  };
}

module.exports = {
  MODULE_IDS,
  DEFAULT_MODULE_CONFIG,
  cloneDefaults,
};
