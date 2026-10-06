'use strict';

const { getAiSettings } = require('./settings');
const { createProviderInstance, getSupportedModels } = require('./models');
const { getRawModelId, resolveModelSelection } = require('./model_identity');
const { selectInitialModel } = require('./model_router');
const { describeModelCooldowns } = require('./model_failure_cache');

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
  providerConfig.onStatus?.({
    phase: 'model_fallback',
    message: `Requested model is unavailable; using ${route.model.id}.`,
  });
}

// Why an explicitly requested model was not routable: missing from the live
// catalog, marked unavailable (provider/plan/admin), or cooling down.
function describeUnroutableModel(models, requestedId, userId, agentId) {
  const entry = resolveModelSelection(models, requestedId);
  if (!entry) {
    const providers = [...new Set(models.map((model) => model.provider))].join(',') || 'none';
    return `not in the live catalog (catalog providers: ${providers})`;
  }
  const cooldowns = describeModelCooldowns(userId, agentId, entry.id);
  if (cooldowns.length > 0) return `cooling down: ${cooldowns.join('; ')}`;
  if (entry.available === false) {
    return `unavailable (provider status ${entry.providerStatus || 'unknown'}`
      + `${entry.runtimeUnavailable ? ', runtime health' : ''})`;
  }
  return 'excluded by routing';
}

function logRouting(models, settings, route, { userId, agentId, isSubagent, modelOverride }) {
  const requestedId = String(
    modelOverride
      || (isSubagent && settings.default_subagent_model !== 'auto'
        ? settings.default_subagent_model
        : settings.default_chat_model)
      || 'auto',
  ).trim();
  const scope = `user=${userId} agent=${agentId || 'main'}${isSubagent ? ' subagent' : ''}`;
  if (!route.reason) {
    console.info(`[ModelRouter] ${scope} requested=${requestedId} selected=${route.model.id}`);
    return;
  }
  console.warn(
    `[ModelRouter] ${scope} requested=${requestedId} is ${describeUnroutableModel(models, requestedId, userId, agentId)};`
    + ` falling back to ${route.model.id}`,
  );
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
  logRouting(models, settings, route, { userId, agentId, isSubagent, modelOverride });
  reportRoutingFallback(providerConfig, route);
  return buildSelection(route.model, userId, providerConfig);
}

module.exports = { getProviderForUser };
