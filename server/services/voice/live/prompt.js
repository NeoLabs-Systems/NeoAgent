'use strict';

const { getConversationContext } = require('../../ai/history');
const { buildVoicePersonaSections, localNow } = require('../../behavior/modules/persona');
const { renderFragment } = require('../../ai/prompts/registry');

const HISTORY_MESSAGES = 24;
const MAX_HISTORY_MESSAGE_CHARS = 700;

// How the live model relates to the task runtime leads the prompt, because the
// persona's casual register otherwise wins over it. Models copy example wording
// closely, so these rules show what not to say but never what to say. Gemini Live
// calls the task tools itself; GPT-Live can only hand off, and the run it starts
// sees the owner's running tasks.
function callRules(taskTools) {
  return `${renderFragment('voice/call_rules.md')}\n${renderFragment(taskTools ? 'voice/task_tools.md' : 'voice/handoff_tools.md')}`;
}

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

function describeRunningTasks(tasks) {
  if (!tasks.length) return '';
  return [
    '## tasks running as the call connected',
    ...tasks.map((task) => {
      const minutes = Math.round((task.running_for_seconds || 0) / 60);
      return `- task ${task.task_id} (started in ${task.started_in}, running for ${minutes} min): ${clampText(task.request, 300)}`;
    }),
  ].join('\n');
}

// The live model speaks with the same persona the agent runs write with,
// plus owner instructions, style notes, and memory about the owner. Delegated
// runs keep the normal agent prompt and do the work.
async function buildLivePrompt({
  memoryManager,
  userId,
  agentId,
  conversationId,
  runningTasks = [],
  taskTools = false,
  devicePlatform = null,
}) {
  const persona = await buildVoicePersonaSections({ userId, agentId, memoryManager });
  const history = recentSpokenHistory(conversationId);
  const instructions = [
    callRules(taskTools),
    devicePlatform === 'm5stickc-plus2'
      ? 'The answer is displayed on a very small wearable screen. Keep every response extra short, using only the essential words.'
      : '',
    ...persona,
    `now: ${localNow(userId)}`,
    describeRunningTasks(runningTasks),
    history.summary ? `## earlier in this conversation (summary)\n${history.summary}` : '',
  ].filter(Boolean).join('\n\n');
  return { instructions, history: history.messages };
}

module.exports = {
  buildLivePrompt,
};
