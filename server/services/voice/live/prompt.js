'use strict';

const db = require('../../../db/database');
const { getConversationContext } = require('../../ai/history');
const { buildPersonaSections, localNow } = require('../../behavior/modules/interaction_writer');
const { resolveStyleBundle } = require('../../behavior/modules/persona');

const HISTORY_MESSAGES = 24;
const MAX_HISTORY_MESSAGE_CHARS = 700;

// How the live model relates to the task runtime. These rules lead the prompt
// because the persona's casual register otherwise wins over them; everything
// about who it is comes from the shared persona.
const CALL_RULES = `## rules for this call (they override everything below)
- You cannot do anything yourself during the call. Nothing you say is saved, sent, changed, or looked up.
- Any request to remember, note, save, send, schedule, change, check, or look something up is work: hand it to the task runtime every time, even when it seems trivial or you think you already know.
- Answer yourself only for conversation and what this prompt and the call already establish.
- Until a task's outcome arrives, speak of it only as something you are doing now ("on it", "I'll note that"), never as done. When the outcome arrives, say what actually happened.
- Progress notes from running tasks arrive as context; use them when asked how it is going. Additions or changes to a running task are handed off the same way.`;

function clampText(text, maxChars) {
  const value = String(text || '').trim();
  return value.length > maxChars ? `${value.slice(0, maxChars)}…` : value;
}

function ownerName(userId) {
  const row = db.prepare('SELECT display_name, username FROM users WHERE id = ?').get(userId);
  return String(row?.display_name || row?.username || '').trim() || 'them';
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

// The live model is the voice of the agent, like the messaging writer is: the
// same persona, owner instructions, style notes, and memory about the owner.
// Delegated runs keep the normal agent prompt and do the work.
async function buildLivePrompt({ memoryManager, userId, agentId, conversationId }) {
  const persona = await buildPersonaSections({
    userId,
    agentId,
    memoryManager,
    name: ownerName(userId),
    medium: 'voice',
    styleNotes: resolveStyleBundle({ memoryManager, userId, agentId, audience: 'owner' }).notes,
  });
  const history = recentSpokenHistory(conversationId);
  const instructions = [
    CALL_RULES,
    ...persona,
    `now: ${localNow(userId)}`,
    history.summary ? `## earlier in this conversation (summary)\n${history.summary}` : '',
  ].filter(Boolean).join('\n\n');
  return { instructions, history: history.messages };
}

module.exports = {
  buildLivePrompt,
};
