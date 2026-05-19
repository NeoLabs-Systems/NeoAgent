'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const { randomUUID } = require('node:crypto');

process.env.OPENAI_API_KEY = '';
process.env.GOOGLE_AI_KEY = '';

const db = require('../../db/database');
const { resolveAgentId } = require('../agents/manager');
const { compactTextPayload } = require('../ai/preModelCompaction');
const { MemoryManager } = require('./manager');
const { MemoryIngestionService, sourceTypesForConnection } = require('./ingestion');
const { buildAssistantFocusSnapshot } = require('../widgets/focus_widget');

function createTestUser() {
  const username = `openhuman-${randomUUID()}`;
  const result = db.prepare(
    'INSERT INTO users (username, password) VALUES (?, ?)',
  ).run(username, 'test');
  const userId = Number(result.lastInsertRowid);
  return {
    userId,
    agentId: resolveAgentId(userId, null),
  };
}

function cleanupUser(userId) {
  db.prepare('DELETE FROM users WHERE id = ?').run(userId);
}

test('pre-model compaction strips noisy HTML and records metrics', () => {
  const input = '<html><style>.x{}</style><body>Read https://example.com/a/really/long/path today.<br>Read https://example.com/a/really/long/path today.</body></html>';
  const result = compactTextPayload(input, { maxChars: 120, maxLines: 5 });

  assert.equal(result.metrics.applied, true);
  assert.ok(result.metrics.strategies.includes('html_to_text'));
  assert.ok(result.metrics.strategies.includes('url_shortening'));
  assert.match(result.text, /example\.com/);
  assert.doesNotMatch(result.text, /<body>/);
});

test('memory ingestion writes typed documents, memory, and materialized views', async () => {
  const { userId, agentId } = createTestUser();
  const memoryManager = new MemoryManager();
  const service = new MemoryIngestionService({ memoryManager, intervalMs: 60_000 });

  try {
    const result = await service.ingestDocuments(userId, [
      {
        externalObjectId: 'thread-123',
        sourceType: 'email',
        normalizedType: 'email',
        title: 'Launch review',
        content: 'The launch review moved to Friday. Alice owns the deck and Bob owns QA.',
        sourceAccount: 'team@example.com',
        salience: 8,
      },
    ], {
      agentId,
      sourceType: 'email',
      providerKey: 'google_workspace',
      sourceAccount: 'team@example.com',
    });

    assert.equal(result.status, 'completed');
    assert.equal(result.documentIds.length, 1);
    assert.equal(result.memoryIds.length, 1);

    const docs = memoryManager.listIngestionDocuments(userId, {
      agentId,
      providerKey: 'google_workspace',
    });
    assert.equal(docs.length, 1);
    assert.equal(docs[0].sourceType, 'email');
    assert.equal(docs[0].sourceAccount, 'team@example.com');

    const changes = memoryManager.listRecentKnowledgeChanges(userId, { agentId });
    assert.ok(changes.some((change) => change.kind === 'document'));

    const views = memoryManager.listKnowledgeViews(userId, { agentId });
    assert.ok(views.some((view) => view.viewType === 'timeline'));
    assert.ok(views.some((view) => view.viewType === 'account'));

    const focus = buildAssistantFocusSnapshot(memoryManager, userId, agentId);
    assert.equal(focus.backgroundAwareness.changedCount > 0, true);
    assert.ok(focus.recentKnowledgeChanges.some((change) => change.title === 'Launch review'));
  } finally {
    cleanupUser(userId);
  }
});

test('integration coverage maps connected apps to durable memory domains', () => {
  assert.deepEqual(sourceTypesForConnection('google_workspace', 'gmail'), ['email']);
  assert.deepEqual(sourceTypesForConnection('github', 'repos'), ['repos', 'tickets']);
  assert.deepEqual(sourceTypesForConnection('spotify', 'spotify'), []);
});
