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

const PROVIDER_HEALTH_SENTINEL = '*';
const DEFAULT_MODEL_UNAVAILABLE_COOLDOWN_MS = 7 * 24 * 60 * 60 * 1000;
const DEFAULT_PROVIDER_AUTH_COOLDOWN_MS = 60 * 60 * 1000;
const DEFAULT_RECOVERY_COOLDOWN_MS = 60 * 1000;
const MAX_TRANSIENT_COOLDOWN_MS = 15 * 60 * 1000;

const MODEL_UNAVAILABLE_CODES = new Set([
  'MODEL_NOT_FOUND',
  'MODEL_NOT_AVAILABLE',
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

function getFailureDisposition(error, now = Date.now()) {
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
  const disposition = getFailureDisposition(error, now);
  if (!selectedId || !disposition) return false;

  const providerId = providerFromSelectionId(selectedId);
  const healthModelId = disposition.scope === 'provider'
    ? PROVIDER_HEALTH_SENTINEL
    : selectedId;
  const entry = {
    userId,
    agentId: scopedAgentId(agentId),
    providerId,
    modelSelectionId: healthModelId,
    scope: disposition.scope,
    failureClass: disposition.failureClass,
    status: disposition.status,
    expiresAt: now + disposition.cooldownMs,
  };
  failures.set(cacheKey(userId, agentId, providerId, healthModelId), entry);
  saveFailure(entry);
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
  const modelIds = new Set();
  const providerIds = new Set();

  for (const [key, entry] of failures) {
    if (entry.expiresAt <= now) {
      failures.delete(key);
      continue;
    }
    if (String(entry.userId) !== String(userId) || entry.agentId !== normalizedAgentId) {
      continue;
    }
    if (entry.scope === 'provider') providerIds.add(entry.providerId);
    else modelIds.add(entry.modelSelectionId);
  }

  for (const entry of listActiveFailures(userId, normalizedAgentId, now)) {
    if (entry.failure_scope === 'provider') providerIds.add(entry.provider_id);
    else modelIds.add(entry.model_selection_id);
  }

  return { modelIds, providerIds };
}

function isProviderCoolingDown(userId, agentId, providerId, now = Date.now()) {
  const normalizedProvider = String(providerId || '').trim().toLowerCase();
  if (!normalizedProvider) return false;
  return getModelHealthSnapshot(userId, agentId, now).providerIds.has(normalizedProvider);
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
  getFailureDisposition,
  getModelHealthSnapshot,
  isModelCoolingDown,
  isPermanentModelFailure,
  isProviderCoolingDown,
  isRecoverableModelFailure,
  recordModelFailure,
  recordModelSuccess,
  shouldSwitchModel,
};
