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
      kind: metadata?.kind || null,
      targetText: metadata?.targetText ? truncate(metadata.targetText, 120) : null,
      createdAt: row.created_at,
    };
  });
}

// The sender's own short chat messages, used as a register reference so the
// reply mirrors how this person actually texts.
function loadRecentSenderTexts({ userId, agentId, platform, chatId, limit = 40 }) {
  const rows = db.prepare(
    `SELECT content
     FROM messages
     WHERE user_id = ?
       AND agent_id IS ?
       AND platform = ?
       AND platform_chat_id = ?
       AND role = 'user'
       AND COALESCE(CASE WHEN json_valid(metadata) THEN json_extract(metadata, '$.kind') END, '') != 'reaction'
     ORDER BY created_at DESC
     LIMIT 200`,
  ).all(userId, agentId, platform, String(chatId));
  const texts = [];
  for (const row of rows) {
    const text = String(row.content || '').trim();
    if (!text || text.length > 90 || text.includes('\n') || text.startsWith('/') || /https?:\/\//.test(text)) continue;
    if (texts.includes(text)) continue;
    texts.push(text);
    if (texts.length >= limit) break;
  }
  return texts.reverse();
}

// True when the run executed work tools, not just messaging or bookkeeping steps.
function runDidWork(runId) {
  if (!runId) return false;
  const row = db.prepare(
    `SELECT 1 FROM agent_steps
     WHERE run_id = ?
       AND tool_name IS NOT NULL
       AND type NOT IN ('messaging', 'note', 'thinking')
     LIMIT 1`,
  ).get(String(runId));
  return Boolean(row);
}

function buildDecisionPacket({
  msg,
  config,
  threadState,
  roomMessages = [],
  addressing = null,
}) {
  const history = Array.isArray(msg.channelContext) && msg.channelContext.length
    ? msg.channelContext.map((item) => ({
      id: item.id || null,
      // Platform labels like "[bot] Name#1234" don't tell the gate these
      // turns were the agent's own, so it reads follow-ups as meant for others.
      sender: item.mine ? 'assistant' : (item.author || item.sender || 'participant'),
      content: truncate(item.content, 280),
    }))
    : roomMessages.map((item) => ({ id: null, sender: item.sender, content: item.content }));
  // The platform history usually ends with the message being judged. It is
  // taken out so the gate sees it once, under the same name the history uses.
  const last = history[history.length - 1];
  const latestInHistory = Boolean(last) && (
    (last.id && msg.messageId ? String(last.id) === String(msg.messageId) : false)
    || truncate(last.content, 280) === truncate(msg.content, 280)
  );
  const recent = (latestInHistory ? history.slice(0, -1) : history)
    .slice(-12)
    .map(({ sender, content }) => ({ sender, content }));

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
      name: (latestInHistory ? last.sender : null)
        || msg.senderDisplayName || msg.senderName || msg.senderUsername || null,
      username: msg.senderUsername || null,
      tag: msg.senderTag || null,
    },
    event: {
      content: truncate(msg.content, 800),
      hasMedia: Boolean(msg.localMediaPath || msg.mediaType),
      mediaType: msg.mediaType || null,
      wasMentioned: msg.wasMentioned === true,
      repliedToAgent: msg.repliedToAgent === true,
      addressedByName: addressing?.addressedByName === true,
      replyTo: msg.replyTo?.content
        ? { sender: msg.replyTo.sender || 'participant', content: truncate(msg.replyTo.content, 280) }
        : null,
      timestamp: msg.timestamp || new Date().toISOString(),
    },
    room: {
      recentMessages: recent,
      secondsSinceAgentSpoke: secondsSinceSpoke,
      recentSilenceCount: Number(threadState?.recentSilenceCount || 0),
      agentNames: Array.isArray(addressing?.names) ? addressing.names.slice(0, 8) : [],
    },
    policy: {
      participationMode: config.participationMode || 'automatic',
      minimumNeedScore: Number(config.minimumNeedScore ?? 0.58),
      groupDefaultPosture: 'hold_side_chatter',
    },
  };
}

module.exports = {
  truncate,
  buildChannelScopeId,
  loadRecentRoomMessages,
  loadRecentSenderTexts,
  runDidWork,
  buildDecisionPacket,
};
