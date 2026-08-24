'use strict';

const { loadLatestContract } = require('../task_contract');
const { listNodes } = require('../work_graph');
const { loadLatestCheckpoint } = require('../checkpoint_service');
const { listEvents } = require('../events/run_event_store');

/**
 * Build a context view from durable state rather than raw transcript alone.
 */
function buildContextView({
  runId,
  systemPrompt = '',
  messages = [],
  evidencePacket = null,
  activeNodeIds = [],
  budgetSnapshot = null,
  maxRecentMessages = 40,
} = {}) {
  const contractRecord = runId ? loadLatestContract(runId) : null;
  const nodes = runId ? listNodes(runId) : [];
  const checkpoint = runId ? loadLatestCheckpoint(runId) : null;
  const recentEvents = runId
    ? listEvents(runId, { afterSequence: 0, limit: 40 }).slice(-20)
    : [];

  const activeNodes = nodes.filter((node) => activeNodeIds.includes(node.id) || activeNodeIds.includes(node.nodeKey));
  const openNodes = nodes.filter((node) => !['completed', 'skipped'].includes(node.status));

  const graphSummary = {
    total: nodes.length,
    completed: nodes.filter((n) => n.status === 'completed').length,
    open: openNodes.map((n) => ({
      key: n.nodeKey,
      kind: n.kind,
      status: n.status,
      objective: n.objective,
    })),
    active: activeNodes.map((n) => ({
      key: n.nodeKey,
      kind: n.kind,
      objective: n.objective,
      successCriteria: n.successCriteria,
    })),
  };

  const stableMessages = [];
  if (systemPrompt) {
    stableMessages.push({ role: 'system', content: systemPrompt });
  }

  if (contractRecord?.contract) {
    stableMessages.push({
      role: 'system',
      content: [
        '[Task contract]',
        `Goal: ${contractRecord.contract.goal}`,
        `Intent: ${contractRecord.contract.intent}`,
        `Complexity: ${contractRecord.contract.complexity}`,
        `Success criteria: ${(contractRecord.contract.success_criteria || []).join('; ') || 'n/a'}`,
        `Evidence requirements: ${(contractRecord.contract.evidence_requirements || []).join('; ') || 'n/a'}`,
        `Verification required: ${contractRecord.contract.verification_required ? 'yes' : 'no'}`,
      ].join('\n'),
    });
  }

  if (graphSummary.total > 0) {
    stableMessages.push({
      role: 'system',
      content: [
        '[Work graph]',
        `Progress: ${graphSummary.completed}/${graphSummary.total} nodes complete`,
        graphSummary.active.length
          ? `Active: ${graphSummary.active.map((n) => `${n.key} (${n.objective})`).join('; ')}`
          : 'Active: none',
        graphSummary.open.length
          ? `Open: ${graphSummary.open.map((n) => `${n.key}:${n.status}`).join(', ')}`
          : 'Open: none',
      ].join('\n'),
    });
  }

  if (evidencePacket) {
    stableMessages.push({
      role: 'system',
      content: `[Evidence packet]\n${JSON.stringify(evidencePacket, null, 2).slice(0, 6000)}`,
    });
  }

  if (budgetSnapshot?.usage) {
    stableMessages.push({
      role: 'system',
      content: `[Run telemetry]\n${JSON.stringify({
        elapsed_ms: Number(budgetSnapshot.usage.wallClockMs) || 0,
        model_turns: Number(budgetSnapshot.usage.modelTurns) || 0,
        input_tokens: Number(budgetSnapshot.usage.inputTokens) || 0,
        output_tokens: Number(budgetSnapshot.usage.outputTokens) || 0,
        tool_runtime_ms: Number(budgetSnapshot.usage.toolRuntimeMs) || 0,
      })}`,
    });
  }

  if (budgetSnapshot?.softLimitReached || budgetSnapshot?.hardLimitReached) {
    stableMessages.push({
      role: 'system',
      content: [
        '[Budget status]',
        budgetSnapshot.hardLimitReached
          ? `Hard limit dimensions: ${(budgetSnapshot.hardDimensions || []).join(', ')}`
          : `Soft limit dimensions: ${(budgetSnapshot.softDimensions || []).join(', ')}`,
        'Prefer narrowing scope, summarizing, or finishing with honest partial results if needed.',
      ].join('\n'),
    });
  }

  if (checkpoint?.state?.workingSummary) {
    stableMessages.push({
      role: 'system',
      content: `[Checkpoint working summary]\n${String(checkpoint.state.workingSummary).slice(0, 3000)}`,
    });
  }

  const recent = Array.isArray(messages) ? messages.slice(-maxRecentMessages) : [];
  // Keep non-system recent turns and tool pairs; system policy already injected above.
  const recentFiltered = recent.filter((msg, index) => {
    if (msg.role !== 'system') return true;
    // Keep late system steering messages.
    return index > 0;
  });

  return {
    messages: [...stableMessages, ...recentFiltered],
    contract: contractRecord?.contract || null,
    graphSummary,
    checkpoint,
    recentEvents: recentEvents.map((event) => ({
      type: event.eventType,
      sequence: event.sequenceIndex,
      at: event.createdAt,
    })),
  };
}

module.exports = {
  buildContextView,
};
