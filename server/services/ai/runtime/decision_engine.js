'use strict';

const { DECISION_KINDS } = require('./constants');

const VALID_KINDS = new Set(Object.values(DECISION_KINDS));

function asArray(value) {
  return Array.isArray(value) ? value : [];
}

function normalizeToolCalls(toolCalls) {
  return asArray(toolCalls).map((call, index) => {
    const fn = call?.function || call || {};
    let args = fn.arguments;
    if (typeof args === 'string') {
      try {
        args = JSON.parse(args || '{}');
      } catch {
        args = { _raw: args };
      }
    }
    return {
      id: call.id || `call_${index + 1}`,
      name: String(fn.name || call.name || '').trim(),
      arguments: args && typeof args === 'object' ? args : {},
      raw: call,
    };
  }).filter((call) => call.name);
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
      return validateDecision({
        kind: DECISION_KINDS.COMPLETE,
        completionClaim: {
          summary: taskComplete.arguments?.summary || content || 'Task complete',
          confidence: Number(taskComplete.arguments?.confidence) || 0.7,
          evidence_ids: asArray(taskComplete.arguments?.evidence_ids),
        },
        content,
        toolCalls,
      });
    }

    const sendMessage = toolCalls.find((call) => call.name === 'send_message');
    if (sendMessage && toolCalls.every((call) => call.name === 'send_message' || call.name === 'task_complete')) {
      // Messaging delivery is still an act; finalization is owned by completion gate + outbox.
      return validateDecision({
        kind: DECISION_KINDS.ACT,
        nodeId: context.nodeId || null,
        toolCalls,
        content,
        terminalHint: Boolean(taskComplete),
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
    assignments: asArray(raw.assignments),
    reason: raw.reason || null,
    patch: raw.patch || null,
    resourceId: raw.resourceId || null,
    wakeCondition: raw.wakeCondition || null,
    question: raw.question || null,
    blocking: raw.blocking === true,
    nodeIds: asArray(raw.nodeIds).map(String),
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
