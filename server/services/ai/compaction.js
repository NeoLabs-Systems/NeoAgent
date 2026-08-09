'use strict';

const SUMMARY_PREFIX = '[Previous conversation summary]';

function textContent(value) {
  if (typeof value === 'string') return value;
  if (Array.isArray(value)) {
    return value.map((part) => {
      if (typeof part === 'string') return part;
      return part?.text || part?.content || JSON.stringify(part || {});
    }).join('\n');
  }
  return value == null ? '' : JSON.stringify(value);
}

function estimateValueTokens(value) {
  if (value == null) return 0;
  const serialized = typeof value === 'string' ? value : JSON.stringify(value);
  return Math.ceil(Buffer.byteLength(serialized, 'utf8') / 4);
}

function estimateMessageTokens(message = {}) {
  return 4
    + estimateValueTokens(message.role)
    + estimateValueTokens(message.name)
    + estimateValueTokens(message.content)
    + estimateValueTokens(message.tool_calls)
    + estimateValueTokens(message.tool_call_id);
}

function estimateTokenCount(messages = [], tools = []) {
  const messageTokens = (Array.isArray(messages) ? messages : [])
    .reduce((total, message) => total + estimateMessageTokens(message), 0);
  return messageTokens + estimateValueTokens(tools);
}

function isSummaryMessage(message) {
  return message?.role === 'system'
    && String(message.content || '').startsWith(SUMMARY_PREFIX);
}

function splitLeadingSystemMessages(messages = []) {
  const leading = [];
  let index = 0;
  while (index < messages.length && messages[index]?.role === 'system') {
    if (!isSummaryMessage(messages[index])) leading.push(messages[index]);
    index += 1;
  }
  const previousSummary = messages.find(isSummaryMessage);
  return {
    leading,
    body: messages.slice(index).filter((message) => !isSummaryMessage(message)),
    previousSummary: previousSummary
      ? String(previousSummary.content || '').slice(SUMMARY_PREFIX.length).trim()
      : '',
  };
}

function findUserTurnStarts(messages = []) {
  const starts = [];
  for (let index = 0; index < messages.length; index += 1) {
    if (messages[index]?.role === 'user') starts.push(index);
  }
  return starts;
}

function selectTurnSafeCut({
  messages,
  fixedMessages = [],
  tools = [],
  targetTokens,
  summaryReserveTokens = 1800,
} = {}) {
  const { leading, body, previousSummary } = splitLeadingSystemMessages(messages);
  const turnStarts = findUserTurnStarts(body);
  if (turnStarts.length < 3) {
    return { compactable: false, reason: 'no_complete_historical_turn' };
  }

  const fixedTokens = estimateTokenCount([...leading, ...fixedMessages], tools);
  for (let turnIndex = 1; turnIndex < turnStarts.length - 1; turnIndex += 1) {
    const cutIndex = turnStarts[turnIndex];
    const retained = body.slice(cutIndex);
    const projected = fixedTokens
      + estimateTokenCount(retained)
      + summaryReserveTokens;
    if (projected <= targetTokens) {
      return {
        compactable: true,
        leading,
        previousSummary,
        compacted: body.slice(0, cutIndex),
        retained,
        projectedTokens: projected,
      };
    }
  }
  return { compactable: false, reason: 'no_safe_cut_point' };
}

function serializeForSummary(messages = []) {
  return messages.map((message) => {
    const role = String(message.role || 'unknown');
    if (role === 'assistant' && Array.isArray(message.tool_calls) && message.tool_calls.length) {
      const names = message.tool_calls
        .map((call) => call?.function?.name || call?.name || 'tool')
        .join(', ');
      return `assistant [tool calls: ${names}]\n${textContent(message.content)}`;
    }
    if (role === 'tool') {
      return `tool ${message.name || message.tool_call_id || ''}\n${textContent(message.content)}`;
    }
    return `${role}\n${textContent(message.content)}`;
  }).join('\n\n');
}

function buildSummaryMessagesFromSource({ previousSummary = '', source = '' } = {}) {
  return [
    {
      role: 'system',
      content: [
        'Compress older conversation turns into one dense factual context block.',
        'Preserve user intent, constraints, corrections, decisions, promised or completed actions, tool outcomes and errors, unresolved blockers, identifiers, dates, file paths, and evidence references.',
        'Do not invent facts, repeat tool narration, or include greetings and filler.',
      ].join(' '),
    },
    {
      role: 'user',
      content: [
        previousSummary ? `Existing summary:\n${previousSummary}` : '',
        `Turns to merge:\n${source}`,
      ].filter(Boolean).join('\n\n'),
    },
  ];
}

function buildSummaryMessages({ previousSummary = '', messages = [] } = {}) {
  return buildSummaryMessagesFromSource({
    previousSummary,
    source: serializeForSummary(messages),
  });
}

function applyCompaction(cut, summary) {
  return [
    ...cut.leading,
    {
      role: 'system',
      content: `${SUMMARY_PREFIX}\n${String(summary || '').trim()}`,
    },
    ...cut.retained,
  ];
}

module.exports = {
  SUMMARY_PREFIX,
  applyCompaction,
  buildSummaryMessages,
  buildSummaryMessagesFromSource,
  estimateMessageTokens,
  estimateTokenCount,
  selectTurnSafeCut,
  serializeForSummary,
  splitLeadingSystemMessages,
};
