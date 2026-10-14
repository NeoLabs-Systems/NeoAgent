'use strict';

const { isAbortError } = require('../../utils/abort');
const {
  getErrorCode,
  getHttpStatus,
  isTransientIoError,
  retryAfterMilliseconds,
} = require('../../utils/retry');
const {
  clearFailures,
  listActiveFailures,
  saveFailure,
} = require('./model_health_store');
const { MODEL_SELECTION_SEPARATOR } = require('./model_identity');
const { AI_PROVIDER_DEFINITIONS } = require('./provider_definitions');

// Stored in place of a model id: every model of the provider, or only its paid
// ones.
const PROVIDER_HEALTH_SENTINEL = '*';
const PAID_MODELS_SENTINEL = '$paid';
const DEFAULT_MODEL_UNAVAILABLE_COOLDOWN_MS = 7 * 24 * 60 * 60 * 1000;
const DEFAULT_PROVIDER_AUTH_COOLDOWN_MS = 60 * 60 * 1000;
const DEFAULT_PROVIDER_BILLING_COOLDOWN_MS = 15 * 60 * 1000;
const DEFAULT_RECOVERY_COOLDOWN_MS = 60 * 1000;
const MAX_TRANSIENT_COOLDOWN_MS = 15 * 60 * 1000;

const MODEL_UNAVAILABLE_CODES = new Set([
  'MODEL_NOT_FOUND',
  'MODEL_NOT_AVAILABLE',
  // GitHub Copilot answers HTTP 400 for models outside the account's plan.
  'MODEL_NOT_SUPPORTED',
  'MODEL_UNSUPPORTED',
  'UNSUPPORTED_MODEL',
]);
const MODEL_RECOVERY_CODES = new Set([
  'MODEL_EMPTY_RESPONSE',
  'MODEL_CALL_TIMEOUT',
]);

const failures = new Map();

function scopedAgentId(agentId) {
  return String(agentId ?? 'main');
}

function providerFromSelectionId(modelSelectionId) {
  const value = String(modelSelectionId || '').trim();
  const separatorIndex = value.indexOf(MODEL_SELECTION_SEPARATOR);
  return separatorIndex > 0 ? value.slice(0, separatorIndex).toLowerCase() : '';
}

function cacheKey(userId, agentId, providerId, modelSelectionId) {
  return [
    String(userId ?? ''),
    scopedAgentId(agentId),
    String(providerId || '').trim().toLowerCase(),
    String(modelSelectionId || '').trim(),
  ].join(':');
}

function readDuration(name, fallback, maximum) {
  const configured = Number(process.env[name]);
  if (!Number.isFinite(configured)) return fallback;
  return Math.max(1_000, Math.min(configured, maximum));
}

function readModelUnavailableCooldownMs() {
  return readDuration(
    'NEOAGENT_MODEL_NOT_FOUND_COOLDOWN_MS',
    DEFAULT_MODEL_UNAVAILABLE_COOLDOWN_MS,
    30 * 24 * 60 * 60 * 1000,
  );
}

function readProviderAuthCooldownMs() {
  return readDuration(
    'NEOAGENT_PROVIDER_AUTH_COOLDOWN_MS',
    DEFAULT_PROVIDER_AUTH_COOLDOWN_MS,
    24 * 60 * 60 * 1000,
  );
}

function readProviderBillingCooldownMs() {
  return readDuration(
    'NEOAGENT_PROVIDER_BILLING_COOLDOWN_MS',
    DEFAULT_PROVIDER_BILLING_COOLDOWN_MS,
    24 * 60 * 60 * 1000,
  );
}

function readRecoveryCooldownMs() {
  return readDuration(
    'NEOAGENT_MODEL_RECOVERY_COOLDOWN_MS',
    DEFAULT_RECOVERY_COOLDOWN_MS,
    MAX_TRANSIENT_COOLDOWN_MS,
  );
}

function normalizedCode(error) {
  return String(getErrorCode(error) || '').trim().toUpperCase();
}

