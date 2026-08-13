'use strict';

const { sanitizeError } = require('../utils/security');
const { logRequestSummary } = require('../utils/logger');

function registerErrorHandler(app) {
  app.use((err, req, res, next) => {
    const status = err.status || err.statusCode || 500;
    const message = sanitizeError(err);
    const code = typeof err?.code === 'string'
      && /^[A-Z][A-Z0-9_]{1,63}$/.test(err.code)
      ? err.code
      : undefined;
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

module.exports = { registerErrorHandler };
