'use strict';

// Server-wide settings the admin API edits live in the .env file. Each change
// is written there and applied to process.env so it takes effect without a
// restart (for code that reads the value at use time).

const { ENV_FILE, upsertEnvValue } = require('../../../runtime/paths');

function cleanLine(value) {
  return String(value ?? '').trim().replace(/[\r\n]/g, '');
}

function persistEnv(key, value) {
  const text = String(value);
  upsertEnvValue(ENV_FILE, key, text);
  if (text === '') {
    delete process.env[key];
  } else {
    process.env[key] = text;
  }
}

function readEnvBool(key, defaultValue) {
  const value = (process.env[key] || '').toLowerCase();
  return value ? ['1', 'true', 'yes', 'on'].includes(value) : defaultValue;
}

function readEnvInt(key, defaultValue) {
  const value = parseInt(process.env[key] || '', 10);
  return Number.isFinite(value) ? value : defaultValue;
}

// Enough of a secret to recognise which one is set, never enough to use it.
function maskSecret(value, prefixLength = 4) {
  if (!value) return '';
  if (value.length <= 8) return '•'.repeat(value.length);
  return `${value.slice(0, prefixLength)}${'•'.repeat(4)}${value.slice(-4)}`;
}

module.exports = {
  cleanLine,
  persistEnv,
  readEnvBool,
  readEnvInt,
  maskSecret,
};
