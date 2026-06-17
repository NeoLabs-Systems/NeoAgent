'use strict';

const { normalizeCompletionConfidence } = require('../completion');
const { normalizeOutgoingMessage } = require('../messagingFallback');
const {
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
}) {
  const draftReply = normalizeOutgoingMessage(lastReply) || '';
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
    triggerSource === 'messaging' && messagingSent
      ? '- A final reply was already delivered via send_message. Use "complete" unless concrete task work remains.'
      : triggerSource === 'messaging'
        ? '- For messaging, do not stop on a partial status message. Continue unless the task is actually complete or externally blocked.'
        : '- Do not stop just because you wrote a status update. Continue unless the task is actually complete or externally blocked.',
  ];

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

module.exports = {
  buildCompletionDecisionPrompt,
  buildGoalContractPrompt,
  goalContractFromAnalysis,
  goalContractFromPlan,
  mergeGoalContracts,
  normalizeCompletionDecision,
  normalizeGoalContract,
  resolveRunGoalContext,
};
