'use strict';

const { sanitizeError } = require('../utils/security');

function registerErrorHandler(app) {
  app.use((err, req, res, next) => {
    console.error('[Unhandled error]', err);
    const status = err.status || err.statusCode || 500;
    const message = sanitizeError(err);
    if (req.path.startsWith('/api/')) {
      return res.status(status).json({ error: message });
    }
    return res.status(status).send('Something went wrong.');
  });
}

module.exports = { registerErrorHandler };
