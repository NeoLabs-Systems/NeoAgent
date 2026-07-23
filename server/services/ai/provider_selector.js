'use strict';

const { getAiSettings } = require('./settings');
const { createProviderInstance, getSupportedModels } = require('./models');
const {
  getRawModelId,
  normalizeModelSelections,
  resolveModelSelection,
} = require('./model_identity');

function buildSelection(model, userId, providerConfig) {
  return {
    provider: createProviderInstance(model.provider, userId, providerConfig),
    model: getRawModelId(model),
    modelSelectionId: model.id,
    providerName: model.provider,
  };
}

async function getProviderForUser(
  userId,
  _task = '',
  isSubagent = false,
  modelOverride = null,
  providerConfig = {},
) {
  const agentId = providerConfig.agentId || null;
  const aiSettings = getAiSettings(userId, agentId);
  const models = await getSupportedModels(userId, agentId, {
    signal: providerConfig.signal,
  });
  const selectableModels = models.filter((model) => model.available !== false);

  if (modelOverride && typeof modelOverride === 'string') {
    const requested = resolveModelSelection(selectableModels, modelOverride);
    if (!requested) {
      throw new Error(`Requested model '${modelOverride.trim()}' is not available.`);
    }
    return buildSelection(requested, userId, providerConfig);
  }

  const configuredEnabledIds = Array.isArray(aiSettings.enabled_models)
    ? aiSettings.enabled_models.map((id) => String(id).trim()).filter(Boolean)
    : [];
  const enabledIds = normalizeModelSelections(selectableModels, configuredEnabledIds);
  const availableModels = configuredEnabledIds.length > 0
    ? selectableModels.filter((model) => enabledIds.includes(model.id))
    : selectableModels;

  if (availableModels.length === 0) {
    const message = configuredEnabledIds.length > 0
      ? 'None of the enabled AI models are currently available. Check model and provider settings.'
      : 'No AI providers are currently available. Open Settings and configure at least one provider.';
    throw new Error(message);
  }

  const fallbackModel = availableModels[0];
  const userSelectedDefault = isSubagent
    ? (aiSettings.default_subagent_model || 'auto')
    : (aiSettings.default_chat_model || 'auto');
  const smarterSelection = aiSettings.smarter_model_selector !== false
    && aiSettings.smarter_model_selector !== 'false';

  let selectedModel = fallbackModel;
  if (userSelectedDefault !== 'auto') {
    selectedModel = resolveModelSelection(availableModels, userSelectedDefault) || fallbackModel;
  } else {
    const selectionHint = providerConfig.selectionHint && typeof providerConfig.selectionHint === 'object'
      ? providerConfig.selectionHint
      : {};
    const preferredPurpose = String(selectionHint.purpose || '').trim().toLowerCase();
    const highAutonomy = selectionHint.autonomyLevel === 'high'
      || selectionHint.complexity === 'complex';
    const requiredConfidence = String(selectionHint.requiredConfidence || '').trim().toLowerCase();
    const costMode = String(selectionHint.costMode || aiSettings.cost_mode || 'balanced_auto')
      .trim()
      .toLowerCase();
    const requestedPurpose = ['planning', 'coding', 'general', 'fast'].includes(preferredPurpose)
      ? preferredPurpose
      : '';
    const priceRank = { free: 0, cheap: 1, medium: 2, expensive: 3 };
    const chooseForPurpose = (purpose) => {
      const candidates = availableModels.filter((model) => model.purpose === purpose);
      if (candidates.length === 0) return null;
      if (['economy', 'cost_saver', 'lowest_cost'].includes(costMode)) {
        return [...candidates].sort((left, right) => (
          (priceRank[left.priceTier] ?? 99) - (priceRank[right.priceTier] ?? 99)
        ))[0];
      }
      if (['quality', 'highest_quality'].includes(costMode) || requiredConfidence === 'high') {
        return candidates.find((model) => model.priceTier !== 'free' && model.priceTier !== 'cheap')
          || candidates[0];
      }
      return candidates[0];
    };

    if (smarterSelection && requestedPurpose) {
      selectedModel = chooseForPurpose(requestedPurpose) || fallbackModel;
    } else if (smarterSelection && highAutonomy) {
      selectedModel = chooseForPurpose('planning') || chooseForPurpose('general') || fallbackModel;
    } else if (isSubagent) {
      selectedModel = chooseForPurpose('fast') || fallbackModel;
    } else {
      selectedModel = chooseForPurpose('general') || fallbackModel;
    }
  }

  return buildSelection(selectedModel, userId, providerConfig);
}

module.exports = { getProviderForUser };
