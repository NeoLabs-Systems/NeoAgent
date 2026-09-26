'use strict';

const db = require('../../db/database');
const { configuredDefaultLimits } = require('../ai/rate_limits');
const { persistEnv } = require('./env_config');
const { httpError } = require('../../utils/http_error');

// A token limit is a whole number >= 0, or null for "use the default". For a
// single account 0 means unlimited; server-wide, anything below 1 falls back to
// the built-in default.
function parseLimit(value, field) {
  if (value === null || value === undefined || value === '') return null;
  const limit = Number(value);
  if (!Number.isInteger(limit) || limit < 0) {
    throw httpError(400, `${field} must be a whole number ≥ 0, or null.`);
  }
  return limit;
}

function getUserRateLimits(userId) {
  const limits = db.prepare('SELECT rate_limit_4h, rate_limit_weekly FROM users WHERE id = ?').get(userId);
  if (!limits) throw httpError(404, 'User not found', 'NOT_FOUND');
  return { limits };
}

function setUserRateLimits(userId, body) {
  const fourHour = parseLimit(body?.rate_limit_4h, 'rate_limit_4h');
  const weekly = parseLimit(body?.rate_limit_weekly, 'rate_limit_weekly');
  db.prepare('UPDATE users SET rate_limit_4h = ?, rate_limit_weekly = ? WHERE id = ?').run(fourHour, weekly, userId);
  return { ok: true };
}

function getDefaultRateLimits() {
  const defaults = configuredDefaultLimits();
  return { rate_limit_4h: defaults.fourHour, rate_limit_weekly: defaults.weekly };
}

function setDefaultRateLimits(body) {
  const fourHour = parseLimit(body?.rate_limit_4h, 'rate_limit_4h');
  const weekly = parseLimit(body?.rate_limit_weekly, 'rate_limit_weekly');
  persistEnv('NEOAGENT_RATE_LIMIT_4H', fourHour ?? '');
  persistEnv('NEOAGENT_RATE_LIMIT_WEEKLY', weekly ?? '');
  return { ok: true };
}

module.exports = {
  getUserRateLimits,
  setUserRateLimits,
  getDefaultRateLimits,
  setDefaultRateLimits,
};
