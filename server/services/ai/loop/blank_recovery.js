'use strict';

const { summarizeForLog } = require('../logFormat');

// A turn that returned neither text nor a tool call. When a failed tool caused
// it, the failure itself is the most useful context; otherwise the model just
// needs to be told the turn was empty and that the task is not finished.
function buildBlankOutputGuidance(toolExecutions = []) {
  const failed = [...toolExecutions].reverse().find((item) => item && item.ok === false);
  if (failed) {
    const toolName = failed.toolName || failed.tool || 'the previous tool';
    const failure = failed.error || failed.summary || failed.status || 'unknown failure';
    return [
      `The previous tool "${toolName}" failed with: ${summarizeForLog(failure, 240)}.`,
      'The latest assistant turn returned no user-facing answer and no tool call, so the task is not terminal.',
      'Continue with the next safe recovery action now: retry with corrected arguments, use another available tool, verify from existing evidence, or report a real blocker only if no autonomous path remains.',
      'Do not invent a finished result. Prefer a concrete recovery step or a truthful partial answer over silence.',
    ].join(' ');
  }
  return [
    'The latest assistant turn returned no user-facing answer and no tool call, so the task is not terminal.',
    'Take the next concrete action now: call the tool you need, or give a complete final answer if the work is already evidenced.',
    'Do not repeat an empty turn and do not claim a result you have not produced.',
  ].join(' ');
}

module.exports = {
  buildBlankOutputGuidance,
};
