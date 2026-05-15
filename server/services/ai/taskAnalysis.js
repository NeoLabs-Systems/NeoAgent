const ANALYSIS_MODES = ['direct_answer', 'execute', 'plan_execute'];
const VERIFICATION_STATUSES = ['verified', 'needs_revision', 'insufficient_evidence'];
const TASK_ANALYSIS_SUGGESTED_TOOLS_LIMIT = 12;
const TASK_ANALYSIS_SUCCESS_CRITERIA_LIMIT = 8;
const PLAN_STEP_SUGGESTED_TOOLS_LIMIT = 8;
const PLAN_STEP_SUCCESS_CRITERIA_LIMIT = 6;
const EXECUTION_PLAN_SUCCESS_CRITERIA_LIMIT = 10;
const EXECUTION_PLAN_VERIFICATION_FOCUS_LIMIT = 8;
const VERIFICATION_MISSING_EVIDENCE_LIMIT = 8;
const VERIFICATION_EVIDENCE_SOURCES_LIMIT = 12;
const TASK_ANALYSIS_CONFIDENCE_WITH_DRAFT = 0.8;
const TASK_ANALYSIS_CONFIDENCE_DEFAULT = 0.55;
const VERIFICATION_CONFIDENCE_VERIFIED = 0.85;
const VERIFICATION_CONFIDENCE_DEFAULT = 0.5;
const JSON_ONLY_RESPONSE_RULE = 'Return JSON only. No markdown, no prose, no code fences.';
const ANALYSIS_SCHEMA_EXAMPLE = {
  mode: 'execute',
  needs_verification: true,
  draft_reply: '',
  goal: 'Answer the user accurately.',
  success_criteria: ['Final reply is correct and specific.'],
  suggested_tools: ['web_search', 'browser_navigate'],
};
const PLAN_SCHEMA_EXAMPLE = {
  steps: [
    {
      title: 'Gather evidence',
      objective: 'Use the most relevant tools to collect the needed facts.',
      suggested_tools: ['web_search'],
      success_criteria: ['Enough evidence is collected to answer safely.'],
    },
  ],
  success_criteria: ['The final answer is correct and verifiable.'],
  verification_focus: ['Confirm the most time-sensitive claim before replying.'],
};
const ANALYSIS_PROMPT_INSTRUCTIONS = [
  'Choose the lightest routing mode that still handles the task well.',
  'Use mode="direct_answer" only when a final user-facing reply can be given immediately without tool work.',
  'Use mode="execute" for normal tool-driven work without a separate planning step.',
  'Use mode="plan_execute" only when the task is genuinely multi-step, broad, or coordination-heavy.',
  'Set needs_verification=true when the final answer should be checked against tool evidence before it is sent.',
  'Set goal to a concise restatement of what the user is asking for in this message. Never leave goal empty.',
  'Keep goal and success_criteria short and practical.',
  'suggested_tools are optional hints, not a required plan.',
];
const PLAN_PROMPT_INSTRUCTIONS = [
  'Create a concise execution plan for the current task.',
  'Focus on practical steps, success criteria, and what needs verification.',
  'Prefer steps that can be executed in parallel when they are independent. Do not serialize unrelated searches or inspections.',
  'Prefer native integrations and structured tools before browser automation or generic shell commands.',
  'For external actions, include a step to draft or confirm before sending unless the user already gave explicit current-session approval.',
  'For code or config changes, include inspection, scoped edit, and verification steps.',
  'For tasks that run later, make the future prompt self-contained and include notification conditions.',
];
const VERIFIER_PROMPT_INSTRUCTIONS = [
  'Verify whether the draft final reply is adequately supported by the gathered evidence.',
  'If the evidence is insufficient, revise the reply so it states the uncertainty clearly instead of guessing.',
  'Cross-check every concrete claim against tool status and output. Remove or rewrite claims that are contradicted by the evidence.',
  'A non-zero execute_command exit code means partial or failed shell evidence. Do not treat later sections of a chained shell command as observed unless they were verified separately.',
  'A successful send_message or make_call means outbound delivery succeeded in this run unless a later messaging tool failed.',
  'Any claim that an outbound action already happened (sent/submitted/called/"already done") must be backed by a successful outbound tool execution in this run. If not backed, rewrite the reply to "not sent yet" and provide a draft or next concrete step.',
  'A successful create_task or update_task tool call is required before claiming a task schedule changed.',
  'If external evidence conflicts with memory, history, or another tool result, preserve the uncertainty instead of flattening it into a single confident claim.',
];
const EXECUTION_GUIDANCE_ACTION_LINES = [
  'Act end-to-end. Run independent searches or inspections in parallel when possible. Prefer native integration tools and structured APIs over browser automation or shell scraping. Use exact IDs and required parameters; list or search first when you do not have them.',
  'Use send_interim_update sparingly when a short real update or question would help.',
  'When you must ask for missing required user input, ask once, then wait for the reply instead of re-asking in the same run.',
  'For outbound messages, calls, emails, shared edits, installs, restarts, or task mutations, verify the action result before claiming it happened. If user confirmation is required and missing, draft or ask instead of sending.',
  'Retry with alternative tools or approaches when one path fails. If evidence is still insufficient, say so explicitly instead of guessing.',
];

