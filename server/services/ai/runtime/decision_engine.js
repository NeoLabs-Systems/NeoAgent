'use strict';

const { DECISION_KINDS } = require('./constants');

const VALID_KINDS = new Set(Object.values(DECISION_KINDS));

function asArray(value) {
  return Array.isArray(value) ? value : [];
}

function normalizeConfidence(value) {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return Math.max(0, Math.min(1, value));
  }
  const label = String(value || '').trim().toLowerCase();
  if (label === 'high') return 0.9;
  if (label === 'medium') return 0.75;
  if (label === 'low') return 0.55;
  const parsed = Number(value);
  if (Number.isFinite(parsed)) return Math.max(0, Math.min(1, parsed));
  return 0.7;
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
      } catch {
        args = { _raw: args };
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

/**
 * Convert a model response into a typed AgentDecision.
 * Prose never substitutes for the protocol.
 */
function decisionFromModelResponse(response = {}, context = {}) {
  const content = String(response.content || '').trim();
  const toolCalls = normalizeToolCalls(response.tool_calls || response.toolCalls || []);

  if (toolCalls.length > 0) {
    const taskComplete = toolCalls.find((call) => call.name === 'task_complete');
    if (taskComplete && toolCalls.length === 1) {
      const args = taskComplete.arguments || {};
      // Tool schema uses `message`; models also emit summary/result aliases.
      const summary = String(
        args.message
        || args.summary
        || args.result
        || content
        || 'Task complete',
      ).trim();
      return validateDecision({
        kind: DECISION_KINDS.COMPLETE,
        completionClaim: {
          summary,
          confidence: normalizeConfidence(args.confidence),
          evidence_ids: asArray(args.evidence_ids || args.evidenceIds),
        },
        content: content || summary,
        toolCalls,
      });
    }

    const sendMessage = toolCalls.find((call) => call.name === 'send_message');
    if (sendMessage && toolCalls.every((call) => call.name === 'send_message' || call.name === 'task_complete')) {
      // Messaging delivery is still an act; finalization is owned by completion gate + outbox.
      // For background runs, purpose=final_result|blocker|no_response is an explicit terminal intent.
      const purpose = String(sendMessage.arguments?.purpose || '').trim().toLowerCase();
      const terminalSend = purpose === 'final_result'
        || purpose === 'blocker'
        || purpose === 'no_response';
      return validateDecision({
        kind: DECISION_KINDS.ACT,
        nodeId: context.nodeId || null,
        toolCalls,
        content: content || String(
          sendMessage.arguments?.content
          || sendMessage.arguments?.message
          || sendMessage.arguments?.text
          || '',
        ).trim(),
        terminalHint: Boolean(taskComplete) || terminalSend,
      });
    }

    return validateDecision({
      kind: DECISION_KINDS.ACT,
      nodeId: context.nodeId || null,
      toolCalls,
      content,
    });
  }

  if (!content) {
    return validateDecision({
      kind: DECISION_KINDS.BLOCK,
      blocker: {
        code: 'blank_model_output',
        message: 'Model returned no content and no tool calls',
      },
    });
  }

  // Intent-to-continue prose is not completion.
  if (/^(i('| a)?m going to|i will|let me|i'll)\b/i.test(content) && content.length < 280) {
    return validateDecision({
      kind: DECISION_KINDS.ACT,
      nodeId: context.nodeId || null,
      toolCalls: [],
      content,
      protocolNote: 'continuation_intent_not_complete',
    });
  }

  if (context.forceComplete === true) {
    return validateDecision({
      kind: DECISION_KINDS.COMPLETE,
      completionClaim: {
        summary: content,
        confidence: 0.6,
        evidence_ids: [],
      },
      content,
      terminal: true,
    });
  }

  return validateDecision({
    kind: DECISION_KINDS.RESPOND,
    content,
    terminal: context.expectTerminalResponse === true,
  });
}

function validateDecision(raw = {}) {
  const kind = String(raw.kind || '').trim();
  if (!VALID_KINDS.has(kind)) {
    return {
      ok: false,
      error: 'unknown_decision_kind',
      decision: null,
      raw,
    };
  }

  const decision = {
    kind,
    content: raw.content != null ? String(raw.content) : '',
    nodeId: raw.nodeId || null,
    toolCalls: normalizeToolCalls(raw.toolCalls || []),
    completionClaim: raw.completionClaim || null,
    blocker: raw.blocker || null,
    terminal: raw.terminal === true,
    terminalHint: raw.terminalHint === true,
    protocolNote: raw.protocolNote || null,
    createdAt: new Date().toISOString(),
  };

  if (kind === DECISION_KINDS.ACT && decision.toolCalls.length === 0 && !decision.protocolNote) {
    // Empty act is allowed only as a protocol-repair signal; mark invalid otherwise.
    return {
      ok: false,
      error: 'act_without_tools',
      decision: null,
      raw: decision,
    };
  }

  if (kind === DECISION_KINDS.COMPLETE && !decision.completionClaim) {
    return {
      ok: false,
      error: 'complete_without_claim',
      decision: null,
      raw: decision,
    };
  }

  if (kind === DECISION_KINDS.RESPOND && !decision.content.trim()) {
    return {
      ok: false,
      error: 'respond_without_content',
      decision: null,
      raw: decision,
    };
  }

  return { ok: true, decision, error: null };
}

function protocolRepairDecision(error, previousRaw = {}) {
  return {
    ok: true,
    decision: {
      kind: DECISION_KINDS.RESPOND,
      content: '',
      nodeId: null,
      toolCalls: [],
      terminal: false,
      protocolNote: `protocol_repair:${error}`,
      repairHint: [
        'Your previous output was not a valid typed decision.',
        `Error: ${error}.`,
        'Call tools using the tool protocol, or provide a complete final answer.',
        'Do not write fake tool-call syntax as plain text.',
      ].join(' '),
      previousRaw,
      createdAt: new Date().toISOString(),
    },
    error: null,
  };
}

module.exports = {
  DECISION_KINDS,
  decisionFromModelResponse,
  validateDecision,
  protocolRepairDecision,
  normalizeToolCalls,
};
