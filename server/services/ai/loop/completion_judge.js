'use strict';

const { normalizeCompletionConfidence } = require('../completion');
const { normalizeOutgoingMessage } = require('../messagingFallback');
const {
  assessResearchAdequacy,
  formatResearchAdequacyGuidance,
  summarizeAvailableTools,
  summarizeResearchEvidenceCatalog,
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
    'Schema: {"status":"continue|complete|blocked","reason":"short concrete reason","blocker_review":{"kind":"user_input|permission|external_dependency|unavailable_capability|none","resolvable_in_run":true,"required_value":"specific missing dependency"},"research_review":{"required":true,"adequate":false,"overall_support":"primary|secondary|context|none","evidence_indexes":[1],"target_coverage":[{"target":"exact requested target","support":"primary|secondary|context|none","evidence_indexes":[1]}],"missing_targets":["exact missing target"]}}',
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
    '- When research intensity is light or deep, fill research_review from the numbered evidence entries. Do not mark complete unless every requested target has concrete support.',
    '- Search snippets, memory, and model priors are leads, not completion evidence. Prefer opened/fetched primary sources before "complete".',
    '- Judge source quality semantically from the actual evidence summary. Tool names, call counts, local notes, and target words in tool arguments do not by themselves make evidence primary or prove a claim.',
    '- evidence_indexes are the numeric parts of E identifiers from the Research evidence catalog. Never cite an entry that does not support the target.',
    '- A real external blocker or genuinely required user input may be "blocked" even when research is incomplete. Name the missing dependency precisely; do not pretend more autonomous research can resolve user-only information.',
    '- For "blocked", blocker_review.kind must identify the external dependency, resolvable_in_run must be false, and required_value must state what is missing. Otherwise choose "continue".',
    '- If the latest draft invents entities, products, people, files, results, or actions that are not supported by tool evidence, use "continue" so the run can gather evidence or rewrite into a truthful partial/blocker answer.',
    '- A polished-sounding answer is not complete if key requested targets still lack direct evidence.',
    '- If the latest draft only announces unfinished work, promises a future update, or asks the user to wait without a concrete result or blocker, use "continue" so the run keeps acting.',
    '- If the latest draft asks for missing required user input, confirmation, or a choice needed to proceed, use "blocked" so the run waits instead of repeating the same ask.',
  ];

  if (adequacy.intensity !== 'none') {
    lines.push(
      `- Research intensity for this run is ${adequacy.intensity}. Successful evidence candidates=${adequacy.evidenceCandidateCount}; unique calls=${adequacy.uniqueEvidenceCandidateCount}. Semantic target coverage has not been precomputed.`,
    );
  }
  if (adequacy.structurallyReady === false) {
    lines.push(
      `- No source evidence is ready for review (${adequacy.reason}). Use "continue" unless the latest draft is a real external blocker.`,
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
    `Recent tool evidence:\n${summarizeToolExecutions(toolExecutions, 12) || 'none'}`,
    adequacy.intensity !== 'none'
      ? `Research evidence catalog:\n${summarizeResearchEvidenceCatalog(toolExecutions) || 'none'}`
      : '',
    adequacy.intensity !== 'none'
      ? `Research preflight: intensity=${adequacy.intensity}; structurally_ready=${adequacy.structurallyReady}; semantic_review_required=true; reason=${adequacy.reason}`
      : '',
    adequacy.targets.length
      ? `Research targets: ${adequacy.targets.join('; ')}`
      : '',
    formatResearchAdequacyGuidance(adequacy),
    `Latest draft reply:\n${draftReply || '(empty)'}`,
  );
  return lines.filter(Boolean).join('\n');
}

function normalizeEvidenceIndexes(value) {
  if (!Array.isArray(value)) return [];
  return [...new Set(value
    .map((entry) => Number(entry))
    .filter((entry) => Number.isInteger(entry) && entry > 0))]
    .slice(0, 20);
}