function buildVerifierSchemaExample(finalReply) {
  return {
    status: 'verified',
    notes: 'The reply is grounded in the available evidence.',
    evidence_sources: ['web_search'],
    missing_evidence: [],
    final_reply: finalReply || '',
    confidence: 0.83,
  };
}

function clampConfidence(value, fallback = 0.5) {
  const num = Number(value);
  if (!Number.isFinite(num)) return fallback;
  return Math.max(0, Math.min(1, num));
}

function normalizeStringList(value, { limit = 8 } = {}) {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => String(item || '').trim())
    .filter(Boolean)
    .slice(0, limit);
}

function selectPlanSteps(raw, fallback) {
  if (Array.isArray(raw?.steps)) return raw.steps;
  if (Array.isArray(fallback?.steps)) return fallback.steps;
  return [];
}

function pickEnum(value, allowed, fallback) {
  const normalized = String(value || '').trim().toLowerCase();
  return allowed.includes(normalized) ? normalized : fallback;
}

function resolveAliasedValue(raw, fallback, snakeKey, camelKey, defaultValue) {
  return raw?.[snakeKey]
    || raw?.[camelKey]
    || fallback?.[snakeKey]
    || fallback?.[camelKey]
    || defaultValue;
}

function resolveAliasedStringList(raw, fallback, snakeKey, camelKey, limit) {
  return normalizeStringList(resolveAliasedValue(raw, fallback, snakeKey, camelKey, []), { limit });
}

function resolveAliasedText(raw, fallback, snakeKey, camelKey, defaultValue = '') {
  return String(resolveAliasedValue(raw, fallback, snakeKey, camelKey, defaultValue)).trim();
}

function composeJsonPrompt(lines, schema) {
  return [
    ...lines,
    'Schema:',
    JSON.stringify(schema, null, 2),
  ].filter(Boolean).join('\n\n');
}

function formatBulletSection(label, items) {
  if (!Array.isArray(items) || items.length === 0) return '';
  return `${label}:\n- ${items.join('\n- ')}`;
}

function formatPlannedSteps(steps = []) {
  if (!Array.isArray(steps) || steps.length === 0) return '';
  return `Planned steps:\n${steps.map((step, index) => {
    const tools = step.suggested_tools?.length ? ` [tools: ${step.suggested_tools.join(', ')}]` : '';
    return `${index + 1}. ${step.title}${tools}`;
  }).join('\n')}`;
}

function formatRuntimeCapabilityHealth(capabilityHealth) {
  return capabilityHealth ? `Runtime capability health:\n${capabilityHealth}` : '';
}

function formatAvailableToolsLine(toolNames) {
  return toolNames ? `Available tools/capabilities: ${toolNames}` : '';
}

function formatEvidenceSourcesLine(evidenceSources) {
  return evidenceSources?.length
    ? `Evidence sources used: ${evidenceSources.join(', ')}`
    : 'Evidence sources used: none';
}

function formatExistingSuccessCriteriaLine(successCriteria) {
  return successCriteria?.length
    ? `Existing success criteria:\n- ${successCriteria.join('\n- ')}`
    : '';
}

function formatSuggestedToolsFromAnalysisLine(suggestedTools) {
  return suggestedTools?.length
    ? `Suggested tools from task analysis: ${suggestedTools.join(', ')}`
    : '';
}

