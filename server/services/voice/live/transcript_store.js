'use strict';

const db = require('../../../db/database');

// A spoken turn is stored exactly like a typed one: in the web chat history the
// app renders, and in the conversation thread that later runs load as context.
function recordVoiceTurn({ userId, agentId, conversationId, sessionId, role, content }) {
  const text = String(content || '').trim();
  if (!text) return;
  const metadata = JSON.stringify({ platform: 'voice_live', sessionId });
  db.prepare(
    `INSERT INTO conversation_history (
      user_id, agent_id, conversation_id, role, content, metadata
    ) VALUES (?, ?, ?, ?, ?, ?)`,
  ).run(userId, agentId, conversationId || null, role, text, metadata);
  if (!conversationId) return;
  db.prepare(
    `INSERT INTO conversation_messages (
      conversation_id, agent_id, role, content, metadata_json
    ) VALUES (?, ?, ?, ?, ?)`,
  ).run(conversationId, agentId, role, text, metadata);
}

// A hand-off that finishes after the call ended is not spoken; like a web chat
// run, its reply joins the chat history (the run itself already stored it in
// the conversation thread).
function recordTaskReply({ userId, agentId, conversationId, runId, content }) {
  db.prepare(
    `INSERT INTO conversation_history (
      user_id, agent_id, agent_run_id, conversation_id, role, content, metadata
    ) VALUES (?, ?, ?, ?, 'assistant', ?, ?)`,
  ).run(userId, agentId, runId, conversationId || null, content, JSON.stringify({ platform: 'voice_live' }));
}

module.exports = {
  recordTaskReply,
  recordVoiceTurn,
};
