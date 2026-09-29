'use strict';

const { DECISION_KINDS } = require('./constants');

function asArray(value) {
  return Array.isArray(value) ? value : [];
}

/**
 * Normalize tool calls into a stable internal shape.
 *
 * Providers and intermediate passes often re-run this on already-normalized
 * calls. Always re-emit an OpenAI wire-format `raw` with `.function.name` so
 * assistant history can be converted by every provider on the next turn.
 */
function normalizeToolCalls(toolCalls) {
  return asArray(toolCalls).map((call, index) => {
    if (!call || typeof call !== 'object') return null;
    // Prefer nested function, then flat name/arguments, then a nested raw
    // left over from a prior normalizeToolCalls pass.
    const priorRaw = call.raw && typeof call.raw === 'object' ? call.raw : null;
    const priorFn = priorRaw?.function && typeof priorRaw.function === 'object'
      ? priorRaw.function
      : null;
    const fn = (call.function && typeof call.function === 'object')
      ? call.function
      : (priorFn || call);
    let args = fn.arguments !== undefined ? fn.arguments : call.arguments;
    if (typeof args === 'string') {
      try {
        args = JSON.parse(args || '{}');
      } catch (error) {
        // Keep only a preview: the full string can be tens of KB of runaway
        // output, and everything stored here is replayed into later prompts.
        args = {
          _raw_preview: args.slice(0, 400),
          _raw_length: args.length,
          _parse_error: String(error.message || error),
        };
      }
    }
    if (args == null || typeof args !== 'object' || Array.isArray(args)) {
      args = {};
    }
    const name = String(fn.name || call.name || priorFn?.name || '').trim();
    if (!name) return null;
    const id = String(call.id || priorRaw?.id || `call_${index + 1}`);
    const thoughtSignature = fn.thought_signature || call.thought_signature || priorFn?.thought_signature;
    const wire = {
      id,
      type: 'function',
      function: {
        name,
        arguments: JSON.stringify(args),
        ...(thoughtSignature ? { thought_signature: thoughtSignature } : {}),
      },
    };
    return {
      id,
      name,
      arguments: args,
      // Always OpenAI wire shape so later model turns never hit missing .function.
      raw: wire,
    };
  }).filter(Boolean);
}

// A model turn is either work or the answer. Tool calls are work; text
// without tool calls is the final answer, written for the user. An empty turn
// is neither and is recovered by the loop.
function decisionFromModelResponse(response = {}) {
  const content = String(response.content || '').trim();
  const toolCalls = normalizeToolCalls(response.tool_calls || response.toolCalls || []);
  if (toolCalls.length > 0) return { kind: DECISION_KINDS.ACT, content, toolCalls };
  if (content) return { kind: DECISION_KINDS.ANSWER, content, toolCalls: [] };
  return { kind: DECISION_KINDS.BLANK, content: '', toolCalls: [] };
}

module.exports = {
  decisionFromModelResponse,
  normalizeToolCalls,
  DECISION_KINDS,
};
