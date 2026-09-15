'use strict';

const db = require('../../db/database');

// In-process reservation map: userId -> reserved token count for in-flight runs.
// Prevents concurrent run starts from collectively bypassing the per-user budget.
const _reservations = new Map();

const DEFAULT_RATE_LIMIT_4H = 2_500_000;
const DEFAULT_RATE_LIMIT_WEEKLY = 10_000_000;

const MAX_RUN_RESERVATION_TOKENS = 100_000;

const WINDOWS = {
  fourHour: {
    durationMs: 4 * 60 * 60 * 1000,
  },
  weekly: {
    durationMs: 7 * 24 * 60 * 60 * 1000,
  },
};

class RateLimitExceededError extends Error {
  constructor(windowKey, snapshot) {
    const label = windowKey === 'fourHour' ? 'the last 4 hours' : 'the last 7 days';
    const usage = snapshot.usage[windowKey];
    const limit = snapshot.limits[windowKey];
    super(`Rate limit exceeded: You have used ${usage} tokens in ${label} (limit: ${limit}).`);
    this.name = 'RateLimitExceededError';
    this.statusCode = 429;
    this.code = 'RATE_LIMIT_EXCEEDED';
    this.rateLimit = {
      window: windowKey,
      ...snapshot,
    };
  }
}

function parsePositiveInteger(value, fallback) {
  const parsed = Number.parseInt(String(value || ''), 10);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
}

function configuredDefaultLimits() {
  return {
    fourHour: parsePositiveInteger(
      process.env.NEOAGENT_RATE_LIMIT_4H,
      DEFAULT_RATE_LIMIT_4H,
    ),
    weekly: parsePositiveInteger(
      process.env.NEOAGENT_RATE_LIMIT_WEEKLY,
      DEFAULT_RATE_LIMIT_WEEKLY,
    ),
  };
}

function parseSqliteDate(value) {
  const text = String(value || '').trim();
  if (!text) return null;
  const normalized = text.includes('T') ? text : `${text.replace(' ', 'T')}Z`;
  const date = new Date(normalized);
  return Number.isNaN(date.getTime()) ? null : date;
}

function usageRows(userId, durationMs) {
  const modifier = `-${Math.floor(durationMs / 1000)} seconds`;
  return db.prepare(
    `SELECT COALESCE(total_tokens, 0) AS tokens, created_at
     FROM agent_runs
     WHERE user_id = ? AND created_at > datetime('now', ?)
     ORDER BY datetime(created_at) ASC`,
  ).all(userId, modifier);
}

function positiveRows(rows) {
  return rows.filter((row) => Number(row.tokens) > 0);
}

// When the committed usage that currently exceeds the limit has aged out of the
// window, i.e. the first moment the user can start a run again.
function recoversAt(rows, durationMs, committedUsage, limit) {
  if (limit == null || committedUsage < limit) return null;
  const requiredExpiry = committedUsage - limit + 1;
  let tokensToExpire = 0;
  for (const row of positiveRows(rows)) {
    tokensToExpire += Number(row.tokens);
    if (tokensToExpire < requiredExpiry) continue;
    const createdAt = parseSqliteDate(row.created_at);
    return createdAt
      ? new Date(createdAt.getTime() + durationMs).toISOString()
      : null;
  }
  return null;
}

// When every run currently inside the window has aged out, i.e. when usage
// returns to zero if no further runs are started.
function fullResetAt(rows, durationMs) {
  let newest = null;
  for (const row of positiveRows(rows)) {
    const createdAt = parseSqliteDate(row.created_at);
    if (createdAt && (newest == null || createdAt > newest)) newest = createdAt;
  }
  return newest
    ? new Date(newest.getTime() + durationMs).toISOString()
    : null;
}