function normalizeResearchReview(raw = null) {
  const review = raw && typeof raw === 'object' && !Array.isArray(raw) ? raw : {};
  const targetCoverage = Array.isArray(review.target_coverage || review.targetCoverage)
    ? (review.target_coverage || review.targetCoverage)
      .filter((entry) => entry && typeof entry === 'object' && !Array.isArray(entry))
      .map((entry) => ({
        target: String(entry.target || '').trim(),
        support: ['primary', 'secondary', 'context', 'none'].includes(
          String(entry.support || '').trim().toLowerCase(),
        )
          ? String(entry.support).trim().toLowerCase()
          : 'none',
        evidence_indexes: normalizeEvidenceIndexes(
          entry.evidence_indexes || entry.evidenceIndexes,
        ),
      }))
      .filter((entry) => entry.target)
      .slice(0, 12)
    : [];
  return {
    required: review.required === true,
    adequate: review.adequate === true,
    overall_support: ['primary', 'secondary', 'context', 'none'].includes(
      String(review.overall_support || review.overallSupport || '').trim().toLowerCase(),
    )
      ? String(review.overall_support || review.overallSupport).trim().toLowerCase()
      : 'none',
    evidence_indexes: normalizeEvidenceIndexes(
      review.evidence_indexes || review.evidenceIndexes,
    ),
    target_coverage: targetCoverage,
    missing_targets: normalizeGoalCriteria(
      review.missing_targets || review.missingTargets || [],
    ),
  };
}

function normalizeCompletionDecision(raw, fallbackStatus = 'continue') {
  const allowed = new Set(['continue', 'complete', 'blocked']);
  const requestedStatus = String(raw.status || '').trim().toLowerCase();
  const rawBlockerReview = raw.blocker_review || raw.blockerReview;
  const blockerReview = rawBlockerReview
    && typeof rawBlockerReview === 'object'
    && !Array.isArray(rawBlockerReview)
    ? rawBlockerReview
    : {};
  const blockerKind = String(blockerReview.kind || '').trim().toLowerCase();
  return {
    status: allowed.has(requestedStatus) ? requestedStatus : fallbackStatus,
    reason: String(raw.reason || '').trim().slice(0, 400),
    blocker_review: {
      kind: [
        'user_input',
        'permission',
        'external_dependency',
        'unavailable_capability',
        'none',
      ].includes(blockerKind)
        ? blockerKind
        : 'none',
      resolvable_in_run: blockerReview.resolvable_in_run !== false
        && blockerReview.resolvableInRun !== false,
      required_value: String(
        blockerReview.required_value || blockerReview.requiredValue || '',
      ).trim().slice(0, 300),
    },
    research_review: normalizeResearchReview(
      raw.research_review || raw.researchReview,
    ),
  };
}

