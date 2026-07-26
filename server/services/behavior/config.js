'use strict';

const db = require('../../db/database');
const { isMainAgent } = require('../agents/manager');
const { MODULE_IDS, cloneDefaults, DEFAULT_MODULE_CONFIG } = require('./defaults');

const SETTINGS_KEY = 'behavior_modules_config';
const PARTICIPATION_MODES = new Set(['automatic', 'mention_only', 'always']);
const MODEL_PURPOSES = new Set(['fast', 'general']);
const DELIVERY_STYLES = new Set(['single', 'natural_bubbles']);

function clampNumber(value, min, max, fallback) {
  const number = Number(value);
  if (!Number.isFinite(number)) return fallback;
  return Math.min(max, Math.max(min, number));
}

function asObject(value) {
  return value && typeof value === 'object' && !Array.isArray(value) ? value : {};
}

function normalizeModules(rawModules, fallbackEnabled = true, sparse = false) {
  const source = asObject(rawModules);
  const modules = {};
  for (const id of MODULE_IDS) {
    if (sparse && !Object.prototype.hasOwnProperty.call(source, id)) continue;
    const entry = asObject(source[id]);
    modules[id] = {
      enabled: entry.enabled == null ? fallbackEnabled : entry.enabled !== false,
    };
  }
  return modules;
}

function normalizeOptionalString(value, fallback = null) {
  if (value == null) return fallback;
  const normalized = String(value).trim();
  return normalized || null;
}

function normalizeLeafConfig(raw = {}, base = cloneDefaults(), sparse = false) {
  const input = asObject(raw);
  const output = {};
  const assign = (key, value) => {
    if (!sparse || Object.prototype.hasOwnProperty.call(input, key)) output[key] = value;
  };
  const enabled = input.enabled == null ? base.enabled !== false : input.enabled !== false;
  assign('enabled', enabled);
  if (!sparse || Object.prototype.hasOwnProperty.call(input, 'modules')) {
    output.modules = normalizeModules(input.modules, enabled, sparse);
  }
  assign(
    'participationMode',
    PARTICIPATION_MODES.has(String(input.participationMode || ''))
      ? String(input.participationMode)
      : (base.participationMode || DEFAULT_MODULE_CONFIG.participationMode),
  );
  assign('minimumNeedScore', clampNumber(
    input.minimumNeedScore,
    0,
    1,
    base.minimumNeedScore ?? DEFAULT_MODULE_CONFIG.minimumNeedScore,
  ));
  assign('batchWindowMs', Math.round(clampNumber(
    input.batchWindowMs,
    0,
    5000,
    base.batchWindowMs ?? DEFAULT_MODULE_CONFIG.batchWindowMs,
  )));
  assign('decisionContextMessageLimit', Math.round(clampNumber(
    input.decisionContextMessageLimit,
    4,
    30,
    base.decisionContextMessageLimit ?? DEFAULT_MODULE_CONFIG.decisionContextMessageLimit,
  )));
  assign(
    'decisionModelId',
    normalizeOptionalString(input.decisionModelId, base.decisionModelId || null),
  );
  assign(
    'decisionModelPurpose',
    MODEL_PURPOSES.has(String(input.decisionModelPurpose || ''))
      ? String(input.decisionModelPurpose)
      : (base.decisionModelPurpose || DEFAULT_MODULE_CONFIG.decisionModelPurpose),
  );
  assign(
    'deliveryStyle',
    DELIVERY_STYLES.has(String(input.deliveryStyle || ''))
      ? String(input.deliveryStyle)
      : (base.deliveryStyle || DEFAULT_MODULE_CONFIG.deliveryStyle),
  );
  assign('maxBubbles', Math.round(clampNumber(
    input.maxBubbles,
    1,
    5,
    base.maxBubbles ?? DEFAULT_MODULE_CONFIG.maxBubbles,
  )));
  assign('bubbleGapMs', Math.round(clampNumber(
    input.bubbleGapMs,
    0,
    5000,
    base.bubbleGapMs ?? DEFAULT_MODULE_CONFIG.bubbleGapMs,
  )));
  assign('normsRefreshMessageGap', Math.round(clampNumber(
    input.normsRefreshMessageGap,
    3,
    200,
    base.normsRefreshMessageGap ?? DEFAULT_MODULE_CONFIG.normsRefreshMessageGap,
  )));
  assign('observabilityIntervalMinutes', Math.round(clampNumber(
    input.observabilityIntervalMinutes,
    30,
    10080,
    base.observabilityIntervalMinutes ?? DEFAULT_MODULE_CONFIG.observabilityIntervalMinutes,
  )));
  return output;
}

function normalizeStoredConfig(raw) {
  const base = cloneDefaults();
  const input = asObject(raw);
  const normalized = {
    schemaVersion: DEFAULT_MODULE_CONFIG.schemaVersion,
    ...normalizeLeafConfig(input, base),
  };
  const platformOverrides = {};
  for (const [platform, value] of Object.entries(asObject(input.platformOverrides))) {
    const key = String(platform || '').trim();
    if (!key) continue;
    platformOverrides[key] = normalizeLeafConfig(value, normalized, true);
  }
  const roomOverrides = {};
  const rawRoomOverrides = Object.keys(asObject(input.roomOverrides)).length
    ? asObject(input.roomOverrides)
    : asObject(input.groupOverrides);
  for (const [roomKey, value] of Object.entries(rawRoomOverrides)) {
    const key = String(roomKey || '').trim();
    if (!key) continue;
    roomOverrides[key] = normalizeLeafConfig(value, normalized, true);
  }
  return {
    ...normalized,
    platformOverrides,
    roomOverrides,
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

function roomConfigKey(platform, chatId) {
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
  const storedValue = readSettingRow(userId, agentId);
  const stored = parseStoredValue(storedValue);
  let effective = normalizeLeafConfig(stored, cloneDefaults());
  let participationModeSource = storedValue == null ? 'default' : 'agent';
  const platformKey = String(platform || '').trim();
  if (platformKey && stored.platformOverrides?.[platformKey]) {
    effective = mergeConfigs(effective, stored.platformOverrides[platformKey]);
    if (Object.prototype.hasOwnProperty.call(stored.platformOverrides[platformKey], 'participationMode')) {
      participationModeSource = 'platform';
    }
  }
  if (isGroup && platformKey && chatId) {
    const key = roomConfigKey(platformKey, chatId);
    if (stored.roomOverrides?.[key]) {
      effective = mergeConfigs(effective, stored.roomOverrides[key]);
      if (Object.prototype.hasOwnProperty.call(stored.roomOverrides[key], 'participationMode')) {
        participationModeSource = 'room';
      }
    }
  }
  effective.modules = normalizeModules(effective.modules, effective.enabled !== false);
  effective.platformOverrides = stored.platformOverrides || {};
  effective.roomOverrides = stored.roomOverrides || {};
  effective.participationModeSource = participationModeSource;
  effective.scope = {
    platform: platformKey || null,
    chatId: chatId ? String(chatId) : null,
    isGroup: Boolean(isGroup),
    roomKey: isGroup && platformKey && chatId ? roomConfigKey(platformKey, chatId) : null,
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
  roomConfigKey,
  isModuleEnabled,
};
