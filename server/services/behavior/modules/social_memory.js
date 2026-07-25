'use strict';

const { buildChannelScopeId, truncate } = require('../signals');
const { isModuleEnabled } = require('../config');

function participantLabel(msg) {
  return msg.senderName || msg.senderDisplayName || msg.senderUsername || msg.sender || 'participant';
}

async function observeInbound(ctx) {
  const { userId, agentId, msg, config, memoryManager } = ctx;
  if (!isModuleEnabled(config, 'social_memory') || !memoryManager || !msg?.isGroup) {
    return { observed: false };
  }

  const scopeId = buildChannelScopeId(msg.platform, msg.chatId);
  const content = [
    `Group chat ${msg.platform}:${msg.chatId}`,
    `Speaker ${participantLabel(msg)} (${msg.sender || 'unknown'}) said: ${truncate(msg.content, 500)}`,
  ].join('. ');

  try {
    await memoryManager.saveMemory(userId, content, 'episodic', 3, {
      agentId,
      scope: { scopeType: 'channel', scopeId },
      sourceRef: {
        sourceType: 'messaging_group',
        sourceId: msg.messageId || null,
        sourceLabel: `${msg.platform} ${msg.chatId}`,
      },
      metadata: {
        platform: msg.platform,
        chat_id: String(msg.chatId || ''),
        participant_id: msg.sender || null,
        participant_name: participantLabel(msg),
        social: true,
        was_mentioned: msg.wasMentioned === true,
      },
    });
  } catch (error) {
    return { observed: false, error: error?.message || String(error) };
  }

  return { observed: true, scopeId };
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

  // Also pull a couple of contact facts about the speaker without expanding into owner core memory.
  try {
    const personHits = await memoryManager.recallMemory(
      userId,
      `${participantLabel(msg)} ${msg.sender || ''} contact relationship`,
      3,
      { agentId },
    );
    for (const hit of personHits) {
      if (['contacts', 'identity', 'preferences'].includes(hit.category)) {
        recalled.push(hit);
      }
    }
  } catch {
    // ignore
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

module.exports = {
  id: 'social_memory',
  observeInbound,
  buildSpeakHints,
};
