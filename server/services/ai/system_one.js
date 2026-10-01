'use strict';

const { getAiSettings } = require('./settings');
const {
  PROVIDER_FACTORIES,
  createProviderInstance,
  getProviderRuntimeConfig,
} = require('./models');
const { refreshProviderModelList } = require('./model_discovery');
const { classifyPriceTier, getInputCostPerM } = require('./model_reference');
const { toSelectableModel } = require('./model_identity');
const { getDisabledModelIds } = require('./model_visibility');
const {
  getFailureDisposition,
  getModelHealthSnapshot,
  isHealthBlocked,
  recordModelFailure,
} = require('./model_failure_cache');
const { recordModelUsage } = require('./usage');
const { isAbortError, throwIfAborted } = require('../../utils/abort');
const { createServiceLogger } = require('../../utils/logger');

const logger = createServiceLogger('SystemOne');

// SystemOne models answer typed questions about a state (yes/no
// probabilities, choices, ordered scores) in a few hundred milliseconds.
// NeoAgent uses them for decisions made behind the scenes; everything a user
// reads is still written by the chat model. Every caller keeps its previous
// path and takes it whenever decide() returns null.
//
// A provider serves SystemOne models when it implements listDecisionModels()
// and decide(): today TypeSafe, OpenRouter, and Ollama (0.35+).
const SYSTEM_ONE_PROVIDERS = Object.freeze(Object.keys(PROVIDER_FACTORIES).filter(
  (providerId) => typeof PROVIDER_FACTORIES[providerId].Provider.prototype.listDecisionModels === 'function',
));
const DECISION_TIMEOUT_MS = 4000;
// The decision thresholds in NeoAgent (the group chat gate, browser steps)
// were calibrated against Jev 1.13, so automatic selection tries it first.
const CALIBRATED_MODEL_IDS = Object.freeze(['jev-1.13.0', 'typesafe/jev-1.13']);

// A keyed provider needs its key; a local one (Ollama) only its address.
function isProviderUsable(runtime) {
  return runtime.supportsApiKey ? runtime.credentialConfigured : Boolean(runtime.baseUrl);
}

function selectionFor(userId, agentId) {
  return getAiSettings(userId, agentId).system_one_model;
}

// The agent picked Auto or a SystemOne model. Whether one can answer right now
// is isSystemOneReady(); this cheap check only decides what to offer up front.
// A settings lookup that fails counts as off: SystemOne must never break the
// path it would have replaced.
function isSystemOneEnabled(userId, agentId = null) {
  if (userId == null) return false;
  try {
    return selectionFor(userId, agentId) !== 'off';
  } catch (error) {
    logger.warn(`Could not read the SystemOne setting; treating it as off: ${error.message}`);
    return false;
  }
}

// Every SystemOne model the agent's providers serve, in the same shape as the
// chat model catalog so clients reuse their model pickers. Models the admin
// switched off, or that are cooling down after a failure, are unavailable.
// Without a user it lists what the server's own credentials reach.
async function getSystemOneModels(userId, agentId = null, { signal = null } = {}) {
  const health = getModelHealthSnapshot(userId, agentId);
  const disabled = new Set(getDisabledModelIds());
  const catalogs = await Promise.allSettled(SYSTEM_ONE_PROVIDERS.map(async (providerId) => {
    const runtime = getProviderRuntimeConfig(userId, providerId, agentId);
    if (!isProviderUsable(runtime)) return [];
    const models = await refreshProviderModelList({
      providerId,
      factory: PROVIDER_FACTORIES[providerId],
      apiKey: runtime.apiKey,
      baseUrl: runtime.baseUrl,
      catalog: 'decisions',
      signal,
    });
    return models.map((model) => {
      const selectable = toSelectableModel(model);
      const priceTier = classifyPriceTier(model.id);
      const runtimeUnavailable = isHealthBlocked(health, { ...selectable, priceTier });
      return {
        ...selectable,
        priceTier,
        inputCostPerM: getInputCostPerM(model.id) ?? null,
        available: !runtimeUnavailable && !disabled.has(selectable.id),
        runtimeUnavailable,
        isByok: runtime.isByok,
        byokLabel: runtime.label || '',
      };
    });
  }));
  throwIfAborted(signal);
  return catalogs.flatMap((result) => (result.status === 'fulfilled' ? result.value : []));
}

