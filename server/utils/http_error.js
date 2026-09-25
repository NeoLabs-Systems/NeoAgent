'use strict';

// An Error that route handlers turn into a 4xx response: `status` picks the
// HTTP status and `code`, when set, lets the client branch without parsing text.
function httpError(status, message, code = null) {
  const error = new Error(message);
  error.status = status;
  if (code) error.code = code;
  return error;
}

module.exports = { httpError };
