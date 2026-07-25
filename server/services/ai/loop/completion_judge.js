'use strict';

const { normalizeCompletionConfidence } = require('../completion');
const { normalizeOutgoingMessage } = require('../messagingFallback');
const {
  assessResearchAdequacy,
  formatResearchAdequacyGuidance,
  summarizeAvailableTools,
  summarizeToolExecutions,
} = require('../toolEvidence');

const GOAL_CONTRACT_SUCCESS_CRITERIA_LIMIT = 12;

function normalizeGoalCriteria(value) {
  if (!Array.isArray(value)) return [];
  const seen = new Set();
  const items = [];
  for (const entry of value) {
    const text = String(entry || '').trim();
    if (!text) continue;
    const signature = text.toLowerCase();
    if (seen.has(signature)) continue;
    seen.add(signature);
    items.push(text);
    if (items.length >= GOAL_CONTRACT_SUCCESS_CRITERIA_LIMIT) break;
  }
  return items;
}

function normalizeGoalContract(raw = null) {
  if (!raw || typeof raw !== 'object') return null;
  const goal = String(raw.goal || '').trim();
  const successCriteria = normalizeGoalCriteria(
    raw.successCriteria || raw.success_criteria || [],
  );
  const rawCompletionConfidence = String(
    raw.completionConfidenceRequired || raw.completion_confidence_required || '',
  ).trim();
  const completionConfidenceRequired = rawCompletionConfidence
    ? normalizeCompletionConfidence(rawCompletionConfidence)
    : '';
  const progressUpdatePolicy = ['none', 'optional', 'required'].includes(String(
    raw.progressUpdatePolicy || raw.progress_update_policy || '',
  ).trim().toLowerCase())
    ? String(raw.progressUpdatePolicy || raw.progress_update_policy || '').trim().toLowerCase()
    : '';
  const autonomyLevel = ['minimal', 'normal', 'high'].includes(String(
    raw.autonomyLevel || raw.autonomy_level || '',
  ).trim().toLowerCase())
    ? String(raw.autonomyLevel || raw.autonomy_level || '').trim().toLowerCase()
    : '';
  const complexity = ['simple', 'standard', 'complex'].includes(String(
    raw.complexity || '',
  ).trim().toLowerCase())
    ? String(raw.complexity || '').trim().toLowerCase()
    : '';

  if (
    !goal
    && successCriteria.length === 0
    && !completionConfidenceRequired
    && !progressUpdatePolicy
    && !autonomyLevel
    && !complexity
  ) {
    return null;
  }

  return {
    goal,
    successCriteria,
    completionConfidenceRequired,
    progressUpdatePolicy: progressUpdatePolicy || '',
    autonomyLevel: autonomyLevel || '',
    complexity: complexity || '',
  };
}

function mergeGoalContracts(existing = null, patch = null) {
  const current = normalizeGoalContract(existing) || null;
  const nextPatch = normalizeGoalContract(patch) || null;
  if (!current && !nextPatch) return null;

  const goal = String(current?.goal || nextPatch?.goal || '').trim();
  const successCriteria = normalizeGoalCriteria([
    ...(current?.successCriteria || []),
    ...(nextPatch?.successCriteria || []),
  ]);
  const completionConfidenceRequired = nextPatch?.completionConfidenceRequired
    || current?.completionConfidenceRequired
    || 'medium';
  const progressUpdatePolicy = nextPatch?.progressUpdatePolicy
    || current?.progressUpdatePolicy
    || '';
  const autonomyLevel = nextPatch?.autonomyLevel
    || current?.autonomyLevel
    || '';
  const complexity = nextPatch?.complexity
    || current?.complexity
    || '';

  return normalizeGoalContract({
    goal,
    successCriteria,
    completionConfidenceRequired,
    progressUpdatePolicy,
    autonomyLevel,
    complexity,
  });
}

function goalContractFromAnalysis(analysis = null) {
  if (!analysis || typeof analysis !== 'object') return null;
  return normalizeGoalContract({
    goal: analysis.goal,
    successCriteria: analysis.success_criteria,
    completionConfidenceRequired: analysis.completion_confidence_required,
    progressUpdatePolicy: analysis.progress_update_policy,
    autonomyLevel: analysis.autonomy_level,
    complexity: analysis.complexity,
  });
}

function goalContractFromPlan(plan = null) {
  if (!plan || typeof plan !== 'object') return null;
  return normalizeGoalContract({
    successCriteria: plan.success_criteria,
  });
}

function buildResolvedGoalContract(runMeta, analysis = null, plan = null) {
  let contract = mergeGoalContracts(runMeta?.goalContract || null, goalContractFromAnalysis(analysis));
  contract = mergeGoalContracts(contract, goalContractFromPlan(plan));
  return contract;
}

