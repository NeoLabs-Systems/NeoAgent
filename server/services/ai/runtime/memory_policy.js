'use strict';

const { estimateTokenCount } = require('../compaction');

// Relevance decides what memory enters context, independent of request language.
const DEFAULT_MIN_SIGNAL = 0.35;
// A match far weaker than the best one is noise next to it.
const RELATIVE_FLOOR = 0.7;
// The most of a model's input budget recalled memory may take.
const MEMORY_BUDGET_SHARE = 0.08;

function decideMemoryRecall(request) {
  const text = String(request || '').trim();
  if (!/[\p{L}\p{N}]/u.test(text)) return { recall: false, trigger: 'no_content', minSignal: 0 };
  return { recall: true, trigger: 'default', minSignal: DEFAULT_MIN_SIGNAL };
}

// The strongest direct evidence a memory matched this query. Its final score
// also carries importance and freshness, which say nothing about relevance.
function directSignal(memory) {
  const breakdown = memory?.scoreBreakdown;
  if (!breakdown) return null;
  return Math.max(
    Number(breakdown.semantic) || 0,
    Number(breakdown.lexical) || 0,
    Number(breakdown.entity) || 0,
    Number(breakdown.relation) || 0,
  );
}

function filterRecalled(recalled = [], { minSignal = 0, relativeFloor = RELATIVE_FLOOR } = {}) {
  const scored = recalled.map((memory) => ({ memory, signal: directSignal(memory) }));
  const best = Math.max(0, ...scored.map((entry) => entry.signal ?? 0));
  const kept = scored
    .filter(({ signal }) => signal === null || (signal >= minSignal && signal >= best * relativeFloor))
    .map(({ memory }) => memory);
  return kept;
}

function memoryTokens(message) {
  return message ? estimateTokenCount([{ role: 'system', content: message }]) : 0;
}

function exceedsMemoryBudget(message, inputBudget) {
  return memoryTokens(message) > Math.max(120, Math.floor(Number(inputBudget) * MEMORY_BUDGET_SHARE));
}

module.exports = {
  decideMemoryRecall,
  exceedsMemoryBudget,
  filterRecalled,
  memoryTokens,
};
