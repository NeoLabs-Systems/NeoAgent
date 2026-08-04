'use strict';

const { evaluateCompletionClaim } = require('./completion_gate');
const { reopenNodes, requiredOpenNodes } = require('./work_graph');
const { EVENT_TYPES, VISIBILITY } = require('./events/event_types');

/**
 * Layered verification. Failed checks produce repair results, not terminal failure.
 */
async function verifyRun({
  runId,
  contract,
  claim = {},
  evidence = [],
  artifacts = [],
  finalContent = '',
  finalDeliveryId = null,
  sideEffects = [],
  path = 'durable',
  semanticVerifier = null,
  eventBus = null,
  userId = null,
  agentId = null,
} = {}) {
  if (eventBus && userId) {
    eventBus.publish({
      runId,
      userId,
      agentId,
      eventType: EVENT_TYPES.VERIFICATION_STARTED,
      payload: { path },
      visibility: VISIBILITY.OPERATOR,
    });
  }

  const gate = evaluateCompletionClaim({
    runId,
    contract,
    claim,
    evidence,
    artifacts,
    finalContent,
    finalDeliveryId,
    sideEffects,
    path,
  });

  if (!gate.accepted) {
    const reopenKeys = gate.failures
      .map((failure) => failure.nodeKey || failure.nodeId || failure.obligation?.id)
      .filter(Boolean);
    const defects = gate.failures.map((failure) => ({
      severity: failure.code === 'critical_defects' ? 'critical' : 'major',
      criterion: failure.code,
      evidence: failure.message,
      suggested_next_actions: suggestActions(failure),
    }));

    if (reopenKeys.length > 0) {
      reopenNodes(runId, reopenKeys, defects);
    } else {
      // Reopen incomplete required nodes when gate fails without specific keys.
      const open = requiredOpenNodes(runId).map((node) => node.nodeKey);
      if (open.length > 0) reopenNodes(runId, open, defects);
    }

    if (eventBus && userId) {
      eventBus.publish({
        runId,
        userId,
        agentId,
        eventType: EVENT_TYPES.VERIFICATION_FAILED,
        payload: { failures: gate.failures, defects },
        visibility: VISIBILITY.OPERATOR,
      });
    }

    const repairable = defects.some((d) => d.severity !== 'blocker')
      && !gate.failures.some((f) => f.code === 'final_already_committed');

    return {
      status: repairable ? 'repair_required' : 'blocked',
      gate,
      defects,
      reopen_nodes: reopenKeys,
      final_reply: finalContent,
    };
  }

  if (typeof semanticVerifier === 'function') {
    try {
      const semantic = await semanticVerifier({
        finalContent: gate.claim.summary || finalContent,
        evidence,
        contract,
      });
      if (semantic && semantic.status && semantic.status !== 'verified') {
        const defects = (semantic.defects || [{
          severity: 'major',
          criterion: 'semantic_verification',
          evidence: semantic.reason || 'Semantic verification rejected the reply',
          suggested_next_actions: ['gather more evidence', 'rewrite unsupported claims'],
        }]);
        const reopen = semantic.reopen_nodes || ['execute', 'verify'];
        reopenNodes(runId, reopen, defects);
        if (eventBus && userId) {
          eventBus.publish({
            runId,
            userId,
            agentId,
            eventType: EVENT_TYPES.VERIFICATION_FAILED,
            payload: { semantic: true, defects },
            visibility: VISIBILITY.OPERATOR,
          });
        }
        return {
          status: 'repair_required',
          gate,
          defects,
          reopen_nodes: reopen,
          final_reply: semantic.final_reply || finalContent,
        };
      }
      if (semantic?.final_reply) {
        return {
          status: 'verified',
          gate,
          defects: [],
          final_reply: semantic.final_reply,
        };
      }
    } catch (error) {
      // Semantic verifier is best-effort after deterministic gate passes.
      return {
        status: 'verified',
        gate,
        defects: [],
        final_reply: finalContent,
        semanticError: error?.message || String(error),
      };
    }
  }

  return {
    status: 'verified',
    gate,
    defects: [],
    final_reply: gate.claim.summary || finalContent,
  };
}

function suggestActions(failure) {
  switch (failure.code) {
    case 'open_work_node':
      return ['resume node', 'collect missing evidence', 'mark blockers explicitly'];
    case 'open_obligation':
      return ['satisfy obligation', 'gather required evidence'];
    case 'unknown_side_effects':
      return ['verify external state', 'do not blind-retry'];
    case 'missing_final_content':
      return ['compose final answer from evidence'];
    case 'critical_defects':
      return ['inspect failing criterion', 'repair producing node'];
    default:
      return ['inspect verification failure', 'repair and retry'];
  }
}

module.exports = {
  verifyRun,
  suggestActions,
};
