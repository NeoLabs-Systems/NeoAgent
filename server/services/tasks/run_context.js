'use strict';

const { getAiSettings } = require('../ai/settings');
const { getConversationContext } = require('../ai/history');

// A task run continues the chat it reports to, so it sees what the user
// already got and said there.
function buildTaskChatContext({ taskRepository, userId, agentId, notifyTarget }) {
  if (!notifyTarget) return { priorMessages: [], priorSummary: '' };
  const conversation = taskRepository.getTaskConversation(
    userId,
    agentId,
    notifyTarget.platform,
    notifyTarget.to,
  );
  if (!conversation) return { priorMessages: [], priorSummary: '' };
  const { chat_history_window: historyWindow } = getAiSettings(userId, agentId);
  const context = getConversationContext(conversation.id, historyWindow);
  return { priorMessages: context.recentMessages, priorSummary: context.summary };
}

// What the previous run of this task delivered, so the next run only reports
// what is new since then.
function buildLastRunNote(lastRun) {
  if (!lastRun) return '';
  let outcome = `It sent nothing. Its result:\n${lastRun.final_response || '(empty)'}`;
  if (lastRun.sentMessages.length > 0) {
    outcome = `It sent the user:\n${lastRun.sentMessages.join('\n---\n')}`;
  } else if (lastRun.error) {
    outcome = `It failed: ${lastRun.error}`;
  }
  return [
    `[Previous run of this task: ${lastRun.created_at} UTC, ${lastRun.status}]`,
    outcome,
    'Do not repeat what that run already delivered; report only what is new since then.',
  ].join('\n');
}

module.exports = {
  buildLastRunNote,
  buildTaskChatContext,
};
