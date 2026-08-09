'use strict';

const {
  applyCompaction,
  buildSummaryMessagesFromSource,
  estimateTokenCount,
  selectTurnSafeCut,
  serializeForSummary,
} = require('../../compaction');

const DEFAULT_MAX_OUTPUT_TOKENS = 16_384;
const MAX_OVERFLOW_RECOVERIES = 2;

function contextWindowFor(provider, model) {
  const raw = Number(provider?.getContextWindow?.(model));
  return Number.isFinite(raw) && raw > 0 ? Math.floor(raw) : 128_000;
}

function contextBudgetFor(provider, model, maxOutputTokens = DEFAULT_MAX_OUTPUT_TOKENS) {
  const contextWindow = contextWindowFor(provider, model);
  const requestedOutput = Math.max(1, Number(maxOutputTokens) || DEFAULT_MAX_OUTPUT_TOKENS);
  const safetyReserve = Math.max(2_048, Math.min(32_768, Math.ceil(contextWindow * 0.05)));
  const outputReserve = Math.min(
    requestedOutput,
    Math.max(1, contextWindow - safetyReserve - 1),
  );
  const inputBudget = Math.max(1, contextWindow - outputReserve - safetyReserve);
  return {
    contextWindow,
    outputReserve,
    safetyReserve,
    inputBudget,
    targetTokens: Math.max(1, Math.floor(inputBudget * 0.75)),
  };
}

function isContextOverflowError(error) {
  const code = String(error?.code || error?.type || '').toLowerCase();
  const message = String(error?.message || error || '').toLowerCase();
  return code.includes('context_length')
    || code.includes('context_window')
    || code === 'context_overflow'
    || /maximum context|context length|context window|prompt is too long|too many tokens/.test(message);
}

function createContextPressureController({ summarize, onEvent } = {}) {
  let overflowRecoveries = 0;

  async function prepare({
    provider,
    model,
    messages = [],
    fixedMessages = [],
    tools = [],
    maxOutputTokens,
    force = false,
    reason = 'threshold',
  } = {}) {
    const budget = contextBudgetFor(provider, model, maxOutputTokens);
    const beforeTokens = estimateTokenCount([...messages, ...fixedMessages], tools);
    if (!force && beforeTokens <= budget.inputBudget) {
      return { messages, changed: false, beforeTokens, afterTokens: beforeTokens, budget };
    }

    onEvent?.('pressure', {
      reason,
      forced: force,
      estimated_tokens: beforeTokens,
      ...budget,
    });
    const cut = selectTurnSafeCut({
      messages,
      fixedMessages,
      tools,
      targetTokens: budget.targetTokens,
    });
    if (!cut.compactable) {
      return {
        messages,
        changed: false,
        irreducible: true,
        reason: cut.reason,
        beforeTokens,
        afterTokens: beforeTokens,
        budget,
      };
    }
    if (typeof summarize !== 'function') {
      throw new Error('Context compaction requires a summarizer.');
    }

    const summaryBudget = contextBudgetFor(provider, model, 1_600);
    const source = serializeForSummary(cut.compacted);
    let summary = cut.previousSummary;
    let offset = 0;
    while (offset < source.length) {
      const summaryTokens = estimateTokenCount(summary
        ? [{ role: 'user', content: summary }]
        : []);
      let chunkChars = Math.max(
        1_000,
        Math.floor(Math.max(250, summaryBudget.targetTokens - summaryTokens - 350) * 4),
      );
      let summaryMessages;
      do {
        summaryMessages = buildSummaryMessagesFromSource({
          previousSummary: summary,
          source: source.slice(offset, offset + chunkChars),
        });
        if (estimateTokenCount(summaryMessages) <= summaryBudget.inputBudget) break;
        chunkChars = Math.floor(chunkChars * 0.75);
      } while (chunkChars >= 1_000);
      if (estimateTokenCount(summaryMessages) > summaryBudget.inputBudget) {
        throw new Error('A historical compaction chunk cannot fit the summarizer context.');
      }
      summary = await summarize(summaryMessages);
      offset += chunkChars;
    }
    const compactedMessages = applyCompaction(cut, summary);
    const afterTokens = estimateTokenCount([...compactedMessages, ...fixedMessages], tools);
    onEvent?.('compacted', {
      reason,
      forced: force,
      before_tokens: beforeTokens,
      after_tokens: afterTokens,
      compacted_messages: cut.compacted.length,
      ...budget,
    });
    return {
      messages: compactedMessages,
      changed: true,
      beforeTokens,
      afterTokens,
      budget,
    };
  }

  function claimOverflowRecovery() {
    if (overflowRecoveries >= MAX_OVERFLOW_RECOVERIES) return false;
    overflowRecoveries += 1;
    return true;
  }

  return {
    prepare,
    claimOverflowRecovery,
    get overflowRecoveries() {
      return overflowRecoveries;
    },
  };
}

module.exports = {
  DEFAULT_MAX_OUTPUT_TOKENS,
  MAX_OVERFLOW_RECOVERIES,
  contextBudgetFor,
  contextWindowFor,
  createContextPressureController,
  isContextOverflowError,
};
