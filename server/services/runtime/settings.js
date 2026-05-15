const db = require('../../db/database');
const { getDeploymentPolicy } = require('../../utils/deployment');

function createDefaultRuntimeSettings() {
  const policy = getDeploymentPolicy();
  return {
    runtime_profile: policy.runtimeDefaults.runtime_profile,
    runtime_backend: policy.runtimeDefaults.runtime_backend,
    browser_backend: policy.runtimeDefaults.browser_backend,
    android_backend: policy.runtimeDefaults.android_backend,
    mcp_backend: policy.runtimeDefaults.mcp_backend,
    cli_backend: policy.runtimeDefaults.cli_backend ?? 'vm',
  };
}

const DEFAULT_RUNTIME_SETTINGS = Object.freeze(createDefaultRuntimeSettings());

function getEffectiveDefaults() {
  return createDefaultRuntimeSettings();
}

const BASE_FALLBACK_SETTINGS = Object.freeze({
  runtime_profile: 'secure-vm',
  runtime_backend: 'vm',
  browser_backend: 'vm',
  android_backend: 'host',
  mcp_backend: 'host-remote',
  cli_backend: 'vm',
});

const RUNTIME_SETTING_KEYS = Object.freeze(Object.keys(DEFAULT_RUNTIME_SETTINGS));

function normalizeChoice(value, allowed, fallback) {
  const normalized = String(value || '').trim().toLowerCase();
  return allowed.includes(normalized) ? normalized : fallback;
}

function deriveDefaultsForProfile(profile) {
  switch (profile) {
    case 'secure-vm':
    case 'trusted-host':
    default:
      return {
        runtime_backend: 'vm',
        browser_backend: 'vm',
        android_backend: 'host',
        cli_backend: 'vm',
      };
  }
}

function normalizeRuntimeSettings(raw = {}) {
  const policy = getDeploymentPolicy();
  const defaults = getEffectiveDefaults();
  const profile = normalizeChoice(raw.runtime_profile, ['secure-vm', 'trusted-host'], defaults.runtime_profile);
  const derived = deriveDefaultsForProfile(profile);
  const runtimeBackend = normalizeChoice(raw.runtime_backend, ['vm'], derived.runtime_backend);
  const browserBackend = normalizeChoice(raw.browser_backend, ['vm', 'extension'], derived.browser_backend);
  const cliBackend = normalizeChoice(raw.cli_backend, ['vm', 'desktop'], derived.cli_backend ?? 'vm');
  const androidBackend = 'host';
  return {
    runtime_profile: profile === 'trusted-host' ? 'secure-vm' : profile,
    runtime_backend: runtimeBackend,
    browser_backend: browserBackend === 'extension' ? 'extension' : 'vm',
    android_backend: androidBackend,
    mcp_backend: 'host-remote',
    cli_backend: cliBackend === 'desktop' ? 'desktop' : 'vm',
  };
}

function parseStoredRuntimeValue(key, value) {
  if (typeof value !== 'string') {
    return value;
  }
  try {
    return JSON.parse(value);
  } catch {
    return value;
  }
}

function serializeRuntimeSettingValue(key, value) {
  return typeof value === 'string' ? value : JSON.stringify(value);
}

function redactRuntimeSettingValue(key, value) {
  return value;
}

function validateRuntimeSettings(raw = {}) {
  const policy = getDeploymentPolicy();
  const settings = normalizeRuntimeSettings(raw);
  const issues = [];

  if (policy.profile === 'prod') {
    if (settings.runtime_profile !== 'secure-vm') {
      issues.push('This deployment is locked to the secure-vm runtime profile.');
    }
    if (settings.runtime_backend !== 'vm') {
      issues.push('This deployment requires the isolated VM runtime backend.');
    }
    if (settings.browser_backend !== 'vm' && settings.browser_backend !== 'extension') {
      issues.push('This deployment requires the VM browser backend or a paired browser extension backend.');
    }
    if (settings.android_backend !== 'host' && settings.android_backend !== 'vm') {
      issues.push('This deployment requires a supported Android backend.');
    }
    if (settings.cli_backend !== 'vm' && settings.cli_backend !== 'desktop') {
      issues.push('This deployment requires a supported CLI backend.');
    }
  }

  return {
    settings,
    valid: issues.length === 0,
    issues,
  };
}

function ensureDefaultRuntimeSettings(userId) {
  if (!userId) {
    return getEffectiveDefaults();
  }

  const rows = db.prepare(
    `SELECT key, value FROM user_settings WHERE user_id = ? AND key IN (${RUNTIME_SETTING_KEYS.map(() => '?').join(', ')})`
  ).all(userId, ...RUNTIME_SETTING_KEYS);

  const seen = new Set(rows.map((row) => row.key));
  const insert = db.prepare(
    'INSERT INTO user_settings (user_id, key, value) VALUES (?, ?, ?) ON CONFLICT(user_id, key) DO NOTHING'
  );

  for (const [key, value] of Object.entries(getEffectiveDefaults())) {
    if (!seen.has(key)) {
      insert.run(userId, key, typeof value === 'string' ? value : JSON.stringify(value));
    }
  }

  return getRuntimeSettings(userId);
}

function getRuntimeSettings(userId) {
  if (!userId) return { ...getEffectiveDefaults() };

  const rows = db.prepare(
    `SELECT key, value FROM user_settings WHERE user_id = ? AND key IN (${RUNTIME_SETTING_KEYS.map(() => '?').join(', ')})`
  ).all(userId, ...RUNTIME_SETTING_KEYS);

  const raw = { ...BASE_FALLBACK_SETTINGS, ...getEffectiveDefaults() };
  for (const row of rows) {
    raw[row.key] = parseStoredRuntimeValue(row.key, row.value);
  }
  return normalizeRuntimeSettings(raw);
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
