'use strict';

const db = require('../../db/database');

const DEFAULT_RATE_LIMIT_4H = 2_500_000;
const DEFAULT_RATE_LIMIT_WEEKLY = 10_000_000;

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

function nextDecreaseAt(rows, durationMs, usage, limit) {
  const positiveRows = rows.filter((row) => Number(row.tokens) > 0);
  if (positiveRows.length === 0) return null;

  let tokensToExpire = 0;
  const requiredExpiry = usage >= limit ? usage - limit + 1 : 1;
  for (const row of positiveRows) {
    tokensToExpire += Number(row.tokens);
    if (tokensToExpire < requiredExpiry) continue;
    const createdAt = parseSqliteDate(row.created_at);
    return createdAt
      ? new Date(createdAt.getTime() + durationMs).toISOString()
      : null;
  }
  return null;
}

function getRateLimitSnapshot(userId) {
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
  const usage = {};
  const remaining = {};
  const reached = {};
  const nextDecreaseAtByWindow = {};

  for (const [windowKey, config] of Object.entries(WINDOWS)) {
    const rows = usageRows(userId, config.durationMs);
    const used = rows.reduce((total, row) => total + Number(row.tokens || 0), 0);
    const limit = limits[windowKey];
    usage[windowKey] = used;
    remaining[windowKey] = limit == null ? null : Math.max(0, limit - used);
    reached[windowKey] = limit != null && used >= limit;
    nextDecreaseAtByWindow[windowKey] = limit == null
      ? null
      : nextDecreaseAt(rows, config.durationMs, used, limit);
  }

  return {
    limits,
    usage,
    remaining,
    reached: {
      ...reached,
      any: reached.fourHour || reached.weekly,
    },
    nextDecreaseAt: nextDecreaseAtByWindow,
  };
}

function enforceRateLimits(userId) {
  const snapshot = getRateLimitSnapshot(userId);
  if (snapshot.reached.fourHour) {
    throw new RateLimitExceededError('fourHour', snapshot);
  }
  if (snapshot.reached.weekly) {
    throw new RateLimitExceededError('weekly', snapshot);
  }
  return snapshot;
}

module.exports = {
  DEFAULT_RATE_LIMIT_4H,
  DEFAULT_RATE_LIMIT_WEEKLY,
  RateLimitExceededError,
  configuredDefaultLimits,
  enforceRateLimits,
  getRateLimitSnapshot,
};
