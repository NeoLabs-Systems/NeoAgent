'use strict';

const ERROR_CLASSES = Object.freeze({
  TRANSIENT_NETWORK: 'transient_network',
  RATE_LIMIT: 'rate_limit',
  BAD_ARGUMENTS: 'bad_arguments',
  MISSING_RESOURCE: 'missing_resource',
  PERMISSION_REQUIRED: 'permission_required',
  POLICY_DENIED: 'policy_denied',
  TOOL_CRASH: 'tool_crash',
  SIDE_EFFECT_UNKNOWN: 'side_effect_unknown',
  MODEL_PROTOCOL_ERROR: 'model_protocol_error',
  LOGIC_FAILURE: 'logic_failure',
  STALLED_PROCESS: 'stalled_process',
  CONTEXT_OVERFLOW: 'context_overflow',
  ARTIFACT_INVALID: 'artifact_invalid',
  VERIFICATION_FAILURE: 'verification_failure',
});

function classifyError(error = {}) {
  const message = String(error?.message || error || '');
  const status = Number(error?.status || error?.statusCode || error?.response?.status || 0);
  const code = String(error?.code || '');

  if (status === 429 || /rate.?limit/i.test(message)) return ERROR_CLASSES.RATE_LIMIT;
  if (status === 401 || status === 403 || /permission|forbidden|unauthorized/i.test(message)) {
    return /policy/i.test(message) ? ERROR_CLASSES.POLICY_DENIED : ERROR_CLASSES.PERMISSION_REQUIRED;
  }
  if (/ECONNRESET|ETIMEDOUT|ENOTFOUND|EAI_AGAIN|socket hang up|network/i.test(message) || code.startsWith('E')) {
    return ERROR_CLASSES.TRANSIENT_NETWORK;
  }
  if (/invalid argument|schema|json parse|unexpected token/i.test(message)) {
    return ERROR_CLASSES.BAD_ARGUMENTS;
  }
  if (/not found|missing file|no such file/i.test(message)) {
    return ERROR_CLASSES.MISSING_RESOURCE;
  }
  if (/context|token|maximum context|too long/i.test(message)) {
    return ERROR_CLASSES.CONTEXT_OVERFLOW;
  }
  if (/protocol|tool call|malformed/i.test(message)) {
    return ERROR_CLASSES.MODEL_PROTOCOL_ERROR;
  }
  if (/timeout after side effect|unknown side effect|deliveryAmbiguous/i.test(message)
    || error?.deliveryAmbiguous === true) {
    return ERROR_CLASSES.SIDE_EFFECT_UNKNOWN;
  }
  if (/artifact|corrupt/i.test(message)) return ERROR_CLASSES.ARTIFACT_INVALID;
  if (/stall|heartbeat/i.test(message)) return ERROR_CLASSES.STALLED_PROCESS;
  if (/crash|segfault|spawn/i.test(message)) return ERROR_CLASSES.TOOL_CRASH;
  return ERROR_CLASSES.LOGIC_FAILURE;
}

function defaultResponseForClass(errorClass) {
  switch (errorClass) {
    case ERROR_CLASSES.TRANSIENT_NETWORK:
      return { action: 'retry_last_safe_action', retryable: true, maxRetries: 3 };
    case ERROR_CLASSES.RATE_LIMIT:
      return { action: 'switch_provider_or_backoff', retryable: true, maxRetries: 3 };
    case ERROR_CLASSES.BAD_ARGUMENTS:
      return { action: 'retry_with_corrected_arguments', retryable: true, maxRetries: 2 };
    case ERROR_CLASSES.MISSING_RESOURCE:
      return { action: 'create_discovery_node', retryable: true, maxRetries: 1 };
    case ERROR_CLASSES.PERMISSION_REQUIRED:
      return { action: 'request_approval', retryable: false };
    case ERROR_CLASSES.POLICY_DENIED:
      return { action: 'block_with_policy', retryable: false };
    case ERROR_CLASSES.TOOL_CRASH:
      return { action: 'switch_tool_or_restart', retryable: true, maxRetries: 2 };
    case ERROR_CLASSES.SIDE_EFFECT_UNKNOWN:
      return { action: 'verify_external_state', retryable: false, blindRetryForbidden: true };
    case ERROR_CLASSES.MODEL_PROTOCOL_ERROR:
      return { action: 'protocol_repair_or_fallback', retryable: true, maxRetries: 2 };
    case ERROR_CLASSES.CONTEXT_OVERFLOW:
      return { action: 'compact_context_and_continue', retryable: true, maxRetries: 2 };
    case ERROR_CLASSES.ARTIFACT_INVALID:
      return { action: 'reopen_producing_node', retryable: true, maxRetries: 2 };
    case ERROR_CLASSES.VERIFICATION_FAILURE:
      return { action: 'reopen_failed_nodes', retryable: true, maxRetries: 3 };
    case ERROR_CLASSES.STALLED_PROCESS:
      return { action: 'diagnose_checkpoint_or_terminate', retryable: true, maxRetries: 1 };
    case ERROR_CLASSES.LOGIC_FAILURE:
    default:
      return { action: 'revise_plan_or_strategy', retryable: true, maxRetries: 2 };
  }
}

function planRecovery(error, context = {}) {
  const errorClass = classifyError(error);
  const response = defaultResponseForClass(errorClass);
  const attempts = Number(context.attemptsForClass || 0);
  if (!response.retryable || attempts >= (response.maxRetries || 0)) {
    return {
      errorClass,
      action: response.blindRetryForbidden ? 'block_with_evidence' : 'deliver_blocker',
      retryable: false,
      response,
      attempts,
    };
  }
  return {
    errorClass,
    action: response.action,
    retryable: true,
    response,
    attempts,
  };
}

module.exports = {
  ERROR_CLASSES,
  classifyError,
  defaultResponseForClass,
  planRecovery,
};
