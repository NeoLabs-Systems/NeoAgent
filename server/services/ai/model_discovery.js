'use strict';

const crypto = require('crypto');

const REFRESH_INTERVAL_MS = 5 * 60 * 1000;
const PERMANENT_ERROR_BACKOFF_MS = 30 * 60 * 1000;
const DISCOVERY_TIMEOUT_MS = 10_000;
const OLLAMA_REFRESH_INTERVAL_MS = 30_000;

const providerModelCache = new Map();
const providerRefreshes = new Map();
const ollamaModelCache = new Map();
const ollamaRefreshes = new Map();
const openrouterPricingCache = new Map();

function inferModelPurpose(id) {
  const value = id.toLowerCase();
  if (/flash|nano|lite|tiny|haiku|scout|mini(?!max)|small/.test(value)) return 'fast';
  if (/r1|qwq|o[0-9]|reasoning|thinking/.test(value)) return 'planning';
  if (/code|coder|starcoder|devstral|codex|codegemma/.test(value)) return 'coding';
  return 'general';
}

const PROVIDER_LABELS = Object.freeze({
  openai: (model) => `${model.id} (OpenAI)`,
  'openai-compatible': (model) => `${model.name || model.id} (Custom OpenAI-compatible)`,
  anthropic: (model) => `${model.name || model.id} (Anthropic)`,
  google: (model) => `${model.name || model.id} (Google)`,
  nvidia: (model) => `${model.id} (NVIDIA NIM)`,
  grok: (model) => `${model.id} (xAI)`,
  'grok-oauth': (model) => `${model.id} (xAI OAuth)`,
  openrouter: (model) => `${model.name || model.id} (OpenRouter)`,
});

function cacheKeyForProvider(providerId, apiKey, baseUrl) {
  return crypto
    .createHash('sha256')
    .update(String(providerId || ''))
    .update('\0')
    .update(String(apiKey || ''))
    .update('\0')
    .update(String(baseUrl || ''))
    .digest('hex');
}

function abortError(signal, fallback = 'Model discovery aborted.') {
  if (signal?.reason instanceof Error) return signal.reason;
  const error = new Error(String(signal?.reason || fallback));
  error.name = 'AbortError';
  error.code = 'ABORT_ERR';
  return error;
}

function waitForSharedResult(promise, signal) {
  if (!signal) return promise;
  if (signal.aborted) return Promise.reject(abortError(signal));

  return new Promise((resolve, reject) => {
    const onAbort = () => reject(abortError(signal));
    signal.addEventListener('abort', onAbort, { once: true });
    promise.then(resolve, reject).finally(() => {
      signal.removeEventListener('abort', onAbort);
    });
  });
}

async function runDiscovery(factory, timeoutMs = DISCOVERY_TIMEOUT_MS) {
  const controller = new AbortController();
  let timer = null;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(() => {
      const error = new Error(`Model discovery timed out after ${timeoutMs}ms.`);
      error.code = 'MODEL_DISCOVERY_TIMEOUT';
      controller.abort(error);
      reject(error);
    }, timeoutMs);
  });

  try {
    return await Promise.race([
      Promise.resolve().then(() => factory(controller.signal)),
      timeout,
    ]);
  } finally {
    clearTimeout(timer);
  }
}

function normalizeRawModels(rawModels, providerId, fallbackIds = []) {
  const source = Array.isArray(rawModels) && rawModels.length > 0
    ? rawModels
    : fallbackIds;
  const labelModel = PROVIDER_LABELS[providerId] || ((model) => model.name || model.id);
  const normalized = [];
  const seen = new Set();

  for (const raw of source) {
    const model = typeof raw === 'string' ? { id: raw, name: raw } : raw;
    const id = String(model?.id || '').trim();
    if (!id || seen.has(id)) continue;
    seen.add(id);
    normalized.push({
      id,
      label: labelModel({ ...model, id }),
      provider: providerId,
      purpose: inferModelPurpose(id),
    });
  }
  return normalized;
}

function updateOpenRouterPricing(rawModels) {
  if (!Array.isArray(rawModels)) return;
  for (const model of rawModels) {
    if (!model || typeof model !== 'object' || model.pricing?.prompt == null) continue;
    const inputPerM = Number.parseFloat(model.pricing.prompt) * 1_000_000;
    if (!Number.isFinite(inputPerM) || inputPerM < 0) continue;
    openrouterPricingCache.set(model.id, inputPerM);
    if (!model.id.includes('/')) continue;
    const bareId = model.id.slice(model.id.indexOf('/') + 1);
    if (!openrouterPricingCache.has(bareId)) {
      openrouterPricingCache.set(bareId, inputPerM);
    }
  }
}

