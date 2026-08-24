'use strict';

const { sanitizeConversationMessages } = require('../history');
const { sanitizeModelOutput } = require('../outputSanitizer');
const { parseJsonObject } = require('../taskAnalysis');
const { withProviderRetry, isTransientError } = require('../providerRetry');
const { normalizeUsage, recordModelUsage } = require('../usage');
const { journalAndReconstructModelRequest } = require('../runtime/model_request_journal');
const {
  resolveModelCallTimeoutMs,
  runAbortableModelCall,
  withModelCallTimeout,
} = require('./model_call_guard');

function isoNow() {
  return new Date().toISOString();
}

function activeJournalIdentity(engine, runId, userId) {
  if (!runId || !userId || !engine.getRunMeta?.(runId)) {
    return { runId: null, userId: null };
  }
  return { runId, userId };
}

async function requestStructuredJson(engine, {
  provider,
  providerName,
  model,
  messages,
  prompt,
  maxTokens = 1400,
  normalize,
  fallback = {},
  reasoningEffort,
  telemetry = null,
  phase = 'structured',
}) {
  const startedAt = Date.now();
  const structuredStep = `model:${phase}`;
  const modelAbortController = new AbortController();
  const parentSignal = telemetry?.signal;
  const abortFromParent = () => modelAbortController.abort(parentSignal?.reason);
  if (parentSignal?.aborted) abortFromParent();
  else parentSignal?.addEventListener('abort', abortFromParent, { once: true });
  if (telemetry?.runId) {
    engine.updateRunProgress(telemetry.runId, {
      currentPhase: 'model',
      currentStep: structuredStep,
      currentTool: null,
      currentStepStartedAt: isoNow(),
    });
  }

  try {
    const reasoning = reasoningEffort || engine.getReasoningEffort(providerName, {});
    const journalIdentity = activeJournalIdentity(engine, telemetry?.runId, telemetry?.userId);
    const durableRequest = journalAndReconstructModelRequest({
      ...journalIdentity,
      agentId: telemetry?.agentId || null,
      phase,
      iteration: telemetry?.iteration || 0,
      provider: providerName,
      model,
      messages: sanitizeConversationMessages([
        ...messages,
        { role: 'system', content: prompt },
      ]),
      tools: [],
      maxTokens,
      reasoningEffort: reasoning,
    });
    const response = await withProviderRetry(
      () => withModelCallTimeout(
        provider.chat(
          durableRequest.messages,
          durableRequest.tools,
          {
            model: durableRequest.header.model,
            maxTokens: durableRequest.header.maxTokens,
            reasoningEffort: durableRequest.header.reasoningEffort,
            signal: modelAbortController.signal,
          }
        ),
        { ...(telemetry || {}), modelAbortController },
        `${phase} model call`,
      ),
      {
        label: `Engine ${model} (structured)`,
        isRetryable: (err) => !modelAbortController.signal.aborted && isTransientError(err),
        signal: modelAbortController.signal,
      }
    );
    if (telemetry?.runId && telemetry?.userId) {
      recordModelUsage({
        runId: telemetry.runId,
        stepId: telemetry.stepId || null,
        userId: telemetry.userId,
        agentId: telemetry.agentId || null,
        provider: providerName,
        model,
        phase,
        usage: response.usage,
        latencyMs: Date.now() - startedAt,
      });
    }

    const parsed = parseJsonObject(response.content || '');
    const normalizedUsage = normalizeUsage(response.usage);
    return {
      value: normalize(parsed || {}, fallback),
      raw: response.content || '',
      usage: normalizedUsage?.totalTokens || 0,
    };
  } finally {
    parentSignal?.removeEventListener('abort', abortFromParent);
    const runMeta = telemetry?.runId ? engine.getRunMeta(telemetry.runId) : null;
    if (runMeta?.progressLedger?.currentStep === structuredStep) {
      engine.updateRunProgress(telemetry.runId, {
        currentPhase: 'idle',
        currentStep: null,
        currentTool: null,
        currentStepStartedAt: null,
      });
    }
  }
}

