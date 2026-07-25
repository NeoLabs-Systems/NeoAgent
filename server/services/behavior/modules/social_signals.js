'use strict';

const { setThreadState, getThreadState } = require('../state');
const { isModuleEnabled } = require('../config');

function recordSignal(ctx) {
  const { userId, agentId, msg, config, signalType = 'message', details = {} } = ctx;
  if (!isModuleEnabled(config, 'social_signals')) {
    return { recorded: false };
  }
  const state = getThreadState(userId, agentId, msg.platform, msg.chatId);
  const signals = Array.isArray(state.recentSignals) ? state.recentSignals.slice(-19) : [];
  signals.push({
    type: signalType,
    at: new Date().toISOString(),
    sender: msg.sender || null,
    details,
  });
  setThreadState(userId, agentId, msg.platform, msg.chatId, {
    recentSignals: signals,
  });
  return { recorded: true, count: signals.length };
}

module.exports = {
  id: 'social_signals',
  recordSignal,
};