function getRateLimitSnapshot(userId, { includeReservations = false } = {}) {
  const userLimits = db.prepare(
    'SELECT rate_limit_4h, rate_limit_weekly FROM users WHERE id = ?',
  ).get(userId);
  const defaults = configuredDefaultLimits();
  const customFourHour = userLimits?.rate_limit_4h;
  const customWeekly = userLimits?.rate_limit_weekly;
  const limits = {
    fourHour: customFourHour == null
      ? defaults.fourHour
      : (customFourHour > 0 ? customFourHour : null),
    weekly: customWeekly == null
      ? defaults.weekly
      : (customWeekly > 0 ? customWeekly : null),
    fourHourIsCustom: customFourHour != null,
    weeklyIsCustom: customWeekly != null,
  };
  const reserved = includeReservations ? (_reservations.get(String(userId)) || 0) : 0;
  const usage = {};
  const remaining = {};
  const reached = {};
  const recoversAtByWindow = {};
  const fullResetAtByWindow = {};

  for (const [windowKey, config] of Object.entries(WINDOWS)) {
    const rows = usageRows(userId, config.durationMs);
    const committed = rows.reduce((total, row) => total + Number(row.tokens || 0), 0);
    const used = committed + reserved;
    const limit = limits[windowKey];
    usage[windowKey] = used;
    remaining[windowKey] = limit == null ? null : Math.max(0, limit - used);
    reached[windowKey] = limit != null && used >= limit;
    // Reservations belong to in-flight runs and are released when those runs
    // finish, so only committed usage has a time-based expiry.
    recoversAtByWindow[windowKey] = recoversAt(rows, config.durationMs, committed, limit);
    fullResetAtByWindow[windowKey] = fullResetAt(rows, config.durationMs);
  }

  return {
    limits,
    usage,
    remaining,
    reached: {
      ...reached,
      any: reached.fourHour || reached.weekly,
    },
    recoversAt: recoversAtByWindow,
    fullResetAt: fullResetAtByWindow,
  };
}

function noopReleaseReservation() {}

function calculateReservation(limits) {
  const finiteLimits = [limits.fourHour, limits.weekly]
    .filter((limit) => Number.isFinite(limit) && limit > 0);
  if (finiteLimits.length === 0) return 1;
  const minFiniteLimit = Math.min(...finiteLimits);
  return Math.min(
    MAX_RUN_RESERVATION_TOKENS,
    Math.max(1, Math.floor(minFiniteLimit * 0.1)),
  );
}

function rateLimitsDisabledByEnv() {
  return String(process.env.NEOAGENT_DISABLE_RATE_LIMITS || '').toLowerCase() === 'true';
}

function enforceRateLimits(userId, options = {}) {
  if (options.bypass === true || rateLimitsDisabledByEnv()) {
    return {
      snapshot: getRateLimitSnapshot(userId, { includeReservations: false }),
      releaseReservation: noopReleaseReservation,
      bypassed: true,
    };
  }

  const snapshot = getRateLimitSnapshot(userId, { includeReservations: true });
  if (snapshot.reached.fourHour) {
    throw new RateLimitExceededError('fourHour', snapshot);
  }
  if (snapshot.reached.weekly) {
    throw new RateLimitExceededError('weekly', snapshot);
  }
  // Reserve a bounded placeholder so concurrent starts see this run as
  // in-flight without letting one run consume the user's entire budget.
  const key = String(userId);
  const reserve = calculateReservation(snapshot.limits);
  _reservations.set(key, (_reservations.get(key) || 0) + reserve);
  return { snapshot, releaseReservation: () => releaseReservation(userId, reserve) };
}

function releaseReservation(userId, amount) {
  const key = String(userId);
  const current = _reservations.get(key) || 0;
  const next = current - amount;
  if (next <= 0) {
    _reservations.delete(key);
  } else {
    _reservations.set(key, next);
  }
}

module.exports = {
  DEFAULT_RATE_LIMIT_4H,
  DEFAULT_RATE_LIMIT_WEEKLY,
  MAX_RUN_RESERVATION_TOKENS,
  RateLimitExceededError,
  configuredDefaultLimits,
  enforceRateLimits,
  getRateLimitSnapshot,
  releaseReservation,
};