async function requestModelResponse(engine, {
  provider,
  providerName,
  model,
  messages,
  tools,
  options,
  runId,
  iteration,
}) {
  const startedAt = Date.now();
  const parentSignal = options.signal;
  const journalIdentity = activeJournalIdentity(engine, options.runId || runId, options.userId);
  const durableRequest = journalAndReconstructModelRequest({
    ...journalIdentity,
    agentId: options.agentId || null,
    phase: options.phase || 'model_turn',
    iteration,
    provider: providerName,
    model,
    messages: sanitizeConversationMessages(messages),
    tools: Array.isArray(tools) ? tools : [],
    maxTokens: options.maxTokens,
    reasoningEffort: engine.getReasoningEffort(providerName, options),
  });
  const requestMessages = durableRequest.messages;
  const requestTools = durableRequest.tools;
  const attemptModelCall = async () => {
    const modelAbortController = new AbortController();
    const abortFromParent = () => modelAbortController.abort(parentSignal?.reason);
    if (parentSignal?.aborted) abortFromParent();
    else parentSignal?.addEventListener('abort', abortFromParent, { once: true });
    const callOptions = {
      model: durableRequest.header.model,
      maxTokens: durableRequest.header.maxTokens,
      reasoningEffort: durableRequest.header.reasoningEffort,
      signal: modelAbortController.signal,
    };
    let response = null;
    let streamContent = '';

    try {
      if (options.stream !== false) {
        const stream = provider.stream(requestMessages, requestTools, callOptions);
        const iterator = stream[Symbol.asyncIterator]();
        try {
          while (true) {
            const next = await withModelCallTimeout(
              iterator.next(),
              { ...options, modelAbortController },
              `Model stream iteration ${iteration}`,
            );
            if (next.done) break;
            const chunk = next.value;
            if (chunk.type === 'content') {
              streamContent += chunk.content;
              engine.emit(options.userId, 'run:stream', {
                runId,
                content: sanitizeModelOutput(streamContent, { model }),
                iteration,
              });
            }
            if (chunk.type === 'done') {
              response = chunk;
            }
            if (chunk.type === 'tool_calls') {
              response = {
                content: chunk.content || streamContent,
                toolCalls: chunk.toolCalls,
                providerContentBlocks: chunk.providerContentBlocks || null,
                finishReason: 'tool_calls',
                usage: chunk.usage || null,
              };
            }
          }
        } catch (err) {
          Promise.resolve(iterator.return?.()).catch(() => {});
          throw err;
        }
      } else {
        response = await withModelCallTimeout(
          provider.chat(requestMessages, requestTools, callOptions),
          { ...options, modelAbortController },
          `Model iteration ${iteration}`,
        );
      }
      return { response, streamContent };
    } finally {
      parentSignal?.removeEventListener('abort', abortFromParent);
    }
  };

  let response;
  let streamContent;
  ({ response, streamContent } = await withProviderRetry(attemptModelCall, {
    ...(options.retry || {}),
    label: `Engine ${model}`,
    isRetryable: (err) => !parentSignal?.aborted && isTransientError(err),
    onRetry: ({ attempt, delayMs }) => {
      // Stream payloads are full snapshots for one iteration, so clearing and
      // replaying the same durable request cannot duplicate a visible message.
      if (options.stream !== false) {
        engine.emit(options.userId, 'run:stream', { runId, content: '', iteration });
      }
      engine.emit(options.userId, 'run:interim', {
        runId,
        message: `Model service busy; retrying (attempt ${attempt}) in ${Math.max(1, Math.round(delayMs / 1000))}s.`,
        phase: 'recovering',
      });
    },
    signal: parentSignal,
  }));

  const resolvedResponse = response || {
    content: streamContent,
    toolCalls: [],
    finishReason: 'stop',
    usage: null,
  };
  const hasContent = Boolean(String(resolvedResponse.content || streamContent || '').trim());
  const hasToolCalls = Array.isArray(resolvedResponse.toolCalls) && resolvedResponse.toolCalls.length > 0;
  if (!hasContent && !hasToolCalls) {
    const error = new Error(`Model ${model} returned an empty response.`);
    error.code = 'MODEL_EMPTY_RESPONSE';
    throw error;
  }
  if (options.runId && options.userId) {
    recordModelUsage({
      runId: options.runId,
      stepId: options.stepId || null,
      userId: options.userId,
      agentId: options.agentId || null,
      provider: providerName,
      model,
      phase: options.phase || 'model_turn',
      usage: resolvedResponse.usage,
      latencyMs: Date.now() - startedAt,
      metadata: { iteration },
    });
  }

  return {
    response: resolvedResponse,
    responseModel: model,
    streamContent,
  };
}

module.exports = {
  requestModelResponse,
  requestStructuredJson,
  resolveModelCallTimeoutMs,
  runAbortableModelCall,
  withModelCallTimeout,
};
