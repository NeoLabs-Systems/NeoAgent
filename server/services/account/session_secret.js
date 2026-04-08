'use strict';

const crypto = require('crypto');

const INSECURE_SESSION_SECRET_VALUES = new Set([
  'neoagent-dev-secret-change-me',
  'change-this-to-a-random-secret-in-production',
  'change-me-to-something-random',
]);

let fallbackSecret = null;

function configuredSessionSecret() {
  return String(process.env.SESSION_SECRET || '').trim();
}

function isInsecureSessionSecret(value = configuredSessionSecret()) {
  const secret = String(value || '').trim();
  return !secret || INSECURE_SESSION_SECRET_VALUES.has(secret);
}

function getSessionSecret() {
  const configured = configuredSessionSecret();
  if (configured && !isInsecureSessionSecret(configured)) return configured;
  if (!fallbackSecret) fallbackSecret = crypto.randomBytes(32).toString('hex');
  return fallbackSecret;
}

module.exports = {
  configuredSessionSecret,
  getSessionSecret,
  isInsecureSessionSecret,
};
