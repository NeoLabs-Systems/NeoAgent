'use strict';

const db = require('../../db/database');
const { isMainAgent } = require('../agents/manager');
const { MODULE_IDS, cloneDefaults, DEFAULT_MODULE_CONFIG } = require('./defaults');

const SETTINGS_KEY = 'behavior_modules_config';

function clampNumber(value, min, max, fallback) {
  const number = Number(value);
  if (!Number.isFinite(number)) return fallback;
  return Math.min(max, Math.max(min, number));
}

function asObject(value) {
  return value && typeof value === 'object' && !Array.isArray(value) ? value : {};
}

function normalizeModules(rawModules, fallbackEnabled = true) {
  const source = asObject(rawModules);
  const modules = {};
  for (const id of MODULE_IDS) {
    const entry = asObject(source[id]);
    modules[id] = {
      enabled: entry.enabled == null ? fallbackEnabled : entry.enabled !== false,
    };
  }
  return modules;
}

function normalizeLeafConfig(raw = {}, base = cloneDefaults()) {
  const input = asObject(raw);
  const enabled = input.enabled == null ? base.enabled !== false : input.enabled !== false;
  return {
    enabled,
    modules: normalizeModules(input.modules, enabled),
    holdBackStrength: clampNumber(
      input.holdBackStrength,
      0,
      1,
      base.holdBackStrength ?? DEFAULT_MODULE_CONFIG.holdBackStrength,
    ),
    cooldownSeconds: Math.round(clampNumber(
      input.cooldownSeconds,
      0,
      3600,
      base.cooldownSeconds ?? DEFAULT_MODULE_CONFIG.cooldownSeconds,
    )),
    requireAddressHint: input.requireAddressHint == null
      ? Boolean(base.requireAddressHint)
      : Boolean(input.requireAddressHint),
    deliveryStyle: ['single', 'natural_bubbles'].includes(String(input.deliveryStyle || ''))
      ? String(input.deliveryStyle)
      : (base.deliveryStyle || DEFAULT_MODULE_CONFIG.deliveryStyle),
    maxBubbles: Math.round(clampNumber(
      input.maxBubbles,
      1,
      5,
      base.maxBubbles ?? DEFAULT_MODULE_CONFIG.maxBubbles,
    )),
    bubbleGapMs: Math.round(clampNumber(
      input.bubbleGapMs,
      0,
      5000,
      base.bubbleGapMs ?? DEFAULT_MODULE_CONFIG.bubbleGapMs,
    )),
    decisionModelPreference: ['cheap', 'default'].includes(String(input.decisionModelPreference || ''))
      ? String(input.decisionModelPreference)
      : (base.decisionModelPreference || DEFAULT_MODULE_CONFIG.decisionModelPreference),
    memoryRetentionDays: Math.round(clampNumber(
      input.memoryRetentionDays,
      1,
      3650,
      base.memoryRetentionDays ?? DEFAULT_MODULE_CONFIG.memoryRetentionDays,
    )),
    normsRefreshMessageGap: Math.round(clampNumber(
      input.normsRefreshMessageGap,
      3,
      200,
      base.normsRefreshMessageGap ?? DEFAULT_MODULE_CONFIG.normsRefreshMessageGap,
    )),
    observabilityIntervalMinutes: Math.round(clampNumber(
      input.observabilityIntervalMinutes,
      30,
      10080,
      base.observabilityIntervalMinutes ?? DEFAULT_MODULE_CONFIG.observabilityIntervalMinutes,
    )),
  };
}

function normalizeStoredConfig(raw) {
  const base = cloneDefaults();
  const input = asObject(raw);
  const normalized = normalizeLeafConfig(input, base);
  const platformOverrides = {};
  for (const [platform, value] of Object.entries(asObject(input.platformOverrides))) {
    const key = String(platform || '').trim();
    if (!key) continue;
    platformOverrides[key] = normalizeLeafConfig(value, normalized);
  }
  const groupOverrides = {};
  for (const [groupKey, value] of Object.entries(asObject(input.groupOverrides))) {
    const key = String(groupKey || '').trim();
    if (!key) continue;
    groupOverrides[key] = normalizeLeafConfig(value, normalized);
  }
  return {
    ...normalized,
    platformOverrides,
    groupOverrides,
  };
}

function readSettingRow(userId, agentId) {
  const row = db.prepare(
    'SELECT value FROM agent_settings WHERE user_id = ? AND agent_id = ? AND key = ?',
  ).get(userId, agentId, SETTINGS_KEY);
  if (row?.value != null) return row.value;
  if (isMainAgent(userId, agentId)) {
    const legacy = db.prepare(
      'SELECT value FROM user_settings WHERE user_id = ? AND key = ?',
    ).get(userId, SETTINGS_KEY);
    return legacy?.value;
  }
  return null;
}

function parseStoredValue(value) {
  if (value == null || value === '') return cloneDefaults();
  if (typeof value === 'object') return normalizeStoredConfig(value);
  try {
    return normalizeStoredConfig(JSON.parse(value));
  } catch {
    return cloneDefaults();
  }
}

function getBehaviorConfig(userId, agentId = null) {
  return parseStoredValue(readSettingRow(userId, agentId));
}

function setBehaviorConfig(userId, agentId, config) {
  const normalized = normalizeStoredConfig(config);
  db.prepare(
    `INSERT INTO agent_settings (user_id, agent_id, key, value)
     VALUES (?, ?, ?, ?)
     ON CONFLICT(user_id, agent_id, key) DO UPDATE SET value = excluded.value`,
  ).run(userId, agentId, SETTINGS_KEY, JSON.stringify(normalized));
  return normalized;
}

function groupConfigKey(platform, chatId) {
  return `${String(platform || '').trim()}::${String(chatId || '').trim()}`;
}

function mergeConfigs(base, override) {
  if (!override) return base;
  return {
    ...base,
    ...override,
    modules: {
      ...asObject(base.modules),
      ...asObject(override.modules),
    },
  };
}

function resolveBehaviorConfig(userId, agentId, { platform = null, chatId = null, isGroup = false } = {}) {
  const stored = getBehaviorConfig(userId, agentId);
  let effective = normalizeLeafConfig(stored, cloneDefaults());
  const platformKey = String(platform || '').trim();
  if (platformKey && stored.platformOverrides?.[platformKey]) {
    effective = mergeConfigs(effective, stored.platformOverrides[platformKey]);
  }
  if (isGroup && platformKey && chatId) {
    const key = groupConfigKey(platformKey, chatId);
    if (stored.groupOverrides?.[key]) {
      effective = mergeConfigs(effective, stored.groupOverrides[key]);
    }
  }
  effective.modules = normalizeModules(effective.modules, effective.enabled !== false);
  effective.platformOverrides = stored.platformOverrides || {};
  effective.groupOverrides = stored.groupOverrides || {};
  effective.scope = {
    platform: platformKey || null,
    chatId: chatId ? String(chatId) : null,
    isGroup: Boolean(isGroup),
    groupKey: isGroup && platformKey && chatId ? groupConfigKey(platformKey, chatId) : null,
  };
  return effective;
}

function isModuleEnabled(config, moduleId) {
  if (!config || config.enabled === false) return false;
  const entry = config.modules?.[moduleId];
  if (!entry) return false;
  return entry.enabled !== false;
}

module.exports = {
  SETTINGS_KEY,
  getBehaviorConfig,
  setBehaviorConfig,
  resolveBehaviorConfig,
  normalizeStoredConfig,
  groupConfigKey,
  isModuleEnabled,
};
