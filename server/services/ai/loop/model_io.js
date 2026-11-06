'use strict';

const { sanitizeConversationMessages } = require('../history');
const { mayBeRawToolCall, sanitizeModelOutput } = require('../outputSanitizer');
const { extractJsonObject } = require('../../../utils/text');
const { withProviderRetry, isTransientError } = require('../providerRetry');
const { degenerateOutputDetails, isDegenerateOutputError } = require('../providers/stream_guard');
const { normalizeUsage, recordModelUsage } = require('../usage');
const { captureRequest } = require('../runtime/run_capture');
const { estimatePromptMetrics, mergePromptMetrics } = require('../runtime/prompt_metrics');
const { EVENT_TYPES } = require('../runtime/events/event_types');
const { recordEventSafe } = require('../runtime/events/run_event_store');
const {
  isModelCallTimeout,
  resolveModelCallTimeoutMs,
  runAbortableModelCall,
  resolveStreamIdleTimeoutMs,
  withModelCallTimeout,
} = require('./model_call_guard');

// The per-call ceiling already waited minutes on this model; retrying it
// repeats that wait instead of moving on to the next model.
function isRetryableModelError(err) {
  return !isModelCallTimeout(err) && isTransientError(err);
}

function wireMessages(provider, messages) {
  return typeof provider.prepareMessages === 'function' ? provider.prepareMessages(messages) : messages;
}

function modelResponsePayload({ phase, providerName, model, startedAt, response, retryCount = 0 }) {
  const usage = normalizeUsage(response?.usage);
  const toolCalls = response?.toolCalls || response?.tool_calls || [];
  return {
    phase,
    model: { provider: providerName, model },
    // A router may answer with something other than what was asked for.
    ...(response?.model && response.model !== model ? { served_model: response.model } : {}),
    duration_ms: Date.now() - startedAt,
    usage: usage
      ? {
        input_tokens: usage.inputTokens,
        output_tokens: usage.outputTokens,
        reasoning_tokens: usage.reasoningTokens,
        cached_read_tokens: usage.cachedReadTokens,
        cache_write_tokens: usage.cacheWriteTokens,
      }
      : null,
    finish_reason: response?.finishReason || null,
    truncated: response?.truncated === true,
    tool_call_names: toolCalls
      .map((call) => call?.function?.name || call?.name)
      .filter(Boolean),
    retry_count: retryCount,
  };
}

