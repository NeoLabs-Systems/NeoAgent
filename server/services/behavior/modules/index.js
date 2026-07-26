'use strict';

const turnTaking = require('./turn_taking');
const socialMemory = require('./social_memory');
const norms = require('./norms');
const persona = require('./persona');
const agentIdentity = require('./agent_identity');
const channelStyle = require('./channel_style');
const theoryOfMind = require('./theory_of_mind');
const socialSignals = require('./social_signals');
const socialObservability = require('./social_observability');
const delivery = require('../delivery');

const BEHAVIOR_MODULES = Object.freeze([
  turnTaking,
  socialMemory,
  norms,
  persona,
  agentIdentity,
  channelStyle,
  theoryOfMind,
  socialSignals,
  socialObservability,
  delivery,
]);

module.exports = {
  BEHAVIOR_MODULES,
};
