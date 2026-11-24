'use strict';

// Asking a signed-in account for its password or a 2FA code again, before a
// sensitive change, is throttled per account, not per client address, so a
// stolen session (or a client that changes its address or spoofs
// X-Forwarded-For) can't guess faster than that. From the 5th failure in 15
// minutes each next try waits twice as long (2 s, 4 s, ...); the 10th locks
// the confirmations until the oldest of those failures leaves the window.
// Locks are short on purpose, so they never shut the owner out for long.
// Sign-in is not counted here.

const db = require('../../db/database');
const { httpError } = require('../../utils/http_error');

const FAILURE_WINDOW_MS = 15 * 60 * 1000;
const FAILURES_BEFORE_DELAY = 5;
const FAILURES_BEFORE_LOCK = 10;
const BASE_DELAY_MS = 2000;

/** The key a signed-in account's password and code confirmations count under. */
function confirmKey(userId) {
  return `confirm:user:${userId}`;
}

function confirmLocked(retryAfterMs) {
  const retryAfter = Math.max(1, Math.ceil(retryAfterMs / 1000));
  const wait = retryAfter >= 90 ? `${Math.ceil(retryAfter / 60)} minutes` : `${retryAfter} seconds`;
  const error = httpError(429, `Too many wrong passwords or codes for this account. Try again in ${wait}.`, 'LOGIN_LOCKED');
  error.retryAfter = retryAfter;
  return error;
}

/** Refuses a try while the account is throttled: 429 LOGIN_LOCKED with `retryAfter` seconds. */
function assertSignInAllowed(key, now = Date.now()) {
  const failures = db.prepare(`
    SELECT failed_at_ms FROM login_failures WHERE account_key = ? AND failed_at_ms > ? ORDER BY failed_at_ms
  `).all(key, now - FAILURE_WINDOW_MS).map((row) => row.failed_at_ms);
  if (failures.length >= FAILURES_BEFORE_LOCK) {
    throw confirmLocked(failures[failures.length - FAILURES_BEFORE_LOCK] + FAILURE_WINDOW_MS - now);
  }
  if (failures.length >= FAILURES_BEFORE_DELAY) {
    const next = failures[failures.length - 1] + BASE_DELAY_MS * 2 ** (failures.length - FAILURES_BEFORE_DELAY);
    if (now < next) throw confirmLocked(next - now);
  }
}

/**
 * Counts a try as failed before its password or code is checked, so
 * parallel guesses count too; a success takes it back (clearFailures).
 */
function recordFailure(key, { kind }, now = Date.now()) {
  db.prepare('DELETE FROM login_failures WHERE failed_at_ms <= ?').run(now - FAILURE_WINDOW_MS);
  db.prepare('INSERT INTO login_failures (account_key, kind, failed_at_ms) VALUES (?, ?, ?)')
    .run(key, kind, now);
}

/** After a right password or code only failures of that kind go (`kind` null clears all). */
function clearFailures(key, kind = null) {
  db.prepare('DELETE FROM login_failures WHERE account_key = ? AND (? IS NULL OR kind = ?)').run(key, kind, kind);
}

module.exports = {
  assertSignInAllowed,
  clearFailures,
  confirmKey,
  recordFailure,
};