// Why a model call failed, in a word a report can group by.
function classifyModelError(error) {
  if (isModelCallTimeout(error)) return 'timeout';
  const status = Number(error?.status || error?.statusCode || error?.response?.status);
  if (status === 429) return 'rate_limited';
  if (status >= 500) return 'provider_unavailable';
  if (status === 401 || status === 403) return 'auth';
  if (status === 400) return 'bad_request';
  return String(error?.code || 'unknown').toLowerCase();
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
  const modelAbortController = new AbortController();
  const parentSignal = telemetry?.signal;
  const abortFromParent = () => modelAbortController.abort(parentSignal?.reason);
  if (parentSignal?.aborted) abortFromParent();
  else parentSignal?.addEventListener('abort', abortFromParent, { once: true });

  try {
    const reasoning = reasoningEffort || engine.getReasoningEffort(providerName, {});
    const requestMessages = sanitizeConversationMessages([
      ...messages,
      { role: 'system', content: prompt },
    ]);
    if (telemetry?.runId) {
      captureRequest(engine.getRunMeta?.(telemetry.runId), {
        runId: telemetry.runId,
        userId: telemetry.userId,
        phase,
        iteration: telemetry.iteration || 0,
        provider: providerName,
        model,
        maxTokens,
        reasoningEffort: reasoning,
        messages: requestMessages,
      });
    }
    const response = await withProviderRetry(
      () => withModelCallTimeout(
        provider.chat(
          wireMessages(provider, requestMessages),
          [],
          {
            model,
            maxTokens,
            reasoningEffort: reasoning,
            structured: true,
            signal: modelAbortController.signal,
          }
        ),
        { ...(telemetry || {}), modelAbortController },
        `${phase} model call`,
      ),
      {
        label: `Engine ${model} (structured)`,
        isRetryable: (err) => !modelAbortController.signal.aborted && isRetryableModelError(err),
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
      recordEventSafe({
        runId: telemetry.runId,
        userId: telemetry.userId,
        agentId: telemetry.agentId || null,
        eventType: EVENT_TYPES.MODEL_RESPONSE,
        payload: modelResponsePayload({ phase, providerName, model, startedAt, response }),
      });
    }

    const parsed = extractJsonObject(response.content || '');
    const normalizedUsage = normalizeUsage(response.usage);
    return {
      value: normalize(parsed || {}, fallback),
      // False when the reply held no usable JSON object (truncated output,
      // prose), so callers can tell a real answer from a silent fallback.
      parsed: Boolean(parsed),
      raw: response.content || '',
      usage: normalizedUsage?.totalTokens || 0,
    };
  } finally {
    parentSignal?.removeEventListener('abort', abortFromParent);
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
  const phase = options.phase || 'model_turn';
  const eventRunId = options.runId || runId;
  const runMeta = eventRunId && options.userId ? engine.getRunMeta?.(eventRunId) : null;
  const requestMessages = sanitizeConversationMessages(messages);
  // Tool definitions open the cached prompt prefix, so the same set must be sent in
  // the same order every time; selection order changes from run to run.
  const requestTools = Array.isArray(tools)
    ? [...tools].sort((left, right) => String(left?.name || '').localeCompare(String(right?.name || '')))
    : [];
  const maxTokens = options.maxTokens;
  const reasoningEffort = engine.getReasoningEffort(providerName, options);
  const ledger = {
    runId: eventRunId,
    userId: options.userId,
    agentId: options.agentId || null,
  };
  if (runMeta) {
    const promptMetrics = estimatePromptMetrics(requestMessages, requestTools);
    if (phase === 'model_turn') {
      runMeta.promptMetrics = mergePromptMetrics(runMeta.promptMetrics, promptMetrics, iteration, requestTools.length);
    }
    const requestId = captureRequest(runMeta, {
      runId: eventRunId,
      userId: options.userId,
      phase,
      iteration,
      provider: providerName,
      model,
      maxTokens,
      reasoningEffort,
      messages: requestMessages,
      tools: requestTools,
    });
    recordEventSafe({
      ...ledger,
      eventType: EVENT_TYPES.MODEL_REQUEST,
      requestId,
      payload: {
        phase,
        iteration,
        model: { provider: providerName, model },
        context: {
          estimated_tokens: promptMetrics.totalEstimatedTokens,
          system_tokens: promptMetrics.systemPromptTokens,
          tool_schema_tokens: promptMetrics.toolSchemaTokens,
          tool_catalog_tokens: promptMetrics.toolCatalogTokens,
          history_tokens: promptMetrics.historyTokens,
          memory_tokens: promptMetrics.recalledMemoryTokens,
          runtime_note_tokens: promptMetrics.runtimeNoteTokens,
          tool_replay_tokens: promptMetrics.toolReplayTokens,
          active_tool_count: requestTools.length,
        },
        privacy: { content_stored: Boolean(requestId), redaction_policy: 'metadata-default' },
      },
    });
  }
  // A tool call whose arguments ran away is handed back to the loop as that
  // same call with its arguments discarded. The tool rejects it with the
  // reason, and the model's next turn is the retry — with the failure in
  // context, which recovers far more reliably than replaying the request blind.
  const discardedToolCall = (error) => {
    const { reason, outputBytes, toolName, argumentKey } = degenerateOutputDetails(error);
    if (!toolName) return null;
    const declared = Object.keys(requestTools.find((tool) => tool?.name === toolName)?.parameters?.properties || {});
    const why = argumentKey && declared.length
      ? `${toolName} has no argument "${argumentKey}"; its arguments are ${declared.join(', ')}. The call was discarded; send it again with those names.`
      : `The arguments streamed for this call degenerated into ${reason.replace(/_/g, ' ')} after ${outputBytes} bytes and were discarded. Resend the call with complete, well-formed arguments.`;
    return {
      content: '',
      toolCalls: [{
        id: `discarded_${iteration}`,
        type: 'function',
        function: {
          name: toolName,
          arguments: JSON.stringify({ _discarded: why }),
        },
      }],
      finishReason: 'tool_calls',
      usage: null,
    };
  };
  const attemptModelCall = async () => {
    const modelAbortController = new AbortController();
    const abortFromParent = () => modelAbortController.abort(parentSignal?.reason);
    if (parentSignal?.aborted) abortFromParent();
    else parentSignal?.addEventListener('abort', abortFromParent, { once: true });
    const callOptions = {
      model,
      maxTokens,
      reasoningEffort,
      // Routing models (typesafe/jev-router) keep their pick per session.
      sessionId: options.conversationId || options.runId || runId || null,
      signal: modelAbortController.signal,
    };
    let response = null;
    let streamContent = '';

    try {
      if (options.stream !== false) {
        const stream = provider.stream(wireMessages(provider, requestMessages), requestTools, callOptions);
        const iterator = stream[Symbol.asyncIterator]();
        try {
          while (true) {
            const next = await withModelCallTimeout(
              iterator.next(),
              { ...options, modelAbortController, modelCallTimeoutMs: resolveStreamIdleTimeoutMs(options) },
              `Model stream iteration ${iteration}`,
            );
            if (next.done) break;
            const chunk = next.value;
            if (chunk.type === 'content') {
              streamContent += chunk.content;
              engine.emit(options.userId, 'run:stream', {
                runId,
                // Text that may yet turn out to be a written-out tool call stays back.
                content: mayBeRawToolCall(streamContent) ? '' : sanitizeModelOutput(streamContent, { model }),
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
                reasoningState: chunk.reasoningState || null,
                finishReason: 'tool_calls',
                usage: chunk.usage || null,
              };
            }
          }
        } catch (err) {
          Promise.resolve(iterator.return?.()).catch(() => {});
          if (isDegenerateOutputError(err)) response = discardedToolCall(err);
          if (!response) throw err;
        }
      } else {
        response = await withModelCallTimeout(
          provider.chat(wireMessages(provider, requestMessages), requestTools, callOptions),
          { ...options, modelAbortController },
          `Model iteration ${iteration}`,
        );
      }
      return { response, streamContent };
    } finally {
      parentSignal?.removeEventListener('abort', abortFromParent);
    }
  };

  let retryCount = 0;
  let response;
  let streamContent;
  try {
    ({ response, streamContent } = await withProviderRetry(attemptModelCall, {
    ...(options.retry || {}),
    label: `Engine ${model}`,
    isRetryable: (err) => !parentSignal?.aborted && isRetryableModelError(err),
    onRetry: ({ attempt, delayMs }) => {
      retryCount = attempt;
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
  } catch (error) {
    if (runMeta) {
      recordEventSafe({
        ...ledger,
        eventType: EVENT_TYPES.MODEL_RESPONSE,
        payload: {
          phase,
          iteration,
          model: { provider: providerName, model },
          duration_ms: Date.now() - startedAt,
          retry_count: retryCount,
          outcome: { status: 'failed', error_class: classifyModelError(error) },
        },
      });
    }
    throw error;
  }

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
      phase,
      usage: resolvedResponse.usage,
      latencyMs: Date.now() - startedAt,
      metadata: { iteration },
    });
  }
  if (runMeta) {
    recordEventSafe({
      ...ledger,
      eventType: EVENT_TYPES.MODEL_RESPONSE,
      payload: {
        ...modelResponsePayload({ phase, providerName, model, startedAt, response: resolvedResponse, retryCount }),
        iteration,
        outcome: { status: 'success', retry_count: retryCount },
      },
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
