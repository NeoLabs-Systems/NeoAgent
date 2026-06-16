'use strict';

const { summarizeForLog } = require('../logFormat');

function latestFailedToolExecution(toolExecutions = []) {
  return [...toolExecutions].reverse().find((item) => item && item.ok === false) || null;
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

module.exports = {
  buildBlankAfterToolFailureGuidance,
  latestFailedToolExecution,
  shouldContinueAfterBlankToolFailure,
};
