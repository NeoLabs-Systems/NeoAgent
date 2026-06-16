'use strict';

const assert = require('node:assert/strict');
const { afterEach, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

let ctx;

afterEach(() => {
  teardownTestRuntime(ctx);
  ctx = null;
});

test('interruptStaleAgentRuns marks orphaned running rows as interrupted on startup recovery', async () => {
  ctx = createTestRuntime();
  const db = require('../../../server/db/database');
  const user = await createTestUser(ctx.db, { username: 'stale_run_recovery' });

  db.prepare(
    `INSERT INTO agent_runs (id, user_id, status, title)
     VALUES (?, ?, 'running', ?)`
  ).run('run-stale', user.userId, 'Stale run');
  db.prepare(
    `INSERT INTO agent_steps (id, run_id, status, type, description, started_at)
     VALUES (?, ?, 'running', 'tool', ?, datetime('now'))`
  ).run('step-stale', 'run-stale', 'Waiting on a tool');

  const changed = db.interruptStaleAgentRuns();
  assert.equal(changed, 1);

  const runRow = db.prepare(
    'SELECT status, error, completed_at FROM agent_runs WHERE id = ?'
  ).get('run-stale');
  assert.equal(runRow.status, 'interrupted');
  assert.equal(runRow.error, db.STALE_RUN_INTERRUPTED_ERROR);
  assert.ok(runRow.completed_at);

  const stepRow = db.prepare(
    'SELECT status, error, completed_at FROM agent_steps WHERE id = ?'
  ).get('step-stale');
  assert.equal(stepRow.status, 'interrupted');
  assert.equal(stepRow.error, db.STALE_RUN_INTERRUPTED_ERROR);
  assert.ok(stepRow.completed_at);
});

test('stopServices interrupts active runs before shutdown continues', async () => {
  ctx = createTestRuntime();
  const { stopServices } = require('../../../server/services/manager');
  let interrupted = 0;

  await stopServices({
    locals: {
      agentEngine: {
        interruptAllActiveRuns() {
          interrupted += 1;
        },
      },
    },
  });

  assert.equal(interrupted, 1);
});
