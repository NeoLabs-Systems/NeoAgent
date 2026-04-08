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

function isChromeExtensionOrigin(origin) {
  try {
    return new URL(origin).protocol === 'chrome-extension:';
  } catch {
    return false;
  }
}

function isAllowedOrigin(origin, options = {}) {
  if (!origin) return true;
  if (configuredOrigins.includes(origin)) return true;
  if (isLoopbackOrigin(origin)) return true;
  if (options.allowChromeExtension && isChromeExtensionOrigin(origin)) return true;
  return false;
}

function validateOrigin(origin, callback, options = {}) {
  if (isAllowedOrigin(origin, options)) return callback(null, true);
  return callback(new Error(`Origin not allowed: ${origin || 'unknown'}`));
}

module.exports = {
  configuredOrigins,
  isChromeExtensionOrigin,
  isAllowedOrigin,
  isLoopbackOrigin,
  validateOrigin
};
