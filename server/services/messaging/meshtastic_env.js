'use strict';

const fs = require('fs');
const { ENV_FILE } = require('../../../runtime/paths');
const { parseEnv } = require('../../../runtime/env');

const MESHTASTIC_ENABLED_ENV_KEY = 'MESHTASTIC_ENABLED';
const FALSE_VALUES = new Set(['0', 'false', 'no', 'off', 'disabled']);

function normalizeMeshtasticEnabled(value, fallback = true) {
  if (value == null) return fallback;
  const normalized = String(value).trim().toLowerCase();
  if (!normalized) return fallback;
  return !FALSE_VALUES.has(normalized);
}

function readEnvFileRaw(envFile = ENV_FILE) {
  if (!fs.existsSync(envFile)) return '';
  return fs.readFileSync(envFile, 'utf8');
}


function readMeshtasticEnabled({
  env = process.env,
  envFile = ENV_FILE,
  fallback = true,
} = {}) {
  const envValue = env?.[MESHTASTIC_ENABLED_ENV_KEY];
  if (envValue != null && String(envValue).trim()) {
    return normalizeMeshtasticEnabled(envValue, fallback);
  }
  const parsed = parseEnv(readEnvFileRaw(envFile));
  return normalizeMeshtasticEnabled(parsed.get(MESHTASTIC_ENABLED_ENV_KEY), fallback);
}

module.exports = {
  MESHTASTIC_ENABLED_ENV_KEY,
  normalizeMeshtasticEnabled,
  readMeshtasticEnabled,
};
