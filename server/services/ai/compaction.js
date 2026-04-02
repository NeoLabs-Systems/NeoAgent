async function compact(messages, provider, model) {
  const systemMsg = messages.find(m => m.role === 'system');
  const nonSystem = messages.filter(m => m.role !== 'system');

  if (nonSystem.length < 12) return messages;

  const keepRecent = 10;
  const toCompact = nonSystem.slice(0, -keepRecent);
  const recent = nonSystem.slice(-keepRecent);

  const compactionText = toCompact.map((msg) => {
    if (msg.role === 'assistant' && msg.tool_calls) {
      const tools = msg.tool_calls.map((tc) => tc.function.name).join(', ');
      return `assistant(tools:${tools}) ${(msg.content || '').slice(0, 320)}`;
    }
    if (msg.role === 'tool') {
      return `tool:${msg.name || 'tool'} ${(msg.content || '').slice(0, 220)}`;
    }
    return `${msg.role}: ${(msg.content || '').slice(0, 360)}`;
  }).join('\n');

  const summaryPrompt = [
    { role: 'system', content: 'Compress conversation context. Preserve goals, constraints, decisions, promised follow-ups, recurring tasks, tool outcomes, errors, and unresolved work. Keep concrete facts (dates/times/names/status) and avoid vague wording.' },
    { role: 'user', content: `Summarize this conversation:\n\n${compactionText}` }
  ];

  try {
    const response = await provider.chat(summaryPrompt, [], { model, maxTokens: 900 });
    const summary = response.content || 'Previous conversation context (summary unavailable).';

    const compactedMessages = [];
    if (systemMsg) compactedMessages.push(systemMsg);
    compactedMessages.push({
      role: 'system',
      content: `[Previous conversation summary]\n${summary}`
    });
    compactedMessages.push(...recent);

    return compactedMessages;
  } catch (err) {
    console.error('Compaction failed:', err.message);
    const trimmed = [];
    if (systemMsg) trimmed.push(systemMsg);
    trimmed.push({
      role: 'system',
      content: '[Earlier conversation context was trimmed due to length]'
    });
    trimmed.push(...recent);
    return trimmed;
  }
}

function estimateTokenCount(messages) {
  let count = 0;
  for (const msg of messages) {
    if (msg.content) count += Math.ceil(msg.content.length / 4);
    if (msg.tool_calls) count += Math.ceil(JSON.stringify(msg.tool_calls).length / 4);
  }
  return count;
}

function shouldCompact(messages, contextWindow) {
  const used = estimateTokenCount(messages);
  return used > contextWindow * 0.85;
}

module.exports = { compact, estimateTokenCount, shouldCompact };
