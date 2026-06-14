'use strict';

const { performance } = require('node:perf_hooks');

function mean(values) {
  if (!values.length) return 0;
  return values.reduce((sum, value) => sum + value, 0) / values.length;
}

function percentile(values, fraction) {
  if (!values.length) return 0;
  const sorted = [...values].sort((left, right) => left - right);
  const index = Math.min(sorted.length - 1, Math.ceil(sorted.length * fraction) - 1);
  return sorted[Math.max(0, index)];
}

function calculateRetrievalMetrics(results, relevantKeys, k) {
  const returned = results.slice(0, k);
  const relevance = returned.map((result) => (
    relevantKeys.has(`memory:${result.id}`)
    || relevantKeys.has(`source:${result.sourceRef?.sourceId || ''}`)
      ? 1
      : 0
  ));
  const relevantRetrieved = relevance.reduce((sum, value) => sum + value, 0);
  const totalRelevant = relevantKeys.size;
  const precisionAtK = returned.length ? relevantRetrieved / returned.length : 0;
  const recallAtK = totalRelevant ? relevantRetrieved / totalRelevant : 0;
  const firstRelevant = relevance.indexOf(1);
  const dcg = relevance.reduce(
    (sum, value, index) => sum + value / Math.log2(index + 2),
    0,
  );
  let idealDcg = 0;
  for (let index = 0; index < Math.min(totalRelevant, returned.length); index += 1) {
    idealDcg += 1 / Math.log2(index + 2);
  }

  return {
    hitAtK: relevantRetrieved > 0 ? 1 : 0,
    precisionAtK,
    recallAtK,
    f1AtK: precisionAtK + recallAtK
      ? (2 * precisionAtK * recallAtK) / (precisionAtK + recallAtK)
      : 0,
    mrr: firstRelevant >= 0 ? 1 / (firstRelevant + 1) : 0,
    ndcg: idealDcg ? dcg / idealDcg : 0,
    relevantRetrieved,
    totalRelevant,
  };
}

function normalizeQuestions(dataset) {
  const questions = Array.isArray(dataset)
    ? dataset
    : dataset?.questions || dataset?.queries;
  if (!Array.isArray(questions) || !questions.length) {
    throw new Error('Dataset must contain a non-empty questions or queries array.');
  }

  return questions.map((question, index) => {
    const query = String(question.query || question.question || '').trim();
    const relevantMemoryIds = Array.isArray(question.relevantMemoryIds)
      ? question.relevantMemoryIds.map(String).filter(Boolean)
      : [];
    const relevantSourceIds = Array.isArray(question.relevantSourceIds)
      ? question.relevantSourceIds.map(String).filter(Boolean)
      : Array.isArray(question.haystackSessionIds)
        ? question.haystackSessionIds.map(String).filter(Boolean)
        : [];
    if (!query) throw new Error(`Question ${index + 1} has no query.`);
    if (!relevantMemoryIds.length && !relevantSourceIds.length) {
      throw new Error(`Question ${index + 1} has no relevant memory or source IDs.`);
    }
    return {
      id: String(question.id || question.questionId || index + 1),
      query,
      category: String(question.category || question.questionType || 'uncategorized'),
      relevantMemoryIds,
      relevantSourceIds,
      validAt: question.validAt || null,
      knownAt: question.knownAt || null,
    };
  });
}

function aggregateEvaluations(evaluations, k) {
  const metricNames = ['hitAtK', 'precisionAtK', 'recallAtK', 'f1AtK', 'mrr', 'ndcg'];
  const retrieval = { k };
  for (const metric of metricNames) {
    retrieval[metric] = mean(evaluations.map((evaluation) => evaluation.metrics[metric]));
  }
  const latencies = evaluations.map((evaluation) => evaluation.latencyMs);
  const contextTokens = evaluations.map((evaluation) => evaluation.contextTokensEstimate);
  const candidateCounts = evaluations.map((evaluation) => evaluation.candidateCount);
  return {
    questions: evaluations.length,
    retrieval,
    latencyMs: {
      mean: mean(latencies),
      median: percentile(latencies, 0.5),
      p95: percentile(latencies, 0.95),
      p99: percentile(latencies, 0.99),
      max: latencies.length ? Math.max(...latencies) : 0,
    },
    contextTokensEstimate: {
      mean: mean(contextTokens),
      p95: percentile(contextTokens, 0.95),
      max: contextTokens.length ? Math.max(...contextTokens) : 0,
    },
    candidateCount: {
      mean: mean(candidateCounts),
      p95: percentile(candidateCounts, 0.95),
      max: candidateCounts.length ? Math.max(...candidateCounts) : 0,
    },
  };
}

async function runRetrievalBenchmark({
  memoryManager,
  userId,
  agentId,
  dataset,
  k = 15,
}) {
  const limit = Math.max(1, Math.min(Number(k) || 15, 50));
  const questions = normalizeQuestions(dataset);
  const evaluations = [];

  for (const question of questions) {
    const relevantKeys = new Set([
      ...question.relevantMemoryIds.map((id) => `memory:${id}`),
      ...question.relevantSourceIds.map((id) => `source:${id}`),
    ]);
    const startedAt = performance.now();
    const results = await memoryManager.recallMemory(userId, question.query, limit, {
      agentId,
      validAt: question.validAt,
      knownAt: question.knownAt,
    });
    const latencyMs = performance.now() - startedAt;
    const contextText = results
      .map((result) => result.summary || result.content || '')
      .join('\n');

    evaluations.push({
      id: question.id,
      category: question.category,
      query: question.query,
      latencyMs,
      contextTokensEstimate: Math.ceil(contextText.length / 4),
      candidateCount: Math.max(
        0,
        ...results.map((result) => Number(result.scoreBreakdown?.candidateCount) || 0),
      ),
      retrievedMemoryIds: results.map((result) => result.id),
      retrievedSourceIds: results
        .map((result) => result.sourceRef?.sourceId)
        .filter(Boolean),
      metrics: calculateRetrievalMetrics(results, relevantKeys, limit),
    });
  }

  const categories = {};
  for (const category of new Set(evaluations.map((evaluation) => evaluation.category))) {
    categories[category] = aggregateEvaluations(
      evaluations.filter((evaluation) => evaluation.category === category),
      limit,
    );
  }

  return {
    generatedAt: new Date().toISOString(),
    dataset: String(dataset?.name || 'unnamed'),
    userId,
    agentId,
    ...aggregateEvaluations(evaluations, limit),
    categories,
    evaluations,
  };
}

module.exports = {
  calculateRetrievalMetrics,
  normalizeQuestions,
  runRetrievalBenchmark,
};