function validateResearchReview(review, researchAdequacy, toolExecutions = []) {
  if (!researchAdequacy || researchAdequacy.intensity === 'none') {
    return { valid: true, reason: '' };
  }
  if (researchAdequacy.structurallyReady === false) {
    return {
      valid: false,
      reason: researchAdequacy.reason || 'No successful source evidence is available.',
    };
  }
  if (!review?.required || review.adequate !== true) {
    return {
      valid: false,
      reason: 'The completion judge did not confirm adequate research evidence.',
    };
  }

  const isValidEvidenceIndex = (index) => {
    const execution = (Array.isArray(toolExecutions) ? toolExecutions : [])[index - 1];
    return Boolean(
      execution
      && execution.ok === true
      && execution.evidenceRelevant !== false
      && execution.evidenceSource !== 'messaging',
    );
  };
  const hasValidEvidence = (indexes) => (
    Array.isArray(indexes) && indexes.some(isValidEvidenceIndex)
  );
  const requiredTargets = Array.isArray(researchAdequacy.targets)
    ? researchAdequacy.targets
    : [];

  if (requiredTargets.length === 0) {
    const reviewIndexes = [
      ...(review.evidence_indexes || []),
      ...(review.target_coverage || []).flatMap((entry) => entry.evidence_indexes || []),
    ];
    if (!hasValidEvidence(reviewIndexes)) {
      return { valid: false, reason: 'The research review cites no successful evidence entry.' };
    }
    if (researchAdequacy.intensity === 'deep' && review.overall_support !== 'primary') {
      return { valid: false, reason: 'Deep research lacks primary source support.' };
    }
    if (review.overall_support === 'none') {
      return { valid: false, reason: 'The research review did not classify its source support.' };
    }
    return { valid: true, reason: '' };
  }

  const coverageByTarget = new Map(
    (review.target_coverage || []).map((entry) => [
      String(entry.target || '').trim().toLowerCase(),
      entry,
    ]),
  );
  for (const target of requiredTargets) {
    const coverage = coverageByTarget.get(String(target).trim().toLowerCase());
    if (!coverage || coverage.support === 'none' || !hasValidEvidence(coverage.evidence_indexes)) {
      return {
        valid: false,
        reason: `The research review does not cite supporting evidence for "${target}".`,
      };
    }
    if (researchAdequacy.intensity === 'deep' && coverage.support !== 'primary') {
      return {
        valid: false,
        reason: `Deep research still lacks primary evidence for "${target}".`,
      };
    }
  }
  return { valid: true, reason: '' };
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
  if (decision?.status === 'blocked') {
    const blockerReview = decision.blocker_review;
    if (
      blockerReview
      && blockerReview.kind !== 'none'
      && blockerReview.resolvable_in_run === false
      && blockerReview.required_value
    ) {
      return decision;
    }
    return {
      ...decision,
      status: 'continue',
      reason: 'The completion judge did not substantiate a blocker that requires external input or state.',
    };
  }
  if (decision?.status === 'complete') {
    const reviewValidation = validateResearchReview(
      decision.research_review,
      researchAdequacy,
      options.toolExecutions || [],
    );
    if (reviewValidation.valid) return decision;
    return {
      status: 'continue',
      reason: reviewValidation.reason,
      research_review: decision.research_review,
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
    'Schema: {"assessment":"progressing|churn|blocked","reason":"one short concrete sentence","blocker_kind":"user_input|permission|external_dependency|unavailable_capability|none","resolvable_in_run":true}',
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
      ? `Research preflight: intensity=${adequacy.intensity}; evidence_candidates=${adequacy.evidenceCandidateCount}; semantic target coverage must be judged from the evidence summaries.`
      : '',
    adequacy.targets.length
      ? `Requested research targets: ${adequacy.targets.join('; ')}.`
      : '',
    '',
    'Assessment rules:',
    '- "progressing": You are systematically gathering necessary context and the next concrete action is already determined — you know exactly what to do next.',
    '- "churn": You are re-reading/re-searching information already in context, or exploring without a clear next concrete step. Accept the nudge and act.',
    '- "blocked": No concrete action is available in this run. You have all the evidence needed to deliver a truthful final answer or a specific external blocker.',
    '- Use "blocked" only with a non-none blocker_kind and resolvable_in_run=false. Partial evidence, a failed attempt, or uncertainty is not by itself an external blocker.',
    '- For multi-target research, keep "progressing" while uncovered targets remain and a fresh primary source can still be opened. Do not mark "blocked" just because you have partial notes.',
    '- Re-querying the same snippet source for an already covered target is "churn". Opening a different primary source for an uncovered target is "progressing".',
    adequacy.structurallyReady === false
      ? '- No successful source evidence exists yet. Prefer "progressing" if a concrete source-gathering step remains, but use "blocked" for a genuine external dependency or required user input.'
      : '',
  ];
  return lines.filter(Boolean).join('\n');
}

function enforceChurnAssessment(assessment) {
  const normalized = normalizeChurnAssessment(assessment);
  if (
    normalized.assessment === 'blocked'
    && (
      normalized.blocker_kind === 'none'
      || normalized.resolvable_in_run !== false
    )
  ) {
    return {
      ...normalized,
      assessment: 'churn',
      reason: 'The churn assessment did not identify a concrete external blocker.',
    };
  }
  return normalized;
}

function normalizeChurnAssessment(raw) {
  const allowed = new Set(['progressing', 'churn', 'blocked']);
  const assessment = String(raw?.assessment || '').trim().toLowerCase();
  const blockerKind = String(raw?.blocker_kind || raw?.blockerKind || '').trim().toLowerCase();
  return {
    assessment: allowed.has(assessment) ? assessment : 'churn',
    reason: String(raw?.reason || '').trim().slice(0, 300),
    blocker_kind: [
      'user_input',
      'permission',
      'external_dependency',
      'unavailable_capability',
      'none',
    ].includes(blockerKind)
      ? blockerKind
      : 'none',
    resolvable_in_run: raw?.resolvable_in_run !== false
      && raw?.resolvableInRun !== false,
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
  normalizeResearchReview,
  normalizeGoalContract,
  resolveRunGoalContext,
  validateResearchReview,
};