function transientCooldownMs(error, now) {
  const configured = readRecoveryCooldownMs();
  const retryAfter = retryAfterMilliseconds(
    error?.headers || error?.response?.headers,
    now,
  );
  if (!Number.isFinite(retryAfter)) return configured;
  return Math.max(configured, Math.min(retryAfter, MAX_TRANSIENT_COOLDOWN_MS));
}

// An aggregator resells many vendors' models under one account. Its rate
// limits come from the upstream serving one model, and running out of credit
// stops only the models that cost money.
function isAggregator(providerId) {
  const key = String(providerId || '').trim().toLowerCase();
  return AI_PROVIDER_DEFINITIONS[key]?.aggregator === true;
}

function getFailureDisposition(error, now = Date.now(), providerId = null) {
  if (!error || isAbortError(error)) return null;

  const status = getHttpStatus(error);
  const code = normalizedCode(error);

  if (status === 404 || MODEL_UNAVAILABLE_CODES.has(code)) {
    return {
      scope: 'model',
      failureClass: 'model_unavailable',
      cooldownMs: readModelUnavailableCooldownMs(),
      status,
    };
  }

  if (status === 401 || status === 403) {
    return {
      scope: 'provider',
      failureClass: 'provider_auth',
      cooldownMs: readProviderAuthCooldownMs(),
      status,
    };
  }

  if (status === 402) {
    return {
      scope: isAggregator(providerId) ? 'paid' : 'provider',
      failureClass: 'provider_billing',
      cooldownMs: readProviderBillingCooldownMs(),
      status,
    };
  }

  if (status === 429 && isAggregator(providerId)) {
    return {
      scope: 'model',
      failureClass: 'model_rate_limit',
      cooldownMs: transientCooldownMs(error, now),
      status,
    };
  }

  if (status === 429 || isTransientIoError(error)) {
    return {
      scope: 'provider',
      failureClass: status === 429 ? 'provider_rate_limit' : 'provider_transient',
      cooldownMs: transientCooldownMs(error, now),
      status,
    };
  }

  if (MODEL_RECOVERY_CODES.has(code)) {
    return {
      scope: 'model',
      failureClass: 'model_transient',
      cooldownMs: transientCooldownMs(error, now),
      status,
    };
  }

  return null;
}

function isPermanentModelFailure(error) {
  return getFailureDisposition(error)?.failureClass === 'model_unavailable';
}

function isRecoverableModelFailure(error) {
  const disposition = getFailureDisposition(error);
  return Boolean(disposition && disposition.failureClass !== 'model_unavailable');
}

function shouldSwitchModel(error) {
  return getFailureDisposition(error) !== null;
}

function recordModelFailure(userId, agentId, modelSelectionId, error, now = Date.now()) {
  const selectedId = String(modelSelectionId || '').trim();
  const providerId = providerFromSelectionId(selectedId);
  const disposition = getFailureDisposition(error, now, providerId);
  if (!selectedId || !disposition) return false;

  const healthModelId = {
    provider: PROVIDER_HEALTH_SENTINEL,
    paid: PAID_MODELS_SENTINEL,
  }[disposition.scope] ?? selectedId;
  const entry = {
    userId,
    agentId: scopedAgentId(agentId),
    providerId,
    modelSelectionId: healthModelId,
    // Stored as provider-wide; the sentinel says which of its models it covers.
    scope: disposition.scope === 'model' ? 'model' : 'provider',
    failureClass: disposition.failureClass,
    status: disposition.status,
    expiresAt: now + disposition.cooldownMs,
  };
  failures.set(cacheKey(userId, agentId, providerId, healthModelId), entry);
  saveFailure(entry);
  console.warn(
    `[ModelHealth] ${describeHealthEntry(entry.scope, providerId, healthModelId)}`
    + ` cooling down (${disposition.failureClass}, HTTP ${disposition.status ?? 'n/a'})`
    + ` until ${new Date(entry.expiresAt).toISOString()}`
    + ` user=${userId} agent=${entry.agentId}: ${String(error?.message || error).slice(0, 200)}`,
  );
  return true;
}

