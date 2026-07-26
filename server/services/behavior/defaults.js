'use strict';

const MODULE_IDS = Object.freeze([
  'turn_taking',
  'social_memory',
  'norms',
  'persona',
  'agent_identity',
  'channel_style',
  'theory_of_mind',
  'social_signals',
  'social_observability',
  'delivery',
]);

const DEFAULT_MODULE_CONFIG = Object.freeze({
  schemaVersion: 1,
  enabled: true,
  participationMode: 'automatic',
  minimumNeedScore: 0.72,
  batchWindowMs: 900,
  decisionContextMessageLimit: 12,
  decisionModelId: null,
  decisionModelPurpose: 'fast',
  deliveryStyle: 'natural_bubbles',
  maxBubbles: 4,
  bubbleGapMs: 650,
  normsRefreshMessageGap: 18,
  observabilityIntervalMinutes: 360,
});

function cloneDefaults() {
  return {
    schemaVersion: DEFAULT_MODULE_CONFIG.schemaVersion,
    enabled: DEFAULT_MODULE_CONFIG.enabled,
    modules: {
      turn_taking: { enabled: true },
      social_memory: { enabled: true },
      norms: { enabled: true },
      persona: { enabled: true },
      agent_identity: { enabled: true },
      channel_style: { enabled: true },
      theory_of_mind: { enabled: true },
      social_signals: { enabled: true },
      social_observability: { enabled: true },
      delivery: { enabled: true },
    },
    participationMode: DEFAULT_MODULE_CONFIG.participationMode,
    minimumNeedScore: DEFAULT_MODULE_CONFIG.minimumNeedScore,
    batchWindowMs: DEFAULT_MODULE_CONFIG.batchWindowMs,
    decisionContextMessageLimit: DEFAULT_MODULE_CONFIG.decisionContextMessageLimit,
    decisionModelId: DEFAULT_MODULE_CONFIG.decisionModelId,
    decisionModelPurpose: DEFAULT_MODULE_CONFIG.decisionModelPurpose,
    deliveryStyle: DEFAULT_MODULE_CONFIG.deliveryStyle,
    maxBubbles: DEFAULT_MODULE_CONFIG.maxBubbles,
    bubbleGapMs: DEFAULT_MODULE_CONFIG.bubbleGapMs,
    normsRefreshMessageGap: DEFAULT_MODULE_CONFIG.normsRefreshMessageGap,
    observabilityIntervalMinutes: DEFAULT_MODULE_CONFIG.observabilityIntervalMinutes,
    platformOverrides: {},
    roomOverrides: {},
  };
}

module.exports = {
  MODULE_IDS,
  DEFAULT_MODULE_CONFIG,
  cloneDefaults,
};
