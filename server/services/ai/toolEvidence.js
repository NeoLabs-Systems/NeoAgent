'use strict';

// Classifies tool executions into run evidence (what changed, what failed, what
// is relevant to the user's answer) and builds the deterministic recovery
// context the engine feeds back to the model after a failure. Kept free of
// engine state so the classification rules are pure and unit testable.

const { compactToolResult } = require('./toolResult');
const { summarizeForLog } = require('./logFormat');
const { normalizeOutgoingMessage, clampRunContext } = require('./messagingFallback');

// Ordered classification rules mapping a tool name to its evidence "source"
// bucket. First matching rule wins, so order is significant. Declared as data
// rather than a nested ternary so new tool families can be slotted in by adding
// a row instead of editing control flow.
const EVIDENCE_SOURCE_RULES = [
  { source: 'browser', match: (name) => name.startsWith('browser_') },
  { source: 'android', match: (name) => name.startsWith('android_') },
  { source: 'mcp', match: (name) => name.startsWith('mcp_') },
  { source: 'memory', match: (name) => name.startsWith('memory_') || name === 'session_search' },
  { source: 'search', match: (name) => name === 'web_search' },
  { source: 'http', match: (name) => name === 'http_request' },
  { source: 'files', match: (name) => ['read_file', 'search_files', 'list_directory', 'write_file', 'edit_file', 'code_navigate', 'query_structured_data'].includes(name) },
  { source: 'command', match: (name) => name === 'execute_command' },
  { source: 'skills', match: (name) => name.includes('skill') },
  { source: 'tasks', match: (name) => name === 'create_task' || name === 'update_task' || name === 'delete_task' || name === 'list_tasks' || name.includes('widget') },
  { source: 'messaging', match: (name) => name === 'send_message' || name === 'make_call' },
  { source: 'data', match: (name) => name.startsWith('recordings_') || name === 'read_health_data' },
  { source: 'vision', match: (name) => name === 'analyze_image' },
  { source: 'subagent', match: (name) => name.includes('subagent') },
];

function deriveEvidenceSource(name) {
  const rule = EVIDENCE_SOURCE_RULES.find((entry) => entry.match(name));
  return rule ? rule.source : 'tool';
}

