'use strict';

const { getAiSettings } = require('../settings');
const { resolveModelSelection } = require('../model_identity');
const { getFailureDisposition } = require('../model_failure_cache');
const { selectFallbackModel } = require('../model_router');

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
  const currentModel = resolveModelSelection(models, currentModelId);
  const disposition = getFailureDisposition(failureError);
  const excludedProviderIds = disposition?.scope === 'provider' && currentModel?.provider
    ? [currentModel.provider]
    : [];
  const failedModelIds = new Set(
    [...excludedModelIds, currentModelId]
      .map((id) => String(id || '').trim())
      .filter(Boolean),
  );
  const fallback = selectFallbackModel({
    models,
    settings: aiSettings,
    userId,
    agentId,
    currentModelId,
    preferredFallbackId,
    excludedModelIds: failedModelIds,
    excludedProviderIds,
  });
  return fallback?.id || null;
}

module.exports = {
  getFailureFallbackModelId,
};
