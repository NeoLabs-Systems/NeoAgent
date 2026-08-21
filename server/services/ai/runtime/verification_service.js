'use strict';

const { evaluateCompletionClaim } = require('./completion_gate');
const { listNodes, reopenNodes, requiredOpenNodes } = require('./work_graph');
const { EVENT_TYPES, VISIBILITY } = require('./events/event_types');
const { buildVerificationFingerprint } = require('./verification_fingerprint');

/**
 * Layered verification. Failed checks produce repair results, not terminal failure.
 */
async function verifyRun({
  runId,
  contract,
  contractVersion = 0,
  claim = {},
  evidence = [],
  artifacts = [],
  finalContent = '',
  finalDeliveryId = null,
  sideEffects = [],
  path = 'durable',
  semanticVerifier = null,
  previousSemanticFailure = null,
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
    const fingerprint = buildVerificationFingerprint({
      contractVersion: contractVersion || contract?.version || contract?.contract_version || 0,
      finalContent: gate.claim.summary || finalContent,
      nodes: listNodes(runId),
      evidence,
      artifacts,
      sideEffects,
    });
    if (previousSemanticFailure?.fingerprint === fingerprint) {
      if (eventBus && userId) {
        eventBus.publish({
          runId,
          userId,
          agentId,
          eventType: EVENT_TYPES.VERIFICATION_UNCHANGED,
          payload: {
            fingerprint,
            defects: previousSemanticFailure.defects || [],
          },
          visibility: VISIBILITY.OPERATOR,
        });
      }
      return {
        status: 'repair_required',
        gate,
        defects: previousSemanticFailure.defects || [],
        reopen_nodes: previousSemanticFailure.reopen_nodes || [],
        final_reply: previousSemanticFailure.final_reply || finalContent,
        fingerprint,
        unchanged: true,
        semanticFailure: previousSemanticFailure,
      };
    }
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
        const semanticFailure = {
          fingerprint,
          defects,
          reopen_nodes: reopen,
          final_reply: semantic.final_reply || finalContent,
        };
        return {
          status: 'repair_required',
          gate,
          defects,
          reopen_nodes: reopen,
          final_reply: semantic.final_reply || finalContent,
          fingerprint,
          semanticFailure,
        };
      }
      if (semantic?.final_reply) {
        return {
          status: 'verified',
          gate,
          defects: [],
          final_reply: semantic.final_reply,
          fingerprint,
        };
      }
    } catch (error) {
      // A requested semantic check is part of the completion contract. Failing
      // open here turns a verifier outage or malformed verifier response into a
      // false claim of success. Reopen the work instead; the orchestrator bounds
      // repair attempts and will deliver an honest partial result if it persists.
      const message = error?.message || String(error);
      const defects = [{
        severity: 'major',
        criterion: 'semantic_verifier_unavailable',
        evidence: `Semantic verification failed: ${message}`,
        suggested_next_actions: ['retry verification', 'preserve uncertainty if verification remains unavailable'],
      }];
      const reopen = ['execute', 'verify'];
      reopenNodes(runId, reopen, defects);
      const semanticFailure = {
        fingerprint,
        defects,
        reopen_nodes: reopen,
        final_reply: finalContent,
      };
      return {
        status: 'repair_required',
        gate,
        defects,
        reopen_nodes: reopen,
        final_reply: finalContent,
        semanticError: message,
        semanticFailure,
        fingerprint,
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
};
