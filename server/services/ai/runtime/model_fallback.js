'use strict';

const { getAiSettings } = require('../settings');
const {
  normalizeModelSelections,
  resolveModelSelection,
} = require('../model_identity');
const { isModelCoolingDown } = require('../model_failure_cache');

async function getFailureFallbackModelId(
  userId,
  agentId,
  currentModelId,
  preferredFallbackId = null,
  failureError = null,
  signal = null,
  excludedModelIds = [],
) {
  const { getSupportedModels } = require('../models');
  const aiSettings = getAiSettings(userId, agentId);
  const models = await getSupportedModels(userId, agentId, { signal });
  const excluded = new Set(
    [...excludedModelIds]
      .map((id) => String(id || '').trim())
      .filter(Boolean),
  );
  const availableModels = models.filter(
    (model) => model.available !== false
      && !isModelCoolingDown(userId, agentId, model.id)
      && !excluded.has(model.id),
  );
  const configuredEnabledIds = Array.isArray(aiSettings.enabled_models)
    ? aiSettings.enabled_models.map((id) => String(id).trim()).filter(Boolean)
    : [];
  const enabledIds = normalizeModelSelections(availableModels, configuredEnabledIds);
  const pool = configuredEnabledIds.length > 0
    ? availableModels.filter((model) => enabledIds.includes(model.id))
    : availableModels;
  const fallbackSearchPool = pool;
  const currentModel = resolveModelSelection(models, currentModelId);

  const failureStatus = Number(
    failureError?.status
    ?? failureError?.statusCode
    ?? failureError?.response?.status,
  );
  const isProviderScopedFailure = (
    failureStatus === 401
    || failureStatus === 403
    || failureStatus === 429
    || (failureStatus >= 500 && failureStatus < 600)
    || /rate.?limit|free-models-per|service unavailable|provider unavailable|authentication|api key/i
      .test(String(failureError?.message || ''))
  );

  if (preferredFallbackId && !isProviderScopedFailure) {
    const preferred = resolveModelSelection(fallbackSearchPool, preferredFallbackId)
      || resolveModelSelection(availableModels, preferredFallbackId);
    if (preferred && preferred.id !== currentModel?.id) return preferred.id;
  }

  if (currentModel?.provider) {
    const differentProvider = fallbackSearchPool.find((model) =>
      model.id !== currentModel.id && model.provider !== currentModel.provider);
    if (differentProvider) return differentProvider.id;
  }

  if (preferredFallbackId) {
    const preferred = resolveModelSelection(fallbackSearchPool, preferredFallbackId)
      || resolveModelSelection(availableModels, preferredFallbackId);
    if (preferred && preferred.id !== currentModel?.id) return preferred.id;
  }

  const differentModel = fallbackSearchPool.find((model) => model.id !== currentModel?.id);
  return differentModel?.id || null;
}

module.exports = {
  getFailureFallbackModelId,
};
