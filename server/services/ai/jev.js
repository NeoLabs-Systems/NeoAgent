'use strict';

const { getAiSettings } = require('./settings');
const { createProviderInstance, getProviderRuntimeConfig } = require('./models');
const { recordModelUsage } = require('./usage');

// Jev answers typed questions about a state (yes/no probabilities, choices,
// ordered scores) in a few hundred milliseconds. NeoAgent uses it for
// decisions made behind the scenes; everything a user reads is still written
// by the chat model. Every caller keeps its previous path and takes it
// whenever decide() returns null.
//
// OpenRouter is the only provider serving Jev today. Another provider only
// needs a decide() implementation and an entry here.
const DECISION_PROVIDERS = Object.freeze(['openrouter']);
const DECISION_TIMEOUT_MS = 4000;

// Server-wide policy (NEOAGENT_JEV), set in Admin › Models or with
// `neoagent jev`: `off` turns Jev off everywhere, `on` turns it on for every
// agent, and `agent` (the default) leaves it to each agent's settings.
const JEV_POLICIES = Object.freeze(['agent', 'on', 'off']);

function getJevPolicy() {
  const value = String(process.env.NEOAGENT_JEV || '').trim().toLowerCase();
  return JEV_POLICIES.includes(value) ? value : 'agent';
}

// The provider that serves Jev for this agent, or null when Jev is switched
// off or no decision provider has credentials. A settings lookup that fails
// counts as off: Jev must never break the path it would have replaced.
function jevProviderFor(userId, agentId = null) {
  if (userId == null) return null;
  const policy = getJevPolicy();
  if (policy === 'off') return null;
  try {
    if (policy === 'agent' && getAiSettings(userId, agentId).jev_enabled !== true) return null;
    return DECISION_PROVIDERS.find((providerId) => (
      getProviderRuntimeConfig(userId, providerId, agentId).credentialConfigured
    )) || null;
  } catch (error) {
    console.warn(`[Jev] Could not read the Jev setting; treating Jev as off: ${error.message}`);
    return null;
  }
}

function isJevEnabled(userId, agentId = null) {
  return jevProviderFor(userId, agentId) !== null;
}

function isProbability(value) {
  return typeof value === 'number' && Number.isFinite(value) && value >= 0 && value <= 1;
}

function isValidAnswer(question, answer) {
  if (!answer || answer.type !== question.type) return false;
  if (question.type === 'noul') return isProbability(answer.noul);
  if (question.type === 'choice') {
    return Object.prototype.hasOwnProperty.call(question.criteria || {}, answer.choice)
      && isProbability(answer.confidence)
      && Boolean(answer.probabilities)
      && Object.values(answer.probabilities).every(isProbability);
  }
  if (question.type === 'score') {
    return typeof answer.score === 'number' && Number.isFinite(answer.score);
  }
  return false;
}

// The usage row keeps the answers so every automatic decision can be audited
// next to its cost.
function summarizeAnswers(answers) {
  return Object.fromEntries(Object.entries(answers).map(([key, answer]) => {
    if (answer.type === 'noul') return [key, answer.noul];
    if (answer.type === 'choice') return [key, { choice: answer.choice, confidence: answer.confidence }];
    return [key, { score: answer.score, confidence: answer.confidence }];
  }));
}

async function decide({
  userId,
  agentId = null,
  runId = null,
  stepId = null,
  phase,
  state,
  questions,
  signal = null,
}) {
  const providerId = jevProviderFor(userId, agentId);
  if (!providerId) return null;
  const startedAt = Date.now();
  try {
    const provider = createProviderInstance(providerId, userId, { agentId });
    const result = await provider.decide({
      state,
      questions,
      signal,
      timeoutMs: DECISION_TIMEOUT_MS,
    });
    const invalid = Object.keys(questions)
      .filter((key) => !isValidAnswer(questions[key], result.answers[key]));
    if (invalid.length > 0) {
      throw new Error(`invalid answers for ${invalid.join(', ')}`);
    }
    if (runId) {
      recordModelUsage({
        runId,
        stepId,
        userId,
        agentId,
        provider: providerId,
        model: result.model,
        phase,
        usage: result.usage,
        latencyMs: Date.now() - startedAt,
        estimatedCostUsd: result.usage?.cost,
        metadata: { answers: summarizeAnswers(result.answers) },
      });
    }
    return result.answers;
  } catch (error) {
    if (signal?.aborted) throw error;
    console.warn(`[Jev] ${phase} decision unavailable, using the model path instead: ${error.message}`);
    return null;
  }
}

module.exports = {
  JEV_POLICIES,
  decide,
  getJevPolicy,
  isJevEnabled,
};
