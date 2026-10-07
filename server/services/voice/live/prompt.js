'use strict';

const { getConversationContext } = require('../../ai/history');
const { buildVoicePersonaSections, localNow } = require('../../behavior/modules/persona');

const HISTORY_MESSAGES = 24;
const MAX_HISTORY_MESSAGE_CHARS = 700;

// How the live model relates to the task runtime. These rules lead the prompt
// because the persona's casual register otherwise wins over them; everything
// about who it is comes from the shared persona.
const CALL_RULES = `## rules for this call (they override everything below)
- You cannot do anything yourself during the call. Nothing you say is saved, sent, changed, or looked up.
- Any request to remember, note, save, send, schedule, change, check, or look something up is work: hand it to the task runtime every time, even when it seems trivial or you think you already know.
- Answer yourself only for conversation and what this prompt and the call already establish.
- Tasks run in the background while you keep talking, several at once if needed. Until a task's outcome arrives, speak of it only as something you are doing or about to do ("on it", "I'll note that"; "mach ich", "notier ich dir"), never in the past tense ("noted", "done", "hab's notiert", "ist erledigt"): nothing has happened yet. When the outcome arrives, say what actually happened.
- Progress from running tasks reaches you as context; when you are told to pass an update on, say it in a sentence or two, then let the owner talk.`;

// Gemini Live calls the task tools itself; GPT-Live can only hand off, and the
// run it starts sees the owner's running tasks.
const TASK_TOOL_RULES = `- For tasks that are already running, use the task tools instead of starting new work: check_tasks when the owner asks how things are going, update_task when they add to or change a task or answer its question, cancel_task when they want one stopped. Say a task is stopped only after cancel_task confirms it.
- Refer to tasks by what they do; never read task ids aloud.`;
const HANDOFF_RULES = '- Checking on, changing, or stopping a running task is handed off like any other request; the task runtime knows which tasks are running.';

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
}) {
  const persona = await buildVoicePersonaSections({ userId, agentId, memoryManager });
  const history = recentSpokenHistory(conversationId);
  const instructions = [
    `${CALL_RULES}\n${taskTools ? TASK_TOOL_RULES : HANDOFF_RULES}`,
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
