'use strict';

const { requestStructuredJson } = require('../model_client');
const { loadRecentRoomMessages, truncate } = require('../signals');
const { getThreadState, setThreadState } = require('../state');
const { isModuleEnabled } = require('../config');

const SYSTEM_PROMPT = `You extract a compact group-chat norms profile for an AI participant.
Return JSON with keys:
promptBlock (short instructions the agent can follow to match the room's voice),
notes (array of short observations).
No phrase blacklists. Describe style, formality, humor, length, and participation norms.`;

function getNormsPromptBlock(ctx) {
  if (!isModuleEnabled(ctx.config, 'norms')) return '';
  const state = getThreadState(ctx.userId, ctx.agentId, ctx.msg.platform, ctx.msg.chatId);
  return String(state.normsPromptBlock || '').trim();
}

async function maybeRefreshNorms(ctx) {
  const { userId, agentId, msg, config, signal = null } = ctx;
  if (!msg?.isGroup || !isModuleEnabled(config, 'norms')) {
    return { refreshed: false };
  }

  const state = getThreadState(userId, agentId, msg.platform, msg.chatId);
  const count = Number(state.messageCountSinceNorms || 0) + 1;
  const gap = Number(config.normsRefreshMessageGap || 18);
  if (count < gap) {
    setThreadState(userId, agentId, msg.platform, msg.chatId, {
      messageCountSinceNorms: count,
    });
    return { refreshed: false, deferred: true };
  }

  const roomMessages = loadRecentRoomMessages({
    userId,
    agentId,
    platform: msg.platform,
    chatId: msg.chatId,
    limit: 24,
  });
  if (roomMessages.length < 4) {
    setThreadState(userId, agentId, msg.platform, msg.chatId, {
      messageCountSinceNorms: count,
    });
    return { refreshed: false, reason: 'insufficient_history' };
  }

  try {
    const result = await requestStructuredJson({
      agentEngine: ctx.agentEngine,
      userId,
      agentId,
      purpose: 'fast',
      system: SYSTEM_PROMPT,
      prompt: JSON.stringify({
        platform: msg.platform,
        chatId: msg.chatId,
        recentMessages: roomMessages.map((item) => ({
          sender: item.sender,
          content: item.content,
        })),
      }),
      signal,
      maxTokens: 280,
    });
    const promptBlock = truncate(result.parsed?.promptBlock || '', 900);
    if (!promptBlock) {
      setThreadState(userId, agentId, msg.platform, msg.chatId, {
        messageCountSinceNorms: 0,
      });
      return { refreshed: false, reason: 'empty_block' };
    }
    setThreadState(userId, agentId, msg.platform, msg.chatId, {
      normsPromptBlock: `## Group norms\n${promptBlock}`,
      normsUpdatedAt: new Date().toISOString(),
      messageCountSinceNorms: 0,
    });
    return { refreshed: true };
  } catch (error) {
    if (signal?.aborted) throw error;
    setThreadState(userId, agentId, msg.platform, msg.chatId, {
      messageCountSinceNorms: count,
    });
    return { refreshed: false, error: error?.message || String(error) };
  }
}

function composeContext(ctx) {
  const content = getNormsPromptBlock(ctx);
  return content ? { key: 'norms', priority: 50, content } : null;
}

module.exports = {
  id: 'norms',
  composeContext,
  afterTurn: maybeRefreshNorms,
  getNormsPromptBlock,
  maybeRefreshNorms,
};
