'use strict';

const MAX_THREAD_STATES = 1000;
const THREAD_STATE_TTL_MS = 7 * 24 * 60 * 60 * 1000;
const threadStates = new Map();

function stateKey(userId, agentId, platform, chatId) {
  return [
    String(userId || ''),
    String(agentId || 'main'),
    String(platform || ''),
    String(chatId || ''),
  ].join('::');
}

function defaultState() {
  return {
    turnEpoch: 0,
    lastDecision: null,
    lastDecisionAt: null,
    lastSpokeAt: null,
    messageCountSinceNorms: 0,
    normsPromptBlock: '',
    normsUpdatedAt: null,
    lastObservabilityAt: null,
    lastObservabilitySummary: null,
    messageCountSinceObservability: 0,
    recentSilenceCount: 0,
    recentSignals: [],
  };
}

function evictThreadStates() {
  const cutoff = Date.now() - THREAD_STATE_TTL_MS;
  for (const [key, entry] of threadStates.entries()) {
    if (entry.touchedAt < cutoff) threadStates.delete(key);
  }
  while (threadStates.size > MAX_THREAD_STATES) {
    const oldest = threadStates.keys().next().value;
    if (oldest == null) break;
    threadStates.delete(oldest);
  }
}

function getThreadState(userId, agentId, platform, chatId) {
  const key = stateKey(userId, agentId, platform, chatId);
  const entry = threadStates.get(key);
  if (!entry) return defaultState();
  threadStates.delete(key);
  threadStates.set(key, entry);
  entry.touchedAt = Date.now();
  return { ...defaultState(), ...entry.value };
}

function setThreadState(userId, agentId, platform, chatId, patch = {}) {
  const key = stateKey(userId, agentId, platform, chatId);
  const current = getThreadState(userId, agentId, platform, chatId);
  const next = {
    ...current,
    ...patch,
  };
  threadStates.delete(key);
  threadStates.set(key, { value: next, touchedAt: Date.now() });
  evictThreadStates();
  return next;
}

function bumpTurnEpoch(userId, agentId, platform, chatId) {
  const current = getThreadState(userId, agentId, platform, chatId);
  return setThreadState(userId, agentId, platform, chatId, {
    turnEpoch: Number(current.turnEpoch || 0) + 1,
  });
}

function isTurnCurrent(userId, agentId, platform, chatId, turnEpoch) {
  return Number(getThreadState(userId, agentId, platform, chatId).turnEpoch || 0)
    === Number(turnEpoch || 0);
}

function markSpoke(userId, agentId, platform, chatId) {
  return setThreadState(userId, agentId, platform, chatId, {
    lastSpokeAt: new Date().toISOString(),
    recentSilenceCount: 0,
  });
}

function clearThreadStates() {
  threadStates.clear();
}

module.exports = {
  getThreadState,
  setThreadState,
  bumpTurnEpoch,
  isTurnCurrent,
  markSpoke,
  clearThreadStates,
  stateKey,
};
