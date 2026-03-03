async function compact(messages, provider, model) {
  const systemMsg = messages.find(m => m.role === 'system');
  const nonSystem = messages.filter(m => m.role !== 'system');

  if (nonSystem.length < 6) return messages;

  const keepRecent = 6;
  const toCompact = nonSystem.slice(0, -keepRecent);
  const recent = nonSystem.slice(-keepRecent);

  let compactionText = '';
  for (const msg of toCompact) {
    if (msg.role === 'user') {
      compactionText += `User: ${(msg.content || '').slice(0, 500)}\n`;
    } else if (msg.role === 'assistant') {
      const content = (msg.content || '').slice(0, 500);
      if (msg.tool_calls) {
        const tools = msg.tool_calls.map(tc => tc.function.name).join(', ');
        compactionText += `Assistant: [used tools: ${tools}] ${content}\n`;
      } else {
        compactionText += `Assistant: ${content}\n`;
      }
    } else if (msg.role === 'tool') {
      const result = (msg.content || '').slice(0, 200);
      compactionText += `Tool result: ${result}\n`;
    }
  }

  const summaryPrompt = [
    { role: 'system', content: 'Summarize this conversation history concisely. Preserve: key decisions, facts learned, user preferences, task outcomes, and any errors or important results. Be thorough but compact.' },
    { role: 'user', content: `Summarize this conversation:\n\n${compactionText}` }
  ];

  try {
    const response = await provider.chat(summaryPrompt, [], { model, maxTokens: 2000 });
    const summary = response.content || 'Previous conversation context (summary unavailable).';

    const compactedMessages = [];
    if (systemMsg) compactedMessages.push(systemMsg);
    compactedMessages.push({
      role: 'user',
      content: `[Previous conversation summary]\n${summary}`
    });
    compactedMessages.push({
      role: 'assistant',
      content: 'Understood. I have the context from our previous conversation. Continuing.'
    });
    compactedMessages.push(...recent);

    return compactedMessages;
  } catch (err) {
    console.error('Compaction failed:', err.message);
    const trimmed = [];
    if (systemMsg) trimmed.push(systemMsg);
    trimmed.push({
      role: 'user',
      content: '[Earlier conversation context was trimmed due to length]'
    });
    trimmed.push({
      role: 'assistant',
      content: 'Understood. Some earlier context was trimmed. Continuing with recent messages.'
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
