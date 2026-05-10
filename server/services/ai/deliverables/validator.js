'use strict';

const {
  normalizeDeliverableResult,
  normalizeDeliverableValidationResult,
} = require('./contracts');

class DeliverableValidationError extends Error {
  constructor(message, details = {}) {
    super(message);
    this.name = 'DeliverableValidationError';
    this.deliverableValidation = details.validation || null;
    this.deliverableResult = details.result || null;
    this.disableAutonomousRetry = true;
  }
}

async function validateDeliverableExecution({
  workflow,
  request,
  plan,
  finalReply,
  artifacts,
  toolExecutions,
  runId,
}) {
  const validation = normalizeDeliverableValidationResult(
    await workflow.validate({
      request,
      plan,
      finalReply,
      artifacts,
      toolExecutions,
      runId,
    }),
  );
  const result = normalizeDeliverableResult({
    type: workflow.type,
    status: validation.status === 'passed' ? 'completed' : 'failed',
    summary: workflow.summarize({
      request,
      plan,
      finalReply,
      artifacts: validation.artifacts,
      validation,
      toolExecutions,
      runId,
    }),
    artifacts: validation.artifacts,
    validation,
    metadata: {
      requestedOutputs: request?.requestedOutputs || [],
      supportingCapabilities: request?.supportingCapabilities || [],
      preferredTools: plan?.preferredTools || [],
    },
  });
  return { validation, result };
}

module.exports = {
  DeliverableValidationError,
  validateDeliverableExecution,
};