function buildGoalContractPrompt(contract, label = 'Persistent run goal') {
  const normalized = normalizeGoalContract(contract);
  if (!normalized) return '';
  const lines = [];
  if (normalized.goal) {
    lines.push(`${label}: ${normalized.goal}`);
  }
  if (normalized.successCriteria.length > 0) {
    lines.push(`Persistent success criteria:\n- ${normalized.successCriteria.join('\n- ')}`);
  }
  const contractLine = [
    normalized.complexity ? `complexity=${normalized.complexity}` : '',
    normalized.autonomyLevel ? `autonomy_level=${normalized.autonomyLevel}` : '',
    normalized.progressUpdatePolicy ? `progress_update_policy=${normalized.progressUpdatePolicy}` : '',
    normalized.completionConfidenceRequired ? `completion_confidence_required=${normalized.completionConfidenceRequired}` : '',
  ].filter(Boolean).join('; ');
  if (contractLine) {
    lines.push(`Persistent autonomy contract: ${contractLine}`);
  }
  return lines.join('\n');
}

function resolveRunGoalContext(runMeta, analysis = null, plan = null) {
  const goalContract = buildResolvedGoalContract(runMeta, analysis, plan);
  const successCriteria = goalContract?.successCriteria?.length
    ? goalContract.successCriteria.slice(0, 6)
    : (Array.isArray(plan?.success_criteria)
      ? plan.success_criteria
        .map((item) => String(item || '').trim())
        .filter(Boolean)
        .slice(0, 6)
      : []);
  const effectiveGoal = goalContract?.goal || analysis?.goal || '';
  const effectiveComplexity = goalContract?.complexity || analysis?.complexity || 'standard';
  const effectiveAutonomyLevel = goalContract?.autonomyLevel || analysis?.autonomy_level || 'normal';
  const effectiveProgressPolicy = goalContract?.progressUpdatePolicy || analysis?.progress_update_policy || 'optional';
  const effectiveCompletionConfidence = goalContract?.completionConfidenceRequired
    || analysis?.completion_confidence_required
    || 'medium';
  const persistedGoalPrompt = buildGoalContractPrompt(goalContract);
  return {
    goalContract,
    successCriteria,
    effectiveGoal,
    effectiveComplexity,
    effectiveAutonomyLevel,
    effectiveProgressPolicy,
    effectiveCompletionConfidence,
    persistedGoalPrompt,
  };
}

