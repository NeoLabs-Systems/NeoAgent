'use strict';

const {
  getBehaviorConfig,
  setBehaviorConfig,
  resolveBehaviorConfig,
  normalizeStoredConfig,
  groupConfigKey,
  isModuleEnabled,
  SETTINGS_KEY,
} = require('./config');
const { MODULE_IDS, cloneDefaults, DEFAULT_MODULE_CONFIG } = require('./defaults');
const { createBehaviorPipeline } = require('./pipeline');
const { getThreadState, setThreadState } = require('./state');
const { splitIntoNaturalBubbles, deliverSocialReply } = require('./delivery');

module.exports = {
  MODULE_IDS,
  DEFAULT_MODULE_CONFIG,
  SETTINGS_KEY,
  cloneDefaults,
  getBehaviorConfig,
  setBehaviorConfig,
  resolveBehaviorConfig,
  normalizeStoredConfig,
  groupConfigKey,
  isModuleEnabled,
  createBehaviorPipeline,
  getThreadState,
  setThreadState,
  splitIntoNaturalBubbles,
  deliverSocialReply,
};
