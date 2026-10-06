'use strict';

const assert = require('node:assert/strict');
const { afterEach, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');
const { extractEntities } = require('../../../server/services/memory/intelligence');

let ctx;

afterEach(() => {
  teardownTestRuntime(ctx);
  ctx = null;
});

test('extractEntities drops date parts, timezones and header labels', () => {
  const entities = extractEntities([
    'Date: Fri, 12 Sep 2025 10:00:00 CEST',
    'From: Example.org <notify@example.org>',
    'The user Sam prefers Flutter. When Sam is home, Home Assistant runs. Moved to Aug 12 in UTC.',
  ].join('\n'));
  const byName = new Map(entities.map((entity) => [entity.name, entity]));

  for (const noise of ['Date', 'Fri', 'Sep', 'CEST', 'Aug', 'UTC', '<notify@example.org']) {
    assert.ok(!byName.has(noise), noise);
  }
  assert.equal(byName.get('notify@example.org')?.kind, 'email');
  assert.equal(byName.get('Example.org')?.kind, 'domain');
  assert.equal(byName.get('Home Assistant')?.inSentence, true);
  assert.equal(byName.get('Sam')?.inSentence, true);
  assert.equal(byName.get('The')?.inSentence, false);
  assert.equal(byName.get('When Sam')?.inSentence, false);
});

test('entity graph hides common sentence-initial words and links co-mentions', async () => {
  ctx = createTestRuntime();
  const db = require('../../../server/db/database');
  const { resolveAgentId } = require('../../../server/services/agents/manager');
  const { MemoryManager } = require('../../../server/services/memory/manager');
  const { pruneNoiseMemoryEntities } = require('../../../lib/schema_migrations');
  const user = await createTestUser(ctx.db, { username: 'memory_entity_graph' });
  const agentId = resolveAgentId(user.userId, null);
  const manager = new MemoryManager();

  await manager.saveMemory(user.userId, 'The team deploys Orbit with Caddy.', 'episodic', 6, { agentId });
  await manager.saveMemory(user.userId, 'Then the team runs Home Assistant on Orbit.', 'episodic', 6, { agentId });
  await manager.saveMemory(user.userId, 'Kestrel reviews the plan and then signs off.', 'episodic', 6, { agentId });
  db.prepare(
    `INSERT INTO memory_entities (id, user_id, agent_id, entity_key, name, kind, mention_count)
     VALUES ('noise', ?, ?, 'date fri', 'Date: Fri', 'identifier', 99)`
  ).run(user.userId, agentId);

  pruneNoiseMemoryEntities(db);

  const graph = manager.getEntityGraph(user.userId, { agentId });
  const names = graph.nodes.map((node) => node.name).sort();
  assert.deepEqual(names, ['Caddy', 'Home Assistant', 'Kestrel', 'Orbit']);
  const byId = new Map(graph.nodes.map((node) => [node.id, node.name]));
  const link = graph.edges.find((edge) => (
    [byId.get(edge.source), byId.get(edge.target)].sort().join(' + ') === 'Caddy + Orbit'
  ));
  assert.equal(link?.weight, 1);

  const orbit = graph.nodes.find((node) => node.name === 'Orbit');
  assert.equal(manager.listEntityMemories(user.userId, orbit.id, { agentId }).length, 2);
});

test('sentence-position backfill marks existing mentions', async () => {
  ctx = createTestRuntime();
  const db = require('../../../server/db/database');
  const { resolveAgentId } = require('../../../server/services/agents/manager');
  const { MemoryManager } = require('../../../server/services/memory/manager');
  const { migrateEntityMentionSentencePosition } = require('../../../lib/schema_migrations');
  const user = await createTestUser(ctx.db, { username: 'memory_entity_backfill' });
  const agentId = resolveAgentId(user.userId, null);
  const manager = new MemoryManager();

  await manager.saveMemory(user.userId, 'Then the team ships Orbit.', 'episodic', 6, { agentId });
  db.prepare('UPDATE memory_entity_mentions SET in_sentence = NULL').run();

  migrateEntityMentionSentencePosition(db);

  const rows = db.prepare(
    `SELECT ent.name, mem.in_sentence FROM memory_entity_mentions mem
     JOIN memory_entities ent ON ent.id = mem.entity_id ORDER BY ent.name`
  ).all();
  assert.deepEqual(rows.map((row) => `${row.name}:${row.in_sentence}`), ['Orbit:1', 'Then:0']);
});
