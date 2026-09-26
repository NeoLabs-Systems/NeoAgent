'use strict';

const { isModuleEnabled } = require('../config');
const { ruleDecision } = require('./decisions');

// Turns that need no reading of the room: direct chats and switched-off gates.
function bypassDecision(msg, config) {
  if (!msg?.isGroup) {
    return ruleDecision('speak', 'direct_chat', 'Direct chat always engages.');
  }
  if (!isModuleEnabled(config, 'turn_taking') || config.enabled === false) {
    return ruleDecision('speak', 'turn_taking_disabled', 'Turn-taking disabled; engaging.');
  }
  return null;
}

// Turns settled by how the message reached the agent and the room's
// participation mode. Returns null when the room has to be judged.
function addressDecision(msg, config, addressing) {
  if (addressing.structurallyAddressed) {
    return ruleDecision(
      'speak',
      msg.repliedToAgent ? 'reply_to_agent' : 'addressed',
      'Platform metadata directly addresses the agent.',
    );
  }
  const mode = config.participationMode || 'automatic';
  if (mode === 'always') {
    return ruleDecision('speak', 'participation_always', 'Room participation is configured to always engage.');
  }
  if (mode === 'mention_only') {
    return ruleDecision('stay_silent', 'mention_only', 'Room participation requires a structural mention or reply.');
  }
  if (addressing.addressedByName) {
    return ruleDecision(
      'speak',
      'addressed_by_name',
      'The message names the agent without a platform mention tag.',
      { confidence: 0.9 },
    );
  }
  return null;
}

module.exports = {
  bypassDecision,
  addressDecision,
};
