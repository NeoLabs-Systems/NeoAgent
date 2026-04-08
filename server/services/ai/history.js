const db = require('../../db/database');
const { resolveAgentId } = require('../agents/manager');

const WEB_SUMMARY_KEY = 'web_chat_summary';
const WEB_SUMMARY_COUNT_KEY = 'web_chat_summary_count';
const SUMMARY_TRIGGER_COUNT = 12;
const MAX_SUMMARY_CHARS = 6000;

function clampSummary(text) {
  const str = String(text || '').trim();
  if (!str) return '';
  if (str.length <= MAX_SUMMARY_CHARS) return str;
  return `${str.slice(0, MAX_SUMMARY_CHARS)}\n...[summary trimmed]`;
}

function buildSummaryCarrier(summary) {
  if (!summary) return null;
  return {
    role: 'system',
    content: `[Conversation summary]\n${clampSummary(summary)}`
  };
}

function normalizeHistoryRows(rows) {
  return rows.map((msg) => {
    const out = { role: msg.role, content: msg.content || '' };
    if (msg.tool_calls) {
      try {
        out.tool_calls = JSON.parse(msg.tool_calls);
      } catch { }
    }
    if (msg.tool_call_id) out.tool_call_id = msg.tool_call_id;
    if (msg.name) out.name = msg.name;
    return out;
  });
}

function sanitizeConversationMessages(messages) {
  const sanitized = [];
  let pendingToolSequence = null;

  const dropPendingSequence = () => {
    pendingToolSequence = null;
  };

  const flushPendingSequence = () => {
    if (!pendingToolSequence) return;
    if (pendingToolSequence.pendingIds.size === 0) {
      sanitized.push(...pendingToolSequence.messages);
    }
    pendingToolSequence = null;
  };

  for (const msg of messages || []) {
    if (!msg || !msg.role) continue;

    if (msg.role === 'assistant' && Array.isArray(msg.tool_calls) && msg.tool_calls.length > 0) {
      const toolCallIds = msg.tool_calls
        .map((toolCall) => toolCall?.id)
        .filter(Boolean);

      if (toolCallIds.length === 0) {
        dropPendingSequence();
        sanitized.push(msg);
        continue;
      }

      dropPendingSequence();
      pendingToolSequence = {
        messages: [msg],
        pendingIds: new Set(toolCallIds)
      };
      continue;
    }

    if (msg.role === 'tool') {
      if (
        pendingToolSequence
        && msg.tool_call_id
        && pendingToolSequence.pendingIds.has(msg.tool_call_id)
      ) {
        pendingToolSequence.messages.push(msg);
        pendingToolSequence.pendingIds.delete(msg.tool_call_id);
        if (pendingToolSequence.pendingIds.size === 0) {
          flushPendingSequence();
        }
      }
      continue;
    }

    dropPendingSequence();
    sanitized.push(msg);
  }

  flushPendingSequence();
  return sanitized;
}

function serializeHistoryForSummary(messages) {
  return messages.map((msg) => {
    if (msg.role === 'tool') {
      return `tool:${msg.name || 'tool'} ${String(msg.content || '').slice(0, 320)}`;
    }
    if (msg.role === 'assistant' && msg.tool_calls?.length) {
      const toolNames = msg.tool_calls.map((tc) => tc.function?.name).filter(Boolean).join(', ');
      return `assistant(tool_calls:${toolNames}) ${String(msg.content || '').slice(0, 320)}`;
    }
    return `${msg.role}: ${String(msg.content || '').slice(0, 400)}`;
  }).join('\n');
}

async function summarizeMessages(provider, model, existingSummary, messages, label = 'conversation') {
  if (!messages.length) return existingSummary || '';

  const prompt = [
    {
      role: 'system',
      content: 'Compress conversation context. Preserve user goals, constraints, preferences, decisions, promised follow-ups, recurring schedules, important facts, tool outcomes, and unresolved issues. Keep concrete details (names, dates, times, statuses) and avoid vague wording. Keep the same personality context. Output plain text only.'
    },
    {
      role: 'user',
      content: [
        existingSummary ? `Existing summary:\n${clampSummary(existingSummary)}` : 'Existing summary: none',
        `New ${label} messages:\n${serializeHistoryForSummary(messages)}`,
        'Write an updated summary in under 420 words. Include a short section for "Open commitments" when applicable.'
      ].join('\n\n')
    }
  ];

  const response = await provider.chat(prompt, [], { model, maxTokens: 900 });
  return clampSummary(response.content || existingSummary || '');
}

function getWebChatSummaryState(userId, agentId = null) {
  const scopedAgentId = resolveAgentId(userId, agentId);
  const rows = db.prepare(
    'SELECT key, value FROM agent_settings WHERE user_id = ? AND agent_id = ? AND key IN (?, ?)'
  ).all(userId, scopedAgentId, WEB_SUMMARY_KEY, WEB_SUMMARY_COUNT_KEY);

  let summary = '';
  let count = 0;

  for (const row of rows) {
    let value = row.value;
    try {
      value = JSON.parse(row.value);
    } catch { }

    if (row.key === WEB_SUMMARY_KEY) summary = clampSummary(value || '');
    if (row.key === WEB_SUMMARY_COUNT_KEY) count = Number(value || 0);
  }

  return { summary, count };
}

