'use strict';

// Calls OpenRouter directly for the answerer/judge steps of the QA-head, deliberately
// bypassing NeoAgent's own agent loop — this measures the memory system's retrieval
// quality, not the consumer chat agent, mirroring omi's protocol.
async function openRouterChat({ baseUrl, apiKey, model, prompt, temperature = 0, maxTokens = 700 }) {
  const url = `${String(baseUrl || 'https://openrouter.ai/api/v1').replace(/\/+$/, '')}/chat/completions`;
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model,
      temperature,
      max_tokens: maxTokens,
      messages: [{ role: 'user', content: prompt }],
    }),
  });
  if (!response.ok) {
    const text = await response.text().catch(() => '');
    throw new Error(`OpenRouter chat completion (${model}) failed with HTTP ${response.status}: ${text.slice(0, 200)}`);
  }
  const payload = await response.json();
  const content = payload?.choices?.[0]?.message?.content;
  return {
    content: typeof content === 'string' ? content.trim() : '',
    usage: {
      inputTokens: Number(payload?.usage?.prompt_tokens || 0),
      outputTokens: Number(payload?.usage?.completion_tokens || 0),
    },
  };
}

module.exports = {
  openRouterChat,
};
