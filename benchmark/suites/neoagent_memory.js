'use strict';

const { calculateRetrievalMetrics } = require('../../server/services/memory/evaluation');
const { readJson } = require('./shared');

async function seedMemories(client, memories) {
  const saved = [];
  for (const memory of memories) {
    const response = await client.createMemory({
      content: memory.content,
      category: memory.category || 'semantic',
      importance: memory.importance || 5,
      sourceRef: memory.sourceRef || {
        sourceType: 'benchmark',
        sourceId: memory.id,
        sourceLabel: 'NeoAgent benchmark',
      },
      metadata: {
        benchmarkId: memory.id,
      },
    });
    saved.push({
      ...memory,
      savedId: response.id,
    });
  }
  return saved;
}

function buildRelevantKeys(savedMemories, relevantMemoryIds) {
  const keys = new Set();
  for (const memoryId of relevantMemoryIds || []) {
    const saved = savedMemories.find((entry) => entry.id === memoryId);
    if (saved?.savedId) {
      keys.add(`memory:${saved.savedId}`);
    }
  }
  return keys;
}

function buildMemorySuite(config) {
  return {
    id: 'neoagent_memory_retrieval',
    label: 'NeoAgent Memory Retrieval',
    benchmarkType: 'first_party',
    modelDriven: false,

    async preflight() {
      const dataset = await readJson(config.suitePaths.neoagent_memory_retrieval.datasetPath);
      return {
        runnable: true,
        dataset,
      };
    },

    async run(context, _model, preflight) {
      const dataset = preflight.dataset;
      const savedMemories = await seedMemories(context.client, dataset.memories || []);
      const limit = Number(dataset.k || 5);
      const results = [];

      for (const query of dataset.queries || []) {
        const startedAt = Date.now();
        const recallResults = await context.client.recallMemories(query.query, limit);
        const relevantKeys = buildRelevantKeys(savedMemories, query.relevantMemoryIds);
        const metrics = calculateRetrievalMetrics(recallResults, relevantKeys, limit);
        const passed = metrics.hitAtK === 1;

        results.push({
          suiteId: this.id,
          suiteLabel: this.label,
          benchmarkType: this.benchmarkType,
          modelDriven: false,
          caseId: query.id,
          status: passed ? 'passed' : 'failed',
          score: Number(metrics.ndcg || metrics.hitAtK || 0),
          reason: passed ? '' : 'No relevant memory was retrieved within the top-k results.',
          provider: null,
          modelId: null,
          priceTier: null,
          latencyMs: Date.now() - startedAt,
          tokenUsage: null,
          estimatedCostUsd: null,
          finalResponse: JSON.stringify({
            retrievedIds: recallResults.map((item) => item.id),
            metrics,
          }),
          runId: null,
          artifactRefs: [],
          requiredSignalCoverage: null,
          metadata: {
            category: query.category,
            metrics,
            retrievedMemoryIds: recallResults.map((item) => item.id),
          },
        });
      }

      return results;
    },
  };
}

module.exports = {
  buildMemorySuite,
};
