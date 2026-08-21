'use strict';

const { randomUUID } = require('crypto');
const db = require('../../../db/database');
const { EVENT_TYPES, VISIBILITY } = require('./events/event_types');
const { DEFAULT_MAX_SILENCE_SECONDS } = require('./constants');

function asArray(value) {
  return Array.isArray(value) ? value.filter(Boolean) : [];
}

function asObject(value, fallback = {}) {
  return value && typeof value === 'object' && !Array.isArray(value) ? value : fallback;
}

function normalizeContract(raw = {}, defaults = {}) {
  const source = asObject(raw, {});
  const deliverables = asArray(source.deliverables).map((item, index) => {
    if (typeof item === 'string') {
      return { id: `d${index + 1}`, type: 'text', required: true, description: item };
    }
    return {
      id: String(item.id || `d${index + 1}`),
      type: String(item.type || 'text'),
      required: item.required !== false,
      description: item.description || item.goal || '',
    };
  });

  return {
    goal: String(source.goal || defaults.goal || '').trim(),
    intent: String(source.intent || defaults.intent || 'execute').trim() || 'execute',
    complexity: String(source.complexity || defaults.complexity || 'standard').trim() || 'standard',
    deliverables,
    constraints: asArray(source.constraints).map(String),
    exclusions: asArray(source.exclusions).map(String),
    evidence_requirements: asArray(source.evidence_requirements || source.evidenceRequirements).map(String),
    success_criteria: asArray(source.success_criteria || source.successCriteria).map(String),
    research_targets: asArray(source.research_targets || source.researchTargets).map(String),
    research_depth: String(source.research_depth || source.researchDepth || 'none'),
    freshness_required: source.freshness_required === true || source.freshnessRequired === true,
    verification_required: source.verification_required !== false
      && source.verificationRequired !== false
      && (source.needs_verification === true
        || source.needsVerification === true
        || source.verification_required === true
        || defaults.verification_required === true),
    side_effect_policy: asObject(source.side_effect_policy || source.sideEffectPolicy, {
      repository_write: 'ask',
      push: 'ask',
      external_message: 'ask',
    }),
    update_policy: asObject(source.update_policy || source.updatePolicy, {
      acknowledge_immediately: defaults.acknowledge_immediately !== false,
      max_silence_seconds: Number(
        source.update_policy?.max_silence_seconds
        || source.updatePolicy?.maxSilenceSeconds
        || defaults.max_silence_seconds
        || DEFAULT_MAX_SILENCE_SECONDS,
      ) || DEFAULT_MAX_SILENCE_SECONDS,
    }),
    completion_policy: asObject(source.completion_policy || source.completionPolicy, {
      required_confidence: Number(
        source.completion_policy?.required_confidence
        || source.completionPolicy?.requiredConfidence
        || 0.7,
      ) || 0.7,
      verification_required: source.verification_required !== false,
      partial_completion_allowed: source.partial_completion_allowed === true
        || source.partialCompletionAllowed === true,
    }),
    classification_confidence: Number(
      source.classification_confidence
      ?? source.classificationConfidence
      ?? defaults.classification_confidence
      ?? 0.55,
    ) || 0.55,
    open_obligations: asArray(source.open_obligations || source.openObligations),
    steering_history: asArray(source.steering_history || source.steeringHistory),
    version: Number(source.version || 1) || 1,
  };
}

function contractFromAnalysis(analysis = {}, userMessage = '') {
  const mode = String(analysis.mode || 'execute');
  const intent = mode === 'direct_answer' ? 'respond' : 'execute';
  const success = asArray(analysis.success_criteria).map(String);
  const researchTargets = asArray(analysis.research_targets).map(String);
  const needsTools = mode !== 'direct_answer'
    || researchTargets.length > 0
    || asArray(analysis.suggested_tools).length > 0;

  const open = [];
  if (needsTools) open.push({ id: 'execution', type: 'execution', required: true });
  if (analysis.needs_verification) open.push({ id: 'verification', type: 'verification', required: true });
  if (researchTargets.length > 0 || ['light', 'deep'].includes(String(analysis.research_depth || ''))) {
    open.push({ id: 'research', type: 'research', required: true, targets: researchTargets });
  }
  if (mode === 'plan_execute') {
    open.push({ id: 'plan', type: 'plan', required: true });
  }

  return normalizeContract({
    goal: analysis.goal || String(userMessage || '').trim().slice(0, 500),
    intent,
    complexity: analysis.complexity || 'standard',
    deliverables: mode === 'direct_answer'
      ? [{ id: 'reply', type: 'text', required: true, description: 'Final user-facing answer' }]
      : [{ id: 'result', type: 'task_result', required: true, description: analysis.goal || 'Completed work' }],
    success_criteria: success,
    research_targets: researchTargets,
    research_depth: analysis.research_depth || 'none',
    evidence_requirements: success,
    verification_required: analysis.needs_verification === true || mode === 'plan_execute',
    classification_confidence: Number(analysis.confidence ?? analysis.classification_confidence ?? 0.55),
    open_obligations: open,
    update_policy: {
      acknowledge_immediately: mode !== 'direct_answer',
      max_silence_seconds: analysis.progress_update_policy === 'required' ? 60 : DEFAULT_MAX_SILENCE_SECONDS,
    },
    completion_policy: {
      required_confidence: analysis.completion_confidence_required === 'high' ? 0.9 : 0.7,
      verification_required: analysis.needs_verification === true,
    },
  });
}

