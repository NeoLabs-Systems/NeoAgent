'use strict';

const { ENV_FILE, upsertEnvValue } = require('../../../runtime/paths');

const STRING_FIELDS = Object.freeze({
  from: 'NEOAGENT_EMAIL_FROM',
  smtpHost: 'NEOAGENT_EMAIL_SMTP_HOST',
  smtpUser: 'NEOAGENT_EMAIL_SMTP_USER',
  replyTo: 'NEOAGENT_EMAIL_REPLY_TO',
  brandName: 'NEOAGENT_EMAIL_BRAND_NAME',
  supportUrl: 'NEOAGENT_EMAIL_SUPPORT_URL',
  publicUrl: 'NEOAGENT_EMAIL_PUBLIC_URL',
});

const BOOLEAN_FIELDS = Object.freeze({
  smtpSecure: ['NEOAGENT_EMAIL_SMTP_SECURE', false],
  smtpRequireTls: ['NEOAGENT_EMAIL_SMTP_REQUIRE_TLS', true],
  smtpRejectUnauthorized: ['NEOAGENT_EMAIL_SMTP_REJECT_UNAUTHORIZED', true],
  requireSignupConfirmation: ['NEOAGENT_EMAIL_REQUIRE_SIGNUP_CONFIRMATION', true],
  requireEmailChangeConfirmation: ['NEOAGENT_EMAIL_REQUIRE_EMAIL_CHANGE_CONFIRMATION', true],
  notifyUnusualLogin: ['NEOAGENT_EMAIL_NOTIFY_UNUSUAL_LOGIN', true],
  notifyAccountChanges: ['NEOAGENT_EMAIL_NOTIFY_ACCOUNT_CHANGES', true],
});

function envString(env, key) {
  return String(env[key] || '').trim();
}

function envBoolean(env, key, defaultValue) {
  const value = envString(env, key).toLowerCase();
  if (!value) return defaultValue;
  return ['1', 'true', 'yes', 'on'].includes(value);
}

function envPositiveInteger(env, key, defaultValue) {
  const value = Number(envString(env, key));
  return Number.isInteger(value) && value > 0 ? value : defaultValue;
}

function cleanSingleLine(value, label) {
  const cleaned = String(value ?? '').trim();
  if (/[\r\n]/.test(cleaned)) {
    const error = new Error(`${label} must be a single line.`);
    error.statusCode = 400;
    throw error;
  }
  return cleaned;
}

function requireBoolean(value, label) {
  if (typeof value !== 'boolean') {
    const error = new Error(`${label} must be true or false.`);
    error.statusCode = 400;
    throw error;
  }
  return value;
}

function requireInteger(value, label, { min, max }) {
  const number = Number(value);
  if (!Number.isInteger(number) || number < min || number > max) {
    const error = new Error(`${label} must be an integer from ${min} to ${max}.`);
    error.statusCode = 400;
    throw error;
  }
  return number;
}

function requireHttpUrl(value, label) {
  const cleaned = cleanSingleLine(value, label);
  if (!cleaned) return '';
  try {
    const url = new URL(cleaned);
    if (url.protocol !== 'http:' && url.protocol !== 'https:') throw new Error('invalid protocol');
  } catch {
    const error = new Error(`${label} must be an HTTP or HTTPS URL.`);
    error.statusCode = 400;
    throw error;
  }
  return cleaned.replace(/\/$/, '');
}

function encodeEnvValue(value) {
  return JSON.stringify(String(value));
}

function persistValue(envFile, env, key, value) {
  upsertEnvValue(envFile, key, encodeEnvValue(value));
  if (value === '') {
    delete env[key];
  } else {
    env[key] = String(value);
  }
}

function getAdminEmailSettings({ env = process.env } = {}) {
  const smtpPort = envPositiveInteger(env, 'NEOAGENT_EMAIL_SMTP_PORT', 587);
  const settings = {
    smtpPort,
    tokenTtlHours: envPositiveInteger(env, 'NEOAGENT_EMAIL_TOKEN_TTL_HOURS', 24),
    smtpPasswordConfigured: Boolean(envString(env, 'NEOAGENT_EMAIL_SMTP_PASS')),
  };

  for (const [name, key] of Object.entries(STRING_FIELDS)) {
    settings[name] = envString(env, key);
  }
  for (const [name, [key, defaultValue]] of Object.entries(BOOLEAN_FIELDS)) {
    let effectiveDefault = defaultValue;
    if (name === 'smtpSecure') effectiveDefault = smtpPort === 465;
    if (name === 'smtpRequireTls') effectiveDefault = !settings.smtpSecure;
    settings[name] = envBoolean(env, key, effectiveDefault);
  }

  const missing = [];
  if (!settings.from) missing.push('Sender address');
  if (!settings.smtpHost) missing.push('SMTP host');

  return {
    configured: missing.length === 0,
    missing,
    settings,
  };
}

function updateAdminEmailSettings(body, { env = process.env, envFile = ENV_FILE } = {}) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    const error = new Error('Email settings must be an object.');
    error.statusCode = 400;
    throw error;
  }

  const values = {};
  for (const name of Object.keys(STRING_FIELDS)) {
    values[name] = name === 'supportUrl' || name === 'publicUrl'
      ? requireHttpUrl(body[name], name === 'supportUrl' ? 'Support URL' : 'Public URL')
      : cleanSingleLine(body[name], name);
  }

  values.smtpPort = requireInteger(body.smtpPort, 'SMTP port', { min: 1, max: 65535 });
  values.tokenTtlHours = requireInteger(body.tokenTtlHours, 'Token lifetime', { min: 1, max: 8760 });

  for (const name of Object.keys(BOOLEAN_FIELDS)) {
    values[name] = requireBoolean(body[name], name);
  }

  const smtpPassword = cleanSingleLine(body.smtpPassword, 'SMTP password');
  const clearSmtpPassword = body.clearSmtpPassword === true;

  for (const [name, key] of Object.entries(STRING_FIELDS)) {
    persistValue(envFile, env, key, values[name]);
  }
  persistValue(envFile, env, 'NEOAGENT_EMAIL_SMTP_PORT', values.smtpPort);
  persistValue(envFile, env, 'NEOAGENT_EMAIL_TOKEN_TTL_HOURS', values.tokenTtlHours);
  for (const [name, [key]] of Object.entries(BOOLEAN_FIELDS)) {
    persistValue(envFile, env, key, values[name]);
  }
  if (smtpPassword || clearSmtpPassword) {
    persistValue(envFile, env, 'NEOAGENT_EMAIL_SMTP_PASS', clearSmtpPassword ? '' : smtpPassword);
  }

  return getAdminEmailSettings({ env });
}

module.exports = {
  getAdminEmailSettings,
  updateAdminEmailSettings,
};
