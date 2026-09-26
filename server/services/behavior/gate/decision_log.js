'use strict';

// Recent group turn-taking decisions, kept in memory per platform so the
// access settings can show why the agent spoke or held back.
const MAX_ENTRIES_PER_PLATFORM = 30;
const MAX_PREVIEW_CHARS = 160;
const decisionLogs = new Map();

function logKey(userId, agentId, platform) {
  return [String(userId || ''), String(agentId || 'main'), String(platform || '')].join('::');
}

function previewOf(content) {
  const text = String(content || '').replace(/\s+/g, ' ').trim();
  return text.length > MAX_PREVIEW_CHARS ? `${text.slice(0, MAX_PREVIEW_CHARS - 1)}…` : text;
}

function recordDecision(userId, agentId, msg, decision) {
  const key = logKey(userId, agentId, msg.platform);
  const entries = decisionLogs.get(key) || [];
  entries.unshift({
    at: new Date().toISOString(),
    chatId: String(msg.chatId || ''),
    chatName: msg.groupName || msg.channelName || msg.roomName || null,
    serverName: msg.guildName || null,
    senderName: msg.senderName || null,
    preview: previewOf(msg.content),
    wasMentioned: Boolean(msg.wasMentioned),
    repliedToAgent: Boolean(msg.repliedToAgent),
    decision: decision.decision,
    reasonCodes: Array.isArray(decision.reasonCodes) ? decision.reasonCodes : [],
    needScore: Number(decision.needScore || 0),
    needThreshold: Number.isFinite(decision.needThreshold) ? decision.needThreshold : null,
    jevScores: decision.jevScores || null,
    confidence: Number(decision.confidence || 0),
    tokenPath: decision.tokenPath || null,
    model: decision.model || null,
    latencyMs: Number(decision.latencyMs || 0),
  });
  entries.length = Math.min(entries.length, MAX_ENTRIES_PER_PLATFORM);
  decisionLogs.set(key, entries);
}

function listDecisions(userId, agentId, platform) {
  return [...(decisionLogs.get(logKey(userId, agentId, platform)) || [])];
}

function clearDecisionLogs() {
  decisionLogs.clear();
}

module.exports = {
  recordDecision,
  listDecisions,
  clearDecisionLogs,
};