function getWebChatContext(userId, recentLimit, options = {}) {
  const agentId = resolveAgentId(userId, options.agentId || options.agent_id || null);
  const state = getWebChatSummaryState(userId, agentId);
  const recent = db.prepare(
    'SELECT role, content FROM conversation_history WHERE user_id = ? AND agent_id = ? ORDER BY created_at DESC LIMIT ?'
  ).all(userId, agentId, recentLimit).reverse();

  return {
    summary: state.summary,
    summaryCount: state.count,
    recentMessages: normalizeHistoryRows(recent),
    totalMessages: db.prepare('SELECT COUNT(*) AS count FROM conversation_history WHERE user_id = ? AND agent_id = ?').get(userId, agentId).count
  };
}

async function refreshWebChatSummary(userId, provider, model, recentLimit, force = false, options = {}) {
  const agentId = resolveAgentId(userId, options.agentId || options.agent_id || null);
  const totalMessages = db.prepare('SELECT COUNT(*) AS count FROM conversation_history WHERE user_id = ? AND agent_id = ?').get(userId, agentId).count;
  const { summary, count } = getWebChatSummaryState(userId, agentId);
  const targetCount = Math.max(0, totalMessages - recentLimit);
  const newMessages = targetCount - count;

  if (targetCount <= count || (!force && newMessages < SUMMARY_TRIGGER_COUNT)) {
    return { updated: false, summary, summaryCount: count };
  }

  const rows = db.prepare(
    'SELECT role, content FROM conversation_history WHERE user_id = ? AND agent_id = ? ORDER BY created_at ASC LIMIT ? OFFSET ?'
  ).all(userId, agentId, newMessages, count);

  const nextSummary = clampSummary(await summarizeMessages(provider, model, summary, normalizeHistoryRows(rows), 'web chat'));
  const upsert = db.prepare(
    'INSERT INTO agent_settings (user_id, agent_id, key, value) VALUES (?, ?, ?, ?) ON CONFLICT(user_id, agent_id, key) DO UPDATE SET value = excluded.value'
  );
  upsert.run(userId, agentId, WEB_SUMMARY_KEY, JSON.stringify(nextSummary));
  upsert.run(userId, agentId, WEB_SUMMARY_COUNT_KEY, JSON.stringify(targetCount));
  return { updated: true, summary: nextSummary, summaryCount: targetCount };
}

function clearWebChatSummary(userId, options = {}) {
  const agentId = resolveAgentId(userId, options.agentId || options.agent_id || null);
  db.prepare('DELETE FROM agent_settings WHERE user_id = ? AND agent_id = ? AND key IN (?, ?)').run(userId, agentId, WEB_SUMMARY_KEY, WEB_SUMMARY_COUNT_KEY);
}

function getConversationContext(conversationId, recentLimit) {
  const convo = db.prepare(
    'SELECT summary, summary_message_count FROM conversations WHERE id = ?'
  ).get(conversationId);

  const recent = db.prepare(
    'SELECT role, content, tool_calls, tool_call_id, name FROM conversation_messages WHERE conversation_id = ? ORDER BY created_at DESC LIMIT ?'
  ).all(conversationId, recentLimit).reverse();

  return {
    summary: convo?.summary || '',
    summaryCount: Number(convo?.summary_message_count || 0),
    recentMessages: sanitizeConversationMessages(normalizeHistoryRows(recent)),
    totalMessages: db.prepare('SELECT COUNT(*) AS count FROM conversation_messages WHERE conversation_id = ?').get(conversationId).count
  };
}

async function refreshConversationSummary(conversationId, provider, model, recentLimit, force = false) {
  const convo = db.prepare(
    'SELECT summary, summary_message_count FROM conversations WHERE id = ?'
  ).get(conversationId);
  if (!convo) return { updated: false, summary: '', summaryCount: 0 };

  const totalMessages = db.prepare('SELECT COUNT(*) AS count FROM conversation_messages WHERE conversation_id = ?').get(conversationId).count;
  const currentCount = Number(convo.summary_message_count || 0);
  const targetCount = Math.max(0, totalMessages - recentLimit);
  const newMessages = targetCount - currentCount;

  if (targetCount <= currentCount || (!force && newMessages < SUMMARY_TRIGGER_COUNT)) {
    return { updated: false, summary: convo.summary || '', summaryCount: currentCount };
  }

  const rows = db.prepare(
    'SELECT role, content, tool_calls, tool_call_id, name FROM conversation_messages WHERE conversation_id = ? ORDER BY created_at ASC LIMIT ? OFFSET ?'
  ).all(conversationId, newMessages, currentCount);

  const nextSummary = clampSummary(await summarizeMessages(provider, model, convo.summary || '', normalizeHistoryRows(rows), 'thread'));
  db.prepare(
    "UPDATE conversations SET summary = ?, summary_message_count = ?, last_summary = datetime('now') WHERE id = ?"
  ).run(nextSummary, targetCount, conversationId);
  return { updated: true, summary: nextSummary, summaryCount: targetCount };
}

module.exports = {
  SUMMARY_TRIGGER_COUNT,
  MAX_SUMMARY_CHARS,
  buildSummaryCarrier,
  clampSummary,
  clearWebChatSummary,
  getConversationContext,
  getWebChatContext,
  refreshConversationSummary,
  refreshWebChatSummary,
  sanitizeConversationMessages,
  summarizeMessages
};
