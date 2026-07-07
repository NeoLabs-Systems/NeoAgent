'use strict';

function normalizeOpenRouterModel(raw = {}) {
  const inputPerM = raw.pricing?.prompt != null
    ? Number(raw.pricing.prompt) * 1_000_000
    : null;
  const outputPerM = raw.pricing?.completion != null
    ? Number(raw.pricing.completion) * 1_000_000
    : null;
  return {
    id: String(raw.id || '').trim(),
    name: String(raw.name || raw.id || '').trim(),
    inputCostPerM: Number.isFinite(inputPerM) ? inputPerM : null,
    outputCostPerM: Number.isFinite(outputPerM) ? outputPerM : null,
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

// mem0/Zep/Letta/Omi all answer and judge LoCoMo with gpt-4o-mini specifically — an
// arbitrary "cheapest model on the market this week" pick would both weaken answer/judge
// quality (confounding the memory-quality signal we're trying to measure) and break
// comparability with those published numbers, so it's preferred by default whenever it's
// available on OpenRouter.
const PREFERRED_DEFAULT_MODEL_ID = 'openai/gpt-4o-mini';

// Falls back to the cheapest priced model if the preferred default isn't available (e.g.
// no OpenRouter access to it) or an explicit model id is configured. Free-tier models are
// excluded from that fallback since they're commonly rate-limited/unstable at benchmark
// scale; only used if nothing priced is available either.
function selectModel(models, explicitModelId) {
  if (explicitModelId) {
    const found = models.find((model) => model.id === explicitModelId);
    if (!found) {
      throw new Error(`Configured benchmark model is unavailable on OpenRouter: ${explicitModelId}`);
    }
    return found;
  }
  const preferred = models.find((model) => model.id === PREFERRED_DEFAULT_MODEL_ID);
  if (preferred) return preferred;

  const priced = models.filter((model) => (
    Number.isFinite(model.inputCostPerM) && model.inputCostPerM > 0
  ));
  const candidates = priced.length ? priced : models;
  const fallback = [...candidates].sort((left, right) => {
    const leftCost = (left.inputCostPerM || 0) + (left.outputCostPerM || 0);
    const rightCost = (right.inputCostPerM || 0) + (right.outputCostPerM || 0);
    if (leftCost !== rightCost) return leftCost - rightCost;
    return left.id.localeCompare(right.id);
  })[0] || null;
  if (fallback) {
    console.warn(
      `[locomo] ${PREFERRED_DEFAULT_MODEL_ID} is unavailable on OpenRouter; falling back to `
      + `${fallback.id}. Scores won't be directly comparable to mem0/Zep/Letta/Omi's published numbers.`,
    );
  }
  return fallback;
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
  estimateRunCost,
  fetchOpenRouterCatalog,
  normalizeOpenRouterModel,
  selectModel,
};
