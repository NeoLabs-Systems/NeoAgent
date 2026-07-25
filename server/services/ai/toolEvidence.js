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
  { source: 'messaging', match: (name) => name === 'send_message' || name === 'make_call' },
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
  if (name === 'send_message' || name === 'send_interim_update' || name === 'make_call' || name === 'notify_user') return false;
  if (name === 'think' || name === 'activate_tools' || name === 'task_complete') return false;
  return true;
}

const PRIMARY_RESEARCH_SOURCES = new Set([
  'browser',
  'http',
  'integration',
  'files',
  'command',
  'mcp',
  'android',
  'data',
  'vision',
  'skills',
  'subagent',
]);

const SECONDARY_RESEARCH_SOURCES = new Set([
  'search',
  'memory',
]);

// External/source-backed tools only. Local file/edit/shell work must not
// inherit a research burden just because inspection tools are available.
const RESEARCH_TOOL_HINTS = new Set([
  'web_search',
  'http_request',
  'browser_navigate',
  'browser_open',
  'browser_click',
  'browser_type',
  'browser_snapshot',
  'browser_evaluate',
  'analyze_image',
  'spawn_subagent',
  'delegate_to_agent',
]);

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

// Structural target extraction only: quoted spans and product-like proper names.
// No phrase-based intent filters.
function isProductLikeToken(token = '') {
  const value = String(token || '').trim();
  if (!value) return false;
  if (/[0-9]/.test(value)) return true;
  if (/[-_/]/.test(value)) return true;
  if (/[a-z][A-Z]/.test(value)) return true;
  return false;
}

