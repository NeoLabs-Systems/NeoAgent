'use strict';

const { requestStructuredJson } = require('../model_client');
const { loadRecentRoomMessages } = require('../signals');
const { getThreadState, setThreadState } = require('../state');
const { isModuleEnabled } = require('../config');

const SYSTEM_PROMPT = `You audit how an AI participant is landing in a group chat.
Return JSON with keys:
healthScore (0-100),
summary (short paragraph),
findings (array of short strings),
recommendations (array of short strings).
Do not change policy yourself; report only.`;

async function maybeAnalyze(ctx) {
  const { userId, agentId, msg, config, signal = null } = ctx;
  if (!msg?.isGroup || !isModuleEnabled(config, 'social_observability')) {
    return { analyzed: false };
  }

  const state = getThreadState(userId, agentId, msg.platform, msg.chatId);
  const intervalMs = Number(config.observabilityIntervalMinutes || 360) * 60 * 1000;
  if (state.lastObservabilityAt) {
    const age = Date.now() - Date.parse(state.lastObservabilityAt);
    if (Number.isFinite(age) && age < intervalMs) {
      return { analyzed: false, deferred: true, summary: state.lastObservabilitySummary || null };
    }
  }

  const roomMessages = loadRecentRoomMessages({
    userId,
    agentId,
    platform: msg.platform,
    chatId: msg.chatId,
    limit: 30,
  });
  if (roomMessages.length < 6) {
    return { analyzed: false, reason: 'insufficient_history' };
  }

  try {
    const result = await requestStructuredJson({
      userId,
      agentId,
      preference: 'cheap',
      system: SYSTEM_PROMPT,
      prompt: JSON.stringify({
        platform: msg.platform,
        chatId: msg.chatId,
        recentSilenceCount: state.recentSilenceCount || 0,
        recentMessages: roomMessages,
      }),
      signal,
      maxTokens: 320,
    });
    const summary = {
      healthScore: Number(result.parsed?.healthScore || 0),
      summary: String(result.parsed?.summary || '').trim(),
      findings: Array.isArray(result.parsed?.findings) ? result.parsed.findings.slice(0, 8) : [],
      recommendations: Array.isArray(result.parsed?.recommendations) ? result.parsed.recommendations.slice(0, 8) : [],
      at: new Date().toISOString(),
    };
    setThreadState(userId, agentId, msg.platform, msg.chatId, {
      lastObservabilityAt: summary.at,
      lastObservabilitySummary: summary,
    });
    return { analyzed: true, summary };
  } catch (error) {
    if (signal?.aborted) throw error;
    return { analyzed: false, error: error?.message || String(error) };
  }
}

function getLatestSummary(userId, agentId, platform, chatId) {
  const state = getThreadState(userId, agentId, platform, chatId);
  return state.lastObservabilitySummary || null;
}

module.exports = {
  id: 'social_observability',
  maybeAnalyze,
  getLatestSummary,
};
