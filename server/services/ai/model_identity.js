'use strict';

const MODEL_SELECTION_SEPARATOR = '::';

function createModelSelectionId(provider, modelId) {
  return `${String(provider).trim().toLowerCase()}${MODEL_SELECTION_SEPARATOR}${String(modelId).trim()}`;
}

function parseModelSelectionId(value) {
  const raw = String(value || '').trim();
  const separator = raw.indexOf(MODEL_SELECTION_SEPARATOR);
  if (separator <= 0) return null;
  const provider = raw.slice(0, separator).trim().toLowerCase();
  const modelId = raw.slice(separator + MODEL_SELECTION_SEPARATOR.length).trim();
  if (!provider || !modelId || modelId === 'auto') return null;
  return { provider, modelId };
}

function getRawModelId(model) {
  return String(model?.modelId || model?.id || '').trim();
}

function toSelectableModel(model) {
  const provider = String(model?.provider || '').trim().toLowerCase();
  const modelId = getRawModelId(model);
  return {
    ...model,
    id: createModelSelectionId(provider, modelId),
    modelId,
    provider,
  };
}

function resolveModelSelection(models, value, options = {}) {
  const requested = String(value || '').trim();
  if (!requested) return null;

  const exact = models.find((model) => model.id === requested);
  if (exact) return exact;

  const legacyMatches = models.filter((model) => getRawModelId(model) === requested);
  if (legacyMatches.length <= 1) return legacyMatches[0] || null;

  const preferredProvider = String(options.preferredProvider || '').trim().toLowerCase();
  if (preferredProvider) {
    const preferred = legacyMatches.find((model) => model.provider === preferredProvider);
    if (preferred) return preferred;
  }

  // Preserve the catalog's stable ordering for legacy, unscoped settings. New
  // selections always use the provider-scoped id and are therefore unambiguous.
  return legacyMatches[0];
}

function normalizeModelSelections(models, values) {
  if (!Array.isArray(values)) return [];
  const normalized = [];
  const seen = new Set();
  for (const value of values) {
    const model = resolveModelSelection(models, value);
    if (!model || seen.has(model.id)) continue;
    seen.add(model.id);
    normalized.push(model.id);
  }
  return normalized;
}

function modelMatchesConfiguredId(model, configuredIds) {
  if (!configuredIds) return false;
  return configuredIds.has(model.id) || configuredIds.has(getRawModelId(model));
}

module.exports = {
  MODEL_SELECTION_SEPARATOR,
  createModelSelectionId,
  parseModelSelectionId,
  getRawModelId,
  modelMatchesConfiguredId,
  normalizeModelSelections,
  resolveModelSelection,
  toSelectableModel,
};
