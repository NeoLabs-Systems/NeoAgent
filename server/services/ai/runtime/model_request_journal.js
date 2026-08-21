'use strict';

const { createHash, randomUUID } = require('crypto');
const { appendEvent, findEventByRequestId } = require('./events/run_event_store');
const { EVENT_TYPES, VISIBILITY } = require('./events/event_types');

function canonicalize(value) {
  if (Array.isArray(value)) return value.map(canonicalize);
  if (!value || typeof value !== 'object') return value;
  const result = {};
  for (const key of Object.keys(value).sort()) {
    if (value[key] !== undefined) result[key] = canonicalize(value[key]);
  }
  return result;
}

function snapshotValue(value) {
  return JSON.parse(JSON.stringify(canonicalize(value)));
}

function requestDigest(request) {
  return createHash('sha256').update(JSON.stringify(canonicalize(request))).digest('hex');
}

function deepFreeze(value) {
  if (!value || typeof value !== 'object' || Object.isFrozen(value)) return value;
  Object.freeze(value);
  for (const child of Object.values(value)) deepFreeze(child);
  return value;
}

function recordModelRequest({
  runId,
  userId,
  agentId = null,
  phase = 'model_turn',
  iteration = 0,
  provider = null,
  model,
  messages = [],
  tools = [],
  maxTokens,
  reasoningEffort,
}) {
  const requestId = randomUUID();
  const request = snapshotValue({
    header: {
      phase,
      iteration: Number(iteration) || 0,
      provider,
      model,
      maxTokens,
      reasoningEffort,
    },
    messages,
    tools,
  });
  const digest = requestDigest(request);
  appendEvent({
    runId,
    userId,
    agentId,
    eventType: EVENT_TYPES.MODEL_REQUEST_RECORDED,
    requestId,
    payload: { request_id: requestId, digest, request },
    visibility: VISIBILITY.INTERNAL,
    sensitivity: 'private',
  });
  return { requestId, digest };
}

function reconstructModelRequest(runId, requestId) {
  const event = findEventByRequestId(runId, requestId, EVENT_TYPES.MODEL_REQUEST_RECORDED);
  if (!event?.payload?.request) {
    const error = new Error(`Model request ${requestId} is missing from the durable run log.`);
    error.code = 'MODEL_REQUEST_NOT_RECONSTRUCTABLE';
    throw error;
  }
  const request = snapshotValue(event.payload.request);
  const digest = requestDigest(request);
  if (digest !== event.payload.digest) {
    const error = new Error(`Model request ${requestId} failed its durable digest check.`);
    error.code = 'MODEL_REQUEST_RECONSTRUCTION_MISMATCH';
    throw error;
  }
  return deepFreeze(request);
}

function journalAndReconstructModelRequest(input) {
  if (!input?.runId || !input?.userId) {
    return deepFreeze(snapshotValue({
      header: {
        phase: input?.phase || 'model_turn',
        iteration: Number(input?.iteration) || 0,
        provider: input?.provider || null,
        model: input?.model,
        maxTokens: input?.maxTokens,
        reasoningEffort: input?.reasoningEffort,
      },
      messages: input?.messages || [],
      tools: input?.tools || [],
    }));
  }
  const recorded = recordModelRequest(input);
  return reconstructModelRequest(input.runId, recorded.requestId);
}

module.exports = {
  canonicalize,
  journalAndReconstructModelRequest,
  reconstructModelRequest,
  recordModelRequest,
  requestDigest,
};
