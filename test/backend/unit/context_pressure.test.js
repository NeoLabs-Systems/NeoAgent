'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  SUMMARY_PREFIX,
  estimateTokenCount,
  selectTurnSafeCut,
} = require('../../../server/services/ai/compaction');
const {
  createContextPressureController,
  isContextOverflowError,
} = require('../../../server/services/ai/runtime/context/context_pressure');

function oversizedHistory() {
  return [
    { role: 'system', content: 'Permanent system policy.' },
    { role: 'user', content: `old request ${'a'.repeat(18_000)}` },
    {
      role: 'assistant',
      content: 'checking',
      tool_calls: [{
        id: 'call-1',
        type: 'function',
        function: { name: 'inspect', arguments: JSON.stringify({ data: 'b'.repeat(8_000) }) },
      }],
    },
    { role: 'tool', tool_call_id: 'call-1', name: 'inspect', content: 'c'.repeat(16_000) },
    { role: 'assistant', content: 'Old turn complete.' },
    { role: 'user', content: 'Newest completed user turn.' },
    { role: 'assistant', content: 'Newest completed answer.' },
    { role: 'user', content: 'Current unfinished turn.' },
  ];
}

test('context pressure compacts a few oversized turns without splitting tool pairs', async () => {
  const messages = oversizedHistory();
  const summaryInputs = [];
  const controller = createContextPressureController({
    summarize: async (summaryMessages) => {
      summaryInputs.push(summaryMessages);
      return 'The older request was inspected and completed.';
    },
  });
  const provider = { getContextWindow: () => 12_000 };
  const tools = [{ name: 'inspect', parameters: { type: 'object', properties: {} } }];
  const result = await controller.prepare({
    provider,
    model: 'small-context',
    messages,
    fixedMessages: [{ role: 'system', content: 'Durable contract and evidence.' }],
    tools,
    maxOutputTokens: 1_000,
  });

  assert.equal(result.changed, true);
  assert.ok(summaryInputs.length >= 1);
  const combinedSummaryInput = summaryInputs.map((input) => input[1].content).join('\n');
  assert.match(combinedSummaryInput, /tool inspect/);
  assert.match(combinedSummaryInput, /Old turn complete/);
  assert.equal(result.messages[0].content, 'Permanent system policy.');
  assert.ok(result.messages.some((message) => String(message.content).startsWith(SUMMARY_PREFIX)));
  assert.ok(result.messages.some((message) => message.content === 'Newest completed user turn.'));
  assert.ok(result.messages.some((message) => message.content === 'Current unfinished turn.'));
  assert.equal(result.messages.some((message) => message.tool_call_id === 'call-1'), false);
  assert.ok(result.afterTokens <= result.budget.targetTokens);
  assert.ok(estimateTokenCount([...result.messages], tools) < estimateTokenCount(messages, tools));
});

test('turn-safe selection preserves both the active and newest completed turns', () => {
  const cut = selectTurnSafeCut({
    messages: oversizedHistory(),
    targetTokens: 7_000,
  });
  assert.equal(cut.compactable, true);
  assert.equal(cut.retained[0].content, 'Newest completed user turn.');
  assert.equal(cut.retained.at(-1).content, 'Current unfinished turn.');
  const toolCallIndex = cut.compacted.findIndex((message) => message.tool_calls?.length);
  const toolResultIndex = cut.compacted.findIndex((message) => message.tool_call_id === 'call-1');
  assert.ok(toolCallIndex >= 0 && toolResultIndex === toolCallIndex + 1);
});

test('previous summaries are folded into the next summary', async () => {
  const messages = oversizedHistory();
  messages.splice(1, 0, { role: 'system', content: `${SUMMARY_PREFIX}\nEarlier compacted facts.` });
  const summaryPrompts = [];
  const controller = createContextPressureController({
    summarize: async (summaryMessages) => {
      summaryPrompts.push(summaryMessages[1].content);
      return 'Merged facts.';
    },
  });
  const result = await controller.prepare({
    provider: { getContextWindow: () => 12_000 },
    model: 'small-context',
    messages,
    maxOutputTokens: 1_000,
  });
  assert.equal(result.changed, true);
  assert.match(summaryPrompts.join('\n'), /Earlier compacted facts/);
  assert.equal(result.messages.filter((message) => String(message.content).startsWith(SUMMARY_PREFIX)).length, 1);
});

test('overflow classification and recovery budget do not catch unrelated failures', () => {
  assert.equal(isContextOverflowError(new Error('maximum context length exceeded')), true);
  assert.equal(isContextOverflowError(Object.assign(new Error('rate limited'), { code: 'RATE_LIMIT' })), false);
  const controller = createContextPressureController();
  assert.equal(controller.claimOverflowRecovery(), true);
  assert.equal(controller.claimOverflowRecovery(), true);
  assert.equal(controller.claimOverflowRecovery(), false);
});

test('compaction propagates summarizer cancellation unchanged', async () => {
  const abortReason = new Error('compaction cancelled by caller');
  abortReason.name = 'AbortError';
  const controller = createContextPressureController({
    summarize: async () => { throw abortReason; },
  });
  await assert.rejects(
    controller.prepare({
      provider: { getContextWindow: () => 12_000 },
      model: 'small-context',
      messages: oversizedHistory(),
      maxOutputTokens: 1_000,
      force: true,
    }),
    (error) => error === abortReason,
  );
});

test('irreducible current context is reported instead of splitting retained turns', async () => {
  const messages = oversizedHistory();
  messages[5].content += 'x'.repeat(20_000);
  messages[7].content += 'y'.repeat(20_000);
  const controller = createContextPressureController({ summarize: async () => 'summary' });
  const result = await controller.prepare({
    provider: { getContextWindow: () => 8_000 },
    model: 'tiny',
    messages,
    maxOutputTokens: 1_000,
    force: true,
  });
  assert.equal(result.changed, false);
  assert.equal(result.irreducible, true);
  assert.match(result.reason, /safe_cut|complete_historical_turn/);
});
