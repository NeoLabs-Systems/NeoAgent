const db = require('../../db/database');
const { getDeploymentPolicy } = require('../../utils/deployment');
const { decryptValue, encryptValue } = require('../integrations/secrets');

function createDefaultRuntimeSettings() {
  const policy = getDeploymentPolicy();
  return {
    runtime_profile: policy.runtimeDefaults.runtime_profile,
    runtime_backend: policy.runtimeDefaults.runtime_backend,
    browser_backend: policy.runtimeDefaults.browser_backend,
    android_backend: policy.runtimeDefaults.android_backend,
    mcp_backend: policy.runtimeDefaults.mcp_backend,
    remote_worker_base_url: '',
    remote_worker_token: '',
  };
}

const DEFAULT_RUNTIME_SETTINGS = Object.freeze(createDefaultRuntimeSettings());

function getEffectiveDefaults() {
  return createDefaultRuntimeSettings();
}

const BASE_FALLBACK_SETTINGS = Object.freeze({
  runtime_profile: 'trusted-host',
  runtime_backend: 'host',
  browser_backend: 'host',
  android_backend: 'host',
  mcp_backend: 'host-remote',
  remote_worker_base_url: '',
  remote_worker_token: '',
});

const RUNTIME_SETTING_KEYS = Object.freeze(Object.keys(DEFAULT_RUNTIME_SETTINGS));

function normalizeChoice(value, allowed, fallback) {
  const normalized = String(value || '').trim().toLowerCase();
  return allowed.includes(normalized) ? normalized : fallback;
}

function deriveDefaultsForProfile(profile) {
  switch (profile) {
    case 'secure-vm':
      return {
        runtime_backend: 'vm',
        browser_backend: 'vm',
        android_backend: 'vm',
      };
    case 'hybrid':
      return {
        runtime_backend: 'remote',
        browser_backend: 'remote',
        android_backend: 'remote',
      };
    case 'trusted-host':
    default:
      return {
        runtime_backend: 'host',
        browser_backend: 'host',
        android_backend: 'host',
      };
  }
}

function normalizeRuntimeSettings(raw = {}) {
  const policy = getDeploymentPolicy();
  const defaults = getEffectiveDefaults();
  const profile = normalizeChoice(raw.runtime_profile, ['secure-vm', 'trusted-host', 'hybrid'], defaults.runtime_profile);
  const derived = deriveDefaultsForProfile(profile);
  const runtimeBackend = normalizeChoice(raw.runtime_backend, ['host', 'vm', 'remote'], derived.runtime_backend);
  const browserBackend = normalizeChoice(raw.browser_backend, ['host', 'vm', 'remote', 'extension'], derived.browser_backend);
  const androidBackend = normalizeChoice(raw.android_backend, ['host', 'vm', 'remote'], derived.android_backend);
  return {
    runtime_profile: profile,
    runtime_backend: policy.allowHostRuntime ? runtimeBackend : (runtimeBackend === 'host' ? 'vm' : runtimeBackend),
    browser_backend: policy.allowHostRuntime ? browserBackend : (browserBackend === 'host' ? 'vm' : browserBackend),
    android_backend: policy.allowHostRuntime ? androidBackend : (androidBackend === 'host' ? 'vm' : androidBackend),
    mcp_backend: 'host-remote',
    remote_worker_base_url: typeof raw.remote_worker_base_url === 'string' ? raw.remote_worker_base_url.trim() : '',
    remote_worker_token: typeof raw.remote_worker_token === 'string' ? raw.remote_worker_token.trim() : '',
  };
}

function parseStoredRuntimeValue(key, value) {
  if (typeof value !== 'string') {
    return value;
  }
  if (key === 'remote_worker_token') {
    return decryptValue(value);
  }
  try {
    return JSON.parse(value);
  } catch {
    return value;
  }
}

function serializeRuntimeSettingValue(key, value) {
  if (key === 'remote_worker_token') {
    return encryptValue(typeof value === 'string' ? value.trim() : '');
  }
  return typeof value === 'string' ? value : JSON.stringify(value);
}

function redactRuntimeSettingValue(key, value) {
  if (key === 'remote_worker_token') {
    return '';
  }
  return value;
}

function isValidRemoteWorkerBaseUrl(value) {
  const candidate = String(value || '').trim();
  if (!candidate) {
    return false;
  }
  try {
    const parsed = new URL(candidate);
    return parsed.protocol === 'http:' || parsed.protocol === 'https:';
  } catch {
    return false;
  }
}

function validateRuntimeSettings(raw = {}) {
  const policy = getDeploymentPolicy();
  const settings = normalizeRuntimeSettings(raw);
  const issues = [];
  const needsRemoteWorker =
    settings.runtime_backend === 'remote'
    || settings.browser_backend === 'remote'
    || settings.android_backend === 'remote';

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
    if (settings.android_backend !== 'vm') {
      issues.push('This deployment requires the VM Android backend.');
    }
  }

  if (needsRemoteWorker && !settings.remote_worker_base_url) {
    issues.push('A remote worker URL is required when any runtime backend uses remote execution.');
  } else if (settings.remote_worker_base_url && !isValidRemoteWorkerBaseUrl(settings.remote_worker_base_url)) {
    issues.push('Remote worker URL must be a valid http or https URL.');
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
