'use strict';

// Model-free helpers for shaping outgoing messages, plus the instructions for
// the two side turns the runtime asks the model for: progress pings and the
// wrap-up after a runaway guard stops a run. The text the user sees is always
// written by the model; nothing here produces a reply on its own.

const {
  buildPlatformFormattingGuide,
  normalizeOutgoingMessageForPlatform,
} = require('../messaging/formatting_guides');

function normalizeOutgoingMessage(content, platform = null, options = {}) {
  const normalized = normalizeOutgoingMessageForPlatform(platform, content);
  if (options.collapseWhitespace === false) {
    return normalized;
  }
  return normalized.replace(/\s+/g, ' ').trim();
}

function clampRunContext(text, maxChars) {
  const value = normalizeOutgoingMessage(text);
  if (!value) return '';
  if (value.length <= maxChars) return value;
  return `${value.slice(0, maxChars)}...`;
}

function normalizeInterimText(content, platform = null) {
  return normalizeOutgoingMessageForPlatform(platform, content, {
    stripNoResponseMarker: false,
  }).trim();
}

function buildProgressUpdatePrompt() {
  // Intentionally carries NO voice/formatting rules of its own: this prompt runs with
  // the run's real system prompt as context, so the update inherits the same voice and
  // formatting guidelines as every other message and stays maintainable in one place.
  return [
    'You are mid-task and working autonomously while the user waits.',
    'Send ONE brief progress ping only if the actual recent tool activity below contains user-relevant progress or a real blocker.',
    'If there is no materially useful update for the user, output an empty string.',
    'Describe what the evidence literally shows. Do not invent work, outcomes, systems, artifacts, or next steps that are not present in the activity.',
    'If the recent activity only shows inspection or failed commands, say that plainly and do not imply state-changing progress.',
    'Do not mention progress checks, heartbeats, internal status, sent-message bookkeeping, or tool names unless the tool name itself matters to the user.',
    'This is not the final answer: do not claim the task is done and do not summarize results.',
    'No greeting, no question, no sign-off; vary the wording from your previous update.',
    'Follow your normal voice and formatting rules. Output only the message text.',
  ].join(' ');
}

// What each runaway guard means, told to the model for its last turn.
const WRAP_UP_REASONS = Object.freeze({
  turn_limit: 'the run reached its emergency turn limit',
  no_progress: 'the last several steps changed nothing and found nothing new',
  tool_failures: 'every tool call in the last several steps failed',
  context_overflow: 'the conversation grew too large to continue',
  blank_output: 'the model kept returning empty turns',
});

function buildWrapUpPrompt(reason, platform = null) {
  const why = WRAP_UP_REASONS[reason] || reason;
  return [
    `This run has to stop here because ${why}. This is your final turn: do not call any tools.`,
    'Write your reply to the user from the work already done in this conversation: what you got done, what is still missing, and the concrete reason.',
    'Never invent results, entities, or tool outcomes that the conversation does not show, and do not promise work that has not happened.',
    buildPlatformFormattingGuide(platform),
  ].join('\n\n');
}

module.exports = {
  normalizeOutgoingMessage,
  clampRunContext,
  normalizeInterimText,
  buildWrapUpPrompt,
  buildProgressUpdatePrompt,
};