function classifyToolExecution(toolName, toolArgs = {}, result, errorMessage = '') {
  const name = String(toolName || '');
  const evidenceRelevantPrefixes = ['browser_', 'android_'];
  const evidenceRelevantExact = new Set([
    'web_search',
    'http_request',
    'read_file',
    'search_files',
    'list_directory',
    'code_navigate',
    'query_structured_data',
    'session_search',
    'memory_recall',
    'analyze_image',
    'read_health_data',
    'recordings_list',
    'recordings_get',
    'recordings_search',
    'list_tasks',
    'wait_subagent',
  ]);
  const stateChangingExact = new Set([
    'execute_command',
    'write_file',
    'edit_file',
    'send_interim_update',
    'send_message',
    'make_call',
    'create_skill',
    'update_skill',
    'delete_skill',
    'create_task',
    'update_task',
    'delete_task',
    'create_ai_widget',
    'update_ai_widget',
    'delete_ai_widget',
    'save_widget_snapshot',
    'mcp_add_server',
    'mcp_remove_server',
    'spawn_subagent',
    'cancel_subagent',
  ]);

  const evidenceSource = deriveEvidenceSource(name);

  const evidenceRelevant = evidenceRelevantExact.has(name)
    || evidenceRelevantPrefixes.some((prefix) => name.startsWith(prefix));
  const stateChanged = stateChangingExact.has(name)
    || name.startsWith('android_')
    || ['browser_click', 'browser_type', 'browser_evaluate'].includes(name);

  let normalizedError = String(errorMessage || result?.error || '').trim();
  if (!normalizedError && name === 'execute_command' && result && typeof result === 'object') {
    if (result.timedOut) {
      normalizedError = `Command timed out after ${result.durationMs || 'unknown'} ms`;
    } else if (result.killed || result.signal) {
      normalizedError = 'Command was killed before it finished';
    } else if (typeof result.exitCode === 'number' && result.exitCode !== 0) {
      normalizedError = summarizeForLog(result.stderr || result.stdout || `Command exited with code ${result.exitCode}`, 220);
    }
  }

  if (!normalizedError && result && typeof result === 'object') {
    const nestedResult = result.result && typeof result.result === 'object' && !Array.isArray(result.result)
      ? result.result
      : null;
    const detail = normalizeOutgoingMessage(
      result.reason
      || result.message
      || nestedResult?.reason
      || nestedResult?.message
      || ''
    );

    if (result.skipped === true || nestedResult?.skipped === true) {
      normalizedError = detail || 'Tool reported skipped outcome.';
    } else if (result.success === false || nestedResult?.success === false) {
      normalizedError = detail || 'Tool reported success=false.';
    } else if (result.sent === false || nestedResult?.sent === false) {
      normalizedError = detail || 'Tool reported sent=false.';
    }
  }

  return {
    toolName: name,
    ok: !normalizedError,
    error: normalizedError,
    evidenceSource,
    evidenceRelevant,
    stateChanged,
    dependsOnOutput: true,
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

function summarizeAvailableTools(tools = [], { exclude = [] } = {}) {
  const excluded = new Set((Array.isArray(exclude) ? exclude : [exclude]).filter(Boolean));
  return tools
    .map((tool) => String(tool?.name || '').trim())
    .filter((name) => name && !excluded.has(name))
    .slice(0, 24)
    .join(', ');
}

function inferToolFailureMessage(toolName, result) {
  const explicitError = normalizeOutgoingMessage(result?.error || '');
  if (explicitError) return explicitError;

  if (!result || typeof result !== 'object') return '';

  if (toolName === 'execute_command') {
    if (result.timedOut) {
      return `Command timed out after ${result.durationMs || 'unknown'} ms`;
    }
    if (result.killed || result.signal) {
      return 'Command was killed before it finished';
    }
    if (typeof result.exitCode === 'number' && result.exitCode !== 0) {
      return summarizeForLog(result.stderr || result.stdout || `Command exited with code ${result.exitCode}`, 220);
    }
  }

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

function buildAutonomousRecoveryContext({ err, toolExecutions = [], tools = [], userMessage, visibleMessageSent = false }) {
  const lastFailure = [...toolExecutions].reverse().find((item) => !item.ok);
  const alternativeTools = summarizeAvailableTools(tools, { exclude: lastFailure?.toolName || null });
  const parts = [
    'This is an internal recovery retry for the same user task. Continue the task instead of stopping.',
    userMessage ? `Original task: ${clampRunContext(userMessage, 260)}` : '',
    lastFailure?.toolName ? `Previous attempt failed on tool: ${lastFailure.toolName}.` : '',
    lastFailure?.error ? `Concrete failure: ${summarizeForLog(lastFailure.error, 260)}.` : '',
    err?.message ? `Run-level error after that failure: ${summarizeForLog(err.message, 220)}.` : '',
    'Do not send a blocker message just because one tool path failed.',
    'Use a different safe approach if available: alternate tool, different query, browser path, HTTP fetch, file/code inspection, or command verification.',
    visibleMessageSent ? 'A user-facing message was already sent in a previous internal attempt. Continue silently unless you have a materially new finished result or a real external blocker.' : '',
    alternativeTools ? `Other available tools in this run: ${alternativeTools}.` : '',
    'Only stop if the remaining problem truly requires an external dependency or user action outside this run.'
  ];
  return parts.filter(Boolean).join(' ');
}

module.exports = {
  classifyToolExecution,
  deriveEvidenceSource,
  summarizeToolExecutions,
  summarizeAvailableTools,
  inferToolFailureMessage,
  buildAutonomousRecoveryContext,
};
