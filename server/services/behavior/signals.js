'use strict';

const db = require('../../db/database');

function truncate(text, max = 280) {
  const value = String(text || '').replace(/\s+/g, ' ').trim();
  if (value.length <= max) return value;
  return `${value.slice(0, max - 1)}…`;
}

function buildChannelScopeId(platform, chatId) {
  return `${String(platform || '').trim()}:${String(chatId || '').trim()}`;
}

function loadRecentRoomMessages({ userId, agentId, platform, chatId, limit = 12 }) {
  const rows = db.prepare(
    `SELECT role, content, created_at, metadata
     FROM messages
     WHERE user_id = ?
       AND agent_id IS ?
       AND platform = ?
       AND platform_chat_id = ?
     ORDER BY created_at DESC
     LIMIT ?`,
  ).all(userId, agentId, platform, String(chatId), Math.max(1, Math.min(Number(limit) || 12, 30)));

  return rows.reverse().map((row) => {
    let metadata = null;
    try {
      metadata = row.metadata ? JSON.parse(row.metadata) : null;
    } catch {
      metadata = null;
    }
    const sender = row.role === 'assistant'
      ? 'assistant'
      : (metadata?.senderDisplayName || metadata?.senderName || metadata?.sender || 'participant');
    return {
      role: row.role,
      sender,
      content: truncate(row.content, 320),
      createdAt: row.created_at,
    };
  });
}

function buildDecisionPacket({
  msg,
  config,
  threadState,
  roomMessages = [],
  localMemoryHints = [],
}) {
  const recent = Array.isArray(msg.channelContext) && msg.channelContext.length
    ? msg.channelContext.slice(-12).map((item) => ({
      sender: item.author || item.sender || 'participant',
      content: truncate(item.content, 280),
    }))
    : roomMessages.slice(-12).map((item) => ({
      sender: item.sender,
      content: item.content,
    }));

  const secondsSinceSpoke = threadState?.lastSpokeAt
    ? Math.max(0, Math.round((Date.now() - Date.parse(threadState.lastSpokeAt)) / 1000))
    : null;

  return {
    chat: {
      platform: msg.platform,
      chatId: String(msg.chatId || ''),
      isGroup: Boolean(msg.isGroup),
      groupName: msg.groupName || msg.guildName || msg.channelName || null,
    },
    sender: {
      id: msg.sender || null,
      name: msg.senderName || msg.senderDisplayName || msg.senderUsername || null,
      username: msg.senderUsername || null,
      tag: msg.senderTag || null,
    },
    event: {
      content: truncate(msg.content, 800),
      hasMedia: Boolean(msg.localMediaPath || msg.mediaType),
      mediaType: msg.mediaType || null,
      wasMentioned: msg.wasMentioned === true,
      repliedToAgent: msg.repliedToAgent === true,
      timestamp: msg.timestamp || new Date().toISOString(),
    },
    room: {
      recentMessages: recent,
      secondsSinceAgentSpoke: secondsSinceSpoke,
      recentSilenceCount: Number(threadState?.recentSilenceCount || 0),
    },
    policy: {
      participationMode: config.participationMode || 'automatic',
      minimumNeedScore: Number(config.minimumNeedScore ?? 0.72),
      groupDefaultPosture: 'prefer_hold_back',
    },
    roomHints: Array.isArray(localMemoryHints) ? localMemoryHints.slice(0, 4) : [],
  };
}

module.exports = {
  truncate,
  buildChannelScopeId,
  loadRecentRoomMessages,
  buildDecisionPacket,
};
