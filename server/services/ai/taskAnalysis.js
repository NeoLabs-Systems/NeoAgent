const ANALYSIS_MODES = ['direct_answer', 'execute', 'plan_execute'];
const VERIFICATION_STATUSES = ['verified', 'needs_revision', 'insufficient_evidence'];
const COMPLEXITY_LEVELS = ['simple', 'standard', 'complex'];
const AUTONOMY_LEVELS = ['minimal', 'normal', 'high'];
const PROGRESS_UPDATE_POLICIES = ['none', 'optional', 'required'];
const COMPLETION_CONFIDENCE_LEVELS = ['medium', 'high'];
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
  research_targets: [],
  suggested_tools: ['web_search', 'browser_navigate'],
  complexity: 'standard',
  autonomy_level: 'normal',
  progress_update_policy: 'optional',
  parallel_work: false,
  completion_confidence_required: 'medium',
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
  'Choose the lightest routing mode that still handles the task well. Prefer speed for simple work and depth only when the request needs tools or multi-step evidence.',
  'Use mode="direct_answer" only when a final user-facing reply can be given immediately without tool work. The draft_reply must be the actual answer, not a promise to check later.',
  'For short immediate questions, greetings, small explanations, quick conversational replies, or pure opinion/advice that does not need live lookup, prefer mode="direct_answer" with progress_update_policy="none", complexity="simple", autonomy_level="minimal", and an empty research_targets list. Speed matters more than creating plans or tasks.',
  'Use mode="execute" for normal tool-driven work without a separate planning step.',
  'Use mode="plan_execute" only when the task is genuinely multi-step, broad, or coordination-heavy.',
  'Never invent entities, products, people, files, or outcomes to fill gaps. If the user refers to multiple targets but only one is known, ask once or research only the known ones and mark the rest unknown.',
  'Set needs_verification=true when the final answer should be checked against tool evidence before it is sent.',
  'Set goal to a concise restatement of what the user is asking for in this message. Never leave goal empty.',
  'Keep goal and success_criteria short and practical.',
  'suggested_tools are optional hints, not a required plan.',
  'Set complexity from the actual work shape, not from keywords: simple, standard, or complex.',
  'Set autonomy_level="high" when the agent should decide sequencing, retries, evidence gathering, and verification without asking the user unless blocked.',
  'Set progress_update_policy="required" for long, slow, voice, messaging, or externally visible work where silence would be confusing.',
  'Do not suggest create_task, update_task, delete_task, or list_tasks for ordinary immediate work. Use task tools only when the user asks for future, recurring, scheduled, monitored, background, or existing-task management behavior.',
  'Set parallel_work=true when independent tool calls or subagents can materially reduce latency.',
  'Set completion_confidence_required="high" when wrong completion would be costly, state-changing, user-visible, or hard to recover.',
  'For research, product/device comparisons, reviews, fact-checks, or multi-entity look-into requests, use mode="execute" or mode="plan_execute", never direct_answer. Set needs_verification=true, freshness_risk="possible" or higher, and completion_confidence_required="high".',
  'When the user asks to look into multiple devices, products, options, or entities, put each named target into research_targets and success_criteria and keep them exact. Prefer suggested_tools that can open primary sources (web_search plus browser_navigate/http_request) rather than answering from memory.',
];
const PLAN_PROMPT_INSTRUCTIONS = [
  'Create a concise execution plan for the current task.',
  'Focus on practical steps, success criteria, and what needs verification.',
  'Prefer steps that can be executed in parallel when they are independent. Do not serialize unrelated searches or inspections.',
  'Prefer native integrations and structured tools before browser automation or generic shell commands.',
  'For external actions, include a step to draft or confirm before sending unless the user already gave explicit current-session approval.',
  'For code or config changes, include inspection, scoped edit, and verification steps.',
  'For tasks that run later, make the future prompt self-contained and include notification conditions.',
  'Call out independent work that can start before slower blocking work finishes.',
  'Make the final step prove completion against the success criteria, not just produce a plausible answer.',
];
const VERIFIER_PROMPT_INSTRUCTIONS = [
  'Verify whether the draft final reply is adequately supported by the gathered evidence.',
  'If the evidence is insufficient, revise the reply so it states the uncertainty clearly instead of guessing.',
  'Cross-check every concrete claim against tool status and output. Remove or rewrite claims that are contradicted by the evidence.',
  'When the task or prompt names a specific entity to check (for example a city, account, person, date, source, or destination), preserve that target exactly. If the gathered evidence is for a different entity, treat the draft as needing revision or insufficient evidence.',
  'When the task says to include something only if it is available or only if a condition is met, omit that section when the evidence does not show the condition was satisfied.',
  'A non-zero execute_command exit code means partial or failed shell evidence. Do not treat later sections of a chained shell command as observed unless they were verified separately.',
  'A successful send_message or make_call means outbound delivery succeeded in this run unless a later messaging tool failed.',
  'Any claim that an outbound action already happened (sent/submitted/called/"already done") must be backed by a successful outbound tool execution in this run. If not backed, rewrite the reply to "not sent yet" and provide a draft or next concrete step.',
  'A successful create_task or update_task tool call is required before claiming a task schedule changed.',
  'If external evidence conflicts with memory, history, or another tool result, preserve the uncertainty instead of flattening it into a single confident claim.',
  'When the draft reply is already correct and fully supported by the evidence, return it unchanged. Do not rewrite for style.',
  'For multi-entity research or comparison replies, every compared target needs supporting tool evidence. If a target was never searched or opened, mark insufficient_evidence and rewrite the reply so it does not invent that target\'s specs.',
  'Do not invent missing targets, products, people, or outcomes. If the draft invents an entity that is not in the task and not in tool evidence, rewrite it out or mark insufficient_evidence.',
  'Search-result snippets alone are weak evidence for concrete product claims. Prefer opened pages, fetched docs, or other primary tool output. If only snippets exist, either keep the claim clearly provisional or mark missing_evidence.',
];
const EXECUTION_GUIDANCE_ACTION_LINES = [
  'Act end-to-end. Run independent searches or inspections in parallel when possible. Prefer native integration tools and structured APIs over browser automation or shell scraping. Use exact IDs and required parameters; list or search first when you do not have them.',
  'For research and multi-entity comparisons, cover each requested target with its own search/open path. Do not stop after one partial lead or invent the remaining devices from memory. Open primary sources before stating concrete specs.',
  'For GitHub issue implementation or PR work, fetch the issue once, then establish or reuse a writable local checkout, create a task branch, inspect/edit/test locally, and push/open the PR. Use direct GitHub file mutation tools only as a fallback when a local checkout is unavailable.',
  'Prefer the highest-level available tool for the job. If a tool accepts normal text, JSON, file paths, or line ranges, pass those directly instead of reconstructing equivalent data through shell commands.',
  'Your shell (execute_command) starts in your workspace, and the file tools (read_file, read_files, write_file, edit_file, replace_file_range, list_directory, search_files) operate on that same workspace. Keep source checkouts and generated files in the shared workspace, then prefer file tools for inspection and edits instead of shell snippets. Clone a repo once and reuse it; do not re-clone or re-list the same tree.',
  'Tool results are already present in the conversation as tool output. Do not assume a tool result was persisted to a readable /tmp path unless that exact path was explicitly returned by the tool result.',
  'Use send_interim_update sparingly when a short real update or question would help.',
  'Do not create background tasks for immediate short work. Answer directly unless the user asked to schedule, repeat, monitor, defer, or manage a saved task.',
  'When you must ask for missing required user input, ask once, then wait for the reply instead of re-asking in the same run.',
  'For outbound messages, calls, emails, shared edits, installs, restarts, or task mutations, verify the action result before claiming it happened. If user confirmation is required and missing, draft or ask instead of sending.',
  'Retry with alternative tools or approaches when one path fails. If evidence is still insufficient, say so explicitly instead of guessing.',
  'When completion_confidence_required is high, do not call task_complete with low confidence. Verify, inspect, or revise until confidence is at least medium and preferably high.',
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

function defaultAutonomyForMode(mode) {
  if (mode === 'direct_answer') return 'minimal';
  if (mode === 'plan_execute') return 'high';
  return 'normal';
}

function defaultComplexityForMode(mode) {
  if (mode === 'direct_answer') return 'simple';
  if (mode === 'plan_execute') return 'complex';
  return 'standard';
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
  const researchTargets = Array.isArray(analysis.research_targets)
    ? analysis.research_targets.filter(Boolean)
    : [];
  const promotedMode = promoteAnalysisMode(analysis.mode, {
    verificationNeed: analysis.verification_need,
    freshnessRisk: analysis.freshness_risk,
    draftReply,
    planningDepth: analysis.planning_depth,
  });

  // Direct answers are for zero-tool replies only. Any research targets or
  // freshness/verification burden must enter the tool loop.
  return promotedMode === 'direct_answer'
    && !analysis.needs_subagents
    && Boolean(draftReply)
    && researchTargets.length === 0
    && String(analysis.verification_need || 'none') === 'none'
    && String(analysis.freshness_risk || 'none') === 'none';
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

function summarizeTools(tools = []) {
  return tools
    .map((tool) => String(tool?.name || '').trim())
    .filter(Boolean);
}

function summarizeToolCatalog(tools = []) {
  return tools
    .map((tool) => {
      const name = String(tool?.name || '').trim();
      if (!name) return '';
      const description = String(tool?.description || '').replace(/\s+/g, ' ').trim();
      return description ? `${name}: ${description}` : name;
    })
    .filter(Boolean)
    .join('\n');
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
  const researchTargets = resolveAliasedStringList(
    raw,
    fallback,
    'research_targets',
    'researchTargets',
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

  let mode = promoteAnalysisMode(initialMode, {
    verificationNeed,
    freshnessRisk,
    draftReply,
    planningDepth,
  });

  // Structural promotion: explicit research targets require tool work.
  if (researchTargets.length > 0 && mode === 'direct_answer') {
    mode = planningDepth === 'deep' || researchTargets.length >= 2 ? 'plan_execute' : 'execute';
  }

  let effectiveVerificationNeed = verificationNeed;
  let effectiveFreshnessRisk = freshnessRisk;
  if (researchTargets.length > 0) {
    if (effectiveVerificationNeed === 'none') {
      effectiveVerificationNeed = researchTargets.length >= 2 ? 'required' : 'light';
    }
    if (effectiveFreshnessRisk === 'none') {
      effectiveFreshnessRisk = researchTargets.length >= 2 ? 'possible' : 'possible';
    }
    if (mode === 'execute' && researchTargets.length >= 2) {
      mode = 'plan_execute';
    }
  }

  const normalizedComplexity = pickEnum(
    resolveAliasedValue(raw, fallback, 'complexity', 'complexity', ''),
    COMPLEXITY_LEVELS,
    defaultComplexityForMode(mode),
  );
  const normalizedAutonomyLevel = pickEnum(
    resolveAliasedValue(raw, fallback, 'autonomy_level', 'autonomyLevel', ''),
    AUTONOMY_LEVELS,
    defaultAutonomyForMode(mode),
  );

  return {
    mode,
    freshness_risk: effectiveFreshnessRisk,
    verification_need: effectiveVerificationNeed,
    planning_depth: mode === 'plan_execute' ? 'deep' : mode === 'direct_answer' ? 'none' : planningDepth,
    confidence: clampConfidence(
      raw.confidence ?? fallback.confidence,
      draftReply ? TASK_ANALYSIS_CONFIDENCE_WITH_DRAFT : TASK_ANALYSIS_CONFIDENCE_DEFAULT,
    ),
    suggested_tools: suggestedTools,
    needs_subagents: resolveAliasedBoolean(raw, fallback, 'needs_subagents', 'needsSubagents'),
    needs_verification: effectiveVerificationNeed !== 'none',
    draft_reply: draftReply,
    goal: resolveAliasedText(raw, fallback, 'goal', 'goal', ''),
    success_criteria: successCriteria,
    research_targets: researchTargets,
    complexity: mode === 'plan_execute' ? 'complex' : normalizedComplexity,
    autonomy_level: mode === 'plan_execute' ? 'high' : normalizedAutonomyLevel,
    progress_update_policy: pickEnum(
      resolveAliasedValue(raw, fallback, 'progress_update_policy', 'progressUpdatePolicy', ''),
      PROGRESS_UPDATE_POLICIES,
      mode === 'direct_answer' ? 'none' : 'optional',
    ),
    parallel_work: resolveAliasedBoolean(raw, fallback, 'parallel_work', 'parallelWork'),
    completion_confidence_required: pickEnum(
      resolveAliasedValue(raw, fallback, 'completion_confidence_required', 'completionConfidenceRequired', ''),
      COMPLETION_CONFIDENCE_LEVELS,
      effectiveVerificationNeed === 'required' || mode === 'plan_execute' || researchTargets.length >= 2
        ? 'high'
        : 'medium',
    ),
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
  const toolCatalog = summarizeToolCatalog(tools);
  const forceModeLine = forceMode && ANALYSIS_MODES.includes(forceMode)
    ? `Preferred mode override from the runtime: ${forceMode}. Honor it unless it is clearly unsafe or impossible.`
    : '';

  return composeJsonPrompt([
    JSON_ONLY_RESPONSE_RULE,
    ...ANALYSIS_PROMPT_INSTRUCTIONS,
    forceModeLine,
    formatRuntimeCapabilityHealth(capabilityHealth),
    toolCatalog ? `Complete available tool catalog:\n${toolCatalog}` : '',
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
    `Autonomy: complexity=${analysis.complexity || 'standard'}, autonomy_level=${analysis.autonomy_level || 'normal'}, progress_update_policy=${analysis.progress_update_policy || 'optional'}, parallel_work=${analysis.parallel_work === true}, completion_confidence_required=${analysis.completion_confidence_required || 'medium'}`,
  ], PLAN_SCHEMA_EXAMPLE);
}

function buildExecutionGuidance({ analysis, plan = null, capabilityHealth }) {
  const lines = [
    `Execution mode: ${analysis.mode}.`,
    analysis.goal ? `Goal: ${analysis.goal}` : '',
    formatBulletSection('Success criteria', analysis.success_criteria),
    formatBulletSection('Research targets', analysis.research_targets),
    analysis.suggested_tools?.length
      ? `Advisory tool suggestions: ${analysis.suggested_tools.join(', ')}`
      : '',
    `Autonomy contract: complexity=${analysis.complexity || 'standard'}; autonomy_level=${analysis.autonomy_level || 'normal'}; progress_update_policy=${analysis.progress_update_policy || 'optional'}; parallel_work=${analysis.parallel_work === true}; completion_confidence_required=${analysis.completion_confidence_required || 'medium'}.`,
    analysis.progress_update_policy === 'required'
      ? 'Progress updates are required for this run: when the work becomes slow, changes method, or hits a temporary blocker, use send_interim_update with a concise factual update. Do not use progress updates as completion, and do not continue long read-only work silently after a progress-check nudge.'
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

function buildVerifierPrompt({ analysis, tools = [], toolExecutionSummary, evidenceSources, finalReply }) {
  const toolNames = summarizeTools(tools).join(', ');
  return composeJsonPrompt([
    JSON_ONLY_RESPONSE_RULE,
    ...VERIFIER_PROMPT_INSTRUCTIONS,
    formatAvailableToolsLine(toolNames),
    'Do not claim a tool or capability was unavailable if it is listed as available in this run. A missing tool execution is missing evidence, not proof of missing tool exposure.',
    `Freshness risk: ${analysis.freshness_risk}`,
    `Verification need: ${analysis.verification_need}`,
    `Completion confidence required: ${analysis.completion_confidence_required || 'medium'}`,
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
