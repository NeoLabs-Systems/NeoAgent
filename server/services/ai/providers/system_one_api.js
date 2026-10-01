'use strict';

const { fetchResponseText } = require('../../network/http');

// Every SystemOne host (TypeSafe, OpenRouter, Ollama) takes TypeSafe's request
// shape at its systemone endpoint and answers with { model, answers, usage }.
async function postSystemOneDecision(url, {
  headers = {},
  model,
  state,
  questions,
  signal = null,
  timeoutMs,
}) {
  const { response, text } = await fetchResponseText(url, {
    method: 'POST',
    headers: { ...headers, 'Content-Type': 'application/json' },
    body: JSON.stringify({ model, state, questions }),
    maxResponseBytes: 1024 * 1024,
    serviceName: 'SystemOne decision',
    signal,
    timeoutMs,
  });
  let payload = null;
  try {
    payload = JSON.parse(text || '{}');
  } catch {
    payload = null;
  }
  if (!response.ok) {
    const detail = typeof payload?.error === 'string' ? payload.error : payload?.error?.message;
    const error = new Error(`${model} returned HTTP ${response.status}${detail ? `: ${detail}` : ''}`);
    error.status = response.status;
    throw error;
  }
  if (!payload?.answers || typeof payload.answers !== 'object') {
    throw new Error(`${model} returned no answers.`);
  }
  return {
    model: payload.model || model,
    answers: payload.answers,
    usage: payload.usage || {},
  };
}

module.exports = { postSystemOneDecision };
