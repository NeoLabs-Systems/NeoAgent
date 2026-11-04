'use strict';

const { estimateMessageTokens, estimateTokenCount, SUMMARY_PREFIX } = require('../compaction');

const MEMORY_PREFIX = '[Recalled context';
const CATALOG_PREFIX = '[Tool discovery]';

function messageSection(message, index) {
  if (message?.role === 'tool') return 'toolReplayTokens';
  if (message?.role === 'system') {
    const text = typeof message.content === 'string' ? message.content : '';
    if (text.startsWith(MEMORY_PREFIX)) return 'recalledMemoryTokens';
    if (text.startsWith(CATALOG_PREFIX)) return 'toolCatalogTokens';
    if (text.startsWith(SUMMARY_PREFIX)) return 'historyTokens';
    if (index <= 1) return 'systemPromptTokens';
    return 'runtimeNoteTokens';
  }
  return 'historyTokens';
}

// Where a request's context goes. Estimates, not billing: they exist to show
// which section grew, and to compare one harness change against another.
function estimatePromptMetrics(messages = [], tools = []) {
  const metrics = {
    systemPromptTokens: 0,
    toolSchemaTokens: estimateTokenCount([], tools),
    toolCatalogTokens: 0,
    historyTokens: 0,
    recalledMemoryTokens: 0,
    runtimeNoteTokens: 0,
    toolReplayTokens: 0,
    totalEstimatedTokens: 0,
  };
  messages.forEach((message, index) => {
    metrics[messageSection(message, index)] += estimateMessageTokens(message);
  });
  metrics.totalEstimatedTokens = Object.entries(metrics)
    .filter(([key]) => key !== 'totalEstimatedTokens')
    .reduce((total, [, value]) => total + value, 0);
  return metrics;
}

function mergePromptMetrics(summary = {}, metrics, iteration, toolCount) {
  return {
    iterationsObserved: Math.max(summary.iterationsObserved || 0, iteration),
    toolCount,
    maxEstimatedTokens: Math.max(summary.maxEstimatedTokens || 0, metrics.totalEstimatedTokens),
    maxSystemPromptTokens: Math.max(summary.maxSystemPromptTokens || 0, metrics.systemPromptTokens),
    maxToolSchemaTokens: Math.max(summary.maxToolSchemaTokens || 0, metrics.toolSchemaTokens),
    maxHistoryTokens: Math.max(summary.maxHistoryTokens || 0, metrics.historyTokens),
    maxRecalledMemoryTokens: Math.max(summary.maxRecalledMemoryTokens || 0, metrics.recalledMemoryTokens),
    maxToolReplayTokens: Math.max(summary.maxToolReplayTokens || 0, metrics.toolReplayTokens),
    lastEstimate: metrics,
  };
}

module.exports = {
  estimatePromptMetrics,
  mergePromptMetrics,
};
