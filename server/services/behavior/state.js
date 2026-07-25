'use strict';

const db = require('../../db/database');

const STATE_PREFIX = 'behavior_state_';

function stateKey(platform, chatId) {
  return `${STATE_PREFIX}${String(platform || '').trim()}::${String(chatId || '').trim()}`;
}

function readJson(value, fallback = {}) {
  if (value == null || value === '') return { ...fallback };
  if (typeof value === 'object') return { ...fallback, ...value };
  try {
    return { ...fallback, ...JSON.parse(value) };
  } catch {
    return { ...fallback };
  }
}

function getThreadState(userId, agentId, platform, chatId) {
  const row = db.prepare(
    'SELECT value FROM agent_settings WHERE user_id = ? AND agent_id = ? AND key = ?',
  ).get(userId, agentId, stateKey(platform, chatId));
  return readJson(row?.value, {
    turnEpoch: 0,
    lastDecision: null,
    lastDecisionAt: null,
    lastSpokeAt: null,
    messageCountSinceNorms: 0,
    normsPromptBlock: '',
    normsUpdatedAt: null,
    lastObservabilityAt: null,
    lastObservabilitySummary: null,
    recentSilenceCount: 0,
  });
}

function setThreadState(userId, agentId, platform, chatId, patch = {}) {
  const current = getThreadState(userId, agentId, platform, chatId);
  const next = {
    ...current,
    ...patch,
  };
  db.prepare(
    `INSERT INTO agent_settings (user_id, agent_id, key, value)
     VALUES (?, ?, ?, ?)
     ON CONFLICT(user_id, agent_id, key) DO UPDATE SET value = excluded.value`,
  ).run(userId, agentId, stateKey(platform, chatId), JSON.stringify(next));
  return next;
}

function bumpTurnEpoch(userId, agentId, platform, chatId) {
  const current = getThreadState(userId, agentId, platform, chatId);
  return setThreadState(userId, agentId, platform, chatId, {
    turnEpoch: Number(current.turnEpoch || 0) + 1,
  });
}

module.exports = {
  getThreadState,
  setThreadState,
  bumpTurnEpoch,
  stateKey,
};
