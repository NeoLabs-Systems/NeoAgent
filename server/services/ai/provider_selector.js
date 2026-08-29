'use strict';

const { getAiSettings } = require('./settings');
const { createProviderInstance, getSupportedModels } = require('./models');
const { getRawModelId } = require('./model_identity');
const { selectInitialModel } = require('./model_router');

function buildSelection(model, userId, providerConfig) {
  return {
    provider: createProviderInstance(model.provider, userId, providerConfig),
    model: getRawModelId(model),
    modelSelectionId: model.id,
    providerName: model.provider,
  };
}

function reportRoutingFallback(providerConfig, route) {
  if (!route.reason) return;
  const message = route.reason === 'configured_pool_unavailable'
    ? `Configured models are unavailable; using ${route.model.id}.`
    : `Requested model is unavailable; using ${route.model.id}.`;
  providerConfig.onStatus?.({ phase: 'model_fallback', message });
}

async function getProviderForUser(
  userId,
  _task = '',
  isSubagent = false,
  modelOverride = null,
  providerConfig = {},
) {
  const agentId = providerConfig.agentId || null;
  const settings = getAiSettings(userId, agentId);
  const models = await getSupportedModels(userId, agentId, {
    signal: providerConfig.signal,
  });
  const route = selectInitialModel({
    models,
    settings,
    userId,
    agentId,
    isSubagent,
    modelOverride,
    selectionHint: providerConfig.selectionHint,
  });
  reportRoutingFallback(providerConfig, route);
  return buildSelection(route.model, userId, providerConfig);
}

module.exports = { getProviderForUser };
