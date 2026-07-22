'use strict';

const { createAbortError, isAbortError } = require('../../../utils/abort');

function sanitizeProviderErrorDetail(value) {
  return String(value || 'Unknown provider error')
    .slice(0, 2000)
    .replace(/\b(Bearer|Basic|token)\s+[A-Za-z0-9._~+/=-]+/gi, '$1 [redacted]')
    .replace(/([?&](?:key|api_key|access_token)=)[^&\s]+/gi, '$1[redacted]')
    .replace(
      /\b(api[_-]?key|access_token|refresh_token|authorization)\b\s*[:=]\s*["']?[^\s,"'}\]]+/gi,
      '$1=[redacted]',
    );
}

function wrapProviderError(error, prefix, options = {}) {
  if (options.signal?.aborted) return createAbortError(options.signal);
  if (isAbortError(error)) return error;

  const detail = typeof options.detail === 'string'
    ? options.detail
    : error?.message || String(error);
  const wrapped = new Error(
    `${prefix}: ${sanitizeProviderErrorDetail(detail)}`,
    { cause: error },
  );
  for (const property of ['status', 'statusCode', 'code', 'headers', 'response', 'type']) {
    if (error?.[property] !== undefined) wrapped[property] = error[property];
  }
  return wrapped;
}

module.exports = {
  sanitizeProviderErrorDetail,
  wrapProviderError,
};
