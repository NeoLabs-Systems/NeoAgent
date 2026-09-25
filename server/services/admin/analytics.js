'use strict';

const db = require('../../db/database');

const DAY_MS = 86_400_000;

// `range` is the number of days the time series cover: 1..365, default 30.
function normalizeRange(value) {
  return Math.min(Math.max(parseInt(value, 10) || 30, 1), 365);
}

function count(sql, ...params) {
  return db.prepare(sql).get(...params).n;
}

function summaryStats() {
  const now = new Date().toISOString();
  const dayAgo = new Date(Date.now() - DAY_MS).toISOString();
  const weekAgo = new Date(Date.now() - 7 * DAY_MS).toISOString();
  const totals = db.prepare('SELECT COUNT(*) AS n, COALESCE(SUM(total_tokens),0) AS t FROM agent_runs').get();
  const completed = count("SELECT COUNT(*) AS n FROM agent_runs WHERE status = 'completed'");
  return {
    totalUsers: count('SELECT COUNT(*) AS n FROM users'),
    activeToday: count('SELECT COUNT(*) AS n FROM users WHERE last_login > ?', dayAgo),
    newThisWeek: count('SELECT COUNT(*) AS n FROM users WHERE created_at > ?', weekAgo),
    totalRuns: totals.n,
    runsToday: count('SELECT COUNT(*) AS n FROM agent_runs WHERE created_at > ?', dayAgo),
    runsThisWeek: count('SELECT COUNT(*) AS n FROM agent_runs WHERE created_at > ?', weekAgo),
    totalTokens: totals.t,
    tokensToday: count('SELECT COALESCE(SUM(total_tokens),0) AS n FROM agent_runs WHERE created_at > ?', dayAgo),
    avgTokensPerRun: totals.n > 0 ? Math.round(totals.t / totals.n) : 0,
    successRate: totals.n > 0 ? Math.round((completed / totals.n) * 100) : 0,
    activeSessions: count('SELECT COUNT(*) AS n FROM user_sessions WHERE revoked_at IS NULL AND expires_at > ?', now),
    totalStorage: count('SELECT COALESCE(SUM(byte_size),0) AS n FROM artifacts'),
  };
}

function getAnalytics(rangeValue) {
  const rangeAgo = new Date(Date.now() - normalizeRange(rangeValue) * DAY_MS).toISOString();

  const runsByDay = db.prepare(`
    SELECT date(created_at) AS date,
           COUNT(*) AS runs,
           COALESCE(SUM(total_tokens), 0) AS tokens
    FROM agent_runs
    WHERE created_at > ?
    GROUP BY date(created_at)
    ORDER BY date
  `).all(rangeAgo);

  const usersByDay = db.prepare(`
    SELECT date(created_at) AS date, COUNT(*) AS newUsers
    FROM users
    WHERE created_at > ?
    GROUP BY date(created_at)
    ORDER BY date
  `).all(rangeAgo);

  const modelBreakdown = db.prepare(`
    SELECT COALESCE(model, 'unknown') AS model,
           COUNT(*) AS runs,
           COALESCE(SUM(total_tokens), 0) AS tokens
    FROM agent_runs
    WHERE created_at > ?
    GROUP BY model
    ORDER BY runs DESC
    LIMIT 10
  `).all(rangeAgo);

  const statusBreakdown = db.prepare(`
    SELECT status, COUNT(*) AS count
    FROM agent_runs
    GROUP BY status
    ORDER BY count DESC
  `).all();

  const topUsers = db.prepare(`
    SELECT u.id, u.username, u.display_name,
           COALESCE(r.runs,    0) AS runs,
           COALESCE(r.tokens,  0) AS tokens,
           COALESCE(a.storage, 0) AS storage
    FROM users u
    LEFT JOIN (
      SELECT user_id, COUNT(*) AS runs, COALESCE(SUM(total_tokens),0) AS tokens
      FROM agent_runs GROUP BY user_id
    ) r ON r.user_id = u.id
    LEFT JOIN (
      SELECT user_id, COALESCE(SUM(byte_size),0) AS storage
      FROM artifacts GROUP BY user_id
    ) a ON a.user_id = u.id
    ORDER BY tokens DESC LIMIT 10
  `).all();

  const recentRuns = db.prepare(`
    SELECT r.id, u.username, r.title, r.status, r.model, r.total_tokens,
           r.created_at, r.completed_at
    FROM agent_runs r
    JOIN users u ON u.id = r.user_id
    ORDER BY r.created_at DESC LIMIT 25
  `).all();

  return {
    stats: summaryStats(),
    runsByDay,
    usersByDay,
    modelBreakdown,
    statusBreakdown,
    topUsers,
    recentRuns,
  };
}

module.exports = { getAnalytics };