function extractResearchTargets(text = '') {
  const raw = String(text || '');
  if (!raw.trim()) return [];

  const targets = [];
  const quoted = raw.match(/["“”'‘’`]([^"“”'‘’`]{2,80})["“”'‘’`]/g) || [];
  for (const match of quoted) {
    const cleaned = match.replace(/^["“”'‘’`]|["“”'‘’`]$/g, '').trim();
    if (cleaned) targets.push(cleaned);
  }

  // Require each subsequent token to start with a capital letter or digit so
  // ordinary sentence fragments ("Implement the pause...") do not become targets.
  const productish = raw.match(
    /\b[A-Z][A-Za-z0-9+./-]*(?:[ -][A-Z0-9][A-Za-z0-9+./-]*){0,5}\b/g,
  ) || [];
  for (const match of productish) {
    const cleaned = match.replace(/\s+/g, ' ').trim();
    const parts = cleaned.split(/\s+/).filter(Boolean);
    if (parts.length === 0) continue;
    if (parts.length === 1) {
      if (!isProductLikeToken(parts[0]) || parts[0].length < 4) continue;
    } else if (!parts.some(isProductLikeToken) && parts.length < 2) {
      continue;
    } else if (!parts.some(isProductLikeToken) && parts.every((part) => part.length <= 3)) {
      continue;
    }
    // Drop pure sentence openers with no product-like signal.
    if (parts.length >= 2 && !parts.some(isProductLikeToken)) {
      // Keep multi-token proper names such as brand + model family only when
      // at least one token is long enough to be a meaningful entity name.
      if (!parts.some((part) => part.length >= 5)) continue;
    }
    targets.push(cleaned);
  }

  return uniqueResearchTokens(targets, { limit: 8 });
}

function collectResearchTargets(analysis = null, goalContext = null) {
  const explicit = uniqueResearchTokens([
    ...(Array.isArray(analysis?.research_targets) ? analysis.research_targets : []),
    ...(Array.isArray(goalContext?.researchTargets) ? goalContext.researchTargets : []),
  ], { limit: 8 });
  if (explicit.length > 0) return explicit;

  const goalText = [
    goalContext?.effectiveGoal,
    analysis?.goal,
    ...(Array.isArray(goalContext?.successCriteria) ? goalContext.successCriteria : []),
    ...(Array.isArray(analysis?.success_criteria) ? analysis.success_criteria : []),
  ].filter(Boolean).join(' ');

  return extractResearchTargets(goalText);
}

function hasResearchToolHint(analysis = null) {
  const tools = Array.isArray(analysis?.suggested_tools) ? analysis.suggested_tools : [];
  return tools.some((name) => {
    const tool = String(name || '').trim().toLowerCase();
    if (!tool) return false;
    if (RESEARCH_TOOL_HINTS.has(tool)) return true;
    return tool.startsWith('browser_')
      || tool.startsWith('mcp_')
      || tool === 'web_search'
      || tool.includes('web_search')
      || tool.includes('http_request');
  });
}

function resolveResearchIntensity(analysis = null, goalContext = null) {
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
  const targets = collectResearchTargets(analysis, goalContext);
  const researchToolHint = hasResearchToolHint(analysis);

  if (mode === 'direct_answer' && verificationNeed === 'none' && freshnessRisk === 'none') {
    return 'none';
  }

  // External/source-backed work only. Pure local implementation tasks must not
  // inherit a research burden just because they are complex or multi-step.
  const needsExternalEvidence = (
    targets.length > 0
    || researchToolHint
    || freshnessRisk === 'possible'
    || freshnessRisk === 'high'
    || verificationNeed === 'required'
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

function isPrimaryResearchSource(source = '') {
  return PRIMARY_RESEARCH_SOURCES.has(String(source || '').trim().toLowerCase());
}

function isSecondaryResearchSource(source = '') {
  return SECONDARY_RESEARCH_SOURCES.has(String(source || '').trim().toLowerCase());
}

function executionMentionsTarget(execution = {}, target = '') {
  const needle = String(target || '').trim().toLowerCase();
  if (!needle) return false;
  const haystack = [
    execution.summary,
    execution.toolName,
    execution.evidenceSource,
    JSON.stringify(execution.input || {}),
  ].join(' ').toLowerCase();
  if (haystack.includes(needle)) return true;

  const tokens = needle
    .split(/[^a-z0-9+]+/i)
    .map((token) => token.trim())
    .filter((token) => token.length >= 3);
  if (tokens.length === 0) return false;
  const matched = tokens.filter((token) => haystack.includes(token)).length;
  return matched >= Math.min(2, tokens.length);
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
  const primary = successful.filter((item) => isPrimaryResearchSource(item.evidenceSource));
  const secondary = successful.filter((item) => isSecondaryResearchSource(item.evidenceSource));
  const coveredTargets = targets.filter((target) => (
    successful.some((item) => executionMentionsTarget(item, target))
  ));
  const primaryCoveredTargets = targets.filter((target) => (
    primary.some((item) => executionMentionsTarget(item, target))
  ));
  const uncoveredTargets = targets.filter((target) => !coveredTargets.includes(target));
  const primaryUncoveredTargets = targets.filter((target) => !primaryCoveredTargets.includes(target));

  const requiredPrimarySources = intensity === 'deep'
    ? (targets.length > 0 ? Math.min(4, targets.length) : 2)
    : intensity === 'light'
      ? 1
      : 0;
  const requiredSecondarySources = intensity === 'deep' ? 1 : 0;
  const requiredTargetCoverage = intensity === 'deep'
    ? targets.length
    : intensity === 'light'
      ? Math.min(targets.length, 1)
      : 0;
  const requiredPrimaryTargetCoverage = intensity === 'deep'
    ? targets.length
    : 0;

  const missing = [];
  if (primary.length < requiredPrimarySources) {
    missing.push(
      `Need ${requiredPrimarySources} primary source open/fetch/inspect step(s); have ${primary.length}.`,
    );
  }
  if (secondary.length < requiredSecondarySources && primary.length < requiredPrimarySources) {
    missing.push('Need at least one search lead before finishing deep research.');
  }
  if (targets.length > 0 && coveredTargets.length < requiredTargetCoverage) {
    missing.push(
      `Need evidence for: ${uncoveredTargets.slice(0, 4).join('; ') || targets.slice(0, 4).join('; ')}.`,
    );
  }
  if (targets.length > 0 && primaryCoveredTargets.length < requiredPrimaryTargetCoverage) {
    missing.push(
      `Need primary-source evidence for: ${primaryUncoveredTargets.slice(0, 4).join('; ') || targets.slice(0, 4).join('; ')}.`,
    );
  }
  if (intensity === 'deep' && primary.length === 0 && secondary.length > 0) {
    missing.push('Search snippets alone are not enough; open primary sources for the key claims.');
  }
  if (intensity === 'light' && primary.length === 0 && secondary.length === 0) {
    missing.push('Need at least one successful search or primary-source check before finishing.');
  }

  const adequate = intensity === 'none' ? true : missing.length === 0;
  const nextActions = [];
  if (!adequate) {
    if (primaryUncoveredTargets.length > 0) {
      nextActions.push(
        `Open or fetch primary sources for each remaining target: ${primaryUncoveredTargets.slice(0, 4).join('; ')}.`,
      );
    } else if (uncoveredTargets.length > 0) {
      nextActions.push(
        `Research each remaining target separately: ${uncoveredTargets.slice(0, 4).join('; ')}.`,
      );
    }
    if (primary.length < requiredPrimarySources) {
      nextActions.push('Open or fetch primary pages/docs for the remaining claims instead of guessing from memory or snippets.');
    }
    if (secondary.length === 0 && intensity === 'deep') {
      nextActions.push('Run targeted searches, then open the strongest sources.');
    }
  }

  return {
    intensity,
    adequate,
    requiredPrimarySources,
    requiredSecondarySources,
    requiredTargetCoverage,
    requiredPrimaryTargetCoverage,
    primarySourceCount: primary.length,
    secondarySourceCount: secondary.length,
    targets,
    coveredTargets,
    primaryCoveredTargets,
    uncoveredTargets,
    primaryUncoveredTargets,
    missing,
    nextActions,
    reason: adequate
      ? (intensity === 'none'
        ? 'No research burden for this run.'
        : 'Research evidence covers the requested targets.')
      : clampResearchText(missing.join(' ') || 'Research evidence is still incomplete.', 320),
  };
}

function formatResearchAdequacyGuidance(assessment = null) {
  if (!assessment || assessment.adequate !== false) return '';
  const lines = [
    'Research self-check: evidence is still incomplete for this run.',
    assessment.reason ? `Gap: ${assessment.reason}` : '',
    assessment.nextActions?.length
      ? `Next safe steps:\n- ${assessment.nextActions.join('\n- ')}`
      : '',
    'Do not complete with memory, guesses, or a partial comparison while these gaps remain. Gather the missing evidence first, or return a blocker that names exactly what could not be verified.',
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
  extractResearchTargets,
  formatResearchAdequacyGuidance,
  gatheredNewEvidence,
  isSubstantiveProgressEvidence,
  isSubstantiveProgressToolName,
  resolveResearchIntensity,
  summarizeProgressToolExecutions,
  summarizeToolExecutions,
  summarizeAvailableTools,
  inferToolFailureMessage,
  buildAutonomousRecoveryContext,
  resolveDeclaredToolAccess,
};
