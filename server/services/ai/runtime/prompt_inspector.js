'use strict';

const { EVENT_TYPES } = require('./events/event_types');
const { listEventsByType } = require('./events/run_event_store');
const { reconstructModelRequest } = require('./model_request_journal');

/**
 * Read side of the model request journal: every provider call is recorded with
 * its exact messages and tools, which is what the run inspector shows as "the
 * full prompt" — system prompt, recalled memory, history, and user message.
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

function turnSummary(event) {
  const request = event.payload?.request || {};
  const header = request.header || {};
  const messages = Array.isArray(request.messages) ? request.messages : [];
  const tools = Array.isArray(request.tools) ? request.tools : [];
  return {
    requestId: event.payload?.request_id || event.requestId || null,
    digest: event.payload?.digest || null,
    sequenceIndex: event.sequenceIndex,
    createdAt: event.createdAt,
    phase: header.phase || 'model_turn',
    iteration: Number(header.iteration) || 0,
    provider: header.provider || null,
    model: header.model || null,
    maxTokens: Number(header.maxTokens) || 0,
    reasoningEffort: header.reasoningEffort || null,
    messageCount: messages.length,
    toolCount: tools.length,
    characters: messages.reduce((total, message) => total + renderContent(message).length, 0),
  };
}

function listRunPromptTurns(runId) {
  return listEventsByType(runId, EVENT_TYPES.MODEL_REQUEST_RECORDED).map(turnSummary);
}

function getRunPromptTurn(runId, requestId) {
  const request = reconstructModelRequest(runId, requestId);
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
