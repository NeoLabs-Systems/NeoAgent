'use strict';

const db = require('../../db/database');
const { getEmbeddingWithMetadata, sameEmbeddingSpace, serializeEmbedding } = require('./embeddings');
const { replaceMemoryEmbeddingIndex } = require('./embedding_index');

// A memory saved while embedding was failing, or embedded by a model no longer in
// use, cannot be found by meaning: its vector is missing or cannot be compared.
// These are embedded again a few at a time, newest first, until none are left.
const BATCH_SIZE = 20;
// Tried once per process: a router that answers with different models in turn
// must not keep the same memories cycling between them.
const attempted = new Set();

function memoriesToEmbed(limit) {
  const missing = db.prepare(
    `SELECT id, user_id, agent_id, content FROM memories
     WHERE archived = 0 AND embedding IS NULL AND trim(content) != ''
     ORDER BY updated_at DESC`,
  ).all().filter((row) => !attempted.has(row.id)).slice(0, limit);
  if (missing.length) return missing;

  // The model a user's newest memory was embedded with is the one their queries use.
  const current = new Map(db.prepare(
    `SELECT user_id, embedding_provider, embedding_model, embedding_dimensions, MAX(embedded_at)
     FROM memories WHERE embedded_at IS NOT NULL GROUP BY user_id`,
  ).all().map((row) => [row.user_id, {
    provider: row.embedding_provider,
    model: row.embedding_model,
    dimensions: row.embedding_dimensions,
  }]));
  const embedded = db.prepare(
    `SELECT id, user_id, agent_id, content, embedding_provider, embedding_model, embedding_dimensions FROM memories
     WHERE archived = 0 AND embedding IS NOT NULL AND trim(content) != ''
     ORDER BY updated_at DESC`,
  ).all();
  return embedded
    .filter((row) => !attempted.has(row.id) && current.has(row.user_id) && !sameEmbeddingSpace(
      { provider: row.embedding_provider, model: row.embedding_model, dimensions: row.embedding_dimensions },
      current.get(row.user_id),
    ))
    .slice(0, limit);
}

/**
 * Embeds one batch. Returns how many were embedded, or null when the provider
 * gave nothing, so the caller can wait before asking it again.
 */
async function refreshMemoryEmbeddings({ resolveProvider, embed = getEmbeddingWithMetadata, limit = BATCH_SIZE } = {}) {
  const rows = memoriesToEmbed(limit);
  let embedded = 0;
  for (const row of rows) {
    attempted.add(row.id);
    const provider = await resolveProvider(row.user_id, row.agent_id);
    const result = await embed(row.content, provider, {
      inputType: 'document',
      userId: row.user_id,
      agentId: row.agent_id,
    }).catch(() => null);
    if (!result?.vector) {
      attempted.delete(row.id);
      return embedded || null;
    }
    const serialized = serializeEmbedding(result.vector);
    db.prepare(
      `UPDATE memories
       SET embedding = ?, embedding_provider = ?, embedding_model = ?, embedding_dimensions = ?,
           embedded_at = datetime('now')
       WHERE id = ?`,
    ).run(serialized, result.provider, result.model, result.dimensions || result.vector.length, row.id);
    replaceMemoryEmbeddingIndex(db, {
      memoryId: row.id,
      userId: row.user_id,
      agentId: row.agent_id,
      embedding: serialized,
    });
    embedded += 1;
  }
  return embedded;
}

module.exports = { refreshMemoryEmbeddings };
