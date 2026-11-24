'use strict';

// Model-free helpers for shaping outgoing messages, plus the instructions for
// the two side turns the runtime asks the model for: progress pings and the
// wrap-up after a runaway guard stops a run. The text the user sees is always
// written by the model; nothing here produces a reply on its own.

const {
  buildPlatformFormattingGuide,
  normalizeOutgoingMessageForPlatform,
} = require('../messaging/formatting_guides');
const { renderFragment } = require('./prompts/registry');

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

// Carries no voice or formatting rules of its own: this prompt runs with the
// run's real system prompt as context, so the update inherits the same voice as
// every other message.
function buildProgressUpdatePrompt() {
  return renderFragment('runtime/progress_update.md');
}

// What each runaway guard means, told to the model for its last turn.
const WRAP_UP_REASONS = Object.freeze({
  token_budget: 'it used all the tokens it was allowed',
  malformed_output: 'the model kept writing tool calls as text instead of making them',
  turn_limit: 'the run reached its emergency turn limit',
  no_progress: 'the last several steps changed nothing and found nothing new',
  tool_failures: 'every tool call in the last several steps failed',
  context_overflow: 'the conversation grew too large to continue',
  blank_output: 'the model kept returning empty turns',
});

function buildWrapUpPrompt(reason, platform = null) {
  return [
    renderFragment('runtime/wrap_up.md', { why: WRAP_UP_REASONS[reason] || reason }),
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
