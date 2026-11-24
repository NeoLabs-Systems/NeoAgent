'use strict';

// An Error that route handlers turn into a 4xx response: `status` picks the
// HTTP status and `code`, when set, lets the client branch without parsing text.
function httpError(status, message, code = null) {
  const error = new Error(message);
  error.status = status;
  if (code) error.code = code;
  return error;
}

// Application error codes (e.g. INVITE_EXPIRED) are safe to hand to clients so
// they can show the right state; anything else in `err.code` is not.
// Node and driver codes (ENOENT, ERR_INVALID_URL, SQLITE_BUSY) describe the
// server's internals, so they stay out of what clients receive.
const SYSTEM_ERROR_CODE = /^(?:E[A-Z0-9]+|ERR_[A-Z0-9_]+|SQLITE_[A-Z0-9_]+)$/;

function publicErrorCode(err) {
  return typeof err?.code === 'string'
    && /^[A-Z][A-Z0-9_]{1,63}$/.test(err.code)
    && !SYSTEM_ERROR_CODE.test(err.code)
    ? err.code
    : undefined;
}

module.exports = { httpError, publicErrorCode };
