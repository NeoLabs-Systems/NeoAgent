const db = require('../../db/database');

const WEB_SUMMARY_KEY = 'web_chat_summary';
const WEB_SUMMARY_COUNT_KEY = 'web_chat_summary_count';
const SUMMARY_TRIGGER_COUNT = 6;
const MAX_SUMMARY_CHARS = 1600;

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
      content: 'Compress conversation context. Preserve user goals, constraints, preferences, decisions, important facts, tool outcomes, and unresolved issues. Keep the same personality context. Output plain text only.'
    },
    {
      role: 'user',
      content: [
        existingSummary ? `Existing summary:\n${clampSummary(existingSummary)}` : 'Existing summary: none',
        `New ${label} messages:\n${serializeHistoryForSummary(messages)}`,
        'Write an updated summary in under 220 words.'
      ].join('\n\n')
    }
  ];

  const response = await provider.chat(prompt, [], { model, maxTokens: 320 });
  return clampSummary(response.content || existingSummary || '');
}

function getWebChatSummaryState(userId) {
  const rows = db.prepare(
    'SELECT key, value FROM user_settings WHERE user_id = ? AND key IN (?, ?)'
  ).all(userId, WEB_SUMMARY_KEY, WEB_SUMMARY_COUNT_KEY);

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

function getWebChatContext(userId, recentLimit) {
  const state = getWebChatSummaryState(userId);
  const recent = db.prepare(
    'SELECT role, content FROM conversation_history WHERE user_id = ? ORDER BY created_at DESC LIMIT ?'
  ).all(userId, recentLimit).reverse();

  return {
    summary: state.summary,
    summaryCount: state.count,
    recentMessages: normalizeHistoryRows(recent),
    totalMessages: db.prepare('SELECT COUNT(*) AS count FROM conversation_history WHERE user_id = ?').get(userId).count
  };
}

async function refreshWebChatSummary(userId, provider, model, recentLimit, force = false) {
  const totalMessages = db.prepare('SELECT COUNT(*) AS count FROM conversation_history WHERE user_id = ?').get(userId).count;
  const { summary, count } = getWebChatSummaryState(userId);
  const targetCount = Math.max(0, totalMessages - recentLimit);
  const newMessages = targetCount - count;

  if (targetCount <= count || (!force && newMessages < SUMMARY_TRIGGER_COUNT)) {
    return { updated: false, summary, summaryCount: count };
  }

  const rows = db.prepare(
    'SELECT role, content FROM conversation_history WHERE user_id = ? ORDER BY created_at ASC LIMIT ? OFFSET ?'
  ).all(userId, newMessages, count);

  const nextSummary = clampSummary(await summarizeMessages(provider, model, summary, normalizeHistoryRows(rows), 'web chat'));
  const upsert = db.prepare(
    'INSERT INTO user_settings (user_id, key, value) VALUES (?, ?, ?) ON CONFLICT(user_id, key) DO UPDATE SET value = excluded.value'
  );
  upsert.run(userId, WEB_SUMMARY_KEY, JSON.stringify(nextSummary));
  upsert.run(userId, WEB_SUMMARY_COUNT_KEY, JSON.stringify(targetCount));
  return { updated: true, summary: nextSummary, summaryCount: targetCount };
}

function clearWebChatSummary(userId) {
  db.prepare('DELETE FROM user_settings WHERE user_id = ? AND key IN (?, ?)').run(userId, WEB_SUMMARY_KEY, WEB_SUMMARY_COUNT_KEY);
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
    recentMessages: normalizeHistoryRows(recent),
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
  summarizeMessages
};
