'use strict';

const {
  normalizeModelSelections,
  resolveModelSelection,
} = require('./model_identity');
const { getModelHealthSnapshot } = require('./model_failure_cache');

const PURPOSES = new Set(['planning', 'coding', 'general', 'fast']);
const ECONOMY_MODES = new Set(['economy', 'cost_saver', 'lowest_cost']);
const QUALITY_MODES = new Set(['quality', 'highest_quality']);

function configuredModelIds(settings) {
  return Array.isArray(settings?.enabled_models)
    ? settings.enabled_models.map((id) => String(id || '').trim()).filter(Boolean)
    : [];
}

function buildRoutingPools({
  models,
  settings,
  userId,
  agentId,
  excludedModelIds = [],
  excludedProviderIds = [],
}) {
  const selectableModels = (Array.isArray(models) ? models : [])
    .filter((model) => model?.available !== false);
  const health = getModelHealthSnapshot(userId, agentId);
  const excludedModels = new Set(
    [...excludedModelIds].map((id) => String(id || '').trim()).filter(Boolean),
  );
  const excludedProviders = new Set(
    [...excludedProviderIds]
      .map((id) => String(id || '').trim().toLowerCase())
      .filter(Boolean),
  );
  const readyModels = selectableModels.filter((model) => (
    !health.modelIds.has(model.id)
    && !health.providerIds.has(model.provider)
    && !excludedModels.has(model.id)
    && !excludedProviders.has(model.provider)
  ));
  const configuredIds = configuredModelIds(settings);
  const normalizedConfiguredIds = new Set(
    normalizeModelSelections(selectableModels, configuredIds),
  );
  const configuredReadyModels = configuredIds.length > 0
    ? readyModels.filter((model) => normalizedConfiguredIds.has(model.id))
    : readyModels;

  return {
    selectableModels,
    readyModels,
    configuredIds,
    configuredReadyModels,
  };
}

function requestedPurpose({ isSubagent, selectionHint = {} }) {
  const explicitPurpose = String(selectionHint.purpose || '').trim().toLowerCase();
  if (PURPOSES.has(explicitPurpose)) return explicitPurpose;
  if (selectionHint.autonomyLevel === 'high' || selectionHint.complexity === 'complex') {
    return 'planning';
  }
  return isSubagent ? 'fast' : 'general';
}

function priceScore(model, costMode, requiredConfidence) {
  const tier = String(model?.priceTier || '').trim().toLowerCase();
  if (ECONOMY_MODES.has(costMode)) {
    return ({ free: 0, cheap: 1, medium: 2, expensive: 3 })[tier] ?? 4;
  }
  if (QUALITY_MODES.has(costMode) || requiredConfidence === 'high') {
    return ({ expensive: 0, medium: 1, cheap: 2, free: 3 })[tier] ?? 4;
  }
  return 0;
}

function rankModels(models, { isSubagent = false, selectionHint = {}, settings = {} } = {}) {
  const purpose = requestedPurpose({ isSubagent, selectionHint });
  const costMode = String(selectionHint.costMode || settings.cost_mode || 'balanced_auto')
    .trim()
    .toLowerCase();
  const requiredConfidence = String(selectionHint.requiredConfidence || '').trim().toLowerCase();
  const purposeOrder = [purpose, 'general', 'planning', 'coding', 'fast'];
  const purposeRank = new Map();
  for (const entry of purposeOrder) {
    if (!purposeRank.has(entry)) purposeRank.set(entry, purposeRank.size);
  }

  return models
    .map((model, index) => ({
      model,
      index,
      purposeScore: purposeRank.get(model.purpose) ?? purposeRank.size,
      priceScore: priceScore(model, costMode, requiredConfidence),
    }))
    .sort((left, right) => (
      left.purposeScore - right.purposeScore
      || left.priceScore - right.priceScore
      || left.index - right.index
    ))
    .map((entry) => entry.model);
}

function chooseAutomaticModel(models, options) {
  if (!models.length) return null;
  if (options.settings.smarter_model_selector === false) return models[0];
  return rankModels(models, options)[0] || models[0];
}

function resolveReadyModel(readyModels, selectionId) {
  return resolveModelSelection(readyModels, selectionId);
}

function selectInitialModel({
  models,
  settings,
  userId,
  agentId,
  isSubagent = false,
  modelOverride = null,
  selectionHint = {},
}) {
  const pools = buildRoutingPools({ models, settings, userId, agentId });
  if (pools.selectableModels.length === 0) {
    throw new Error('No AI providers are currently available. Open Settings and configure at least one provider.');
  }
  if (pools.readyModels.length === 0) {
    throw new Error('All discovered AI models are temporarily unavailable. The next run will retry after their recovery window.');
  }

  const requestedId = typeof modelOverride === 'string' && modelOverride.trim()
    ? modelOverride.trim()
    : (
      isSubagent
        ? String(settings.default_subagent_model || 'auto')
        : String(settings.default_chat_model || 'auto')
    );
  if (requestedId !== 'auto') {
    const requested = resolveReadyModel(pools.readyModels, requestedId);
    if (requested) return { model: requested, reason: null };
  }

  const preferredPool = pools.configuredReadyModels.length > 0
    ? pools.configuredReadyModels
    : pools.readyModels;
  const automatic = chooseAutomaticModel(preferredPool, {
    isSubagent,
    selectionHint,
    settings,
  });
  const selected = automatic;

  let reason = null;
  if (requestedId !== 'auto') reason = 'requested_model_unavailable';
  else if (pools.configuredIds.length > 0 && pools.configuredReadyModels.length === 0) {
    reason = 'configured_pool_unavailable';
  }
  return { model: selected, reason };
}

function selectFallbackModel({
  models,
  settings,
  userId,
  agentId,
  currentModelId,
  excludedModelIds = [],
  excludedProviderIds = [],
}) {
  const pools = buildRoutingPools({
    models,
    settings,
    userId,
    agentId,
    excludedModelIds,
    excludedProviderIds,
  });
  if (pools.readyModels.length === 0) return null;

  const currentModel = resolveModelSelection(pools.selectableModels, currentModelId)
    || resolveModelSelection(models, currentModelId);
  const configuredPool = pools.configuredReadyModels.length > 0
    ? pools.configuredReadyModels
    : pools.readyModels;
  const diversePool = currentModel?.provider
    ? configuredPool.filter((model) => model.provider !== currentModel.provider)
    : [];
  const candidatePool = diversePool.length > 0 ? diversePool : configuredPool;
  return rankModels(candidatePool, {
    selectionHint: { purpose: currentModel?.purpose || 'general' },
    settings,
  })[0] || null;
}

module.exports = {
  buildRoutingPools,
  rankModels,
  selectFallbackModel,
  selectInitialModel,
};
