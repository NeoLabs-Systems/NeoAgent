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

test('memory_save accepts reusable procedural memories', async () => {
  ctx = createTestRuntime();
  const user = await createTestUser(ctx.db, { username: 'memory_procedural_category' });
  const { resolveAgentId } = require('../../../server/services/agents/manager');
  const { executeTool } = require('../../../server/services/ai/tools');
  const { MemoryManager } = require('../../../server/services/memory/manager');
  const agentId = resolveAgentId(user.userId, null);

  const result = await executeTool('memory_save', {
    content: 'To publish NeoAgent, first check semantic-release configuration, then run the release checklist.',
    category: 'procedural',
    importance: 6,
  }, {
    userId: user.userId,
    agentId,
  }, {});

  assert.equal(result.success, true);
  const memories = new MemoryManager().listMemories(user.userId, { agentId, category: 'procedural' });
  assert.equal(memories.length, 1);
  assert.equal(memories[0].category, 'procedural');
});

test('archiveWeakMemories archives stale weak memories but leaves pinned memories active', async () => {
  ctx = createTestRuntime();
  const user = await createTestUser(ctx.db, { username: 'memory_retention_archive' });
  const db = require('../../../server/db/database');
  const { resolveAgentId } = require('../../../server/services/agents/manager');
  const { MemoryManager } = require('../../../server/services/memory/manager');
  const agentId = resolveAgentId(user.userId, null);
  const manager = new MemoryManager();

  const weakId = await manager.saveMemory(user.userId, 'Temporary status: old noisy detail.', 'episodic', 2, { agentId });
  const pinnedId = await manager.saveMemory(user.userId, 'Pinned preference should stay available.', 'episodic', 2, { agentId });
  db.prepare(
    `UPDATE memories
     SET memory_strength = 0.05,
         updated_at = datetime('now', '-120 days'),
         created_at = datetime('now', '-120 days')
     WHERE id IN (?, ?)`
  ).run(weakId, pinnedId);
  db.prepare('UPDATE memories SET pinned = 1 WHERE id = ?').run(pinnedId);

  const result = manager.archiveWeakMemories(user.userId, {
    agentId,
    minAgeDays: 1,
    strengthThreshold: 0.2,
  });

  assert.equal(result.archived, 1);
  assert.equal(db.prepare('SELECT archived FROM memories WHERE id = ?').get(weakId).archived, 1);
  assert.equal(db.prepare('SELECT archived FROM memories WHERE id = ?').get(pinnedId).archived, 0);
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

test('recall injects the remembered statements without storage metadata', async () => {
  ctx = createTestRuntime();
  const user = await createTestUser(ctx.db, { username: 'memory_recall_shape' });
  const { MemoryManager } = require('../../../server/services/memory/manager');
  const manager = new MemoryManager();

  const message = await manager.buildRecallMessage(user.userId, 'welches mail tool nutzt neo?', {
    recalled: [
      {
        id: 'mem-1',
        content: 'Neo prefers the Gmail integration for email, never neo.eu.com.',
        category: 'preferences',
        entities: [{ name: 'Neo' }, { name: 'Gmail' }],
        factContext: [{
          subject: 'Neo',
          predicate: 'prefers email tool',
          previous: { object: 'neo.eu.com' },
        }],
        sources: [{ title: 'Chat mit Neo', charStart: 100, charEnd: 400 }],
      },
    ],
  });

  assert.match(message, /- Neo prefers the Gmail integration for email, never neo\.eu\.com\.\n?/);
  assert.doesNotMatch(message, /\[preferences\]/);
  assert.doesNotMatch(message, /entities:/);
  assert.doesNotMatch(message, /version history/);
  assert.doesNotMatch(message, /\[source:/);
});
