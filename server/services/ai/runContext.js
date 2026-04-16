'use strict';

const { ensureDefaultAiSettings, getAiSettings } = require('./settings');
const { getWebChatContext } = require('./history');

function normalizeHistoryWindow(configuredWindow, requestedWindow = null) {
  const configured = Math.max(1, Number(configuredWindow) || 1);
  if (requestedWindow == null) {
    return configured;
  }
  const requested = Math.max(1, Number(requestedWindow) || configured);
  return Math.min(configured, requested);
}

function buildAgentRunContext({
  userId,
  agentId,
  task,
  historyWindow = null,
  includeWebContext = false,
}) {
  ensureDefaultAiSettings(userId, agentId);
  const aiSettings = getAiSettings(userId, agentId);
  const effectiveWindow = normalizeHistoryWindow(
    aiSettings.chat_history_window,
    historyWindow,
  );
  const webContext = getWebChatContext(userId, effectiveWindow, { agentId });

  const lastMatchIndex = webContext.recentMessages.findLastIndex(
    (message) => message.role === 'user' && message.content === task,
  );
  const priorMessages = webContext.recentMessages
    .filter((_, index) => index !== lastMatchIndex)
    .slice(-effectiveWindow);

  return {
    priorMessages,
    priorSummary: webContext.summary,
    ...(includeWebContext ? { webContext } : {}),
  };
}

module.exports = {
  buildAgentRunContext,
  normalizeHistoryWindow,
};
