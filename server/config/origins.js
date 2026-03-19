'use strict';

const configuredOrigins = (process.env.ALLOWED_ORIGINS || '')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);

function isLoopbackOrigin(origin) {
  try {
    const parsed = new URL(origin);
    return ['localhost', '127.0.0.1', '[::1]'].includes(parsed.hostname);
  } catch {
    return false;
  }
}

function isAllowedOrigin(origin) {
  if (!origin) return true;
  if (configuredOrigins.includes(origin)) return true;
  if (isLoopbackOrigin(origin)) return true;
  return false;
}

function validateOrigin(origin, callback) {
  if (isAllowedOrigin(origin)) return callback(null, true);
  return callback(new Error(`Origin not allowed: ${origin || 'unknown'}`));
}

module.exports = {
  configuredOrigins,
  isAllowedOrigin,
  isLoopbackOrigin,
  validateOrigin
};
