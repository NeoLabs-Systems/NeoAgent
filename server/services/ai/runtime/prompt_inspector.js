'use strict';

const db = require('../../../db/database');

/**
 * Read side of the run captures: the exact messages and tools of the model
 * requests a run kept, which is what the run inspector shows as "the full
 * prompt" — system prompt, recalled memory, history, and user message.
 */

function renderBlock(block) {
  if (typeof block === 'string') return block;
  if (!block || typeof block !== 'object') return '';
  if (block.type === 'text' && typeof block.text === 'string') return block.text;
  return JSON.stringify(block, null, 2);
}

function renderContent(message) {
  const parts = [];
  const content = message?.content;
  if (typeof content === 'string') {
    parts.push(content);
  } else if (Array.isArray(content)) {
    parts.push(...content.map(renderBlock).filter(Boolean));
  } else if (content) {
    parts.push(JSON.stringify(content, null, 2));
  }
  if (Array.isArray(message?.tool_calls) && message.tool_calls.length) {
    parts.push(`[Tool calls]\n${JSON.stringify(message.tool_calls, null, 2)}`);
  }
  return parts.join('\n\n');
}

function sectionLabel(message, index) {
  const role = String(message?.role || 'unknown');
  if (role === 'system') {
    const text = typeof message.content === 'string' ? message.content.trimStart() : '';
    const tag = text.startsWith('[') ? text.slice(1, text.indexOf(']')) : '';
    if (tag && tag.length <= 80) return tag;
    return index === 0 ? 'System prompt' : 'System';
  }
  if (role === 'user') return 'User message';
  if (role === 'assistant') return 'Assistant turn';
  if (role === 'tool') return `Tool result${message.name ? ` — ${message.name}` : ''}`;
  return role;
}

function parseRequest(row) {
  try {
    return JSON.parse(row.payload_json || '{}');
  } catch {
    return {};
  }
}

function turnSummary(row, sequenceIndex) {
  const request = parseRequest(row);
  const header = request.header || {};
  const messages = Array.isArray(request.messages) ? request.messages : [];
  const tools = Array.isArray(request.tools) ? request.tools : [];
  return {
    requestId: row.request_id,
    sequenceIndex,
    createdAt: row.created_at,
    captureReason: row.reason || null,
    phase: row.phase || header.phase || 'model_turn',
    iteration: Number(row.iteration) || 0,
    provider: row.provider || header.provider || null,
    model: row.model || header.model || null,
    maxTokens: Number(header.maxTokens) || 0,
    reasoningEffort: header.reasoningEffort || null,
    messageCount: messages.length,
    toolCount: tools.length,
    characters: messages.reduce((total, message) => total + renderContent(message).length, 0),
  };
}

function listRunPromptTurns(runId) {
  return db.prepare(
    `SELECT request_id, phase, iteration, provider, model, reason, payload_json, created_at
     FROM agent_run_captures
     WHERE run_id = ? AND datetime(expires_at) > datetime('now')
     ORDER BY id ASC`,
  ).all(runId).map((row, index) => turnSummary(row, index + 1));
}

function getRunPromptTurn(runId, requestId) {
  const row = db.prepare(
    'SELECT request_id, payload_json FROM agent_run_captures WHERE run_id = ? AND request_id = ?',
  ).get(runId, requestId);
  if (!row) {
    const error = new Error(`Model request ${requestId} was not captured for this run.`);
    error.code = 'MODEL_REQUEST_NOT_CAPTURED';
    throw error;
  }
  const request = parseRequest(row);
  const messages = Array.isArray(request.messages) ? request.messages : [];
  const tools = Array.isArray(request.tools) ? request.tools : [];
  return {
    requestId,
    header: request.header,
    sections: messages.map((message, index) => {
      const text = renderContent(message);
      return {
        role: String(message?.role || 'unknown'),
        label: sectionLabel(message, index),
        text,
        characters: text.length,
      };
    }),
    tools: tools.map((tool) => ({
      name: tool?.name || tool?.function?.name || 'tool',
      description: String(tool?.description || tool?.function?.description || '').split('\n')[0],
    })),
  };
}

module.exports = {
  listRunPromptTurns,
  getRunPromptTurn,
};
