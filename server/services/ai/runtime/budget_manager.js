'use strict';

const { buildLoopPolicy } = require('../loopPolicy');

const DEFAULTS = Object.freeze({
  modelTurns: 250,
  inputTokens: 2_000_000,
  outputTokens: 500_000,
  monetaryCostUsd: 25,
  wallClockMs: 60 * 60 * 1000,
  toolRuntimeMs: 20 * 60 * 1000,
  retriesPerNode: 5,
  failuresPerErrorClass: 8,
  evidenceBudget: 24,
  sideEffectBudget: 20,
  subagentCount: 10,
  subagentTurns: 30,
});

function createBudgetManager({
  aiSettings = {},
  triggerType = 'user',
  analysisMode = 'execute',
  options = {},
  startedAtMs = Date.now(),
} = {}) {
  const loopPolicy = buildLoopPolicy(aiSettings, triggerType, analysisMode, options);
  const autonomyPolicy = options.autonomyPolicy && typeof options.autonomyPolicy === 'object'
    ? options.autonomyPolicy
    : {};
  const longHorizon = analysisMode === 'plan_execute'
    || autonomyPolicy.complexity === 'complex'
    || autonomyPolicy.autonomy_level === 'high'
    || autonomyPolicy.autonomyLevel === 'high';
  const defaultEvidenceBudget = longHorizon
    ? DEFAULTS.evidenceBudget * 2
    : analysisMode === 'direct_answer'
      ? 8
      : DEFAULTS.evidenceBudget;
  const limits = {
    modelTurns: loopPolicy.maxIterations || DEFAULTS.modelTurns,
    inputTokens: Number(options.maxInputTokens) || DEFAULTS.inputTokens,
    outputTokens: Number(options.maxOutputTokens) || DEFAULTS.outputTokens,
    monetaryCostUsd: Number(options.maxCostUsd) || DEFAULTS.monetaryCostUsd,
    wallClockMs: Number(options.maxWallClockMs) || DEFAULTS.wallClockMs,
    toolRuntimeMs: Number(options.maxToolRuntimeMs) || DEFAULTS.toolRuntimeMs,
    retriesPerNode: Number(options.maxRetriesPerNode) || DEFAULTS.retriesPerNode,
    failuresPerErrorClass: Number(options.maxFailuresPerErrorClass) || DEFAULTS.failuresPerErrorClass,
    evidenceBudget: Number(options.maxEvidenceItems) || defaultEvidenceBudget,
    sideEffectBudget: Number(options.maxSideEffects) || DEFAULTS.sideEffectBudget,
    subagentCount: Number(aiSettings.subagent_max_children_per_run) || DEFAULTS.subagentCount,
    subagentTurns: Number(aiSettings.subagent_max_turns) || DEFAULTS.subagentTurns,
    consecutiveNoProgress: loopPolicy.maxConsecutiveReadOnlyIterations || 8,
    consecutiveToolFailures: loopPolicy.maxConsecutiveToolFailures || 5,
  };

  const softRatio = 0.8;
  const usage = {
    modelTurns: 0,
    inputTokens: 0,
    outputTokens: 0,
    monetaryCostUsd: 0,
    toolRuntimeMs: 0,
    evidenceItems: 0,
    sideEffects: 0,
    subagentCount: 0,
    subagentTurns: 0,
    consecutiveNoProgress: 0,
    consecutiveToolFailures: 0,
    failuresByClass: Object.create(null),
    retriesByNode: Object.create(null),
  };

  function recordModelTurn({ inputTokens = 0, outputTokens = 0, costUsd = 0 } = {}) {
    usage.modelTurns += 1;
    usage.inputTokens += Math.max(0, Number(inputTokens) || 0);
    usage.outputTokens += Math.max(0, Number(outputTokens) || 0);
    usage.monetaryCostUsd += Math.max(0, Number(costUsd) || 0);
  }

  function recordToolRuntime(ms = 0) {
    usage.toolRuntimeMs += Math.max(0, Number(ms) || 0);
  }

  function recordEvidence(count = 1) {
    usage.evidenceItems += Math.max(0, Number(count) || 0);
  }

  function recordSideEffect(count = 1) {
    usage.sideEffects += Math.max(0, Number(count) || 0);
  }

  // Counts consecutive tool turns that changed no state and produced no new
  // evidence. Reads that pull in new information are progress, so a long
  // research run never trips this; genuine spinning does.
  function recordNoProgressTurn(madeNoProgress) {
    if (madeNoProgress) usage.consecutiveNoProgress += 1;
    else usage.consecutiveNoProgress = 0;
  }

  function recordToolFailure(isFailure, errorClass = 'logic_failure') {
    if (isFailure) {
      usage.consecutiveToolFailures += 1;
      usage.failuresByClass[errorClass] = (usage.failuresByClass[errorClass] || 0) + 1;
    } else {
      usage.consecutiveToolFailures = 0;
    }
  }

  function recordNodeRetry(nodeId) {
    const key = String(nodeId || 'unknown');
    usage.retriesByNode[key] = (usage.retriesByNode[key] || 0) + 1;
    return usage.retriesByNode[key];
  }

  function wallClockMs() {
    return Math.max(0, Date.now() - startedAtMs);
  }

  function dimensionStatus(used, limit) {
    if (!Number.isFinite(limit) || limit <= 0) return 'ok';
    if (used >= limit) return 'hard';
    if (used >= limit * softRatio) return 'soft';
    return 'ok';
  }

  function snapshot() {
    const wall = wallClockMs();
    const dimensions = {
      modelTurns: dimensionStatus(usage.modelTurns, limits.modelTurns),
      inputTokens: dimensionStatus(usage.inputTokens, limits.inputTokens),
      outputTokens: dimensionStatus(usage.outputTokens, limits.outputTokens),
      monetaryCostUsd: dimensionStatus(usage.monetaryCostUsd, limits.monetaryCostUsd),
      wallClockMs: dimensionStatus(wall, limits.wallClockMs),
      toolRuntimeMs: dimensionStatus(usage.toolRuntimeMs, limits.toolRuntimeMs),
      evidenceBudget: dimensionStatus(usage.evidenceItems, limits.evidenceBudget),
      sideEffectBudget: dimensionStatus(usage.sideEffects, limits.sideEffectBudget),
      subagentCount: dimensionStatus(usage.subagentCount, limits.subagentCount),
      consecutiveNoProgress: dimensionStatus(usage.consecutiveNoProgress, limits.consecutiveNoProgress),
      consecutiveToolFailures: dimensionStatus(
        usage.consecutiveToolFailures,
        limits.consecutiveToolFailures,
      ),
    };

    const hard = Object.entries(dimensions).filter(([, status]) => status === 'hard').map(([k]) => k);
    const soft = Object.entries(dimensions).filter(([, status]) => status === 'soft').map(([k]) => k);

    return {
      limits,
      usage: { ...usage, wallClockMs: wall },
      dimensions,
      softLimitReached: soft.length > 0,
      hardLimitReached: hard.length > 0,
      softDimensions: soft,
      hardDimensions: hard,
      loopPolicy,
    };
  }

  function shouldContinue({
    openObligations = [],
    hasNextAction = false,
  } = {}) {
    const snap = snapshot();
    if (snap.hardLimitReached) {
      return {
        continue: false,
        reason: 'hard_budget',
        snapshot: snap,
      };
    }
    if (!openObligations.length) {
      return {
        continue: false,
        reason: 'no_open_obligations',
        snapshot: snap,
      };
    }
    if (!hasNextAction) {
      return {
        continue: false,
        reason: 'no_next_action',
        snapshot: snap,
      };
    }
    if (usage.consecutiveNoProgress >= limits.consecutiveNoProgress) {
      return {
        continue: false,
        reason: 'no_progress_delta',
        snapshot: snap,
      };
    }
    return {
      continue: true,
      reason: 'ok',
      snapshot: snap,
      softWarning: snap.softLimitReached,
    };
  }

  return {
    limits,
    loopPolicy,
    usage,
    recordModelTurn,
    recordToolRuntime,
    recordEvidence,
    recordSideEffect,
    recordNoProgressTurn,
    recordToolFailure,
    recordNodeRetry,
    snapshot,
    shouldContinue,
  };
}

module.exports = {
  createBudgetManager,
  DEFAULTS,
};
