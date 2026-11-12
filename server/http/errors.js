'use strict';

const { sanitizeError } = require('../utils/security');
const { logRequestSummary } = require('../utils/logger');
const { publicErrorCode } = require('../utils/http_error');
const { redactResponseBody } = require('../utils/public_error');
const { isAdminUser } = require('../services/access/admin');

// Every API response passes here, so no route can show a non-admin the
// technical cause of a failure. The server log keeps it for admins.
function redactErrorsForNonAdmins(req, res, next) {
  if (!req.path.startsWith('/api/')) return next();
  const sendJson = res.json.bind(res);
  res.json = (body) => {
    const userId = req.session?.userId;
    if (userId && isAdminUser(userId)) return sendJson(body);
    if (res.statusCode >= 500) {
      console.error('[API failure hidden from non-admin]', req.method, req.path, res.statusCode, body?.error);
    }
    return sendJson(redactResponseBody(body, res.statusCode));
  };
  next();
}

function sendJsonError(res, err, fallbackStatus = 500) {
  const status = Number(err?.status || err?.statusCode || fallbackStatus) || fallbackStatus;
  if (status >= 500) {
    return res.status(status).json({ error: sanitizeError(err) });
  }
  const code = publicErrorCode(err);
  // A throttled account (429 LOGIN_LOCKED) says how many seconds to wait.
  const retryAfter = Number.isInteger(err?.retryAfter) ? err.retryAfter : null;
  if (retryAfter) res.set('Retry-After', String(retryAfter));
  return res.status(status).json({
    error: err?.message || 'Request failed.',
    ...(code ? { code } : {}),
    ...(retryAfter ? { retryAfter } : {}),
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

module.exports = { redactErrorsForNonAdmins, registerErrorHandler, sendJsonError };
