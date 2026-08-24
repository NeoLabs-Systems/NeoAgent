'use strict';

const assert = require('node:assert/strict');
const { afterEach, test } = require('node:test');

const {
  createTestRuntime,
  createTestUser,
  teardownTestRuntime,
} = require('../../helpers/db');

let ctx;

afterEach(() => {
  teardownTestRuntime(ctx);
  ctx = null;
});

test('agent loop policy keeps stall controls but retires productivity budgets', async () => {
  ctx = createTestRuntime();
  const user = await createTestUser(ctx.db, { username: 'loop_policy_settings' });
  const { resolveAgentId } = require('../../../server/services/agents/manager');
  const {
    ensureDefaultAiSettings,
    getAiSettings,
  } = require('../../../server/services/ai/settings');
  const { buildLoopPolicy } = require('../../../server/services/ai/loopPolicy');
  const agentId = resolveAgentId(user.userId, null);

  const defaults = ensureDefaultAiSettings(user.userId, agentId);
  assert.equal(Object.hasOwn(defaults, 'max_iterations'), false);
  assert.equal(defaults.max_consecutive_read_only_iterations, null);
  assert.equal(Object.hasOwn(defaults, 'max_model_failure_recoveries'), false);
  assert.equal(Object.hasOwn(defaults, 'compaction_threshold'), false);
  assert.equal(Object.hasOwn(defaults, 'subagent_max_iterations'), false);
  assert.equal(buildLoopPolicy(defaults, 'tasks', 'execute').maxIterations, 5000);

  const upsert = ctx.db.prepare(
    `INSERT INTO agent_settings (user_id, agent_id, key, value)
     VALUES (?, ?, ?, ?)
     ON CONFLICT(user_id, agent_id, key) DO UPDATE SET value = excluded.value`,
  );
  const configured = {
    max_consecutive_read_only_iterations: 2,
    max_consecutive_tool_failures: 99,
    tool_replay_budget_file_chars: 750,
  };
  for (const [key, value] of Object.entries(configured)) {
    upsert.run(user.userId, agentId, key, JSON.stringify(value));
  }

  const settings = getAiSettings(user.userId, agentId);
  assert.equal(settings.max_consecutive_read_only_iterations, 3);
  assert.equal(settings.max_consecutive_tool_failures, 50);
  assert.equal(settings.tool_replay_budget_file_chars, 750);

  const policy = buildLoopPolicy(settings, 'messaging', 'execute');
  assert.equal(policy.maxIterations, 5000);
  assert.equal(policy.maxConsecutiveReadOnlyIterations, 3);
  assert.equal(policy.maxConsecutiveToolFailures, 50);
  assert.equal(policy.toolResultBudget.file, 750);
});
