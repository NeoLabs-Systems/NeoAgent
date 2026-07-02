'use strict';

const PROTECTED_CATEGORIES = new Set(['identity', 'preferences', 'assistant_self']);

function clamp(value, min, max, fallback) {
  const number = Number(value);
  return Number.isFinite(number) ? Math.max(min, Math.min(max, number)) : fallback;
}

function parseTime(value) {
  const timestamp = Date.parse(String(value || ''));
  return Number.isFinite(timestamp) ? timestamp : null;
}

function ageDaysSince(value, now = Date.now()) {
  const timestamp = parseTime(value);
  if (!timestamp) return 0;
  return Math.max(0, (now - timestamp) / (1000 * 60 * 60 * 24));
}

function isPinnedMemory(memory) {
  if (Number(memory?.pinned || 0) === 1) return true;
  if (PROTECTED_CATEGORIES.has(String(memory?.category || ''))) return true;
  return Number(memory?.importance || 0) >= 9;
}

function getDecayedStrength(memory, now = Date.now()) {
  const strength = clamp(memory?.memory_strength, 0.05, 2, 1);
  if (isPinnedMemory(memory)) return strength;
  const halfLifeDays = clamp(memory?.stale_after_days, 14, 365, 90);
  const lastRelevantAt = memory?.last_accessed_at || memory?.updated_at || memory?.created_at;
  const age = ageDaysSince(lastRelevantAt, now);
  return clamp(strength * Math.pow(0.5, age / halfLifeDays), 0.01, 2, strength);
}

function getRetentionScoreMultiplier(memory, now = Date.now()) {
  if (isPinnedMemory(memory)) return 1.04;
  const decayed = getDecayedStrength(memory, now);
  return clamp(0.82 + (decayed * 0.14), 0.65, 1.08, 1);
}

function getReinforcedStrength(memory) {
  const current = clamp(memory?.memory_strength, 0.05, 2, 1);
  const importanceBoost = clamp(memory?.importance, 1, 10, 5) / 250;
  return clamp(current + 0.06 + importanceBoost, 0.05, 2, 1.08);
}

function isArchiveEligible(memory, options = {}) {
  if (!memory || isPinnedMemory(memory)) return false;
  if (Number(memory.archived || 0) === 1) return false;
  if (Number(memory.importance || 0) >= 8) return false;

  const now = options.now || Date.now();
  const minAgeDays = clamp(options.minAgeDays, 1, 365, 45);
  const threshold = clamp(options.strengthThreshold, 0.01, 1, 0.18);
  const age = ageDaysSince(memory.updated_at || memory.created_at, now);
  return age >= minAgeDays && getDecayedStrength(memory, now) < threshold;
}

module.exports = {
  getDecayedStrength,
  getReinforcedStrength,
  getRetentionScoreMultiplier,
  isArchiveEligible,
  isPinnedMemory,
};
