'use strict';

// Classifies tool executions into run evidence: what changed, what failed, and
// what is relevant to the user's answer. The runaway guards and progress
// narration read it. Kept free of engine state so the rules are pure and unit
// testable.

const { commandFailureMessage } = require('./commandOutcome');
const { compactToolResult } = require('./toolResult');
const { summarizeForLog } = require('./logFormat');
const { normalizeOutgoingMessage, clampRunContext } = require('./messagingFallback');
const { changesState, resolveToolMeta } = require('./tools/metadata');

function classifyToolExecution(
  toolName,
  toolArgs = {},
  result,
  errorMessage = '',
  toolDefinition = null,
) {
  const name = String(toolName || '');
  const meta = resolveToolMeta(name, toolDefinition);

  const normalizedError = String(errorMessage || inferToolFailureMessage(name, result)).trim();

  return {
    toolName: name,
    ok: !normalizedError,
    error: normalizedError,
    evidenceSource: meta.group,
    // Any successful, substantive tool result can advance the run. This default
    // is deliberate: MCP, skills, and newly added integrations must not become
    // invisible to the churn guard. Repetition detection still rejects
    // unchanged retries.
    evidenceRelevant: isSubstantiveProgressToolName(name),
    stateChanged: changesState(meta, toolArgs) && !normalizedError,
    summary: compactToolResult(name, toolArgs, result || { error: errorMessage || 'Tool failed' }, {
      softLimit: 500,
      hardLimit: 900,
    }),
  };
}

function summarizeToolExecutions(toolExecutions = [], maxItems = 10) {
  return toolExecutions.slice(-maxItems).map((item, index) => {
    const status = item.ok ? 'ok' : `error=${item.error}`;
    return `${index + 1}. ${item.toolName} [${item.evidenceSource}] ${status} :: ${clampRunContext(item.summary || '', 220)}`;
  }).join('\n');
}

// A read-only turn that pulls in NEW information is real progress, even though
// it changes no state — research, browsing, reading, and searching are how an
// agent makes headway on "find out X" tasks. Treating those as "no progress"
// (and force-wrapping the run) is what guillotines legitimate research. Genuine
// churn — failed calls, pure `think`, or re-running an identical call that
// returns an unchanged result — is excluded, so the read-only guard still fires
// on real spinning.
function gatheredNewEvidence(execution, repetitionObservation = null) {
  if (!execution || execution.ok !== true) return false;
  if (!execution.evidenceRelevant) return false;
  if (repetitionObservation && repetitionObservation.unchangedCount >= 2) return false;
  return true;
}

// Talking to the user and managing the run's own tools report progress or set
// it up; neither is progress on the task.
function isSubstantiveProgressToolName(toolName = '') {
  const name = String(toolName || '').trim();
  if (!name) return false;
  const { group, sideEffect } = resolveToolMeta(name);
  return group !== 'control' && sideEffect !== 'message';
}

function isSubstantiveProgressEvidence(item = {}) {
  if (!isSubstantiveProgressToolName(item.toolName)) return false;
  if (item.evidenceSource === 'messaging') return false;
  return Boolean(item.evidenceRelevant || item.stateChanged || item.error);
}

function summarizeProgressToolExecutions(toolExecutions = [], maxItems = 10) {
  return summarizeToolExecutions(
    toolExecutions.filter(isSubstantiveProgressEvidence),
    maxItems,
  );
}

function inferToolFailureMessage(toolName, result) {
  const explicitError = normalizeOutgoingMessage(result?.error || '');
  if (explicitError) return explicitError;

  if (!result || typeof result !== 'object') return '';
  // Choosing to say nothing is an answer, not a failed send.
  if (result.reason === 'no_response') return '';

  const nested = result.result && typeof result.result === 'object' ? result.result : {};
  const failedReport = Array.isArray(result.report) ? result.report.find((entry) => entry?.success === false) : null;
  if (result.success === false || nested.success === false || result.sent === false || nested.sent === false || failedReport) {
    return summarizeForLog(String(result.reason || result.message || nested.error || nested.reason || failedReport?.error || failedReport?.note || 'Tool reported an unsuccessful outcome.'), 240);
  }
  if (result.skipped === true || nested.skipped === true) return String(result.reason || result.message || 'Tool reported skipped outcome.');
  if (resolveToolMeta(toolName).group === 'shell') return commandFailureMessage(result);

  if (toolName === 'http_request' && typeof result.status === 'number' && result.status >= 400) {
    const bodySnippet = normalizeOutgoingMessage(result.body || '');
    return summarizeForLog(
      bodySnippet
        ? `HTTP request returned status ${result.status}: ${bodySnippet}`
        : `HTTP request returned status ${result.status}`,
      240
    );
  }

  return '';
}

module.exports = {
  classifyToolExecution,
  gatheredNewEvidence,
  isSubstantiveProgressEvidence,
  summarizeProgressToolExecutions,
  inferToolFailureMessage,
};
