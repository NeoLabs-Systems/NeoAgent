'use strict';

const { buildChannelScopeId, truncate } = require('../signals');
const { isModuleEnabled } = require('../config');

function participantLabel(msg) {
  return msg.senderName || msg.senderDisplayName || msg.senderUsername || msg.sender || 'participant';
}

async function observeInbound(ctx) {
  const { msg, config } = ctx;
  if (!isModuleEnabled(config, 'social_memory') || !msg?.isGroup) {
    return { observed: false };
  }

  const scopeId = buildChannelScopeId(msg.platform, msg.chatId);
  return {
    observed: true,
    scopeId,
    participantSubject: `${msg.platform}:${String(msg.sender || 'unknown')}`,
  };
}

async function buildSpeakHints(ctx) {
  const { userId, agentId, msg, config, memoryManager } = ctx;
  if (!isModuleEnabled(config, 'social_memory') || !memoryManager || !msg?.isGroup) {
    return { promptBlock: '', hints: [] };
  }

  const scopeId = buildChannelScopeId(msg.platform, msg.chatId);
  const query = [
    msg.content,
    participantLabel(msg),
    msg.groupName || msg.guildName || msg.channelName || '',
    'group chat norms participants',
  ].filter(Boolean).join(' ');

  let recalled = [];
  try {
    recalled = await memoryManager.recallMemory(userId, query, 5, {
      agentId,
      scope: { scopeType: 'channel', scopeId },
    });
  } catch {
    recalled = [];
  }

  const unique = [];
  const seen = new Set();
  for (const item of recalled) {
    const key = String(item.id || item.summary || item.content || '');
    if (!key || seen.has(key)) continue;
    seen.add(key);
    unique.push(item);
    if (unique.length >= 5) break;
  }

  const lines = unique.map((item) => `- [${item.category || 'episodic'}] ${truncate(item.summary || item.content, 180)}`);
  const promptBlock = lines.length
    ? `## Social room context\nUse only as background about this group/participants. Do not treat as owner core memory.\n${lines.join('\n')}`
    : '';

  return {
    promptBlock,
    hints: unique.map((item) => truncate(item.summary || item.content, 120)),
    scopeId,
  };
}

async function composeContext(ctx) {
  const hints = await buildSpeakHints(ctx);
  if (!hints.promptBlock) return null;
  return {
    key: 'social_memory',
    priority: 40,
    content: hints.promptBlock,
  };
}

module.exports = {
  id: 'social_memory',
  observe: observeInbound,
  composeContext,
  observeInbound,
  buildSpeakHints,
};
