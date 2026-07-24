'use strict';

const { isAbortError } = require('../../utils/abort');
const {
  getErrorCode,
  getHttpStatus,
  isTransientIoError,
  retryAfterMilliseconds,
} = require('../../utils/retry');

const DEFAULT_COOLDOWN_MS = 15 * 60 * 1000;
const DEFAULT_RECOVERY_COOLDOWN_MS = 60 * 1000;
const failures = new Map();

function cacheKey(userId, agentId, modelSelectionId) {
  return [
    String(userId ?? ''),
    String(agentId ?? 'main'),
    String(modelSelectionId || '').trim(),
  ].join(':');
}

function readPermanentCooldownMs() {
  const configured = Number(process.env.NEOAGENT_MODEL_NOT_FOUND_COOLDOWN_MS);
  if (!Number.isFinite(configured)) return DEFAULT_COOLDOWN_MS;
  return Math.max(1_000, Math.min(configured, 24 * 60 * 60 * 1000));
}

function readRecoveryCooldownMs() {
  const configured = Number(process.env.NEOAGENT_MODEL_RECOVERY_COOLDOWN_MS);
  if (!Number.isFinite(configured)) return DEFAULT_RECOVERY_COOLDOWN_MS;
  return Math.max(1_000, Math.min(configured, 15 * 60 * 1000));
}

function isPermanentModelFailure(error) {
  const status = getHttpStatus(error);
  if (status === 404) return true;
  return /\b404\b.*\b(model|nim|provider|request)\b|\b(model|nim)\b.*\b404\b/i
    .test(String(error?.message || ''));
}

function isRecoverableModelFailure(error) {
  if (!error || isAbortError(error) || isPermanentModelFailure(error)) return false;
  const status = getHttpStatus(error);
  if (status === 401 || status === 403 || status === 429 || (status >= 500 && status < 600)) {
    return true;
  }
  const code = String(getErrorCode(error) || '');
  if (code === 'MODEL_EMPTY_RESPONSE' || code === 'MODEL_CALL_TIMEOUT') return true;
  if (isTransientIoError(error)) return true;
  return /\bempty response|temporarily unavailable|overloaded|rate.?limit|timed? ?out|network error\b/i
    .test(String(error?.message || ''));
}

function resolveCooldownMs(error, now) {
  if (isPermanentModelFailure(error)) return readPermanentCooldownMs();
  if (!isRecoverableModelFailure(error)) return 0;

  const configured = readRecoveryCooldownMs();
  const retryAfter = retryAfterMilliseconds(
    error?.headers || error?.response?.headers,
    now,
  );
  if (!Number.isFinite(retryAfter)) return configured;
  return Math.max(configured, Math.min(retryAfter, 15 * 60 * 1000));
}

function recordModelFailure(userId, agentId, modelSelectionId, error, now = Date.now()) {
  const modelId = String(modelSelectionId || '').trim();
  const cooldownMs = resolveCooldownMs(error, now);
  if (!modelId || cooldownMs <= 0) return false;
  failures.set(cacheKey(userId, agentId, modelId), {
    expiresAt: now + cooldownMs,
  });
  return true;
}

function recordModelSuccess(userId, agentId, modelSelectionId) {
  const modelId = String(modelSelectionId || '').trim();
  if (!modelId) return false;
  return failures.delete(cacheKey(userId, agentId, modelId));
}

function isModelCoolingDown(userId, agentId, modelSelectionId, now = Date.now()) {
  const modelId = String(modelSelectionId || '').trim();
  if (!modelId) return false;
  const key = cacheKey(userId, agentId, modelId);
  const entry = failures.get(key);
  if (!entry) return false;
  if (entry.expiresAt <= now) {
    failures.delete(key);
    return false;
  }
  return true;
}

function clearModelFailureCache() {
  failures.clear();
}

module.exports = {
  clearModelFailureCache,
  isModelCoolingDown,
  isPermanentModelFailure,
  isRecoverableModelFailure,
  recordModelFailure,
  recordModelSuccess,
};
