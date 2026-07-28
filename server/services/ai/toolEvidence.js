'use strict';

// Classifies tool executions into run evidence (what changed, what failed, what
// is relevant to the user's answer) and builds the deterministic recovery
// context the engine feeds back to the model after a failure. Kept free of
// engine state so the classification rules are pure and unit testable.

const { compactToolResult } = require('./toolResult');
const { summarizeForLog } = require('./logFormat');
const { normalizeOutgoingMessage, clampRunContext } = require('./messagingFallback');
const {
  isClearlyReadOnlyShellCommand,
  isProgressToolCall,
} = require('./loop/progress_classification');

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
  { source: 'files', match: (name) => ['read_file', 'read_files', 'search_files', 'list_directory', 'write_file', 'edit_file', 'replace_file_range', 'code_navigate', 'query_structured_data'].includes(name) },
  { source: 'command', match: (name) => name === 'execute_command' },
  { source: 'skills', match: (name) => name.includes('skill') },
  { source: 'tasks', match: (name) => name === 'create_task' || name === 'update_task' || name === 'delete_task' || name === 'list_tasks' || name.includes('widget') },
  { source: 'messaging', match: (name) => name === 'send_message' },
  { source: 'data', match: (name) => name === 'read_health_data' },
  { source: 'vision', match: (name) => name === 'analyze_image' },
  { source: 'subagent', match: (name) => name.includes('subagent') },
];

const STATE_CHANGING_DEVICE_TOOLS = new Set([
  'android_install_apk',
  'android_long_press',
  'android_open_app',
  'android_open_intent',
  'android_press_key',
  'android_start_emulator',
  'android_stop_emulator',
  'android_swipe',
  'android_tap',
  'android_type',
  'desktop_click',
  'desktop_drag',
  'desktop_launch_app',
  'desktop_press_key',
  'desktop_scroll',
  'desktop_select_device',
  'desktop_type',
]);

function deriveEvidenceSource(name) {
  const rule = EVIDENCE_SOURCE_RULES.find((entry) => entry.match(name));
  return rule ? rule.source : 'tool';
}

function resolveDeclaredToolAccess(toolDefinition, toolArgs = {}) {
  const access = String(toolDefinition?.access || '').trim().toLowerCase();
  if (access === 'read' || access === 'write') return access;
  if (access !== 'dynamic_http_method') return null;

  const method = String(toolArgs?.method || toolArgs?.http_method || 'GET')
    .trim()
    .toUpperCase();
  return ['GET', 'HEAD', 'OPTIONS'].includes(method) ? 'read' : 'write';
}