function isPermanentDiscoveryError(error) {
  return /401|403|unauthorized|forbidden|credits|spending/i.test(String(error?.message || ''));
}

async function loadProviderModels({ providerId, factory, apiKey, baseUrl, existing }) {
  let provider = null;
  try {
    const config = {};
    if (factory.apiKey) config.apiKey = apiKey;
    if (factory.baseUrl) config.baseUrl = baseUrl;
    provider = new factory.Provider(config);
    const rawModels = await runDiscovery((signal) => provider.listModels(signal));
    if (providerId === 'openrouter') updateOpenRouterPricing(rawModels);
    const models = normalizeRawModels(rawModels, providerId, provider.models);
    const entry = { models, expiresAt: Date.now() + REFRESH_INTERVAL_MS };
    return entry;
  } catch (error) {
    console.warn(`[Models] Failed to refresh ${providerId} models:`, error.message);
    const models = existing?.models?.length
      ? existing.models
      : normalizeRawModels([], providerId, provider?.models || []);
    const retryAfterMs = isPermanentDiscoveryError(error)
      ? PERMANENT_ERROR_BACKOFF_MS
      : REFRESH_INTERVAL_MS;
    return { models, expiresAt: Date.now() + retryAfterMs };
  }
}

async function refreshProviderModelList({ providerId, factory, apiKey, baseUrl, signal }) {
  const cacheKey = cacheKeyForProvider(providerId, apiKey, baseUrl);
  const existing = providerModelCache.get(cacheKey);
  if (existing && existing.expiresAt > Date.now()) return existing.models;

  let refresh = providerRefreshes.get(cacheKey);
  if (!refresh) {
    refresh = loadProviderModels({ providerId, factory, apiKey, baseUrl, existing })
      .then((entry) => {
        providerModelCache.set(cacheKey, entry);
        return entry.models;
      })
      .finally(() => providerRefreshes.delete(cacheKey));
    providerRefreshes.set(cacheKey, refresh);
  }
  return waitForSharedResult(refresh, signal);
}

async function loadOllamaModels({ baseUrl, Provider, existing }) {
  try {
    const provider = new Provider({ baseUrl });
    const rawModels = await runDiscovery((signal) => provider.listModels(signal));
    const models = normalizeRawModels(rawModels, 'ollama').map((model) => ({
      ...model,
      label: `${model.id} (Ollama / Local)`,
      purpose: 'general',
    }));
    return { models, expiresAt: Date.now() + OLLAMA_REFRESH_INTERVAL_MS };
  } catch (error) {
    console.warn('[Models] Failed to refresh Ollama models:', error.message);
    return {
      models: existing?.models || [],
      expiresAt: Date.now() + OLLAMA_REFRESH_INTERVAL_MS,
    };
  }
}

async function refreshOllamaModels({ baseUrl, Provider, signal }) {
  const cacheKey = String(baseUrl || '');
  const existing = ollamaModelCache.get(cacheKey);
  if (existing && existing.expiresAt > Date.now()) return existing.models;

  let refresh = ollamaRefreshes.get(cacheKey);
  if (!refresh) {
    refresh = loadOllamaModels({ baseUrl, Provider, existing })
      .then((entry) => {
        ollamaModelCache.set(cacheKey, entry);
        return entry.models;
      })
      .finally(() => ollamaRefreshes.delete(cacheKey));
    ollamaRefreshes.set(cacheKey, refresh);
  }
  return waitForSharedResult(refresh, signal);
}

function getInputCostPerM(modelId) {
  return openrouterPricingCache.get(modelId);
}

function classifyPriceTier(modelId) {
  const costPerM = getInputCostPerM(modelId);
  if (costPerM === undefined) return null;
  if (costPerM === 0) return 'free';
  if (costPerM < 0.5) return 'cheap';
  if (costPerM < 5) return 'medium';
  return 'expensive';
}

module.exports = {
  classifyPriceTier,
  getInputCostPerM,
  refreshOllamaModels,
  refreshProviderModelList,
};
