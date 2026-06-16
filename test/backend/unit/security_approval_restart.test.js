'use strict';

const assert = require('node:assert/strict');
const { afterEach, test } = require('node:test');

const { agent } = require('../../helpers/supertest');
const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');
const { createTestApp, loginAs } = require('../../helpers/app');

let ctx;

afterEach(() => {
  teardownTestRuntime(ctx);
  ctx = null;
});

test('stale approval submissions for interrupted runs return 410 Gone', async () => {
  ctx = createTestRuntime();
  const { ToolPolicyService } = require('../../../server/services/security/tool_policy_service');
  const { ApprovalGateService } = require('../../../server/services/security/approval_gate_service');
  const user = await createTestUser(ctx.db, { username: 'approval_restart_user' });
  const app = createTestApp({
    locals: {
      toolPolicyService: new ToolPolicyService(),
      approvalGateService: new ApprovalGateService({
        io: { to() { return { emit() {} }; } },
      }),
    },
  }).app;
  const client = agent(app);
  await loginAs(client, user);

  ctx.db.prepare(
    `INSERT INTO agent_runs (id, user_id, status, title, error)
     VALUES (?, ?, 'interrupted', ?, ?)`
  ).run(
    'run-interrupted-approval',
    user.userId,
    'Interrupted approval run',
    'Server restarted while run was in progress.',
  );

  const response = await client
    .post('/api/security/approvals/stale-approval')
    .send({
      decision: 'approved',
      scope: 'once',
      runId: 'run-interrupted-approval',
      toolName: 'execute_command',
      toolArgs: { command: 'echo hello' },
    })
    .expect(410);

  assert.match(response.body.error, /Approval expired/i);
});
