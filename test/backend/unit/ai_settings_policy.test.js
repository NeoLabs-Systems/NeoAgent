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

test('agent loop policy settings persist, normalize, and preserve contextual defaults', async () => {
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
  assert.equal(defaults.max_iterations, null);
  assert.equal(defaults.max_consecutive_read_only_iterations, null);
  assert.equal(buildLoopPolicy(defaults, 'tasks', 'execute').maxIterations, 40);

  const upsert = ctx.db.prepare(
    `INSERT INTO agent_settings (user_id, agent_id, key, value)
     VALUES (?, ?, ?, ?)
     ON CONFLICT(user_id, agent_id, key) DO UPDATE SET value = excluded.value`,
  );
  const configured = {
    max_iterations: 999,
    max_consecutive_read_only_iterations: 2,
    max_consecutive_tool_failures: 99,
    max_model_failure_recoveries: -1,
    compaction_threshold: 0.05,
    tool_replay_budget_file_chars: 750,
  };
  for (const [key, value] of Object.entries(configured)) {
    upsert.run(user.userId, agentId, key, JSON.stringify(value));
  }

  const settings = getAiSettings(user.userId, agentId);
  assert.equal(settings.max_iterations, 400);
  assert.equal(settings.max_consecutive_read_only_iterations, 3);
  assert.equal(settings.max_consecutive_tool_failures, 50);
  assert.equal(settings.max_model_failure_recoveries, 0);
  assert.equal(settings.compaction_threshold, 0.1);
  assert.equal(settings.tool_replay_budget_file_chars, 750);

  const policy = buildLoopPolicy(settings, 'messaging', 'execute');
  assert.equal(policy.maxIterations, 400);
  assert.equal(policy.maxConsecutiveReadOnlyIterations, 3);
  assert.equal(policy.maxConsecutiveToolFailures, 50);
  assert.equal(policy.maxModelFailureRecoveries, 0);
  assert.equal(policy.compactionThreshold, 0.1);
  assert.equal(policy.toolResultBudget.file, 750);
});
