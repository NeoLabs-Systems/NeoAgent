const ANALYSIS_MODES = ['direct_answer', 'execute', 'plan_execute'];
const REPLY_MODES = ['chat', 'task', 'status', 'silent'];
const FRESHNESS_RISKS = ['none', 'possible', 'high'];
const VERIFICATION_NEEDS = ['none', 'light', 'required'];
const PLANNING_DEPTHS = ['none', 'light', 'deep'];
const VERIFICATION_STATUSES = ['verified', 'needs_revision', 'insufficient_evidence'];

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

function pickEnum(value, allowed, fallback) {
  const normalized = String(value || '').trim().toLowerCase();
  return allowed.includes(normalized) ? normalized : fallback;
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
  const suggestedTools = normalizeStringList(
    raw.suggested_tools || raw.suggestedTools || fallback.suggested_tools || [],
    { limit: 12 }
  );
  const successCriteria = normalizeStringList(
    raw.success_criteria || raw.successCriteria || fallback.success_criteria || [],
    { limit: 8 }
  );

  const draftReply = String(raw.draft_reply || raw.draftReply || fallback.draft_reply || '').trim();
  const initialMode = pickEnum(
    raw.mode || fallback.mode,
    ANALYSIS_MODES,
    draftReply ? 'direct_answer' : 'execute'
  );
  const freshnessRisk = pickEnum(
    raw.freshness_risk || raw.freshnessRisk || fallback.freshness_risk,
    FRESHNESS_RISKS,
    'none'
  );
  const verificationNeed = pickEnum(
    raw.verification_need || raw.verificationNeed || fallback.verification_need,
    VERIFICATION_NEEDS,
    'none'
  );
  const planningDepth = pickEnum(
    raw.planning_depth || raw.planningDepth || fallback.planning_depth,
    PLANNING_DEPTHS,
    initialMode === 'plan_execute' ? 'deep' : 'light'
  );

  let mode = initialMode;
  if (mode === 'direct_answer' && (verificationNeed !== 'none' || freshnessRisk !== 'none' || !draftReply)) {
    mode = planningDepth === 'deep' ? 'plan_execute' : 'execute';
  }
  if (mode === 'execute' && planningDepth === 'deep') {
    mode = 'plan_execute';
  }

  return {
    mode,
    reply_mode: pickEnum(raw.reply_mode || raw.replyMode || fallback.reply_mode, REPLY_MODES, 'task'),
    freshness_risk: freshnessRisk,
    verification_need: verificationNeed,
    planning_depth: planningDepth,
    confidence: clampConfidence(raw.confidence ?? fallback.confidence, draftReply ? 0.8 : 0.55),
    suggested_tools: suggestedTools,
    needs_subagents: raw.needs_subagents === true || raw.needsSubagents === true,
    draft_reply: draftReply,
    goal: String(raw.goal || fallback.goal || '').trim(),
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

  const title = String(rawStep.title || rawStep.step || rawStep.objective || '').trim();
  if (!title) return null;

  return {
    index,
    title,
    objective: String(rawStep.objective || title).trim(),
    suggested_tools: normalizeStringList(rawStep.suggested_tools || rawStep.suggestedTools || [], { limit: 8 }),
    success_criteria: normalizeStringList(rawStep.success_criteria || rawStep.successCriteria || [], { limit: 6 }),
  };
}

function normalizeExecutionPlan(raw = {}, fallback = {}) {
  const steps = (Array.isArray(raw.steps) ? raw.steps : Array.isArray(fallback.steps) ? fallback.steps : [])
    .map((step, index) => normalizePlanStep(step, index + 1))
    .filter(Boolean)
    .slice(0, 8);

  return {
    steps,
    success_criteria: normalizeStringList(raw.success_criteria || raw.successCriteria || fallback.success_criteria || [], { limit: 10 }),
    verification_focus: normalizeStringList(raw.verification_focus || raw.verificationFocus || fallback.verification_focus || [], { limit: 8 }),
  };
}

function normalizeVerificationResult(raw = {}, fallbackReply = '') {
  const finalReply = String(raw.final_reply || raw.finalReply || fallbackReply || '').trim();
  const missingEvidence = normalizeStringList(raw.missing_evidence || raw.missingEvidence || [], { limit: 8 });
  let status = pickEnum(raw.status, VERIFICATION_STATUSES, finalReply ? 'verified' : 'needs_revision');
  if (status === 'verified' && missingEvidence.length > 0) {
    status = 'insufficient_evidence';
  }

  return {
    status,
    notes: String(raw.notes || '').trim(),
    evidence_sources: normalizeStringList(raw.evidence_sources || raw.evidenceSources || [], { limit: 12 }),
    missing_evidence: missingEvidence,
    final_reply: finalReply,
    confidence: clampConfidence(raw.confidence, status === 'verified' ? 0.85 : 0.5),
  };
}

function shouldRunVerifier({ analysis, toolExecutions = [], finalReply = '' }) {
  if (!analysis) return false;
  if (analysis.verification_need === 'required') return true;
  if (analysis.freshness_risk !== 'none') return true;
  if (analysis.confidence < 0.7) return true;
  if (!String(finalReply || '').trim()) return true;

  const meaningfulExecutions = toolExecutions.filter((item) => item && item.toolName);
  if (meaningfulExecutions.length === 0) return analysis.verification_need === 'light';

  return meaningfulExecutions.some((item) => item.stateChanged || item.dependsOnOutput || item.evidenceRelevant);
}

function buildAnalysisPrompt({ triggerSource, capabilityHealth, tools = [], forceMode = null }) {
  const toolNames = summarizeTools(tools).join(', ');
  const forceModeLine = forceMode && ANALYSIS_MODES.includes(forceMode)
    ? `Preferred mode override from the runtime: ${forceMode}. Honor it unless it is clearly unsafe or impossible.`
    : '';

  return [
    'Return JSON only. No markdown, no prose, no code fences.',
    'Decide how much execution depth this task needs before the main run continues.',
    'Use mode="direct_answer" only if you can fully answer right now without tools and without further verification.',
    'Use mode="execute" when tool work is needed but a formal plan is not necessary.',
    'Use mode="plan_execute" when the task likely needs multiple coordinated steps, retries, or delegated subtasks.',
    'Use plan_execute for broad personal searches, cross-source questions, code changes, debugging, scheduled-task changes, or anything that touches external/shared state.',
    'freshness_risk must be "possible" or "high" for anything that may depend on current external facts, status, timelines, or ambiguous relative dates.',
    'verification_need must be "required" whenever fresh evidence is needed, tool output materially determines the answer, confidence is low, or actions changed external state.',
    'verification_need must be "required" for outbound messages/calls/emails, scheduled-task mutations, file edits, installs, service restarts, or code changes.',
    'reply_mode should reflect the intended final reply style: chat, task, status, or silent.',
    'reply_mode="silent" is only appropriate when the user explicitly asked for silence or the trigger is background-only and has no useful user-facing result.',
    'suggested_tools should name the specific tools or capabilities that are most relevant, but they are advisory only.',
    'Prefer official integration tools and structured tools over browser automation, shell scraping, or web search when they can answer the task.',
    'For broad searches, suggest multiple source-specific tools when available so the executor can run them in parallel.',
    'needs_subagents should be true only when independent subtasks can progress in parallel without blocking the next local step.',
    'success_criteria should be concrete and user-visible.',
    'If the task requires a missing required value that cannot be inferred safely, set mode="direct_answer" with a concise draft_reply asking only for that value.',
    forceModeLine,
    capabilityHealth ? `Runtime capability health:\n${capabilityHealth}` : '',
    toolNames ? `Available tools/capabilities: ${toolNames}` : '',
    'Schema:',
    JSON.stringify({
      mode: 'execute',
      reply_mode: 'task',
      freshness_risk: 'possible',
      verification_need: 'light',
      planning_depth: 'light',
      confidence: 0.62,
      suggested_tools: ['web_search', 'browser_navigate'],
      needs_subagents: false,
      draft_reply: '',
      goal: 'Answer the user accurately.',
      success_criteria: ['Final reply is correct and specific.'],
    }, null, 2),
  ].filter(Boolean).join('\n\n');
}

function buildPlanPrompt(analysis, capabilityHealth) {
  return [
    'Return JSON only. No markdown, no prose, no code fences.',
    'Create a concise execution plan for the current task.',
    'Focus on practical steps, success criteria, and what needs verification.',
    'Prefer steps that can be executed in parallel when they are independent. Do not serialize unrelated searches or inspections.',
    'Prefer native integrations and structured tools before browser automation or generic shell commands.',
    'For external actions, include a step to draft or confirm before sending unless the user already gave explicit current-session approval.',
    'For code or config changes, include inspection, scoped edit, and verification steps.',
    'For scheduled tasks, make the future prompt self-contained and include notification conditions.',
    capabilityHealth ? `Runtime capability health:\n${capabilityHealth}` : '',
    `Task goal: ${analysis.goal || 'Complete the user request.'}`,
    analysis.success_criteria?.length
      ? `Existing success criteria:\n- ${analysis.success_criteria.join('\n- ')}`
      : '',
    analysis.suggested_tools?.length
      ? `Suggested tools from task analysis: ${analysis.suggested_tools.join(', ')}`
      : '',
    'Schema:',
    JSON.stringify({
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
    }, null, 2),
  ].filter(Boolean).join('\n\n');
}

function buildExecutionGuidance({ analysis, plan = null, capabilityHealth }) {
  const lines = [
    `Execution mode: ${analysis.mode}.`,
    analysis.goal ? `Goal: ${analysis.goal}` : '',
    analysis.success_criteria?.length
      ? `Success criteria:\n- ${analysis.success_criteria.join('\n- ')}`
      : '',
    analysis.suggested_tools?.length
      ? `Advisory tool suggestions: ${analysis.suggested_tools.join(', ')}`
      : '',
    capabilityHealth ? `Capability health:\n${capabilityHealth}` : '',
  ];

  if (plan?.steps?.length) {
    lines.push(
      `Planned steps:\n${plan.steps.map((step, index) => {
        const tools = step.suggested_tools?.length ? ` [tools: ${step.suggested_tools.join(', ')}]` : '';
        return `${index + 1}. ${step.title}${tools}`;
      }).join('\n')}`
    );
  }

  if (plan?.verification_focus?.length) {
    lines.push(`Verification focus:\n- ${plan.verification_focus.join('\n- ')}`);
  }

  lines.push(
    'Act end-to-end. Run independent searches or inspections in parallel when possible. Prefer native integration tools and structured APIs over browser automation or shell scraping. Use exact IDs and required parameters; list or search first when you do not have them.',
    'Use send_interim_update sparingly when a short real update or question would help.',
    'For outbound messages, calls, emails, shared edits, installs, restarts, or scheduled-task mutations, verify the action result before claiming it happened. If user confirmation is required and missing, draft or ask instead of sending.',
    'Retry with alternative tools or approaches when one path fails. If evidence is still insufficient, say so explicitly instead of guessing.'
  );

  return lines.filter(Boolean).join('\n\n');
}

function buildVerifierPrompt({ analysis, toolExecutionSummary, evidenceSources, finalReply }) {
  return [
    'Return JSON only. No markdown, no prose, no code fences.',
    'Verify whether the draft final reply is adequately supported by the gathered evidence.',
    'If the evidence is insufficient, revise the reply so it states the uncertainty clearly instead of guessing.',
    'Cross-check every concrete claim against tool status and output. Remove or rewrite claims that are contradicted by the evidence.',
    'A non-zero execute_command exit code means partial or failed shell evidence. Do not treat later sections of a chained shell command as observed unless they were verified separately.',
    'A successful send_message or make_call means outbound delivery succeeded in this run unless a later messaging tool failed.',
    'Any claim that an outbound action already happened (sent/submitted/called/"already done") must be backed by a successful outbound tool execution in this run. If not backed, rewrite the reply to "not sent yet" and provide a draft or next concrete step.',
    'A successful scheduled-task create/update/delete tool call is required before claiming a schedule changed.',
    'If external evidence conflicts with memory, history, or another tool result, preserve the uncertainty instead of flattening it into a single confident claim.',
    `Freshness risk: ${analysis.freshness_risk}`,
    `Verification need: ${analysis.verification_need}`,
    evidenceSources?.length ? `Evidence sources used: ${evidenceSources.join(', ')}` : 'Evidence sources used: none',
    toolExecutionSummary ? `Execution evidence:\n${toolExecutionSummary}` : '',
    `Draft final reply:\n${finalReply || '(empty)'}`,
    'Schema:',
    JSON.stringify({
      status: 'verified',
      notes: 'The reply is grounded in the available evidence.',
      evidence_sources: ['web_search'],
      missing_evidence: [],
      final_reply: finalReply || '',
      confidence: 0.83,
    }, null, 2),
  ].filter(Boolean).join('\n\n');
}

module.exports = {
  ANALYSIS_MODES,
  buildAnalysisPrompt,
  buildExecutionGuidance,
  buildPlanPrompt,
  buildVerifierPrompt,
  normalizeExecutionPlan,
  normalizeTaskAnalysis,
  normalizeVerificationResult,
  parseJsonObject,
  shouldRunVerifier,
};
