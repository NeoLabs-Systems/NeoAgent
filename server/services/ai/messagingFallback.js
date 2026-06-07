'use strict';

// Deterministic, model-free helpers for shaping outgoing messages and for
// constructing honest fallback replies when a run fails or the model returns a
// blank message. Kept free of engine state so the behavior is pure and unit
// testable: every function derives its output from its arguments alone.

const {
  buildPlatformFormattingGuide,
  normalizeOutgoingMessageForPlatform,
} = require('../messaging/formatting_guides');
const { summarizeForLog } = require('./logFormat');

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

function joinSentMessages(messages = []) {
  if (!Array.isArray(messages)) return '';
  return messages
    .map((message) => String(message || '').trim())
    .filter(Boolean)
    .join('\n\n');
}

function normalizeInterimText(content, platform = null) {
  return normalizeOutgoingMessageForPlatform(platform, content, {
    stripNoResponseMarker: false,
  }).trim();
}

function buildBlankMessagingReplyPrompt(attempt, platform = null) {
  const formattingGuide = buildPlatformFormattingGuide(platform);
  if (attempt <= 1) {
    return `You must send one non-empty reply for the external messaging user right now. Do not call tools. Give either: (a) the concrete outcome, or (b) a clear blocker. If tool work already happened, summarize what you actually tried and where it got blocked. Do not ask the user to repeat the original request. Do not promise future work unless that work already happened in this run or will happen automatically before this reply is sent.\n\n${formattingGuide}`;
  }

  return `Your previous reply was empty. Return one non-empty message now. Do not call tools. If needed, apologize briefly and explain the blocker in one sentence. Use the run evidence already in the conversation instead of asking the user to restate the task. Do not promise future work unless that work already happened in this run or will happen automatically before this reply is sent.\n\n${formattingGuide}`;
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
  if (name === 'read_file' || name === 'search_files' || name === 'list_directory') return 'checked files';
  if (name === 'web_search' || name === 'http_request') return 'looked up supporting information';
  if (name.startsWith('browser_')) return 'checked the browser state';
  if (name.startsWith('android_')) return 'checked the Android state';
  if (name === 'read_health_data' || name.startsWith('recordings_')) return 'checked stored data';
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
  if (descriptions.length === 1) return `I ${descriptions[0]}`;
  return `I ${descriptions[0]} and ${descriptions[1]}`;
}

function hasFailureSignal(text) {
  const normalized = normalizeOutgoingMessage(text);
  if (!normalized) return false;
  return /\b(error|failed|failure|traceback|exception|timed out|timeout|not found|no such file|permission denied|unable to|cannot|could not|module not found)\b/i.test(normalized);
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
    .find(Boolean);

  if (workSummary && blocker) {
    return `${workSummary}, but I got blocked: ${blocker}. I do not have a confirmed finished result yet.`;
  }
  if (blocker) {
    return `I got blocked while working on this: ${blocker}. I do not have a confirmed finished result yet.`;
  }
  if (workSummary && stepIndex > 0) {
    return `${workSummary}, but I do not have a confirmed finished result yet.`;
  }
  if (failedStepCount > 0) {
    return 'I ran into a tool problem while working on your request, so I do not have a confirmed finished result yet.';
  }
  if (stepIndex > 0) {
    return 'I completed part of the work, but I do not have a confirmed finished result yet.';
  }
  return 'I could not produce a reliable final reply just now.';
}

function buildMessagingFailureScenario({ err, failedStepCount, stepIndex, toolExecutions = [] }) {
  const parts = [];
  const runtimeError = normalizeOutgoingMessage(err?.message || '');
  const workSummary = summarizeRecentWork(toolExecutions);
  const blocker = [...toolExecutions].reverse()
    .map((item) => extractToolFailureMessage(item))
    .find(Boolean);

  if (runtimeError) {
    parts.push(`Runtime error: ${summarizeForLog(runtimeError, 260)}.`);
  }
  if (workSummary) {
    parts.push(`Observed work before failure: ${workSummary}.`);
  }
  if (blocker) {
    parts.push(`Most specific blocker from run evidence: ${summarizeForLog(blocker, 260)}.`);
  }
  if (stepIndex > 0) {
    parts.push(`Completed steps before failure: ${stepIndex}.`);
  }
  if (failedStepCount > 0) {
    parts.push(`Failed tool steps: ${failedStepCount}.`);
  }

  return parts.join(' ');
}

function buildDeterministicMessagingErrorReply({ err, failedStepCount, stepIndex, toolExecutions = [] }) {
  const message = normalizeOutgoingMessage(err?.message || '');
  if (/no ai providers? are currently available/i.test(message)) {
    return 'I cannot continue right now because no AI provider is available for this account. Please check the provider settings.';
  }

  if (/(timeout|timed out)/i.test(message)) {
    return 'I hit a timeout while processing your request and could not finish it reliably.';
  }

  const blocker = [...toolExecutions].reverse()
    .map((item) => extractToolFailureMessage(item))
    .find(Boolean);
  if (blocker) {
    return `I got blocked while checking this: ${blocker}.`;
  }

  if (message) {
    return `I got blocked while working on this: ${message}.`;
  }

  return buildDeterministicMessagingFallback({ failedStepCount, stepIndex, toolExecutions });
}

function buildModelFailureLoopPrompt({ failedModel, nextModel, errorMessage }) {
  return [
    `The previous model call on "${failedModel}" failed with: ${summarizeForLog(errorMessage, 220)}.`,
    `Continue on "${nextModel}" and recover autonomously.`,
    'If a previous plan depended on that failed call, adjust your approach and proceed end-to-end.',
    'Only ask the user for help if no safe path remains.'
  ].join(' ');
}

module.exports = {
  normalizeOutgoingMessage,
  clampRunContext,
  joinSentMessages,
  normalizeInterimText,
  buildBlankMessagingReplyPrompt,
  parseToolExecutionSummary,
  toolWorkDescription,
  summarizeRecentWork,
  hasFailureSignal,
  extractToolFailureMessage,
  buildDeterministicMessagingFallback,
  buildMessagingFailureScenario,
  buildDeterministicMessagingErrorReply,
  buildModelFailureLoopPrompt,
};
