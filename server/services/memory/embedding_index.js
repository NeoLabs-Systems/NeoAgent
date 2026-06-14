'use strict';

const { deserializeEmbedding } = require('./embeddings');

const BAND_COUNT = 10;
const BITS_PER_BAND = 14;
const INDEX_VERSION = 3;
const DEFAULT_CANDIDATE_LIMIT = 600;

function sampledCoordinate(dimension, bandIndex, bitIndex) {
  let value = Math.imul(bandIndex + 1, 0x9e3779b1) ^ Math.imul(bitIndex + 1, 0x85ebca6b);
  value ^= value >>> 16;
  value = Math.imul(value, 0x7feb352d);
  value ^= value >>> 15;
  return (value >>> 0) % dimension;
}

function createEmbeddingBands(vector) {
  if (!vector || !Number.isInteger(vector.length) || vector.length < BITS_PER_BAND) {
    return [];
  }

  const bands = [];
  for (let bandIndex = 0; bandIndex < BAND_COUNT; bandIndex += 1) {
    let bandValue = 0;
    for (let bitIndex = 0; bitIndex < BITS_PER_BAND; bitIndex += 1) {
      const coordinate = sampledCoordinate(vector.length, bandIndex, bitIndex);
      if (Number(vector[coordinate]) >= 0) {
        bandValue |= 1 << bitIndex;
      }
    }
    bands.push({
      bandIndex,
      bandValue,
      dimension: vector.length,
    });
  }
  return bands;
}

function replaceMemoryEmbeddingIndex(db, {
  memoryId,
  userId,
  agentId,
  embedding,
}) {
  const vector = typeof embedding === 'string'
    ? deserializeEmbedding(embedding)
    : embedding;
  const bands = createEmbeddingBands(vector);

  const replace = db.transaction(() => {
    db.prepare('DELETE FROM memory_embedding_bands WHERE memory_id = ?').run(memoryId);
    if (!bands.length) return;
    const insert = db.prepare(
      `INSERT INTO memory_embedding_bands (
         memory_id, user_id, agent_id, dimension, index_version, band_index, band_value, updated_at
       ) VALUES (?, ?, ?, ?, ?, ?, ?, datetime('now'))`
    );
    for (const band of bands) {
      insert.run(
        memoryId,
        userId,
        agentId || '',
        band.dimension,
        INDEX_VERSION,
        band.bandIndex,
        band.bandValue,
      );
    }
  });
  replace();
  return bands.length;
}

function buildBandProbes(vector) {
  const probesByBand = [];
  for (const band of createEmbeddingBands(vector)) {
    const values = [band.bandValue];
    for (let bitIndex = 0; bitIndex < BITS_PER_BAND; bitIndex += 1) {
      values.push(band.bandValue ^ (1 << bitIndex));
      for (let secondBit = bitIndex + 1; secondBit < BITS_PER_BAND; secondBit += 1) {
        values.push(band.bandValue ^ (1 << bitIndex) ^ (1 << secondBit));
      }
    }
    probesByBand.push({
      bandIndex: band.bandIndex,
      values,
    });
  }
  return probesByBand;
}

function findEmbeddingCandidates(db, {
  userId,
  agentId,
  embedding,
  limit = DEFAULT_CANDIDATE_LIMIT,
}) {
  const vector = typeof embedding === 'string'
    ? deserializeEmbedding(embedding)
    : embedding;
  const probesByBand = buildBandProbes(vector);
  if (!probesByBand.length) return [];

  const matches = new Map();
  for (const band of probesByBand) {
    const placeholders = band.values.map(() => '?').join(', ');
    const rows = db.prepare(
      `SELECT memory_id
       FROM memory_embedding_bands
       WHERE user_id = ?
         AND agent_id = ?
         AND dimension = ?
         AND index_version = ?
         AND band_index = ?
         AND band_value IN (${placeholders})`
    ).all(
      userId,
      agentId || '',
      vector.length,
      INDEX_VERSION,
      band.bandIndex,
      ...band.values,
    );
    for (const row of rows) {
      matches.set(row.memory_id, (matches.get(row.memory_id) || 0) + 1);
    }
  }

  return [...matches.entries()]
    .sort((left, right) => right[1] - left[1])
    .slice(0, Math.max(1, Math.min(Number(limit) || DEFAULT_CANDIDATE_LIMIT, 2000)))
    .map(([memoryId, bandMatches]) => ({
      memory_id: memoryId,
      band_matches: bandMatches,
    }));
}

function backfillEmbeddingIndex(db, { limit = 500 } = {}) {
  const rows = db.prepare(
    `SELECT m.id, m.user_id, m.agent_id, m.embedding
     FROM memories m
     LEFT JOIN memory_embedding_bands idx
       ON idx.memory_id = m.id AND idx.index_version = ?
     WHERE m.archived = 0
       AND m.embedding IS NOT NULL
       AND idx.memory_id IS NULL
     ORDER BY m.updated_at DESC
     LIMIT ?`
  ).all(
    INDEX_VERSION,
    Math.max(1, Math.min(Number(limit) || 500, 5000)),
  );

  for (const row of rows) {
    replaceMemoryEmbeddingIndex(db, {
      memoryId: row.id,
      userId: row.user_id,
      agentId: row.agent_id,
      embedding: row.embedding,
    });
  }
  return rows.length;
}

module.exports = {
  BAND_COUNT,
  BITS_PER_BAND,
  INDEX_VERSION,
  backfillEmbeddingIndex,
  createEmbeddingBands,
  findEmbeddingCandidates,
  replaceMemoryEmbeddingIndex,
};
