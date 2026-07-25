'use strict';

const { getProviderForUser } = require('../ai/provider_selector');
const { getSupportedModels } = require('../ai/models');
const { getRawModelId } = require('../ai/model_identity');

function extractJsonObject(text) {
  const raw = String(text || '').trim();
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch {
    // continue
  }
  const fenced = raw.match(/```(?:json)?\s*([\s\S]*?)```/i);
  if (fenced?.[1]) {
    try {
      return JSON.parse(fenced[1].trim());
    } catch {
      // continue
    }
  }
  const start = raw.indexOf('{');
  const end = raw.lastIndexOf('}');
  if (start >= 0 && end > start) {
    try {
      return JSON.parse(raw.slice(start, end + 1));
    } catch {
      return null;
    }
  }
  return null;
}

function pickContent(response) {
  if (!response) return '';
  if (typeof response === 'string') return response;
  if (typeof response.content === 'string') return response.content;
  if (Array.isArray(response.content)) {
    return response.content.map((part) => {
      if (typeof part === 'string') return part;
      return part?.text || part?.content || '';
    }).join('\n');
  }
  if (typeof response.message?.content === 'string') return response.message.content;
  if (typeof response.text === 'string') return response.text;
  return '';
}

async function resolveDecisionProvider(userId, agentId, preference = 'cheap', signal = null) {
  const models = await getSupportedModels(userId, agentId, { signal });
  const available = models.filter((model) => model.available !== false);
  if (!available.length) {
    return getProviderForUser(userId, '', false, null, { agentId, signal });
  }

  let selected = null;
  if (preference === 'cheap') {
    selected = available.find((model) => model.purpose === 'fast')
      || available.find((model) => /mini|nano|haiku|flash|small|lite/i.test(String(model.id || '')))
      || available.find((model) => model.purpose === 'coding')
      || available[0];
  } else {
    selected = available[0];
  }

  return getProviderForUser(userId, '', false, selected.id, { agentId, signal });
}

async function requestStructuredJson({
  userId,
  agentId,
  preference = 'cheap',
  system,
  prompt,
  signal = null,
  maxTokens = 220,
}) {
  const selection = await resolveDecisionProvider(userId, agentId, preference, signal);
  const messages = [
    { role: 'system', content: system },
    { role: 'user', content: prompt },
  ];
  const response = await selection.provider.chat(messages, [], {
    model: selection.model,
    temperature: 0.1,
    maxTokens,
    signal,
  });
  const content = pickContent(response);
  const parsed = extractJsonObject(content);
  return {
    parsed,
    raw: content,
    model: selection.model,
    modelSelectionId: selection.modelSelectionId,
    providerName: selection.providerName,
  };
}

module.exports = {
  extractJsonObject,
  pickContent,
  resolveDecisionProvider,
  requestStructuredJson,
  getRawModelId,
};