function buildCompletionDecisionPrompt({
  triggerSource,
  messagingSent = false,
  goalContext,
  parallelWork = false,
  tools,
  toolExecutions,
  lastReply,
  iteration,
  maxIterations,
  analysis = null,
  researchAdequacy = null,
}) {
  const draftReply = normalizeOutgoingMessage(lastReply) || '';
  const adequacy = researchAdequacy || assessResearchAdequacy({
    analysis,
    goalContext,
    toolExecutions,
  });
  const lines = [
    'Return JSON only.',
    'Decide whether this run should continue autonomously or stop now.',
    'Schema: {"status":"continue|complete|blocked","reason":"short concrete reason"}',
    'Rules:',
    '- Use "continue" whenever any safe next step remains in this same run.',
    '- Use "complete" when the requested outcome is achieved, already done, or a no-op because there is nothing matching the request to change, and the latest draft is the finished user-facing answer.',
    '- Use "blocked" when a specific external dependency, missing user input, permission outside this run, or unavailable required capability makes the task impossible in this run and the latest draft is the blocker reply.',
    '- If the latest draft asks the user for a missing required value, confirmation, or choice needed to proceed, use "blocked" so the run waits instead of repeating the same ask.',
    '- A progress note, next-step note, apology, plan, or promise to investigate is "continue", not "complete".',
    '- A single failed tool attempt is not blocked if another safe retry, verification step, or alternative path remains.',
    '- A tool-specific API error, timeout, rate limit, or missing result inside this run is usually "continue", not "blocked", if any other available tool could still make progress.',
    '- Repeated read-only inspection that has already established the relevant object is absent or unchanged is not progress. Accept a concise complete/blocker reply instead of requiring more searching.',
    `- If completion_confidence_required is ${goalContext.effectiveCompletionConfidence} and the latest draft depends on unverified assumptions, use "continue" so the run can gather evidence, inspect state, or narrow the reply.`,
    '- When research intensity is light or deep, use "continue" until the required primary/source coverage and target coverage are met, or the draft is an explicit blocker naming exactly what could not be verified.',
    '- Search snippets, memory, and model priors are leads, not completion evidence. Prefer opened/fetched primary sources before "complete".',
    '- If the latest draft invents entities, products, people, files, results, or actions that are not supported by tool evidence, use "continue" so the run can gather evidence or rewrite into a truthful partial/blocker answer.',
    '- A polished-sounding answer is not complete if key requested targets still lack direct evidence.',
    '- If the latest draft only announces unfinished work, promises a future update, or asks the user to wait without a concrete result or blocker, use "continue" so the run keeps acting.',
    '- If the latest draft asks for missing required user input, confirmation, or a choice needed to proceed, use "blocked" so the run waits instead of repeating the same ask.',
  ];

  if (adequacy.intensity !== 'none') {
    lines.push(
      `- Research intensity for this run is ${adequacy.intensity}. Current coverage: primary=${adequacy.primarySourceCount}/${adequacy.requiredPrimarySources}, secondary=${adequacy.secondarySourceCount}, targets_covered=${adequacy.coveredTargets.length}/${Math.max(adequacy.requiredTargetCoverage, adequacy.targets.length)}.`,
    );
  }
  if (adequacy.adequate === false) {
    lines.push(
      `- Research is still incomplete (${adequacy.reason}). Use "continue" unless the latest draft is an explicit blocker naming the exact missing evidence.`,
    );
  }

  if (triggerSource === 'messaging' && messagingSent) {
    lines.push('- A final reply was already delivered via send_message. Use "complete" unless concrete task work remains.');
  } else if (triggerSource === 'messaging') {
    lines.push('- For messaging, do not stop on a partial status message. Continue unless the task is actually complete or externally blocked.');
  } else {
    lines.push('- Do not stop just because you wrote a status update. Continue unless the task is actually complete or externally blocked.');
  }

  lines.push(
    goalContext.effectiveGoal ? `Goal: ${goalContext.effectiveGoal}` : '',
    goalContext.persistedGoalPrompt,
    `Autonomy contract: complexity=${goalContext.effectiveComplexity}; autonomy_level=${goalContext.effectiveAutonomyLevel}; progress_update_policy=${goalContext.effectiveProgressPolicy}; parallel_work=${parallelWork === true}; completion_confidence_required=${goalContext.effectiveCompletionConfidence}.`,
    goalContext.successCriteria.length > 0
      ? `Success criteria:\n${goalContext.successCriteria.map((item, index) => `${index + 1}. ${item}`).join('\n')}`
      : '',
    `Current iteration: ${iteration} of ${maxIterations}.`,
    `Available tools in this run: ${summarizeAvailableTools(tools) || 'none'}`,
    `Recent tool evidence:\n${summarizeToolExecutions(toolExecutions, 8) || 'none'}`,
    adequacy.intensity !== 'none'
      ? `Research adequacy: intensity=${adequacy.intensity}; adequate=${adequacy.adequate}; reason=${adequacy.reason}`
      : '',
    adequacy.targets.length
      ? `Research targets: ${adequacy.targets.join('; ')}`
      : '',
    adequacy.uncoveredTargets.length
      ? `Uncovered research targets: ${adequacy.uncoveredTargets.join('; ')}`
      : '',
    formatResearchAdequacyGuidance(adequacy),
    `Latest draft reply:\n${draftReply || '(empty)'}`,
  );
  return lines.filter(Boolean).join('\n');
}

function normalizeCompletionDecision(raw, fallbackStatus = 'continue') {
  const allowed = new Set(['continue', 'complete', 'blocked']);
  const requestedStatus = String(raw.status || '').trim().toLowerCase();
  return {
    status: allowed.has(requestedStatus) ? requestedStatus : fallbackStatus,
    reason: String(raw.reason || '').trim().slice(0, 400),
  };
}

function enforceTerminalReplyDecision(decision, lastReply, options = {}) {
  // Natural-language terminality is judged by the model completion decision.
  // Runtime only enforces structural evidence contracts (research adequacy).
  const researchAdequacy = options.researchAdequacy
    || assessResearchAdequacy({
      analysis: options.analysis || null,
      goalContext: options.goalContext || null,
      toolExecutions: options.toolExecutions || [],
    });
  if (
    researchAdequacy
    && researchAdequacy.adequate === false
    && (decision?.status === 'complete' || decision?.status === 'blocked')
  ) {
    // Allow true blocked outcomes only when the model already chose blocked AND
    // research cannot progress further (no remaining targets/primary gap that
    // tools could still cover). Otherwise force continue for evidence gathering.
    if (
      decision?.status === 'blocked'
      && researchAdequacy.uncoveredTargets.length === 0
      && researchAdequacy.primarySourceCount >= researchAdequacy.requiredPrimarySources
    ) {
      return decision;
    }
    return {
      status: 'continue',
      reason: researchAdequacy.reason
        || 'Research evidence is still incomplete for the requested targets; continue gathering sources before finishing.',
    };
  }
  return decision;
}

