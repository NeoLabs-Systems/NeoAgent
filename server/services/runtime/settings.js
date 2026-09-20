'use strict';

const { getDeploymentPolicy } = require('../../utils/deployment');

// `runtime_backend` is the isolation technology TERMINAL_ENV selected; the rest
// of the runtime shape is fixed.
const DEFAULT_RUNTIME_SETTINGS = Object.freeze({
  runtime_profile: 'cloud-computer',
  computer_backend: 'cloud',
  android_backend: 'host',
  mcp_backend: 'host-remote',
});

const RUNTIME_SETTING_KEYS = Object.freeze([
  ...Object.keys(DEFAULT_RUNTIME_SETTINGS),
  'runtime_backend',
]);

function normalizeRuntimeSettings() {
  return {
    ...DEFAULT_RUNTIME_SETTINGS,
    runtime_backend: getDeploymentPolicy().runtimeDefaults.runtime_backend,
  };
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
  redactRuntimeSettingValue,
  serializeRuntimeSettingValue,
  validateRuntimeSettings,
};
