'use strict';

const { evaluateOpenObligations } = require('./task_contract');
const { requiredOpenNodes } = require('./work_graph');

/**
 * Deterministic completion gate. A model complete decision is only a claim.
 */
function evaluateCompletionClaim({
  runId,
  contract,
  claim = {},
  evidence = [],
  artifacts = [],
  finalContent = '',
  finalDeliveryId = null,
  sideEffects = [],
  path = 'durable',
} = {}) {
  const failures = [];
  const warnings = [];

  if (finalDeliveryId) {
    failures.push({
      code: 'final_already_committed',
      message: 'Final delivery has already been committed for this run',
    });
  }

  const obligationResult = evaluateOpenObligations(contract, {
    completedNodeKeys: claim.completed_node_ids || claim.completedNodeIds || [],
    evidence,
    artifacts,
    finalContent: finalContent || claim.summary || '',
  });

  if (!obligationResult.satisfied && path !== 'fast') {
    for (const open of obligationResult.open) {
      failures.push({
        code: 'open_obligation',
        message: `Open obligation: ${open.id || open.type}`,
        obligation: open,
      });
    }
  }

  if (runId && path === 'durable') {
    const openNodes = requiredOpenNodes(runId);
    const incomplete = openNodes.filter((node) => node.kind !== 'verification' || openNodes.length > 1);
    // Allow verification node to remain open at gate entry; verifier handles it.
    const blocking = openNodes.filter((node) => node.kind !== 'verification');
    if (blocking.length > 0) {
      for (const node of blocking) {
        failures.push({
          code: 'open_work_node',
          message: `Required work node is not complete: ${node.nodeKey}`,
          nodeId: node.id,
          nodeKey: node.nodeKey,
          status: node.status,
        });
      }
    } else if (incomplete.length === 1 && incomplete[0].kind === 'verification') {
      warnings.push({
        code: 'verification_pending',
        message: 'Verification node still open; semantic verification should run next',
      });
    }
  }

  const criticalDefects = (claim.defects || evidence.filter((e) => e.severity === 'critical'));
  if (Array.isArray(criticalDefects) && criticalDefects.length > 0) {
    failures.push({
      code: 'critical_defects',
      message: 'Critical defects remain open',
      defects: criticalDefects,
    });
  }

  const unknownSideEffects = (sideEffects || []).filter((effect) => effect.status === 'unknown');
  if (unknownSideEffects.length > 0) {
    failures.push({
      code: 'unknown_side_effects',
      message: 'One or more side effects are unconfirmed',
      sideEffects: unknownSideEffects.map((e) => e.id || e.tool_name),
    });
  }

  const requiredConfidence = Number(contract?.completion_policy?.required_confidence || 0.7);
  const claimConfidence = Number(claim.confidence || 0);
  if (claimConfidence > 0 && claimConfidence < requiredConfidence) {
    warnings.push({
      code: 'low_claim_confidence',
      message: `Claim confidence ${claimConfidence} below required ${requiredConfidence}`,
    });
  }

  if (path === 'fast') {
    // Fast path only needs no execution obligations and a final text answer.
    const hasText = String(finalContent || claim.summary || '').trim().length > 0;
    if (!hasText) {
      failures.push({
        code: 'missing_final_content',
        message: 'Fast path requires final reply content',
      });
    }
  } else if (!String(finalContent || claim.summary || '').trim()) {
    failures.push({
      code: 'missing_final_content',
      message: 'Completion claim lacks final content',
    });
  }

  const accepted = failures.length === 0;
  return {
    accepted,
    status: accepted ? 'accepted' : 'rejected',
    failures,
    warnings,
    openObligations: obligationResult.open,
    claim: {
      summary: String(claim.summary || finalContent || '').trim(),
      confidence: claimConfidence || null,
      evidence_ids: claim.evidence_ids || claim.evidenceIds || [],
    },
  };
}

module.exports = {
  evaluateCompletionClaim,
};