function removeCachedFailure(userId, agentId, providerId, modelSelectionId) {
  return failures.delete(cacheKey(userId, agentId, providerId, modelSelectionId));
}

function recordModelSuccess(userId, agentId, modelSelectionId) {
  const selectedId = String(modelSelectionId || '').trim();
  if (!selectedId) return false;
  const providerId = providerFromSelectionId(selectedId);
  let removedFromMemory = false;
  for (const healthModelId of [selectedId, PROVIDER_HEALTH_SENTINEL]) {
    removedFromMemory = removeCachedFailure(
      userId,
      agentId,
      providerId,
      healthModelId,
    ) || removedFromMemory;
  }
  const removedFromStore = clearFailures(
    userId,
    scopedAgentId(agentId),
    providerId,
    [selectedId, PROVIDER_HEALTH_SENTINEL],
  );
  return removedFromMemory || removedFromStore;
}

function getModelHealthSnapshot(userId, agentId, now = Date.now()) {
  const normalizedAgentId = scopedAgentId(agentId);
  const snapshot = { modelIds: new Set(), providerIds: new Set(), paidProviderIds: new Set() };
  const add = (scope, providerId, healthModelId) => {
    if (scope !== 'provider') snapshot.modelIds.add(healthModelId);
    else if (healthModelId === PAID_MODELS_SENTINEL) snapshot.paidProviderIds.add(providerId);
    else snapshot.providerIds.add(providerId);
  };

  for (const [key, entry] of failures) {
    if (entry.expiresAt <= now) {
      failures.delete(key);
      continue;
    }
    if (String(entry.userId) !== String(userId) || entry.agentId !== normalizedAgentId) {
      continue;
    }
    add(entry.scope, entry.providerId, entry.modelSelectionId);
  }

  for (const entry of listActiveFailures(userId, normalizedAgentId, now)) {
    add(entry.failure_scope, entry.provider_id, entry.model_selection_id);
  }

  return snapshot;
}

// Whether a health snapshot keeps this catalog model out of routing. A model
// with no known price counts as paid.
function isHealthBlocked(health, model) {
  return health.modelIds.has(model.id)
    || health.providerIds.has(model.provider)
    || (health.paidProviderIds.has(model.provider) && model.priceTier !== 'free');
}

function describeHealthEntry(scope, providerId, healthModelId) {
  if (scope !== 'provider') return healthModelId;
  return healthModelId === PAID_MODELS_SENTINEL
    ? `paid models of provider ${providerId}`
    : `provider ${providerId}`;
}

// Active cooldowns that keep this model out of routing, for diagnostics.
function describeModelCooldowns(userId, agentId, modelSelectionId, now = Date.now()) {
  const selectedId = String(modelSelectionId || '').trim();
  const providerId = providerFromSelectionId(selectedId);
  return listActiveFailures(userId, scopedAgentId(agentId), now)
    .filter((entry) => entry.provider_id === providerId
      && (entry.failure_scope === 'provider' || entry.model_selection_id === selectedId))
    .map((entry) => `${describeHealthEntry(entry.failure_scope, providerId, entry.model_selection_id)}`
      + ` ${entry.failure_class} HTTP ${entry.last_status ?? 'n/a'}`
      + ` until ${new Date(entry.cooldown_until_ms).toISOString()}`);
}

function isModelCoolingDown(userId, agentId, modelSelectionId, now = Date.now()) {
  const selectedId = String(modelSelectionId || '').trim();
  if (!selectedId) return false;
  const health = getModelHealthSnapshot(userId, agentId, now);
  return health.modelIds.has(selectedId)
    || health.providerIds.has(providerFromSelectionId(selectedId));
}

function clearModelFailureCache() {
  failures.clear();
}

module.exports = {
  clearModelFailureCache,
  describeModelCooldowns,
  getFailureDisposition,
  getModelHealthSnapshot,
  isHealthBlocked,
  isModelCoolingDown,
  isPermanentModelFailure,
  isRecoverableModelFailure,
  recordModelFailure,
  recordModelSuccess,
  shouldSwitchModel,
};
