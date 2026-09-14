'use strict';

function getConfiguredOrigins() {
  return (process.env.ALLOWED_ORIGINS || '')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);
}

function isLoopbackOrigin(origin) {
  try {
    const parsed = new URL(origin);
    return ['localhost', '127.0.0.1', '[::1]'].includes(parsed.hostname);
  } catch {
    return false;
  }
}

function isAllowedOrigin(origin, options = {}) {
  if (origin == null || origin === '') {
    return options.allowMissingOrigin !== false;
  }
  if (origin === 'null') return false;
  const configuredOrigins = getConfiguredOrigins();
  if (configuredOrigins.includes(origin)) return true;
  if (configuredOrigins.length === 0 && isLoopbackOrigin(origin)) return true;
  return false;
}

function validateOrigin(origin, callback, options = {}) {
  if (isAllowedOrigin(origin, options)) return callback(null, true);
  const error = new Error(`Origin not allowed: ${origin || 'unknown'}`);
  error.statusCode = 403;
  return callback(error);
}

module.exports = {
  get configuredOrigins() {
    return getConfiguredOrigins();
  },
  isAllowedOrigin,
  isLoopbackOrigin,
  validateOrigin
};
