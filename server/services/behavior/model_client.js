'use strict';

async function requestStructuredJson({
  agentEngine,
  userId,
  agentId,
  modelId = null,
  purpose = 'fast',
  system,
  prompt,
  signal = null,
  maxTokens = 220,
  fallback = {},
}) {
  if (!agentEngine || typeof agentEngine.inferStructured !== 'function') {
    const error = new Error('Behavior inference requires the central AI engine.');
    error.code = 'BEHAVIOR_ENGINE_UNAVAILABLE';
    throw error;
  }
  return agentEngine.inferStructured({
    userId,
    agentId,
    modelId,
    purpose,
    system,
    prompt,
    maxTokens,
    fallback,
    signal,
  });
}

// A Jev decision, or null when Jev is off or unavailable and the caller
// should use its model path.
async function requestDecision({ agentEngine, ...request }) {
  if (typeof agentEngine?.decide !== 'function') return null;
  return agentEngine.decide(request);
}

module.exports = {
  requestDecision,
  requestStructuredJson,
};
