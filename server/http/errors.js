'use strict';

const { sanitizeError } = require('../utils/security');
const { logRequestSummary } = require('../utils/logger');

// Application error codes (e.g. INVITE_EXPIRED) are safe to hand to clients so
// they can show the right state; anything else in `err.code` is not.
function publicErrorCode(err) {
  return typeof err?.code === 'string' && /^[A-Z][A-Z0-9_]{1,63}$/.test(err.code)
    ? err.code
    : undefined;
}

function sendJsonError(res, err, fallbackStatus = 500) {
  const status = Number(err?.status || err?.statusCode || fallbackStatus) || fallbackStatus;
  if (status >= 500) {
    return res.status(status).json({ error: sanitizeError(err) });
  }
  const code = publicErrorCode(err);
  return res.status(status).json({
    error: err?.message || 'Request failed.',
    ...(code ? { code } : {}),
  });
}

function registerErrorHandler(app) {
  app.use((err, req, res, next) => {
    const status = err.status || err.statusCode || 500;
    const message = sanitizeError(err);
    const code = publicErrorCode(err);
    console.error('[Unhandled error]', {
      status,
      message,
      code,
      stack: err?.stack,
    });
    logRequestSummary(status >= 500 ? 'error' : 'warn', req, `failed with ${status}`, {
      error: {
        message,
        code,
        stack: err?.stack
      }
    });
    if (req.path.startsWith('/api/')) {
      return res.status(status).json({
        error: message,
        ...(code ? { code } : {}),
      });
    }
    return res.status(status).send('Something went wrong.');
  });
}

module.exports = { registerErrorHandler, sendJsonError };
