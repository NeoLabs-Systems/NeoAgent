'use strict';

const INTENTS = new Set(['broad', 'procedural', 'episodic', 'profile']);

function hasAny(text, patterns) {
  return patterns.some((pattern) => pattern.test(text));
}

function normalizeIntent(intent) {
  return INTENTS.has(intent) ? intent : 'broad';
}

function routeMemoryQuery(query) {
  const text = String(query || '').toLowerCase();
  if (!text.trim()) {
    return { intent: 'broad', confidence: 0, categoryBoosts: {} };
  }

  const procedural = hasAny(text, [
    /\bhow (?:do|did|should|can) (?:i|we|you)\b/,
    /\b(?:workflow|procedure|runbook|playbook|steps?|checklist|process)\b/,
    /\b(?:repeat|reusable|again|same way|tool[- ]use|command sequence)\b/,
  ]);
  if (procedural) {
    return {
      intent: 'procedural',
      confidence: 0.76,
      categoryBoosts: { procedural: 0.26, tasks: 0.08, episodic: 0.04 },
    };
  }

  const episodic = hasAny(text, [
    /\b(?:when|what happened|last time|previously|yesterday|today|last week|last month)\b/,
    /\b(?:meeting|event|conversation|session|incident|task run)\b/,
  ]);
  if (episodic) {
    return {
      intent: 'episodic',
      confidence: 0.7,
      categoryBoosts: { episodic: 0.18, events: 0.16, tasks: 0.1 },
    };
  }

  const profile = hasAny(text, [
    /\b(?:prefer|preference|likes?|dislikes?|my name|who am i|about me)\b/,
    /\b(?:profile|personality|standing instruction|how should you)\b/,
  ]);
  if (profile) {
    return {
      intent: 'profile',
      confidence: 0.72,
      categoryBoosts: { preferences: 0.2, identity: 0.16, assistant_self: 0.12 },
    };
  }

  return { intent: 'broad', confidence: 0.35, categoryBoosts: {} };
}

function getRouteCategoryBoost(route, category) {
  const intent = normalizeIntent(route?.intent);
  if (intent === 'broad' || Number(route?.confidence || 0) < 0.6) return 0;
  return Number(route?.categoryBoosts?.[category] || 0);
}

module.exports = {
  getRouteCategoryBoost,
  routeMemoryQuery,
};