// The agent's chosen model while it is available; otherwise (and for Auto)
// the calibrated model, then any other available SystemOne model in catalog
// order, so a retired or failing model hands over to the next one.
async function resolveModel(userId, agentId, signal) {
  if (userId == null) return null;
  const selection = selectionFor(userId, agentId);
  if (selection === 'off') return null;
  const ready = (await getSystemOneModels(userId, agentId, { signal }))
    .filter((model) => model.available);
  return ready.find((model) => model.id === selection)
    || ready.find((model) => CALIBRATED_MODEL_IDS.includes(model.modelId))
    || ready[0]
    || null;
}

// True when a SystemOne model can answer for this agent now. Callers that
// stop using the chat model while SystemOne is on (the group chat gate) check
// this, so a server without any available SystemOne model never goes quiet.
async function isSystemOneReady(userId, agentId = null, signal = null) {
  try {
    return Boolean(await resolveModel(userId, agentId, signal));
  } catch (error) {
    if (isAbortError(error, signal)) throw error;
    logger.warn(`Could not resolve a SystemOne model; treating it as off: ${error.message}`);
    return false;
  }
}

function isProbability(value) {
  return typeof value === 'number' && Number.isFinite(value) && value >= 0 && value <= 1;
}

function isValidAnswer(question, answer) {
  if (!answer || answer.type !== question.type) return false;
  if (question.type === 'noul') return isProbability(answer.noul);
  if (question.type === 'choice') {
    return Object.prototype.hasOwnProperty.call(question.criteria || {}, answer.choice)
      && isProbability(answer.confidence)
      && Boolean(answer.probabilities)
      && Object.values(answer.probabilities).every(isProbability);
  }
  if (question.type === 'score') {
    return typeof answer.score === 'number' && Number.isFinite(answer.score);
  }
  return false;
}

// The usage row keeps the answers so every automatic decision can be audited
// next to its cost.
function summarizeAnswers(answers) {
  return Object.fromEntries(Object.entries(answers).map(([key, answer]) => {
    if (answer.type === 'noul') return [key, answer.noul];
    if (answer.type === 'choice') return [key, { choice: answer.choice, confidence: answer.confidence }];
    return [key, { score: answer.score, confidence: answer.confidence }];
  }));
}

async function decide({
  userId,
  agentId = null,
  runId = null,
  stepId = null,
  phase,
  state,
  questions,
  signal = null,
}) {
  const startedAt = Date.now();
  let model = null;
  try {
    // Null when SystemOne is off or no SystemOne model is available.
    model = await resolveModel(userId, agentId, signal);
    if (!model) return null;
    const provider = createProviderInstance(model.provider, userId, { agentId });
    const result = await provider.decide({
      model: model.modelId,
      state,
      questions,
      signal,
      timeoutMs: DECISION_TIMEOUT_MS,
    });
    const invalid = Object.keys(questions)
      .filter((key) => !isValidAnswer(questions[key], result.answers[key]));
    if (invalid.length > 0) {
      throw new Error(`invalid answers for ${invalid.join(', ')}`);
    }
    if (runId) {
      recordModelUsage({
        runId,
        stepId,
        userId,
        agentId,
        provider: model.provider,
        model: result.model,
        phase,
        usage: result.usage,
        latencyMs: Date.now() - startedAt,
        estimatedCostUsd: result.usage?.cost,
        metadata: { answers: summarizeAnswers(result.answers) },
      });
    }
    return result.answers;
  } catch (error) {
    if (signal?.aborted) throw error;
    // Only a model that is gone is benched, so auto moves on to the next one.
    // A slow or rate-limited decision must not pause the provider's chat models.
    if (model && getFailureDisposition(error)?.scope === 'model') {
      recordModelFailure(userId, agentId, model.id, error);
    }
    logger.warn(`${phase} decision unavailable, using the model path instead: ${error.message}`);
    return null;
  }
}

module.exports = {
  decide,
  getSystemOneModels,
  isSystemOneEnabled,
  isSystemOneReady,
};
