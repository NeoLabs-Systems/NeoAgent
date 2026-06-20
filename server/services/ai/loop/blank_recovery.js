'use strict';

const { summarizeForLog } = require('../logFormat');
const { isInternalToolingFailure, normalizeOutgoingMessage } = require('../messagingFallback');

function latestFailedToolExecution(toolExecutions = []) {
  return [...toolExecutions].reverse().find((item) => item && item.ok === false) || null;
}

function isRecoverableInternalToolFailure(toolExecution = null) {
  if (!toolExecution || toolExecution.ok !== false) return false;
  const failure = String(toolExecution.error || toolExecution.summary || toolExecution.status || '').trim();
  return isInternalToolingFailure(failure);
}

function shouldContinueAfterBlankToolFailure({
  lastContent = '',
  failedStepCount = 0,
  remainingIterations = 0,
  toolExecutions = [],
} = {}) {
  return !String(lastContent || '').trim()
    && Number(failedStepCount || 0) > 0
    && Number(remainingIterations || 0) > 0
    && Boolean(latestFailedToolExecution(toolExecutions));
}

function shouldContinueAfterRecoverableToolFailure({
  lastContent = '',
  remainingIterations = 0,
  toolExecutions = [],
} = {}) {
  if (Number(remainingIterations || 0) <= 0) return false;
  const failedExecution = latestFailedToolExecution(toolExecutions);
  if (!isRecoverableInternalToolFailure(failedExecution)) return false;
  const visible = normalizeOutgoingMessage(lastContent || '');
  if (!visible) return false;
  return /\b(blocked|could not|cannot|can't|do not have a confirmed finished result|not found|missing|internal tool issue)\b/i.test(visible);
}

function buildBlankAfterToolFailureGuidance(toolExecutions = []) {
  const failedExecution = latestFailedToolExecution(toolExecutions);
  if (!failedExecution) return '';
  const toolName = failedExecution.toolName || failedExecution.tool || 'the previous tool';
  const failure = failedExecution.error || failedExecution.summary || failedExecution.status || 'unknown failure';
  return [
    `The previous tool "${toolName}" failed with: ${summarizeForLog(failure, 240)}.`,
    'The latest assistant turn returned no user-facing answer and no tool call, so the task is not terminal.',
    'Continue with the next safe recovery action: retry with corrected arguments, use another available tool, verify from existing evidence, or report a real blocker only if no autonomous path remains.',
  ].join(' ');
}

function buildRecoverableToolFailureGuidance(toolExecutions = []) {
  const failedExecution = latestFailedToolExecution(toolExecutions);
  if (!failedExecution) return '';
  const toolName = failedExecution.toolName || failedExecution.tool || 'the previous tool';
  const failure = failedExecution.error || failedExecution.summary || failedExecution.status || 'unknown failure';
  return [
    `The latest blocker came from an internal tool/path issue in "${toolName}": ${summarizeForLog(failure, 240)}.`,
    'This is a recoverable execution problem, not a final user-facing blocker yet.',
    'Do another autonomous recovery step now: locate the correct file or directory, switch to the right workspace path, use list_directory/search_files to discover the target, or rely on user-provided logs if the file only exists on another server.',
    'Do not send a blocker reply until those recovery steps are exhausted.',
  ].join(' ');
}

module.exports = {
  buildBlankAfterToolFailureGuidance,
  buildRecoverableToolFailureGuidance,
  isRecoverableInternalToolFailure,
  latestFailedToolExecution,
  shouldContinueAfterBlankToolFailure,
  shouldContinueAfterRecoverableToolFailure,
};
