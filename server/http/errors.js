'use strict';

const { sanitizeError } = require('../utils/security');
const { logRequestSummary } = require('../utils/logger');

function registerErrorHandler(app) {
  app.use((err, req, res, next) => {
    console.error('[Unhandled error]', err);
    const status = err.status || err.statusCode || 500;
    const message = sanitizeError(err);
    logRequestSummary(status >= 500 ? 'error' : 'warn', req, `failed with ${status}`, {
      error: {
        message: err?.message,
        code: err?.code,
        stack: err?.stack
      }
    });
    if (req.path.startsWith('/api/')) {
      return res.status(status).json({ error: message });
    }
    return res.status(status).send('Something went wrong.');
  });
}

module.exports = { registerErrorHandler };
