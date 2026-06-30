'use strict';

const PRICE_TIER_ORDER = Object.freeze({
  free: 0,
  cheap: 1,
  medium: 2,
  expensive: 3,
});

function normalizeOpenRouterModel(raw = {}) {
  const inputPerM = raw.pricing?.prompt != null
    ? Number(raw.pricing.prompt) * 1_000_000
    : null;
  const outputPerM = raw.pricing?.completion != null
    ? Number(raw.pricing.completion) * 1_000_000
    : null;
  const inputModalities = Array.isArray(raw.architecture?.input_modalities)
    ? raw.architecture.input_modalities.map((value) => String(value).toLowerCase())
    : [];
  const outputModalities = Array.isArray(raw.architecture?.output_modalities)
    ? raw.architecture.output_modalities.map((value) => String(value).toLowerCase())
    : [];

  return {
    id: String(raw.id || '').trim(),
    name: String(raw.name || raw.id || '').trim(),
    inputCostPerM: Number.isFinite(inputPerM) ? inputPerM : null,
    outputCostPerM: Number.isFinite(outputPerM) ? outputPerM : null,
    supportsVision: inputModalities.includes('image'),
    inputModalities,
    outputModalities,
  };
}

async function fetchOpenRouterCatalog(config = {}) {
  if (!config.apiKey) return [];
  const baseUrl = String(config.baseUrl || 'https://openrouter.ai/api/v1').replace(/\/+$/, '');
  const response = await fetch(`${baseUrl}/models`, {
    headers: {
      Authorization: `Bearer ${config.apiKey}`,
    },
  });
  if (!response.ok) {
    throw new Error(`OpenRouter models request failed with HTTP ${response.status}`);
  }
  const payload = await response.json();
  return Array.isArray(payload?.data)
    ? payload.data.map(normalizeOpenRouterModel).filter((model) => model.id)
    : [];
}

function enrichAppModels(appModels, rawOpenRouterModels) {
  const rawById = new Map(rawOpenRouterModels.map((model) => [model.id, model]));
  return appModels.map((model) => ({
    ...model,
    ...(rawById.get(model.id) || {}),
    supportsVision: rawById.get(model.id)?.supportsVision === true,
  }));
}

function assertExplicitModelsAvailable(explicitModelIds, models) {
  const availableIds = new Set(models.map((model) => model.id));
  const missing = explicitModelIds.filter((id) => !availableIds.has(id));
  if (missing.length) {
    throw new Error(`Configured benchmark models are unavailable: ${missing.join(', ')}`);
  }
}

function selectBenchmarkModels({ appModels, rawOpenRouterModels, explicitModelIds = [], priceTierCeiling = 'cheap' }) {
  const enriched = enrichAppModels(
    appModels.filter((model) => model.provider === 'openrouter' && model.available !== false),
    rawOpenRouterModels,
  );
  if (explicitModelIds.length > 0) {
    assertExplicitModelsAvailable(explicitModelIds, enriched);
    return explicitModelIds.map((id) => enriched.find((model) => model.id === id)).filter(Boolean);
  }

  const ceilingRank = PRICE_TIER_ORDER[priceTierCeiling] ?? PRICE_TIER_ORDER.cheap;
  const selected = enriched.filter((model) => {
    const rank = PRICE_TIER_ORDER[model.priceTier] ?? Number.MAX_SAFE_INTEGER;
    return rank <= ceilingRank;
  });
  if (!selected.length) {
    throw new Error(`No available OpenRouter models matched price tier <= ${priceTierCeiling}.`);
  }
  return selected.sort((left, right) => {
    const rankDelta = (PRICE_TIER_ORDER[left.priceTier] ?? 99) - (PRICE_TIER_ORDER[right.priceTier] ?? 99);
    if (rankDelta !== 0) return rankDelta;
    return String(left.id).localeCompare(String(right.id));
  });
}

function estimateRunCost(usage, model) {
  const inputTokens = Number(usage?.inputTokens || 0);
  const outputTokens = Number(usage?.outputTokens || 0);
  const inputCostPerM = Number(model?.inputCostPerM);
  const outputCostPerM = Number(model?.outputCostPerM);
  if (!Number.isFinite(inputCostPerM) || !Number.isFinite(outputCostPerM)) {
    return null;
  }
  return ((inputTokens / 1_000_000) * inputCostPerM) + ((outputTokens / 1_000_000) * outputCostPerM);
}

module.exports = {
  PRICE_TIER_ORDER,
  enrichAppModels,
  estimateRunCost,
  fetchOpenRouterCatalog,
  normalizeOpenRouterModel,
  selectBenchmarkModels,
};
