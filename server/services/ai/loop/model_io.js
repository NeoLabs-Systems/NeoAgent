'use strict';

const { sanitizeConversationMessages } = require('../history');
const { sanitizeModelOutput } = require('../outputSanitizer');
const { parseJsonObject } = require('../taskAnalysis');
const { withProviderRetry, isTransientError } = require('../providerRetry');
const { normalizeUsage, recordModelUsage } = require('../usage');

const MODEL_CALL_TIMEOUT_MS = 5 * 60 * 1000;

function isoNow() {
  return new Date().toISOString();
}

function formatElapsedDuration(durationMs) {
  const totalSeconds = Math.max(1, Math.floor(Number(durationMs || 0) / 1000));
  if (totalSeconds < 60) return `${totalSeconds}s`;
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  if (seconds === 0) return `${minutes}m`;
  return `${minutes}m ${seconds}s`;
}

function resolveModelCallTimeoutMs(options = {}) {
  const requested = Number(options?.modelCallTimeoutMs);
  if (Number.isFinite(requested) && requested > 0) {
    return Math.max(10, requested);
  }
  return MODEL_CALL_TIMEOUT_MS;
}

async function withModelCallTimeout(promise, options = {}, label = 'Model call') {
  const timeoutMs = resolveModelCallTimeoutMs(options);
  let timer = null;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(() => {
      const error = new Error(`${label} timed out after ${formatElapsedDuration(timeoutMs)}.`);
      error.code = 'MODEL_CALL_TIMEOUT';
      reject(error);
    }, timeoutMs);
  });
  try {
    return await Promise.race([Promise.resolve(promise), timeout]);
  } finally {
    if (timer) clearTimeout(timer);
  }
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
  if (telemetry?.runId) {
    engine.updateRunProgress(telemetry.runId, {
      currentPhase: 'model',
      currentStep: structuredStep,
      currentTool: null,
      currentStepStartedAt: isoNow(),
    });
  }

  let completed = false;
  try {
    const response = await withProviderRetry(
      () => withModelCallTimeout(
        provider.chat(
          sanitizeConversationMessages([
            ...messages,
            { role: 'system', content: prompt },
          ]),
          [],
          {
            model,
            maxTokens,
            reasoningEffort: reasoningEffort || engine.getReasoningEffort(providerName, {}),
          }
        ),
        telemetry || {},
        `${phase} model call`,
      ),
      { label: `Engine ${model} (structured)` }
    );
    completed = true;
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
    const runMeta = telemetry?.runId ? engine.getRunMeta(telemetry.runId) : null;
    if (runMeta?.progressLedger?.currentStep === structuredStep) {
      engine.updateRunProgress(telemetry.runId, {
        currentPhase: 'idle',
        currentStep: null,
        currentTool: null,
        currentStepStartedAt: null,
      }, {
        verified: completed,
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
  const requestMessages = sanitizeConversationMessages(messages);
  const callOptions = {
    model,
    reasoningEffort: engine.getReasoningEffort(providerName, options),
  };

  const attemptModelCall = async () => {
    let response = null;
    let streamContent = '';

    if (options.stream !== false) {
      let emittedContent = false;
      const stream = provider.stream(requestMessages, tools, callOptions);
      const iterator = stream[Symbol.asyncIterator]();
      try {
        while (true) {
          const next = await withModelCallTimeout(
            iterator.next(),
            options,
            `Model stream iteration ${iteration}`,
          );
          if (next.done) break;
          const chunk = next.value;
          if (chunk.type === 'content') {
            emittedContent = true;
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
        // Once tokens have streamed to the client a retry would duplicate
        // output, so only the pre-stream window is safe to replay.
        if (emittedContent) err.__providerRetryUnsafe = true;
        throw err;
      }
    } else {
      response = await withModelCallTimeout(
        provider.chat(requestMessages, tools, callOptions),
        options,
        `Model iteration ${iteration}`,
      );
    }

    return { response, streamContent };
  };

  const { response, streamContent } = await withProviderRetry(attemptModelCall, {
    ...(options.retry || {}),
    label: `Engine ${model}`,
    isRetryable: (err) => !err?.__providerRetryUnsafe && isTransientError(err),
    onRetry: ({ attempt, delayMs }) => {
      engine.emit(options.userId, 'run:interim', {
        runId,
        message: `Model service busy; retrying (attempt ${attempt}) in ${Math.max(1, Math.round(delayMs / 1000))}s.`,
        phase: 'recovering',
      });
    },
  });

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
  withModelCallTimeout,
};