// Intentionally lightweight (200-token cap, self-contained) so the model can
// answer cold without re-reading full conversation history.
function buildChurnAssessmentPrompt({
  readOnlyCount,
  alreadyRead,
  goalContext,
  toolExecutions,
  iteration,
  analysis = null,
  researchAdequacy = null,
}) {
  const adequacy = researchAdequacy || assessResearchAdequacy({
    analysis,
    goalContext,
    toolExecutions,
  });
  const lines = [
    'Return JSON only.',
    'Self-assess your current loop state — are you making genuine progress or spinning?',
    'Schema: {"assessment":"progressing|churn|blocked","reason":"one short concrete sentence"}',
    '',
    `Context: ${readOnlyCount} consecutive iteration(s) with only read/search/inspect operations — no concrete state changes yet.`,
    alreadyRead ? `Already inspected: ${alreadyRead}.` : '',
    goalContext.effectiveGoal ? `Goal: ${goalContext.effectiveGoal}` : '',
    goalContext.successCriteria.length > 0
      ? `Success criteria:\n${goalContext.successCriteria.map((c, i) => `${i + 1}. ${c}`).join('\n')}`
      : '',
    `Iteration: ${iteration}`,
    `Recent tool evidence:\n${summarizeToolExecutions(toolExecutions, 6) || 'none'}`,
    adequacy.intensity !== 'none'
      ? `Research adequacy: intensity=${adequacy.intensity}; adequate=${adequacy.adequate}; covered=${adequacy.coveredTargets.length}/${Math.max(adequacy.requiredTargetCoverage, adequacy.targets.length)}; primary=${adequacy.primarySourceCount}/${adequacy.requiredPrimarySources}.`
      : '',
    adequacy.uncoveredTargets.length
      ? `Still uncovered research targets: ${adequacy.uncoveredTargets.join('; ')}.`
      : '',
    '',
    'Assessment rules:',
    '- "progressing": You are systematically gathering necessary context and the next concrete action is already determined — you know exactly what to do next.',
    '- "churn": You are re-reading/re-searching information already in context, or exploring without a clear next concrete step. Accept the nudge and act.',
    '- "blocked": No concrete action is available in this run. You have all the evidence needed to deliver a truthful final answer or a specific external blocker.',
    '- For multi-target research, keep "progressing" while uncovered targets remain and a fresh primary source can still be opened. Do not mark "blocked" just because you have partial notes.',
    '- Re-querying the same snippet source for an already covered target is "churn". Opening a different primary source for an uncovered target is "progressing".',
    adequacy.adequate === false
      ? '- Research adequacy is currently incomplete. Prefer "progressing" if a new primary source for an uncovered target is still available; use "churn" only for repeated identical reads; do not use "blocked" unless tools cannot reach remaining targets.'
      : '',
  ];
  return lines.filter(Boolean).join('\n');
}

function enforceChurnAssessment(assessment, options = {}) {
  const normalized = normalizeChurnAssessment(assessment);
  const researchAdequacy = options.researchAdequacy
    || assessResearchAdequacy({
      analysis: options.analysis || null,
      goalContext: options.goalContext || null,
      toolExecutions: options.toolExecutions || [],
    });
  if (
    researchAdequacy
    && researchAdequacy.adequate === false
    && researchAdequacy.intensity !== 'none'
    && normalized.assessment === 'blocked'
    && (researchAdequacy.uncoveredTargets?.length > 0 || researchAdequacy.primarySourceCount < researchAdequacy.requiredPrimarySources)
  ) {
    return {
      assessment: 'progressing',
      reason: researchAdequacy.reason
        || 'Research targets remain uncovered; keep gathering primary sources instead of force-finishing.',
    };
  }
  return normalized;
}

function normalizeChurnAssessment(raw) {
  const allowed = new Set(['progressing', 'churn', 'blocked']);
  const assessment = String(raw?.assessment || '').trim().toLowerCase();
  return {
    assessment: allowed.has(assessment) ? assessment : 'churn',
    reason: String(raw?.reason || '').trim().slice(0, 300),
  };
}

module.exports = {
  buildChurnAssessmentPrompt,
  buildCompletionDecisionPrompt,
  buildGoalContractPrompt,
  enforceTerminalReplyDecision,
  goalContractFromAnalysis,
  goalContractFromPlan,
  mergeGoalContracts,
  enforceChurnAssessment,
  normalizeChurnAssessment,
  normalizeCompletionDecision,
  normalizeGoalContract,
  resolveRunGoalContext,
};
