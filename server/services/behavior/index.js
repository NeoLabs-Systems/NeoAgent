'use strict';

const {
  getBehaviorConfig,
  setBehaviorConfig,
  resolveBehaviorConfig,
  normalizeStoredConfig,
  roomConfigKey,
  isModuleEnabled,
  SETTINGS_KEY,
} = require('./config');
const { MODULE_IDS, cloneDefaults, DEFAULT_MODULE_CONFIG } = require('./defaults');
const { createBehaviorPipeline } = require('./pipeline');
const {
  getThreadState,
  setThreadState,
  isTurnCurrent,
  markSpoke,
} = require('./state');
const { createBehaviorRegistry, LIFECYCLE_STAGES } = require('./registry');
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
  roomConfigKey,
  isModuleEnabled,
  createBehaviorPipeline,
  createBehaviorRegistry,
  LIFECYCLE_STAGES,
  getThreadState,
  setThreadState,
  isTurnCurrent,
  markSpoke,
  splitIntoNaturalBubbles,
  deliverSocialReply,
};
