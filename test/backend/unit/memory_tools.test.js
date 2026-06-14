'use strict';

const assert = require('node:assert/strict');
const { afterEach, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

let ctx;

afterEach(() => {
  teardownTestRuntime(ctx);
  ctx = null;
});

test('memory tool schemas do not expose an unusable confirmation flag', () => {
  ctx = createTestRuntime();
  const { getAvailableTools } = require('../../../server/services/ai/tools');
  const tools = getAvailableTools(null, {
    names: ['memory_save', 'memory_update_core'],
  });
  const coreTool = tools.find((tool) => tool.name === 'memory_update_core');

  assert.ok(coreTool);
  assert.deepEqual(coreTool.parameters.required, ['key', 'value']);
  assert.equal(coreTool.parameters.properties.confirmed, undefined);
});

test('memory_save accepts the value argument emitted by model tool calls', async () => {
  ctx = createTestRuntime();
  const user = await createTestUser(ctx.db, { username: 'memory_value_alias' });
  const { resolveAgentId } = require('../../../server/services/agents/manager');
  const { executeTool } = require('../../../server/services/ai/tools');
  const { MemoryManager } = require('../../../server/services/memory/manager');
  const agentId = resolveAgentId(user.userId, null);

  const result = await executeTool('memory_save', {
    value: 'Neo lives in Germany.',
    category: 'user_fact',
  }, {
    userId: user.userId,
    agentId,
  }, {});

  assert.equal(result.success, true);
  assert.equal(result.skipped, undefined);
  const memories = new MemoryManager().listMemories(user.userId, { agentId });
  assert.equal(memories.some((memory) => memory.content === 'Neo lives in Germany.'), true);
});

test('memory_update_core writes directly and validates malformed calls', async () => {
  ctx = createTestRuntime();
  const user = await createTestUser(ctx.db, { username: 'core_memory_tool' });
  const { resolveAgentId } = require('../../../server/services/agents/manager');
  const { executeTool } = require('../../../server/services/ai/tools');
  const { MemoryManager } = require('../../../server/services/memory/manager');
  const agentId = resolveAgentId(user.userId, null);
  const context = { userId: user.userId, agentId };

  const malformed = await executeTool('memory_update_core', {
    value: 'Neo lives in Germany.',
  }, context, {});
  assert.match(malformed.error, /Core memory key must be one of/);

  const result = await executeTool('memory_update_core', {
    key: 'user_profile',
    value: 'Neo lives in Germany.',
  }, context, {});
  assert.equal(result.success, true);
  assert.equal(
    new MemoryManager().getCoreMemory(user.userId, { agentId }).user_profile,
    'Neo lives in Germany.',
  );
});