function resolveAliasedBoolean(raw, fallback, snakeKey, camelKey, defaultValue = false) {
  const value = resolveAliasedValue(raw, fallback, snakeKey, camelKey, defaultValue);
  if (typeof value === 'boolean') return value;
  if (typeof value === 'string') {
    const normalized = value.trim().toLowerCase();
    if (normalized === 'true') return true;
    if (normalized === 'false') return false;
  }
  return Boolean(value);
}

function planningDepthForMode(mode) {
  return mode === 'plan_execute' ? 'deep' : mode === 'direct_answer' ? 'none' : 'light';
}

function verificationNeedFor({ mode, needsVerification, hasDraftReply }) {
  if (needsVerification === true) return 'light';
  if (needsVerification === false) {
    return mode === 'direct_answer' && hasDraftReply ? 'none' : 'light';
  }
  return mode === 'direct_answer' && hasDraftReply ? 'none' : 'light';
}

function freshnessRiskFor({ verificationNeed }) {
  return verificationNeed === 'required' ? 'possible' : 'none';
}

function promoteAnalysisMode(initialMode, { verificationNeed, freshnessRisk, draftReply, planningDepth }) {
  let mode = initialMode;
  if (mode === 'direct_answer' && (verificationNeed !== 'none' || freshnessRisk !== 'none' || !draftReply)) {
    mode = planningDepth === 'deep' ? 'plan_execute' : 'execute';
  }
  if (mode === 'execute' && planningDepth === 'deep') {
    mode = 'plan_execute';
  }
  return mode;
}

function isDirectAnswerEligibleAnalysis(analysis) {
  if (!analysis || typeof analysis !== 'object') return false;
  const draftReply = String(analysis.draft_reply || '').trim();
  const promotedMode = promoteAnalysisMode(analysis.mode, {
    verificationNeed: analysis.verification_need,
    freshnessRisk: analysis.freshness_risk,
    draftReply,
    planningDepth: analysis.planning_depth,
  });

  return promotedMode === 'direct_answer' && !analysis.needs_subagents && Boolean(draftReply);
}

function extractJsonCandidate(text) {
  const raw = String(text || '').trim();
  if (!raw) return null;
  const start = raw.indexOf('{');
  const end = raw.lastIndexOf('}');
  if (start === -1 || end === -1 || end <= start) return null;
  return raw.slice(start, end + 1);
}

function parseJsonObject(text) {
  const candidate = extractJsonCandidate(text);
  if (!candidate) return null;

  try {
    const parsed = JSON.parse(candidate);
    return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : null;
  } catch {
    return null;
  }
}

function summarizeTools(tools = [], limit = 80) {
  const names = tools
    .map((tool) => String(tool?.name || '').trim())
    .filter(Boolean);

  if (names.length <= limit) return names;
  return [...names.slice(0, limit), `...(${names.length - limit} more)`];
}

function normalizeTaskAnalysis(raw = {}, fallback = {}) {
  const suggestedTools = resolveAliasedStringList(
    raw,
    fallback,
    'suggested_tools',
    'suggestedTools',
    TASK_ANALYSIS_SUGGESTED_TOOLS_LIMIT,
  );
  const successCriteria = resolveAliasedStringList(
    raw,
    fallback,
    'success_criteria',
    'successCriteria',
    TASK_ANALYSIS_SUCCESS_CRITERIA_LIMIT,
  );

  const draftReply = resolveAliasedText(raw, fallback, 'draft_reply', 'draftReply', '');
  const initialMode = pickEnum(
    raw.mode || fallback.mode,
    ANALYSIS_MODES,
    draftReply ? 'direct_answer' : 'execute'
  );
  const explicitNeedsVerification = resolveAliasedValue(
    raw,
    fallback,
    'needs_verification',
    'needsVerification',
    undefined
  );
  const hasExplicitVerificationNeed = explicitNeedsVerification !== undefined
    || raw?.verification_need !== undefined
    || raw?.verificationNeed !== undefined
    || fallback?.verification_need !== undefined
    || fallback?.verificationNeed !== undefined;
  const explicitVerificationNeed = pickEnum(
    resolveAliasedValue(raw, fallback, 'verification_need', 'verificationNeed', ''),
    ['none', 'light', 'required'],
    ''
  );
  const needsVerification = explicitNeedsVerification !== undefined
    ? resolveAliasedBoolean(raw, fallback, 'needs_verification', 'needsVerification')
    : explicitVerificationNeed
      ? explicitVerificationNeed !== 'none'
      : initialMode !== 'direct_answer';

  const planningDepth = planningDepthForMode(initialMode);
  const verificationNeed = hasExplicitVerificationNeed
    ? (explicitVerificationNeed || verificationNeedFor({
      mode: initialMode,
      needsVerification,
      hasDraftReply: Boolean(draftReply),
    }))
    : verificationNeedFor({
      mode: initialMode,
      needsVerification,
      hasDraftReply: Boolean(draftReply),
    });
  const freshnessRisk = pickEnum(
    resolveAliasedValue(raw, fallback, 'freshness_risk', 'freshnessRisk', ''),
    ['none', 'possible', 'high'],
    freshnessRiskFor({ verificationNeed })
  );

  const mode = promoteAnalysisMode(initialMode, {
    verificationNeed,
    freshnessRisk,
    draftReply,
    planningDepth,
  });

  return {
    mode,
    freshness_risk: freshnessRisk,
    verification_need: verificationNeed,
    planning_depth: planningDepth,
    confidence: clampConfidence(
      raw.confidence ?? fallback.confidence,
      draftReply ? TASK_ANALYSIS_CONFIDENCE_WITH_DRAFT : TASK_ANALYSIS_CONFIDENCE_DEFAULT,
    ),
    suggested_tools: suggestedTools,
    needs_subagents: resolveAliasedBoolean(raw, fallback, 'needs_subagents', 'needsSubagents'),
    needs_verification: verificationNeed !== 'none',
    draft_reply: draftReply,
    goal: resolveAliasedText(raw, fallback, 'goal', 'goal', ''),
    success_criteria: successCriteria,
  };
}