function evaluateOpenObligations(contract, {
  completedNodeKeys = [],
  evidence = [],
  artifacts = [],
  finalContent = '',
} = {}) {
  const c = normalizeContract(contract);
  const completed = new Set(completedNodeKeys.map(String));
  const open = [];

  for (const obligation of asArray(c.open_obligations)) {
    if (obligation.required === false) continue;
    const id = String(obligation.id || obligation.type || '');
    if (completed.has(id) || completed.has(String(obligation.type || ''))) continue;
    if (obligation.type === 'research' && evidence.length > 0) continue;
    // Verification obligations are owned by the verification phase / completion
    // gate itself — do not treat them as still-open execution work here.
    if (obligation.type === 'verification' || id === 'verification') continue;
    // Execution obligation is satisfied once the execute work node completed.
    if (
      (obligation.type === 'execution' || id === 'execution')
      && (completed.has('execute') || completed.has('execute-main') || completed.has('execute_main'))
    ) {
      continue;
    }
    open.push(obligation);
  }

  for (const deliverable of asArray(c.deliverables).filter((d) => d.required !== false)) {
    const hasFinalText = String(finalContent || '').trim().length > 0;
    // User-facing text deliverables (including general task_result reports) are
    // satisfied by a non-empty final reply. Binary artifacts still need evidence.
    if (
      hasFinalText
      && (deliverable.type === 'text'
        || deliverable.type === 'task_result'
        || deliverable.type === 'message'
        || deliverable.type === 'reply')
    ) {
      continue;
    }
    if (artifacts.some((a) => a.type === deliverable.type || a.id === deliverable.id)) continue;
    if (completed.has(deliverable.id)) continue;
    open.push({
      id: deliverable.id,
      type: 'deliverable',
      required: true,
      deliverable,
    });
  }

  // Whether free-text criteria are actually met is a semantic judgement and
  // belongs to the verifier. The deterministic gate can only check that the run
  // produced evidence at all — matching criterion prose against tool output
  // never succeeds and would keep every run reopening until its budget is gone.
  const evidenceRequirements = asArray(c.evidence_requirements);
  if (evidenceRequirements.length > 0 && evidence.length === 0 && artifacts.length === 0) {
    open.push({
      id: 'evidence',
      type: 'evidence',
      required: true,
      criteria: evidenceRequirements,
    });
  }

  return {
    open,
    satisfied: open.length === 0,
    contract: c,
  };
}

function saveContract(runId, contract, { eventBus = null, userId = null, agentId = null } = {}) {
  const normalized = normalizeContract(contract);
  const existing = db.prepare(
    'SELECT COALESCE(MAX(version), 0) AS version FROM agent_task_contracts WHERE run_id = ?',
  ).get(runId);
  const version = Number(existing?.version || 0) + 1;
  normalized.version = version;
  const id = randomUUID();
  db.prepare(
    `INSERT INTO agent_task_contracts (id, run_id, version, contract_json)
     VALUES (?, ?, ?, ?)`,
  ).run(id, runId, version, JSON.stringify(normalized));

  if (eventBus && userId) {
    eventBus.publish({
      runId,
      userId,
      agentId,
      eventType: version === 1 ? EVENT_TYPES.TASK_CONTRACT_CREATED : EVENT_TYPES.TASK_CONTRACT_REVISED,
      payload: { contract_id: id, version, goal: normalized.goal, intent: normalized.intent },
      visibility: VISIBILITY.OPERATOR,
    });
  }

  return { id, version, contract: normalized };
}

function loadLatestContract(runId) {
  const row = db.prepare(
    `SELECT id, run_id, version, contract_json, created_at, updated_at
     FROM agent_task_contracts
     WHERE run_id = ?
     ORDER BY version DESC
     LIMIT 1`,
  ).get(runId);
  if (!row) return null;
  let contract = {};
  try {
    contract = JSON.parse(row.contract_json || '{}');
  } catch {
    contract = {};
  }
  return {
    id: row.id,
    runId: row.run_id,
    version: Number(row.version || 1),
    contract: normalizeContract(contract),
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

module.exports = {
  normalizeContract,
  contractFromAnalysis,
  evaluateOpenObligations,
  saveContract,
  loadLatestContract,
};
