'use strict';

const assert = require('node:assert/strict');
const { afterEach, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

let ctx;

afterEach(() => {
  teardownTestRuntime(ctx);
  ctx = null;
});

function createFakeIo(events) {
  return {
    to(room) {
      return {
        emit(event, payload) {
          events.push({ room, event, payload });
        },
      };
    },
  };
}

test('approval gate persists pending approvals and expires them during shutdown', async () => {
  ctx = createTestRuntime();
  const db = require('../../../server/db/database');
  const { ApprovalGateService } = require('../../../server/services/security/approval_gate_service');
  const user = await createTestUser(ctx.db, { username: 'approval_pending_persistence' });
  db.prepare(
    `INSERT INTO agent_runs (id, user_id, status, title)
     VALUES (?, ?, 'running', ?)`
  ).run('run-pending-approval', user.userId, 'Pending approval run');
  const events = [];
  const service = new ApprovalGateService({ io: createFakeIo(events) });

  const promise = service.requestApproval(
    user.userId,
    'run-pending-approval',
    'execute_command',
    { command: 'echo hello' },
  );

  const pending = db.prepare(
    'SELECT id, status, tool_name FROM pending_approvals WHERE user_id = ?'
  ).get(user.userId);
  assert.ok(pending?.id);
  assert.equal(pending.status, 'pending');
  assert.equal(pending.tool_name, 'execute_command');

  service.shutdown('Approval expired because the server restarted.');
  const decision = await promise;
  assert.equal(decision, 'expired');

  const expired = db.prepare(
    'SELECT status, scope, decided_at FROM pending_approvals WHERE id = ?'
  ).get(pending.id);
  assert.equal(expired.status, 'expired');
  assert.equal(expired.scope, 'once');
  assert.ok(expired.decided_at);
  assert.equal(
    events.some((item) => item.event == 'tool:approval_resolved' && item.payload?.decision == 'expired'),
    true,
  );
});

test('session grants are persisted and reloaded across service restart', async () => {
  ctx = createTestRuntime();
  const db = require('../../../server/db/database');
  const { ApprovalGateService } = require('../../../server/services/security/approval_gate_service');
  const user = await createTestUser(ctx.db, { username: 'approval_session_grant_reload' });
  const runId = 'run-session-grant';
  const toolName = 'execute_command';
  db.prepare(
    `INSERT INTO agent_runs (id, user_id, status, title)
     VALUES (?, ?, 'running', ?)`
  ).run(runId, user.userId, 'Session grant run');

  const service = new ApprovalGateService({ io: createFakeIo([]) });
  const promise = service.requestApproval(
    user.userId,
    runId,
    toolName,
    { command: 'pwd' },
  );
  const pending = db.prepare(
    'SELECT id FROM pending_approvals WHERE user_id = ? AND run_id = ?'
  ).get(user.userId, runId);

  const resolved = service.resolve(
    pending.id,
    user.userId,
    runId,
    toolName,
    { command: 'pwd' },
    'approved',
    'session',
  );
  assert.equal(resolved, true);
  assert.equal(await promise, 'approved');

  const storedGrant = db.prepare(
    'SELECT tool_name, expires_at FROM approval_session_grants WHERE user_id = ? AND run_id = ?'
  ).get(user.userId, runId);
  assert.equal(storedGrant.tool_name, toolName);
  assert.ok(storedGrant.expires_at);

  const reloadedService = new ApprovalGateService({ io: createFakeIo([]) });
  assert.equal(reloadedService.hasSessionGrant(user.userId, runId, toolName), true);
});
