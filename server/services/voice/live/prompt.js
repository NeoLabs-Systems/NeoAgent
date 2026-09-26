'use strict';

const { getConversationContext } = require('../../ai/history');

const HISTORY_MESSAGES = 24;
const MAX_HISTORY_MESSAGE_CHARS = 700;

function clampText(text, maxChars) {
  const value = String(text || '').trim();
  return value.length > maxChars ? `${value.slice(0, maxChars)}…` : value;
}

function recentSpokenHistory(conversationId) {
  if (!conversationId) return { summary: '', messages: [] };
  const context = getConversationContext(conversationId, HISTORY_MESSAGES);
  const messages = context.recentMessages
    .filter((message) => (message.role === 'user' || message.role === 'assistant')
      && typeof message.content === 'string'
      && message.content.trim()
      && !message.tool_calls?.length)
    .map((message) => ({
      role: message.role,
      text: clampText(message.content, MAX_HISTORY_MESSAGE_CHARS),
    }));
  return { summary: String(context.summary || '').trim(), messages };
}

// The live model runs on the same system prompt as every chat run (persona,
// agent identity, memory, clock, skills); the voice_live surface section in
// systemPrompt.js adds how to talk and when to hand work to the task runtime.
async function buildLivePrompt({ agentEngine, userId, agentId, conversationId }) {
  const sections = await agentEngine.buildSystemPrompt(userId, {
    agentId,
    triggerSource: 'voice_live',
    liveVoiceRole: 'front',
    memoryAudience: 'owner',
  });
  const history = recentSpokenHistory(conversationId);
  const instructions = [
    sections.stable,
    sections.dynamic,
    history.summary ? `Earlier in this conversation (summary):\n${history.summary}` : '',
  ].filter(Boolean).join('\n\n');
  return { instructions, history: history.messages };
}

module.exports = {
  buildLivePrompt,
};
