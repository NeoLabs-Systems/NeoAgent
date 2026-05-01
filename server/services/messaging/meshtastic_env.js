'use strict';

const fs = require('fs');
const path = require('path');
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

function writeEnvFileValue(key, value, envFile = ENV_FILE) {
  const raw = readEnvFileRaw(envFile);
  const lines = raw ? raw.split('\n') : [];
  let replaced = false;

  for (let i = 0; i < lines.length; i += 1) {
    if (lines[i].startsWith(`${key}=`)) {
      lines[i] = `${key}=${value}`;
      replaced = true;
      break;
    }
  }

  if (!replaced) {
    lines.push(`${key}=${value}`);
  }

  const output = `${lines
    .filter((_, idx, items) => idx !== items.length - 1 || items[idx] !== '')
    .join('\n')}\n`;
  fs.mkdirSync(path.dirname(envFile), { recursive: true });
  fs.writeFileSync(envFile, output, { mode: 0o600 });
}

function removeEnvFileValue(key, envFile = ENV_FILE) {
  const raw = readEnvFileRaw(envFile);
  if (!raw) return false;
  const lines = raw.split('\n').filter((line) => !line.startsWith(`${key}=`));
  const output = `${lines
    .filter((_, idx, items) => idx !== items.length - 1 || items[idx] !== '')
    .join('\n')}\n`;
  fs.mkdirSync(path.dirname(envFile), { recursive: true });
  fs.writeFileSync(envFile, output, { mode: 0o600 });
  return true;
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

function setMeshtasticEnabled(enabled, {
  env = process.env,
  envFile = ENV_FILE,
} = {}) {
  const normalized = normalizeMeshtasticEnabled(enabled, true);
  writeEnvFileValue(MESHTASTIC_ENABLED_ENV_KEY, normalized ? 'true' : 'false', envFile);
  if (env && typeof env === 'object') {
    env[MESHTASTIC_ENABLED_ENV_KEY] = normalized ? 'true' : 'false';
  }
  return normalized;
}

function resetMeshtasticEnabled({
  env = process.env,
  envFile = ENV_FILE,
} = {}) {
  removeEnvFileValue(MESHTASTIC_ENABLED_ENV_KEY, envFile);
  if (env && typeof env === 'object') {
    delete env[MESHTASTIC_ENABLED_ENV_KEY];
  }
}

module.exports = {
  MESHTASTIC_ENABLED_ENV_KEY,
  normalizeMeshtasticEnabled,
  readMeshtasticEnabled,
  setMeshtasticEnabled,
  resetMeshtasticEnabled,
};
