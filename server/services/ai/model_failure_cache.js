'use strict';

const DEFAULT_COOLDOWN_MS = 15 * 60 * 1000;
const failures = new Map();

function cacheKey(userId, agentId, modelSelectionId) {
  return [
    String(userId ?? ''),
    String(agentId ?? 'main'),
    String(modelSelectionId || '').trim(),
  ].join(':');
}

function readCooldownMs() {
  const configured = Number(process.env.NEOAGENT_MODEL_NOT_FOUND_COOLDOWN_MS);
  if (!Number.isFinite(configured)) return DEFAULT_COOLDOWN_MS;
  return Math.max(1_000, Math.min(configured, 24 * 60 * 60 * 1000));
}

function isPermanentModelFailure(error) {
  const status = Number(
    error?.status
    ?? error?.statusCode
    ?? error?.response?.status,
  );
  if (status === 404) return true;
  return /\b404\b.*\b(model|nim|provider|request)\b|\b(model|nim)\b.*\b404\b/i
    .test(String(error?.message || ''));
}

function recordModelFailure(userId, agentId, modelSelectionId, error, now = Date.now()) {
  const modelId = String(modelSelectionId || '').trim();
  if (!modelId || !isPermanentModelFailure(error)) return false;
  failures.set(cacheKey(userId, agentId, modelId), {
    expiresAt: now + readCooldownMs(),
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
  recordModelFailure,
  recordModelSuccess,
};
