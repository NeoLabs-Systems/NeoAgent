'use strict';

// Deterministic, model-free helpers for shaping outgoing messages and for
// constructing honest fallback replies when a run fails or the model returns a
// blank message. Kept free of engine state so the behavior is pure and unit
// testable: every function derives its output from its arguments alone.

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

function parseToolExecutionSummary(item) {
  if (!item?.summary) return null;
  try {
    const parsed = JSON.parse(item.summary);
    return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : null;
  } catch {
    return null;
  }
}

function toolWorkDescription(toolName) {
  const name = String(toolName || '');
  if (name === 'execute_command') return 'ran shell commands';
  if (name === 'read_file' || name === 'read_files' || name === 'read_artifact' || name === 'search_files' || name === 'list_directory') return 'checked files';
  if (name === 'web_search' || name === 'http_request') return 'looked up supporting information';
  if (name.startsWith('browser_')) return 'checked the browser state';
  if (name.startsWith('android_')) return 'checked the Android state';
  if (name === 'read_health_data') return 'checked stored data';
  return '';
}

function summarizeRecentWork(toolExecutions = []) {
  const descriptions = [];
  for (const item of toolExecutions.slice(-6)) {
    const description = toolWorkDescription(item?.toolName);
    if (!description || descriptions.includes(description)) continue;
    descriptions.push(description);
    if (descriptions.length >= 2) break;
  }

  if (descriptions.length === 0) return '';
  if (descriptions.length === 1) return descriptions[0];
  return `${descriptions[0]} and ${descriptions[1]}`;
}

function hasFailureSignal(text) {
  const normalized = normalizeOutgoingMessage(text);
  if (!normalized) return false;
  return /\b(error|failed|failure|traceback|exception|timed out|timeout|not found|no such file|permission denied|unable to|cannot|could not|module not found)\b/i.test(normalized);
}

function isInternalToolingFailure(text) {
  const normalized = normalizeOutgoingMessage(text);
  if (!normalized) return false;
  return /(purpose=no_response requires content|failed to read file for user|enoent|eisdir|illegal operation on a directory|outside the per-user workspace|outside the shared workspace|path is not a file|file not found:|no such file or directory|can.?t cd to|no such directory|unknown tool:)/i.test(normalized);
}

function summarizeUserVisibleBlocker(text) {
  const normalized = normalizeOutgoingMessage(text);
  if (!normalized) return '';
  if (isInternalToolingFailure(normalized)) {
    return 'hit an internal tool issue while checking that';
  }
  return normalized;
}

function extractToolFailureMessage(item) {
  const directError = normalizeOutgoingMessage(item?.error || '');
  if (directError) return directError;

  const summary = parseToolExecutionSummary(item);
  if (!summary) return '';

  const candidates = [
    summary.message,
    summary.note,
    summary.stderr,
    summary.stdout,
    summary.content,
    summary.excerpt,
    summary.result,
    summary.summary,
  ];

  if (summary.status === 'error') {
    for (const candidate of candidates) {
      const normalized = normalizeOutgoingMessage(candidate || '');
      if (normalized) return normalized;
    }
    if (summary.exitCode != null) {
      return `The last shell command exited with code ${summary.exitCode}`;
    }
  }

  for (const candidate of candidates) {
    const normalized = normalizeOutgoingMessage(candidate || '');
    if (hasFailureSignal(normalized)) return normalized;
  }

  return '';
}

function buildDeterministicMessagingFallback({ failedStepCount, stepIndex, toolExecutions = [] }) {
  const workSummary = summarizeRecentWork(toolExecutions);
  const blocker = [...toolExecutions].reverse()
    .map((item) => extractToolFailureMessage(item))
    .map((message) => summarizeUserVisibleBlocker(message))
    .find(Boolean);

  if (workSummary && blocker) {
    return `${workSummary}, but hit a wall: ${blocker}. no finished result yet.`;
  }
  if (blocker) {
    return `got blocked on this: ${blocker}. no finished result yet.`;
  }
  if (workSummary && stepIndex > 0) {
    return `${workSummary}, but no finished result yet.`;
  }
  if (failedStepCount > 0) {
    return 'hit a tool problem while working on this, so no finished result yet.';
  }
  if (stepIndex > 0) {
    return 'got partway through, but no finished result yet.';
  }
  return 'could not land a reliable final reply just now.';
}

module.exports = {
  normalizeOutgoingMessage,
  clampRunContext,
  normalizeInterimText,
  buildWrapUpPrompt,
  buildProgressUpdatePrompt,
  toolWorkDescription,
  summarizeRecentWork,
  hasFailureSignal,
  isInternalToolingFailure,
  extractToolFailureMessage,
  buildDeterministicMessagingFallback,
};
