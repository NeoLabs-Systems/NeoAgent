'use strict';

const DEFAULT_RUNTIME_SETTINGS = Object.freeze({
  runtime_profile: 'cloud-computer',
  runtime_backend: 'qemu',
  computer_backend: 'cloud',
  android_backend: 'host',
  mcp_backend: 'host-remote',
});

const RUNTIME_SETTING_KEYS = Object.freeze(Object.keys(DEFAULT_RUNTIME_SETTINGS));

function normalizeRuntimeSettings() {
  return { ...DEFAULT_RUNTIME_SETTINGS };
}

function validateRuntimeSettings() {
  return {
    settings: normalizeRuntimeSettings(),
    valid: true,
    issues: [],
  };
}

function ensureDefaultRuntimeSettings() {
  return normalizeRuntimeSettings();
}

function getRuntimeSettings() {
  return normalizeRuntimeSettings();
}

function parseStoredRuntimeValue(_key, value) {
  if (typeof value !== 'string') return value;
  try {
    return JSON.parse(value);
  } catch {
    return value;
  }
}

function serializeRuntimeSettingValue(_key, value) {
  return typeof value === 'string' ? value : JSON.stringify(value);
}

function redactRuntimeSettingValue(key, value) {
  if (/^social_reach_cookies_/i.test(String(key || ''))) {
    return { configured: Boolean(value), redacted: true };
  }
  return value;
}

module.exports = {
  DEFAULT_RUNTIME_SETTINGS,
  RUNTIME_SETTING_KEYS,
  ensureDefaultRuntimeSettings,
  getRuntimeSettings,
  normalizeRuntimeSettings,
  parseStoredRuntimeValue,
  redactRuntimeSettingValue,
  serializeRuntimeSettingValue,
  validateRuntimeSettings,
};
