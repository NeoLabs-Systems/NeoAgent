'use strict';

const { httpError } = require('../../utils/http_error');
const { sendJsonError } = require('../../http/errors');

// Wraps a synchronous handler body: its return value is the JSON response, and
// a thrown error (usually an httpError) becomes the matching error response.
function jsonHandler(action, { status = 200 } = {}) {
  return (req, res) => {
    try {
      res.status(status).json(action(req));
    } catch (err) {
      sendJsonError(res, err);
    }
  };
}

// `:id` / `:userId` route params name a users row: a positive integer.
function userIdParam(value) {
  const id = Number(value);
  if (!Number.isInteger(id) || id <= 0) {
    throw httpError(400, 'Invalid user id', 'INVALID_USER_ID');
  }
  return id;
}

module.exports = { jsonHandler, userIdParam };
