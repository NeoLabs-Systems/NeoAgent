'use strict';

const assert = require('node:assert/strict');
const { after, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

const runtime = createTestRuntime();
after(() => teardownTestRuntime(runtime));

const { sameEmbeddingSpace } = require('../../../server/services/memory/embeddings');
const { refreshMemoryEmbeddings } = require('../../../server/services/memory/embedding_refresh');

test('vectors are comparable only in the space their provider declared, never by a similar name', () => {
  const pinned = { provider: 'neorouter', model: 'gemini-embedding-001', dimensions: 3072 };
  assert.equal(sameEmbeddingSpace(pinned, { ...pinned }), true);
  assert.equal(sameEmbeddingSpace(pinned, { ...pinned, model: 'google-2/gemini-embedding-001' }), false,
    'a host name is not the space: without the pin it only matches itself');
  assert.equal(sameEmbeddingSpace(pinned, { ...pinned, dimensions: 768 }), false, 'another size');
  assert.equal(sameEmbeddingSpace(pinned, { ...pinned, provider: 'google' }), false, 'another provider declares its own spaces');
  assert.equal(sameEmbeddingSpace({ provider: 'legacy_unknown', model: null, dimensions: 1536 }, { provider: 'legacy_unknown', model: null, dimensions: 1536 }), false);
});

test('memories without a comparable vector are embedded again, newest first, once each', async () => {
  const user = await createTestUser(runtime.db, { username: 'refresh_owner' });
  const insert = runtime.db.prepare(
    `INSERT INTO memories (id, user_id, category, content, embedding, embedding_model, embedding_dimensions, embedded_at, updated_at)
     VALUES (?, ?, 'facts', ?, ?, ?, ?, ?, ?)`,
  );
  const vector = (value) => JSON.stringify(Array.from({ length: 4 }, () => value));
  insert.run('current', user.userId, 'Current model memory', vector(1), 'model-a', 4, '2026-11-06 10:00:00', '2026-11-06 10:00:00');
  insert.run('missing', user.userId, 'Saved while embedding failed', null, null, null, null, '2026-11-05 10:00:00');
  insert.run('old-model', user.userId, 'Embedded by an older model', vector(1), 'model-b', 4, '2026-10-01 10:00:00', '2026-10-01 10:00:00');
  insert.run('same-model', user.userId, 'Same model, same provider', vector(1), 'model-a', 4, '2026-11-01 10:00:00', '2026-11-01 10:00:00');
  runtime.db.prepare("UPDATE memories SET embedding_provider = 'neorouter' WHERE embedding IS NOT NULL").run();

  const embedded = [];
  const embed = async (content) => {
    embedded.push(content);
    return { vector: new Float32Array([0.1, 0.2, 0.3, 0.4]), provider: 'neorouter', model: 'model-a', dimensions: 4 };
  };
  const resolveProvider = async () => null;

  assert.equal(await refreshMemoryEmbeddings({ resolveProvider, embed }), 1);
  assert.deepEqual(embedded, ['Saved while embedding failed'], 'missing vectors first');
  assert.equal(await refreshMemoryEmbeddings({ resolveProvider, embed }), 1);
  assert.deepEqual(embedded.slice(1), ['Embedded by an older model'], 'then other models');
  assert.equal(await refreshMemoryEmbeddings({ resolveProvider, embed }), 0, 'nothing left');

  const row = runtime.db.prepare('SELECT embedding_model, embedding_dimensions FROM memories WHERE id = ?').get('old-model');
  assert.deepEqual(row, { embedding_model: 'model-a', embedding_dimensions: 4 });
});

test('a provider that gives nothing makes the batch stop and report it', async () => {
  const user = await createTestUser(runtime.db, { username: 'refresh_failing' });
  runtime.db.prepare(
    `INSERT INTO memories (id, user_id, category, content, updated_at) VALUES ('failing', ?, 'facts', 'Still unembedded', '2026-11-06 11:00:00')`,
  ).run(user.userId);
  assert.equal(await refreshMemoryEmbeddings({ resolveProvider: async () => null, embed: async () => null }), null);
  const row = runtime.db.prepare('SELECT embedding FROM memories WHERE id = ?').get('failing');
  assert.equal(row.embedding, null);
});
