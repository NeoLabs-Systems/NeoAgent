'use strict';

// Decides whether the agent may accept a `task_complete` signal, balancing the
// model's self-reported confidence against the confidence the run requires.

function normalizeCompletionConfidence(value) {
  const normalized = String(value || '').trim().toLowerCase();
  if (normalized === 'high' || normalized === 'medium' || normalized === 'low') return normalized;
  return 'medium';
}

function completionConfidenceRank(value) {
  const normalized = normalizeCompletionConfidence(value);
  if (normalized === 'high') return 3;
  if (normalized === 'medium') return 2;
  return 1;
}

function shouldAcceptTaskComplete({ confidence, requiredConfidence, iteration, maxIterations }) {
  const required = normalizeCompletionConfidence(requiredConfidence || 'medium');
  const actual = normalizeCompletionConfidence(confidence || 'medium');
  if (completionConfidenceRank(actual) >= completionConfidenceRank(required)) {
    return { accept: true, reason: '' };
  }

  const iterationsRemaining = Math.max(0, Number(maxIterations || 0) - Number(iteration || 0));
  if (iterationsRemaining <= 1) {
    return {
      accept: true,
      reason: `Accepted ${actual}-confidence completion at the iteration limit; final verifier will calibrate the answer.`,
    };
  }

  return {
    accept: false,
    reason: `Completion confidence "${actual}" is below required "${required}". Continue with verification, recovery, or a narrower truthful result before completing.`,
  };
}

module.exports = {
  normalizeCompletionConfidence,
  completionConfidenceRank,
  shouldAcceptTaskComplete,
};