function normalizePlanStep(rawStep, index = 0) {
  if (typeof rawStep === 'string') {
    const title = rawStep.trim();
    if (!title) return null;
    return {
      index,
      title,
      objective: title,
      suggested_tools: [],
      success_criteria: [],
    };
  }

  if (!rawStep || typeof rawStep !== 'object' || Array.isArray(rawStep)) {
    return null;
  }

  const title = String(resolveAliasedValue(rawStep, null, 'title', 'step', rawStep.objective || '')).trim();
  if (!title) return null;

  return {
    index,
    title,
    objective: resolveAliasedText(rawStep, null, 'objective', 'objective', title),
    suggested_tools: resolveAliasedStringList(
      rawStep,
      null,
      'suggested_tools',
      'suggestedTools',
      PLAN_STEP_SUGGESTED_TOOLS_LIMIT,
    ),
    success_criteria: resolveAliasedStringList(
      rawStep,
      null,
      'success_criteria',
      'successCriteria',
      PLAN_STEP_SUCCESS_CRITERIA_LIMIT,
    ),
  };
}

function normalizeExecutionPlan(raw = {}, fallback = {}) {
  const steps = selectPlanSteps(raw, fallback)
    .map((step, index) => normalizePlanStep(step, index + 1))
    .filter(Boolean)
    .slice(0, 8);

  return {
    steps,
    success_criteria: resolveAliasedStringList(
      raw,
      fallback,
      'success_criteria',
      'successCriteria',
      EXECUTION_PLAN_SUCCESS_CRITERIA_LIMIT,
    ),
    verification_focus: resolveAliasedStringList(
      raw,
      fallback,
      'verification_focus',
      'verificationFocus',
      EXECUTION_PLAN_VERIFICATION_FOCUS_LIMIT,
    ),
  };
}

function normalizeVerificationResult(raw = {}, fallbackReply = '') {
  const finalReply = resolveAliasedText(raw, null, 'final_reply', 'finalReply', fallbackReply || '');
  const missingEvidence = resolveAliasedStringList(
    raw,
    null,
    'missing_evidence',
    'missingEvidence',
    VERIFICATION_MISSING_EVIDENCE_LIMIT,
  );
  let status = pickEnum(raw.status, VERIFICATION_STATUSES, finalReply ? 'verified' : 'needs_revision');
  if (status === 'verified' && missingEvidence.length > 0) {
    status = 'insufficient_evidence';
  }

  return {
    status,
    notes: String(raw.notes || '').trim(),
    evidence_sources: resolveAliasedStringList(
      raw,
      null,
      'evidence_sources',
      'evidenceSources',
      VERIFICATION_EVIDENCE_SOURCES_LIMIT,
    ),
    missing_evidence: missingEvidence,
    final_reply: finalReply,
    confidence: clampConfidence(
      raw.confidence,
      status === 'verified' ? VERIFICATION_CONFIDENCE_VERIFIED : VERIFICATION_CONFIDENCE_DEFAULT,
    ),
  };
}