function classifyToolExecution(
  toolName,
  toolArgs = {},
  result,
  errorMessage = '',
  toolDefinition = null,
) {
  const name = String(toolName || '');
  const stateChangingExact = new Set([
    'execute_command',
    'write_file',
    'edit_file',
    'replace_file_range',
    'send_interim_update',
    'send_message',
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
    'delegate_to_agent',
    'cancel_subagent',
  ]);

  const declaredAccess = resolveDeclaredToolAccess(toolDefinition, toolArgs);
  const evidenceSource = declaredAccess ? 'integration' : deriveEvidenceSource(name);

  // Any successful, substantive tool result can advance the run. This default
  // is deliberate: MCP, skills, and newly added integrations must not become
  // invisible to the churn guard just because their names were not added to a
  // central allow-list. Repetition detection still rejects unchanged retries.
  const evidenceRelevant = isSubstantiveProgressToolName(name);
  let directStateChange;
  if (name === 'execute_command' || name === 'android_shell') {
    directStateChange = !isClearlyReadOnlyShellCommand(toolArgs?.command || '');
  } else {
    directStateChange = declaredAccess === 'write'
      || STATE_CHANGING_DEVICE_TOOLS.has(name)
      || stateChangingExact.has(name);
  }
  const stateChanged = directStateChange
    || (name.startsWith('github_') && isProgressToolCall(name, toolArgs))
    || (name === 'http_request' && isProgressToolCall(name, toolArgs))
    || ['browser_click', 'browser_evaluate', 'browser_navigate', 'browser_type'].includes(name);

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
    stateChanged: stateChanged && !normalizedError,
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

function isSubstantiveProgressToolName(toolName = '') {
  const name = String(toolName || '').trim();
  if (!name) return false;
  if (name === 'send_message' || name === 'send_interim_update' || name === 'notify_user') return false;
  if (name === 'think' || name === 'activate_tools' || name === 'task_complete') return false;
  return true;
}

function clampResearchText(value, maxChars = 220) {
  const text = String(value || '').replace(/\s+/g, ' ').trim();
  if (!text) return '';
  if (text.length <= maxChars) return text;
  return `${text.slice(0, Math.max(0, maxChars - 1)).trimEnd()}…`;
}

function uniqueResearchTokens(values = [], { limit = 12 } = {}) {
  const seen = new Set();
  const tokens = [];
  for (const value of values) {
    const token = String(value || '').replace(/\s+/g, ' ').trim();
    if (!token) continue;
    const key = token.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    tokens.push(token);
    if (tokens.length >= limit) break;
  }
  return tokens;
}

// Research targets come from structured task analysis / goal contract only.
// Do not NLP-extract entity names from free text.
function collectResearchTargets(analysis = null, goalContext = null) {
  return uniqueResearchTokens([
    ...(Array.isArray(analysis?.research_targets) ? analysis.research_targets : []),
    ...(Array.isArray(goalContext?.researchTargets) ? goalContext.researchTargets : []),
  ], { limit: 8 });
}

function resolveResearchIntensity(analysis = null, goalContext = null) {
  const declaredDepth = String(
    analysis?.research_depth
    || analysis?.researchDepth
    || '',
  ).trim().toLowerCase();
  const declaredTargets = collectResearchTargets(analysis, goalContext);
  if (
    ['none', 'light', 'deep'].includes(declaredDepth)
    && !(declaredDepth === 'none' && declaredTargets.length > 0)
  ) {
    return declaredDepth;
  }

  const mode = String(analysis?.mode || '').trim().toLowerCase();
  const complexity = String(
    goalContext?.effectiveComplexity
    || analysis?.complexity
    || '',
  ).trim().toLowerCase();
  const autonomyLevel = String(
    goalContext?.effectiveAutonomyLevel
    || analysis?.autonomy_level
    || '',
  ).trim().toLowerCase();
  const completionConfidence = String(
    goalContext?.effectiveCompletionConfidence
    || analysis?.completion_confidence_required
    || '',
  ).trim().toLowerCase();
  const verificationNeed = String(analysis?.verification_need || '').trim().toLowerCase();
  const freshnessRisk = String(analysis?.freshness_risk || '').trim().toLowerCase();
  const planningDepth = String(analysis?.planning_depth || '').trim().toLowerCase();
  const targets = declaredTargets;

  if (mode === 'direct_answer' && verificationNeed === 'none' && freshnessRisk === 'none') {
    return 'none';
  }

  const needsExternalEvidence = (
    targets.length > 0
    || freshnessRisk === 'possible'
    || freshnessRisk === 'high'
  );
  if (!needsExternalEvidence) {
    return 'none';
  }

  const deepSignals = [
    mode === 'plan_execute',
    complexity === 'complex',
    autonomyLevel === 'high',
    completionConfidence === 'high',
    verificationNeed === 'required',
    freshnessRisk === 'high',
    planningDepth === 'deep',
    targets.length >= 2,
  ].filter(Boolean).length;

  if (deepSignals >= 2 || targets.length >= 2 || verificationNeed === 'required' || freshnessRisk === 'high') {
    return 'deep';
  }

  return 'light';
}

function isSuccessfulResearchExecution(item = {}) {
  if (!item || item.ok !== true) return false;
  if (!isSubstantiveProgressToolName(item.toolName)) return false;
  if (item.evidenceSource === 'messaging') return false;
  return Boolean(item.evidenceRelevant || item.dependsOnOutput || item.stateChanged);
}

function selectResearchEvidenceCandidates(toolExecutions = [], maxItems = 80) {
  const candidates = (Array.isArray(toolExecutions) ? toolExecutions : [])
    .map((execution, index) => ({ execution, evidenceIndex: index + 1 }))
    .filter(({ execution }) => isSuccessfulResearchExecution(execution));
  if (candidates.length <= maxItems) return candidates;

  const firstCount = Math.floor(maxItems / 4);
  return [
    ...candidates.slice(0, firstCount),
    ...candidates.slice(-(maxItems - firstCount)),
  ];
}

function summarizeResearchEvidenceCatalog(toolExecutions = [], maxItems = 80) {
  return selectResearchEvidenceCandidates(toolExecutions, maxItems)
    .map(({ execution, evidenceIndex }) => (
      `E${evidenceIndex}. ${execution.toolName} [${execution.evidenceSource || 'tool'}] :: ${clampRunContext(execution.summary || '', 160)}`
    ))
    .join('\n');
}

function researchExecutionSignature(execution = {}) {
  return JSON.stringify([
    String(execution.toolName || '').trim(),
    execution.input && typeof execution.input === 'object' ? execution.input : {},
  ]);
}

function assessResearchAdequacy({
  analysis = null,
  goalContext = null,
  toolExecutions = [],
} = {}) {
  const intensity = resolveResearchIntensity(analysis, goalContext);
  const targets = collectResearchTargets(analysis, goalContext);

  const successful = (Array.isArray(toolExecutions) ? toolExecutions : [])
    .filter(isSuccessfulResearchExecution);
  const uniqueEvidenceCandidateCount = new Set(
    successful.map((item) => researchExecutionSignature(item)),
  ).size;
  const structurallyReady = intensity === 'none' || uniqueEvidenceCandidateCount > 0;
  const missing = structurallyReady
    ? []
    : ['No successful source-bearing tool evidence is available for semantic review.'];
  const nextActions = [];
  if (!structurallyReady) {
    nextActions.push('Gather source-backed evidence before requesting completion.');
  } else if (intensity !== 'none') {
    nextActions.push('Have the completion judge map each requested target to concrete evidence entries and assess source quality.');
  }

  return {
    intensity,
    adequate: structurallyReady,
    structurallyReady,
    semanticReviewRequired: intensity !== 'none',
    evidenceCandidateCount: successful.length,
    uniqueEvidenceCandidateCount,
    targets,
    coveredTargets: [],
    primaryCoveredTargets: [],
    uncoveredTargets: intensity === 'none' ? [] : targets,
    primaryUncoveredTargets: intensity === 'none' ? [] : targets,
    missing,
    nextActions,
    reason: structurallyReady
      ? (intensity === 'none'
        ? 'No research burden for this run.'
        : 'Source candidates exist; the AI completion judge must still validate target coverage and source quality.')
      : clampResearchText(missing.join(' ') || 'Research evidence is still incomplete.', 320),
  };
}

function formatResearchAdequacyGuidance(assessment = null) {
  if (!assessment || assessment.intensity === 'none') return '';
  const lines = [
    assessment.structurallyReady
      ? 'Research self-check: source candidates exist, but semantic target coverage is not inferred from tool names, arguments, or token overlap.'
      : 'Research self-check: no successful source evidence is available yet.',
    assessment.reason ? `Gap: ${assessment.reason}` : '',
    assessment.nextActions?.length
      ? `Next safe steps:\n- ${assessment.nextActions.join('\n- ')}`
      : '',
    'The completion judge must explicitly map every requested target to supporting evidence and judge whether that evidence is primary, secondary, or merely contextual.',
  ];
  return lines.filter(Boolean).join('\n');
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
  assessResearchAdequacy,
  formatResearchAdequacyGuidance,
  gatheredNewEvidence,
  isSubstantiveProgressEvidence,
  isSubstantiveProgressToolName,
  resolveResearchIntensity,
  selectResearchEvidenceCandidates,
  summarizeResearchEvidenceCatalog,
  summarizeProgressToolExecutions,
  summarizeToolExecutions,
  summarizeAvailableTools,
  inferToolFailureMessage,
  buildAutonomousRecoveryContext,
  resolveDeclaredToolAccess,
};
