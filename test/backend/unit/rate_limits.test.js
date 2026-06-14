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
  assert.match(snapshot.nextDecreaseAt.fourHour, /^\d{4}-\d{2}-\d{2}T/);
  assert.throws(
    () => enforceRateLimits(user.userId),
    (error) =>
      error instanceof RateLimitExceededError &&
      error.statusCode === 429 &&
      error.code === 'RATE_LIMIT_EXCEEDED',
  );
});