function getMeaningfulToolExecutions(toolExecutions = []) {
  return toolExecutions.filter((item) => item && item.toolName);
}

function requiresVerifierWithoutEvidence(analysis, finalReply) {
  if (!analysis) return false;
  if (analysis.verification_need === 'required') return true;
  if (!String(finalReply || '').trim()) return true;
  return false;
}

function shouldRunVerifier({ analysis, toolExecutions = [], finalReply = '' }) {
  if (!analysis || typeof analysis !== 'object') return true;
  if (requiresVerifierWithoutEvidence(analysis, finalReply)) return true;

  const meaningfulExecutions = getMeaningfulToolExecutions(toolExecutions);
  if (meaningfulExecutions.length === 0) return analysis.verification_need === 'light';

  return meaningfulExecutions.some((item) => item.stateChanged || item.dependsOnOutput || item.evidenceRelevant);
}

function buildAnalysisPrompt({ capabilityHealth, tools = [], forceMode = null }) {
  const toolNames = summarizeTools(tools).join(', ');
  const forceModeLine = forceMode && ANALYSIS_MODES.includes(forceMode)
    ? `Preferred mode override from the runtime: ${forceMode}. Honor it unless it is clearly unsafe or impossible.`
    : '';

  return composeJsonPrompt([
    JSON_ONLY_RESPONSE_RULE,
    ...ANALYSIS_PROMPT_INSTRUCTIONS,
    forceModeLine,
    formatRuntimeCapabilityHealth(capabilityHealth),
    formatAvailableToolsLine(toolNames),
  ], ANALYSIS_SCHEMA_EXAMPLE);
}

function buildPlanPrompt(analysis, capabilityHealth) {
  const taskGoal = analysis.goal || 'Complete the user request.';
  return composeJsonPrompt([
    JSON_ONLY_RESPONSE_RULE,
    ...PLAN_PROMPT_INSTRUCTIONS,
    formatRuntimeCapabilityHealth(capabilityHealth),
    `Task goal: ${taskGoal}`,
    formatExistingSuccessCriteriaLine(analysis.success_criteria),
    formatSuggestedToolsFromAnalysisLine(analysis.suggested_tools),
  ], PLAN_SCHEMA_EXAMPLE);
}

function buildExecutionGuidance({ analysis, plan = null, capabilityHealth }) {
  const lines = [
    `Execution mode: ${analysis.mode}.`,
    analysis.goal ? `Goal: ${analysis.goal}` : '',
    formatBulletSection('Success criteria', analysis.success_criteria),
    analysis.suggested_tools?.length
      ? `Advisory tool suggestions: ${analysis.suggested_tools.join(', ')}`
      : '',
    capabilityHealth ? `Capability health:\n${capabilityHealth}` : '',
  ];

  lines.push(
    formatPlannedSteps(plan?.steps),
    formatBulletSection('Verification focus', plan?.verification_focus),
    ...EXECUTION_GUIDANCE_ACTION_LINES,
  );

  return lines.filter(Boolean).join('\n\n');
}

function buildVerifierPrompt({ analysis, toolExecutionSummary, evidenceSources, finalReply }) {
  return composeJsonPrompt([
    JSON_ONLY_RESPONSE_RULE,
    ...VERIFIER_PROMPT_INSTRUCTIONS,
    `Freshness risk: ${analysis.freshness_risk}`,
    `Verification need: ${analysis.verification_need}`,
    formatEvidenceSourcesLine(evidenceSources),
    toolExecutionSummary ? `Execution evidence:\n${toolExecutionSummary}` : '',
    `Draft final reply:\n${finalReply || '(empty)'}`,
  ], buildVerifierSchemaExample(finalReply));
}

module.exports = {
  ANALYSIS_MODES,
  buildAnalysisPrompt,
  buildExecutionGuidance,
  buildPlanPrompt,
  buildVerifierPrompt,
  isDirectAnswerEligibleAnalysis,
  normalizeExecutionPlan,
  normalizeTaskAnalysis,
  normalizeVerificationResult,
  parseJsonObject,
  promoteAnalysisMode,
  shouldRunVerifier,
};
