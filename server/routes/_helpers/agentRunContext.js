'use strict';

const { ensureDefaultAiSettings, getAiSettings } = require('../../services/ai/settings');
const { getWebChatContext } = require('../../services/ai/history');

function buildAgentRunContext({ userId, agentId, task }) {
  ensureDefaultAiSettings(userId, agentId);
  const aiSettings = getAiSettings(userId, agentId);
  const webContext = getWebChatContext(userId, aiSettings.chat_history_window, { agentId });

  const lastMatchIndex = webContext.recentMessages.findLastIndex(
    (message) => message.role === 'user' && message.content === task,
  );
  const priorMessages = webContext.recentMessages
    .filter((_, index) => index !== lastMatchIndex)
    .slice(-aiSettings.chat_history_window);

  return {
    priorMessages,
    priorSummary: webContext.summary,
    webContext,
  };
}

module.exports = {
  buildAgentRunContext,
};
