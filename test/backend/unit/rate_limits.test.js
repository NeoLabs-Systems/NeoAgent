'use strict';

const assert = require('node:assert/strict');
const { afterEach, beforeEach, test } = require('node:test');

const {
  createTestRuntime,
  createTestUser,
  teardownTestRuntime,
} = require('../../helpers/db');

let ctx;

beforeEach(() => {
  ctx = createTestRuntime();
  delete process.env.NEOAGENT_RATE_LIMIT_4H;
  delete process.env.NEOAGENT_RATE_LIMIT_WEEKLY;
});

afterEach(() => {
  teardownTestRuntime(ctx);
});

test('rate-limit snapshot uses the increased built-in defaults', async () => {
  const user = await createTestUser(ctx.db);
  const {
    getRateLimitSnapshot,
  } = require('../../../server/services/ai/rate_limits');

  const snapshot = getRateLimitSnapshot(user.userId);

  assert.equal(snapshot.limits.fourHour, 2_500_000);
  assert.equal(snapshot.limits.weekly, 10_000_000);
  assert.equal(snapshot.remaining.fourHour, 2_500_000);
  assert.equal(snapshot.reached.any, false);
});

test('rate-limit snapshot reports remaining usage and next decrease', async () => {
  const user = await createTestUser(ctx.db);
  ctx.db.prepare(
    `INSERT INTO agent_runs (id, user_id, status, total_tokens, created_at)
     VALUES ('limited-run', ?, 'completed', 600, datetime('now', '-1 hour'))`,
  ).run(user.userId);
  ctx.db.prepare(
    'UPDATE users SET rate_limit_4h = 500, rate_limit_weekly = 2000 WHERE id = ?',
  ).run(user.userId);
  const {
    RateLimitExceededError,
    enforceRateLimits,
    getRateLimitSnapshot,
  } = require('../../../server/services/ai/rate_limits');

  const snapshot = getRateLimitSnapshot(user.userId);

  assert.equal(snapshot.usage.fourHour, 600);
  assert.equal(snapshot.remaining.fourHour, 0);
  assert.equal(snapshot.reached.fourHour, true);
  assert.match(snapshot.recoversAt.fourHour, /^\d{4}-\d{2}-\d{2}T/);
  assert.throws(
    () => enforceRateLimits(user.userId),
    (error) =>
      error instanceof RateLimitExceededError &&
      error.statusCode === 429 &&
      error.code === 'RATE_LIMIT_EXCEEDED',
  );
});

test('rate-limit reset times reflect recovery, not the oldest run expiring', async () => {
  const user = await createTestUser(ctx.db);
  // Well under the limit, with runs spread across the window.
  for (const [id, offset] of [['old', '-3 hours'], ['recent', '-10 minutes']]) {
    ctx.db.prepare(
      `INSERT INTO agent_runs (id, user_id, status, total_tokens, created_at)
       VALUES (?, ?, 'completed', 100, datetime('now', ?))`,
    ).run(id, user.userId, offset);
  }
  ctx.db.prepare(
    'UPDATE users SET rate_limit_4h = 10000, rate_limit_weekly = 20000 WHERE id = ?',
  ).run(user.userId);
  const {
    getRateLimitSnapshot,
  } = require('../../../server/services/ai/rate_limits');

  const snapshot = getRateLimitSnapshot(user.userId);

  // Nothing is blocked, so there is no recovery time to report...
  assert.equal(snapshot.recoversAt.fourHour, null);
  // ...and the full reset tracks the newest run, ~4h out, not the oldest (~1h).
  const fullResetInMs = new Date(snapshot.fullResetAt.fourHour).getTime() - Date.now();
  assert.ok(
    fullResetInMs > 3.5 * 60 * 60 * 1000,
    `expected a ~4h reset, got ${Math.round(fullResetInMs / 60000)} minutes`,
  );
});

test('rate-limit enforcement can be bypassed without reserving capacity', async () => {
  const user = await createTestUser(ctx.db);
  ctx.db.prepare(
    `INSERT INTO agent_runs (id, user_id, status, total_tokens, created_at)
     VALUES ('limited-run', ?, 'completed', 600, datetime('now', '-1 hour'))`,
  ).run(user.userId);
  ctx.db.prepare(
    'UPDATE users SET rate_limit_4h = 500, rate_limit_weekly = 2000 WHERE id = ?',
  ).run(user.userId);
  const {
    enforceRateLimits,
    getRateLimitSnapshot,
  } = require('../../../server/services/ai/rate_limits');

  const result = enforceRateLimits(user.userId, { bypass: true });
  const snapshot = getRateLimitSnapshot(user.userId, { includeReservations: true });

  assert.equal(result.bypassed, true);
  assert.equal(snapshot.usage.fourHour, 600);
  assert.equal(snapshot.usage.weekly, 600);
  assert.doesNotThrow(() => result.releaseReservation());
});

test('rate-limit reservation is bounded below the full configured limit', async () => {
  const user = await createTestUser(ctx.db);
  ctx.db.prepare(
    'UPDATE users SET rate_limit_4h = 1000, rate_limit_weekly = 2000 WHERE id = ?',
  ).run(user.userId);
  const {
    enforceRateLimits,
    getRateLimitSnapshot,
  } = require('../../../server/services/ai/rate_limits');

  const result = enforceRateLimits(user.userId);
  const reservedSnapshot = getRateLimitSnapshot(user.userId, { includeReservations: true });

  assert.equal(reservedSnapshot.usage.fourHour, 100);
  assert.equal(reservedSnapshot.remaining.fourHour, 900);
  assert.equal(reservedSnapshot.reached.any, false);

  result.releaseReservation();
  const releasedSnapshot = getRateLimitSnapshot(user.userId, { includeReservations: true });
  assert.equal(releasedSnapshot.usage.fourHour, 0);
});
