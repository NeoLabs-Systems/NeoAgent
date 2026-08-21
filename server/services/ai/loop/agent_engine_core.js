'use strict';

const { v4: uuidv4 } = require('uuid');
const fs = require('fs');
const db = require('../../../db/database');
const {
  getConversationContext,
} = require('../history');
const { ensureDefaultAiSettings, getAiSettings } = require('../settings');
const {
  buildPlanPrompt,
  buildVerifierPrompt,
  normalizeExecutionPlan,
  normalizeVerificationResult,
  parseJsonObject,
} = require('../taskAnalysis');
const { summarizeCapabilityHealth } = require('../capabilityHealth');
const { shouldAcceptTaskComplete } = require('../completion');
const { shortenRunId, summarizeForLog } = require('../logFormat');
const { getProviderForUser } = require('../provider_selector');
const {
  recordModelFailure,
  recordModelSuccess,
} = require('../model_failure_cache');
const { runConversation } = require('./conversation_loop');
const {
  TERMINAL_STATUSES,
  checkpointRun,
  closeRun,
  getRunControl,
  requestRunControl,
  transitionRun,
} = require('./lifecycle');
const {
  buildChurnAssessmentPrompt,
  buildCompletionDecisionPrompt,
  enforceTerminalReplyDecision,
  enforceChurnAssessment,
  normalizeChurnAssessment,
  normalizeCompletionDecision,
  resolveRunGoalContext,
} = require('./completion_judge');
const {
  activateToolsForRun: activateToolsForRunImpl,
  applyQueuedSteering: applyQueuedSteeringImpl,
  applyQueuedSystemSteering: applyQueuedSystemSteeringImpl,
  attachProcessToRun: attachProcessToRunImpl,
  buildProgressLedgerSnapshot: buildProgressLedgerSnapshotImpl,
  detachProcessFromRun: detachProcessFromRunImpl,
  enqueueSteering: enqueueSteeringImpl,
  enqueueSystemSteering: enqueueSystemSteeringImpl,
  findActiveRunForUser: findActiveRunForUserImpl,
  findSteerableRunForUser: findSteerableRunForUserImpl,
  getActiveTools: getActiveToolsImpl,
  initializeToolRuntime: initializeToolRuntimeImpl,
  isRunStopped: isRunStoppedImpl,
  markRunFinalDelivery: markRunFinalDeliveryImpl,
  markRunVisibleProgress: markRunVisibleProgressImpl,
  persistProgressLedger: persistProgressLedgerImpl,
  persistRunMetadata: persistRunMetadataImpl,
  recordRunEventSafe,
  searchToolsForRun: searchToolsForRunImpl,
  updateRunGoalContract: updateRunGoalContractImpl,
  updateRunProgress: updateRunProgressImpl,
} = require('./run_state');
const {
  deliverMessagingFinalFallback: deliverMessagingFinalFallbackImpl,
  shouldSendMessagingFinalFallback: shouldSendMessagingFinalFallbackImpl,
} = require('./messaging_delivery');
const {
  requestModelResponse: requestModelResponseImpl,
  requestStructuredJson: requestStructuredJsonImpl,
  runAbortableModelCall,
} = require('./model_io');
const {
  publishInterimUpdate: publishInterimUpdateImpl,
} = require('./callbacks');
const {
  executeReadOnlyBatch: executeReadOnlyBatchImpl,
  executeTool: executeToolImpl,
  getAvailableTools: getAvailableToolsImpl,
  isReadOnlyToolCall: isReadOnlyToolCallImpl,
} = require('./tool_dispatch');
const {
  normalizeOutgoingMessage,
  clampRunContext,
} = require('../messagingFallback');
const {
  assessResearchAdequacy,
  summarizeToolExecutions,
} = require('../toolEvidence');
const {
  buildMemoryConsolidationInstructions,
  normalizeMemoryCandidates,
} = require('../../memory/consolidation');
const {
  buildPlannerPrompt,
  buildRerankerPrompt,
  mergeRetrievalResults,
  normalizeRerankResult,
  normalizeRetrievalPlan,
  shouldEnhanceRetrieval,
} = require('../../memory/retrieval_reasoning');
const {
  createAbortError,
  createLinkedAbortController,
  isAbortError,
  runWithAbortTimeout,
  throwIfAborted,
} = require('../../../utils/abort');

function buildInitialRunMetadata(options = {}) {
  const metadata = {};
  if (options.taskId != null && String(options.taskId).trim()) {
    metadata.taskId = options.taskId;
  }
  if (options.messagingInboundJobId != null && String(options.messagingInboundJobId).trim()) {
    metadata.messagingInboundJobId = String(options.messagingInboundJobId).trim();
  }
  return metadata;
}

function isoNow() {
  return new Date().toISOString();
}

function estimateTokenValue(value) {
  if (!value) return 0;
  if (typeof value === 'string') return Math.ceil(value.length / 4);
  return Math.ceil(JSON.stringify(value).length / 4);
}

const FILE_TOOL_NAMES = new Set([
  'read_file',
  'read_files',
  'write_file',
  'edit_file',
  'replace_file_range',
  'list_directory',
  'search_files',
]);

class AgentEngine {
  constructor(io, services = {}) {
    this.io = io;
    this.activeRuns = new Map();
    this.activeRunPromises = new Set();
    this.backgroundTasks = new Set();
    this.backgroundTaskQueues = new Map();
    this.subagentStartupTasks = new Set();
    this.lifecycleAbortController = new AbortController();
    this.shuttingDown = false;
    this.shutdownPromise = null;
    this.subagents = new Map();
    this.app = services.app || null;
    this.browserController = services.browserController || null;
    this.androidController = services.androidController || null;
    this.runtimeManager = services.runtimeManager || null;
    this.workspaceManager = services.workspaceManager || null;
    this.messagingManager = services.messagingManager || null;
    this.mcpManager = services.mcpManager || services.mcpClient || null;
    this.skillRunner = services.skillRunner || null;
    this.taskRuntime = services.taskRuntime || null;
    this.memoryManager = services.memoryManager || null;
    this.voiceRuntimeManager = services.voiceRuntimeManager || null;
    this.messagingDeliveryRetry = services.messagingDeliveryRetry || {};
  }

  trackBackgroundTask(task, options = {}) {
    if (typeof task !== 'function') {
      throw new TypeError('Background task must be a function.');
    }
    if (this.shuttingDown || this.lifecycleAbortController.signal.aborted) {
      return Promise.reject(createAbortError(
        this.lifecycleAbortController.signal,
        'Agent engine is shutting down.',
      ));
    }

    const key = String(options.key || '').trim();
    const previous = key ? this.backgroundTaskQueues.get(key) : null;
    if (previous && options.coalesce === true) return previous;

    const linked = createLinkedAbortController([
      this.lifecycleAbortController.signal,
      options.signal,
    ]);
    const tracked = Promise.resolve().then(async () => {
      if (previous) {
        try {
          await previous;
        } catch {
          // A failed predecessor must not permanently poison this queue.
        }
      }
      throwIfAborted(linked.signal, 'Background task aborted.');
      return task(linked.signal);
    }).finally(() => {
      linked.cleanup();
    });

    this.backgroundTasks.add(tracked);
    if (key) this.backgroundTaskQueues.set(key, tracked);
    const cleanup = () => {
      this.backgroundTasks.delete(tracked);
      if (key && this.backgroundTaskQueues.get(key) === tracked) {
        this.backgroundTaskQueues.delete(key);
      }
    };
    tracked.then(cleanup, cleanup);
    return tracked;
  }

  shutdown(options = {}) {
    if (this.shutdownPromise) return this.shutdownPromise;

    const reason = String(
      options.reason || 'Server shutting down while agent work was in progress.',
    );
    const timeoutMs = Math.max(100, Number(options.timeoutMs) || 10000);
    this.shuttingDown = true;
    this.lifecycleAbortController.abort(reason);
    this.interruptAllActiveRuns(reason);

    const childShutdowns = [];
    const childPromises = [];
    for (const record of this.subagents.values()) {
      if (typeof record.engine?.shutdown === 'function') {
        childShutdowns.push(record.engine.shutdown({ reason, timeoutMs }));
      }
      if (record.promise) childPromises.push(record.promise);
    }
    const pending = [
      ...this.activeRunPromises,
      ...this.backgroundTasks,
      ...this.subagentStartupTasks,
      ...childShutdowns,
      ...childPromises,
    ];

    this.shutdownPromise = (async () => {
      if (pending.length === 0) {
        return { state: 'stopped', timedOut: false, pendingCount: 0 };
      }

      let timeout = null;
      const timeoutResult = Symbol('agent-engine-shutdown-timeout');
      const result = await Promise.race([
        Promise.allSettled(pending),
        new Promise((resolve) => {
          timeout = setTimeout(() => resolve(timeoutResult), timeoutMs);
        }),
      ]);
      if (timeout) clearTimeout(timeout);
      const timedOut = result === timeoutResult;
      return {
        state: timedOut ? 'timeout' : 'stopped',
        timedOut,
        pendingCount: timedOut
          ? this.activeRunPromises.size
            + this.backgroundTasks.size
            + this.subagentStartupTasks.size
            + Array.from(this.subagents.values()).filter((record) => !record.settled).length
          : 0,
      };
    })();
    return this.shutdownPromise;
  }

  async buildSystemPrompt(userId, context = {}) {
    const { buildSystemPromptSections } = require('../systemPrompt');
    const { MemoryManager } = require('../../memory/manager');
    const memoryManager = this.memoryManager || new MemoryManager();
    const promptSections = await buildSystemPromptSections(userId, context, memoryManager);
    const timelineService = context.timelineService || this.app?.locals?.timelineService || null;
    const timelinePrompt = timelineService?.buildPromptContext?.(userId, {
      agentId: context.agentId || null,
      query: context.rawUserMessage || context.userMessage || '',
      limit: 6,
      sources: ['screen', 'tasks', 'runs'],
    }) || '';
    const skillRunner = context.skillRunner || this.skillRunner || null;
    const skillsPrompt = skillRunner?.getSkillsForPrompt?.({
      userId,
      maxTotalChars: 9000,
      maxDescriptionChars: 180,
      maxTriggerChars: 100,
    }) || '';
    return {
      stable: [promptSections.stable, skillsPrompt].filter(Boolean).join('\n\n'),
      dynamic: [promptSections.dynamic, timelinePrompt].filter(Boolean).join('\n\n'),
    };
  }

  async buildMemoryRecall({
    memoryManager,
    userId,
    agentId,
    query,
    provider,
    providerName,
    model,
    runId,
    stepId = null,
    options = {},
    returnDetails = false,
  }) {
    const signal = options.signal || this.getRunMeta(runId)?.abortController?.signal || null;
    const initial = await memoryManager.recallMemory(userId, query, 12, {
      agentId,
      signal,
    });

    const pendingChunks = memoryManager.getPendingExtractionChunks?.(userId, agentId, 5) || [];
    if (pendingChunks.length) {
      this.trackBackgroundTask((backgroundSignal) => this.extractPendingChunks(
        pendingChunks,
        {
          userId,
          agentId,
          provider,
          providerName,
          model,
          memoryManager,
          signal: backgroundSignal,
        },
      ), {
        key: `memory-extraction:${userId}:${agentId || 'main'}`,
        coalesce: true,
        signal,
      }).catch((err) => {
        if (!isAbortError(err, signal) && !this.shuttingDown) {
          console.warn('[Memory] Background chunk extraction failed:', err.message);
        }
      });
    }

    const decision = shouldEnhanceRetrieval(initial);
    if (!decision.enhance) {
      const message = await memoryManager.buildRecallMessage(userId, query, {
        agentId,
        recalled: initial.slice(0, 5),
      });
      return returnDetails
        ? { message, results: initial.slice(0, 12), enhanced: false, reason: decision.reason }
        : message;
    }

    const stats = memoryManager.getMemoryStats?.(userId, { agentId })
      || { total: initial.length };
    if (!Number(stats.total || 0)) {
      return returnDetails
        ? { message: null, results: [], enhanced: false, reason: 'empty_memory' }
        : null;
    }

    const startedAt = Date.now();
    let plan = null;
    let merged = initial;
    let reranked = initial;
    try {
      const planned = await this.requestStructuredJson({
        provider,
        providerName,
        model,
        messages: [],
        prompt: buildPlannerPrompt(query, initial, new Date().toISOString()),
        maxTokens: 650,
        normalize: (raw) => normalizeRetrievalPlan(raw, query),
        fallback: normalizeRetrievalPlan({}, query),
        reasoningEffort: this.getReasoningEffort(providerName, options),
        telemetry: { runId, stepId, userId, agentId, signal },
        phase: 'memory_retrieval_plan',
      });
      plan = planned.value;
      const resultSets = [initial];
      for (const variant of plan.queryVariants) {
        if (variant === query && initial.length) continue;
        resultSets.push(await memoryManager.recallMemory(userId, variant, 20, {
          agentId,
          validAt: plan.validAt,
          includeHistory: plan.temporalMode === 'historical',
          signal,
        }));
      }
      merged = mergeRetrievalResults(resultSets, 30);
      if (merged.length > 1) {
        const rerankResponse = await this.requestStructuredJson({
          provider,
          providerName,
          model,
          messages: [],
          prompt: buildRerankerPrompt(query, plan, merged.slice(0, 24)),
          maxTokens: 1200,
          normalize: (raw) => normalizeRerankResult(raw, merged),
          fallback: merged,
          reasoningEffort: this.getReasoningEffort(providerName, options),
          telemetry: { runId, stepId, userId, agentId, signal },
          phase: 'memory_retrieval_rerank',
        });
        reranked = rerankResponse.value;
      } else {
        reranked = merged;
      }
    } catch (error) {
      if (isAbortError(error, signal)) throw error;
      console.warn('[Memory] Retrieval enhancement failed:', error.message);
      plan = null;
      merged = initial;
      reranked = initial;
    }

    memoryManager.recordRetrievalEnhancement?.(userId, {
      query,
      reason: decision.reason,
      plan,
      initialCount: initial.length,
      mergedCount: merged.length,
      resultIds: reranked.slice(0, 5).map((result) => result.id),
      latencyMs: Date.now() - startedAt,
    }, { agentId, runId });

    const message = await memoryManager.buildRecallMessage(userId, query, {
      agentId,
      recalled: reranked.slice(0, 5),
    });
    return returnDetails
      ? {
        message,
        results: reranked.slice(0, 12),
        enhanced: plan !== null,
        reason: decision.reason,
        plan,
      }
      : message;
  }

  async extractPendingChunks(chunks, {
    userId,
    agentId,
    provider,
    providerName,
    model,
    memoryManager,
    signal = null,
  }) {
    const consolidationSchema = JSON.stringify({
      memory_candidates: [{
        memory: 'Concise standalone fact.',
        subject: 'Canonical entity or person.',
        predicate: 'Normalized relationship or attribute.',
        object: 'Current atomic value.',
        relation: 'new | updates | extends | derives',
        category: 'identity | preferences | projects | contacts | events | tasks | episodic | assistant_self',
        confidence: 0.8,
        importance: 5,
        is_static: false,
        valid_from: null,
        valid_to: null,
        forget_after: null,
        evidence: 'Short source-grounded quote.',
      }],
    }, null, 2);

    for (const chunk of chunks) {
      try {
        throwIfAborted(signal, 'Memory extraction aborted.');
        const result = await this.requestStructuredJson({
          provider,
          providerName,
          model,
          messages: [],
          prompt: [
            'Return JSON only. Extract durable memory facts from the document chunk below.',
            buildMemoryConsolidationInstructions(new Date().toISOString()),
            `Source type: ${chunk.sourceType || 'document'}`,
            chunk.title ? `Document title: ${chunk.title}` : '',
            `Content:\n${String(chunk.content || '').slice(0, 2400)}`,
            `Schema:\n${consolidationSchema}`,
          ].filter(Boolean).join('\n\n'),
          maxTokens: 800,
          normalize: (raw) => normalizeMemoryCandidates(raw?.memory_candidates || []),
          fallback: [],
          telemetry: { userId, agentId, signal },
          phase: 'document_extraction',
        });

        const candidates = Array.isArray(result.value) ? result.value : [];
        if (candidates.length) {
          await memoryManager.consolidateMemoryCandidates(userId, candidates, {
            agentId,
            metadata: {
              trustLevel: 'external_source',
              sourceChunkMemoryId: chunk.id,
            },
            signal,
          });
        }
        memoryManager.markChunksExtracted?.([chunk.id], { success: true });
      } catch (err) {
        memoryManager.markChunksExtracted?.([chunk.id], { success: false });
        if (isAbortError(err, signal)) throw err;
        console.warn('[Memory] Document chunk extraction failed:', err.message);
      }
    }
  }

  persistRunMetadata(runId, patch = {}) {
    return persistRunMetadataImpl(this, runId, patch);
  }

  updateRunGoalContract(runId, patch = {}, options = {}) {
    return updateRunGoalContractImpl(this, runId, patch, options);
  }

  buildProgressLedgerSnapshot(runMeta) {
    return buildProgressLedgerSnapshotImpl(this, runMeta);
  }

  persistProgressLedger(runId) {
    return persistProgressLedgerImpl(this, runId);
  }

  updateRunProgress(runId, patch = {}, options = {}) {
    return updateRunProgressImpl(this, runId, patch, options);
  }

  markRunVisibleProgress(runId, timestamp = isoNow()) {
    return markRunVisibleProgressImpl(this, runId, timestamp);
  }

  markRunFinalDelivery(runId, content = '', timestamp = isoNow()) {
    return markRunFinalDeliveryImpl(this, runId, content, timestamp);
  }

  recordRunEvent(userId, runId, eventType, payload = {}, options = {}) {
    return recordRunEventSafe(this, userId, runId, eventType, payload, options);
  }

  async persistDeliverableMemory(userId, runId, agentId, deliverableResult) {
    if (!this.memoryManager?.saveMemory || !deliverableResult?.summary) return;
    try {
      await this.memoryManager.saveMemory(
        userId,
        deliverableResult.summary,
        'tasks',
        deliverableResult.validation?.status === 'passed' ? 7 : 5,
        {
          agentId,
          sourceRef: {
            sourceType: 'deliverable_run',
            sourceId: runId,
            sourceLabel: deliverableResult.type || 'deliverable',
          },
          metadata: {
            deliverableType: deliverableResult.type,
            status: deliverableResult.status,
            artifactCount: Array.isArray(deliverableResult.artifacts)
              ? deliverableResult.artifacts.length
              : 0,
            artifacts: Array.isArray(deliverableResult.artifacts)
              ? deliverableResult.artifacts.slice(0, 6)
              : [],
          },
          signal: this.getRunMeta(runId)?.abortController?.signal || null,
        },
      );
    } catch (error) {
      console.error('[Engine] Failed to persist deliverable memory:', error?.message || error);
    }
  }

  async publishInterimUpdate({
    userId,
    runId,
    agentId = null,
    triggerSource = 'web',
    conversationId = null,
    platform = null,
    chatId = null,
    content,
    kind,
    expectsReply = false,
    deferFollowUp = false,
  } = {}) {
    return publishInterimUpdateImpl(this, {
      userId,
      runId,
      agentId,
      triggerSource,
      conversationId,
      platform,
      chatId,
      content,
      kind,
      expectsReply,
      deferFollowUp,
    });
  }

  async requestStructuredJson({
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
    return requestStructuredJsonImpl(this, {
      provider,
      providerName,
      model,
      messages,
      prompt,
      maxTokens,
      normalize,
      fallback,
      reasoningEffort,
      telemetry,
      phase,
    });
  }

  async inferStructured({
    userId,
    agentId = null,
    modelId = null,
    purpose = 'fast',
    system,
    prompt,
    maxTokens = 400,
    fallback = {},
    signal = null,
  }) {
    const { getFailureFallbackModelId } = require('../runtime/model_fallback');
    const configuredFallbackId = getAiSettings(userId, agentId).fallback_model_id;
    const failedModelIds = new Set();
    let requestedModelId = modelId;
    let selected = null;
    let result = null;

    for (let attempt = 0; attempt < 3; attempt += 1) {
      selected = await getProviderForUser(
        userId,
        prompt,
        false,
        requestedModelId,
        {
          agentId,
          signal,
          selectionHint: {
            purpose: purpose === 'general' ? 'general' : 'fast',
            costMode: purpose === 'fast' ? 'economy' : 'balanced_auto',
          },
        },
      );
      try {
        result = await this.requestStructuredJson({
          provider: selected.provider,
          providerName: selected.providerName,
          model: selected.model,
          messages: system ? [{ role: 'system', content: String(system) }] : [],
          prompt: String(prompt || ''),
          maxTokens,
          normalize: (value) => value,
          fallback,
          telemetry: { userId, agentId, signal },
          phase: 'behavior_inference',
        });
        recordModelSuccess(userId, agentId, selected.modelSelectionId);
        break;
      } catch (error) {
        if (isAbortError(error, signal) || signal?.aborted) throw error;
        recordModelFailure(userId, agentId, selected.modelSelectionId, error);
        failedModelIds.add(selected.modelSelectionId);
        if (attempt >= 2) throw error;
        requestedModelId = await getFailureFallbackModelId(
          userId,
          agentId,
          selected.modelSelectionId,
          configuredFallbackId,
          error,
          signal,
          failedModelIds,
        );
        if (!requestedModelId) throw error;
      }
    }

    return {
      parsed: result.value,
      raw: result.raw,
      usage: result.usage,
      model: selected.model,
      modelSelectionId: selected.modelSelectionId,
      providerName: selected.providerName,
    };
  }

  async requestModelResponse({
    provider,
    providerName,
    model,
    messages,
    tools,
    options,
    runId,
    iteration,
  }) {
    return requestModelResponseImpl(this, {
      provider,
      providerName,
      model,
      messages,
      tools,
      options,
      runId,
      iteration,
    });
  }

  async createExecutionPlan({
    provider,
    providerName,
    model,
    messages,
    analysis,
    capabilitySummary,
    options,
  }) {
    const response = await this.requestStructuredJson({
      provider,
      providerName,
      model,
      messages,
      prompt: buildPlanPrompt(analysis, capabilitySummary),
      maxTokens: 1400,
      normalize: normalizeExecutionPlan,
      fallback: {
        success_criteria: analysis.success_criteria,
      },
      reasoningEffort: this.getReasoningEffort(providerName, options),
      telemetry: options,
      phase: 'execution_plan',
    });

    return {
      plan: response.value,
      raw: response.raw,
      usage: response.usage,
    };
  }

  async verifyFinalResponse({
    provider,
    providerName,
    model,
    messages,
    analysis,
    tools,
    toolExecutions,
    finalReply,
    options,
  }) {
    const evidenceSources = [...new Set(
      toolExecutions
        .map((item) => item.evidenceSource)
        .filter(Boolean)
    )];
    const response = await this.requestStructuredJson({
      provider,
      providerName,
      model,
      messages,
      prompt: buildVerifierPrompt({
        analysis,
        tools,
        toolExecutionSummary: summarizeToolExecutions(toolExecutions),
        evidenceSources,
        finalReply,
      }),
      maxTokens: 1200,
      normalize: (raw) => normalizeVerificationResult(raw, finalReply),
      fallback: {
        status: analysis.freshness_risk === 'none' ? 'verified' : 'insufficient_evidence',
        final_reply: finalReply,
      },
      reasoningEffort: this.getReasoningEffort(providerName, options),
      telemetry: options,
      phase: 'verification',
    });

    return {
      verification: response.value,
      raw: response.raw,
      usage: response.usage,
      evidenceSources,
    };
  }

  async decideLoopState({
    provider,
    providerName,
    model,
    messages,
    analysis,
    plan,
    tools,
    toolExecutions,
    lastReply,
    iteration,
    maxIterations,
    options,
    messagingSent = false,
  }) {
    const runMeta = options?.runId ? this.getRunMeta(options.runId) : null;
    const goalContext = resolveRunGoalContext(runMeta, analysis, plan);
    const researchAdequacy = assessResearchAdequacy({
      analysis,
      goalContext,
      toolExecutions,
    });
    const response = await this.requestStructuredJson({
      provider,
      providerName,
      model,
      messages,
      prompt: buildCompletionDecisionPrompt({
        triggerSource: options?.triggerSource || 'web',
        messagingSent,
        goalContext,
        parallelWork: analysis?.parallel_work === true,
        tools,
        toolExecutions,
        lastReply,
        iteration,
        maxIterations,
        analysis,
        researchAdequacy,
      }),
      maxTokens: 500,
      normalize: (raw) => normalizeCompletionDecision(raw, 'continue'),
      fallback: { status: 'continue', reason: 'completion decision unavailable' },
      reasoningEffort: this.getReasoningEffort(providerName, options),
      telemetry: options,
      phase: 'completion_decision',
    });
    return {
      decision: enforceTerminalReplyDecision(response.value, lastReply, {
        analysis,
        goalContext,
        toolExecutions,
        researchAdequacy,
      }),
      usage: response.usage,
      raw: response.raw,
      researchAdequacy,
    };
  }

  async evaluateTaskCompleteSignal({
    provider,
    providerName,
    model,
    messages,
    analysis,
    plan,
    tools,
    toolExecutions,
    finalMessage,
    confidence,
    iteration,
    maxIterations,
    options,
    messagingSent = false,
  }) {
    const goalContext = resolveRunGoalContext(this.getRunMeta(options?.runId), analysis, plan);
    const confidenceDecision = shouldAcceptTaskComplete({
      confidence,
      requiredConfidence: goalContext.effectiveCompletionConfidence,
      iteration,
      maxIterations,
    });
    if (!confidenceDecision.accept) {
      return {
        accepted: false,
        status: 'continue',
        reason: confidenceDecision.reason,
        usage: 0,
      };
    }

    const judged = await this.decideLoopState({
      provider,
      providerName,
      model,
      messages,
      analysis,
      plan,
      tools,
      toolExecutions,
      lastReply: finalMessage,
      iteration,
      maxIterations,
      options,
      messagingSent,
    });
    return {
      accepted: judged.decision.status === 'complete' || judged.decision.status === 'blocked',
      status: judged.decision.status,
      reason: judged.decision.reason,
      usage: judged.usage,
      raw: judged.raw,
    };
  }

  async assessChurnState({
    provider,
    providerName,
    model,
    messages,
    analysis,
    plan,
    toolExecutions,
    readOnlyCount,
    alreadyRead,
    iteration,
    options,
  }) {
    const runMeta = options?.runId ? this.getRunMeta(options.runId) : null;
    const goalContext = resolveRunGoalContext(runMeta, analysis, plan);
    const response = await this.requestStructuredJson({
      provider,
      providerName,
      model,
      messages,
      prompt: buildChurnAssessmentPrompt({
        readOnlyCount,
        alreadyRead,
        goalContext,
        toolExecutions,
        iteration,
        analysis,
        researchAdequacy: assessResearchAdequacy({
          analysis,
          goalContext,
          toolExecutions,
        }),
      }),
      maxTokens: 200,
      normalize: normalizeChurnAssessment,
      fallback: { assessment: 'churn', reason: 'churn assessment unavailable' },
      reasoningEffort: this.getReasoningEffort(providerName, options),
      telemetry: options,
      phase: 'churn_assessment',
    });
    const researchAdequacy = assessResearchAdequacy({
      analysis,
      goalContext,
      toolExecutions,
    });
    return {
      assessment: enforceChurnAssessment(response.value, {
        analysis,
        goalContext,
        toolExecutions,
        researchAdequacy,
      }),
      usage: response.usage,
      researchAdequacy,
    };
  }

  async refreshConversationState({
    conversationId,
    runId,
    provider,
    providerName,
    model,
    finalReply,
    analysis,
    verification,
    historyWindow,
    options,
  }) {
    if (!conversationId) return null;
    const { MemoryManager } = require('../../memory/manager');
    const memoryManager = this.memoryManager || new MemoryManager();
    const context = getConversationContext(conversationId, Math.max(historyWindow, 8));
    const existingState = memoryManager.getConversationState(conversationId);
    const promptMessages = [
      {
        role: 'system',
        content: [
          'Return JSON only. Distill the current thread working state. Keep it concise and concrete.',
          'Track summary, open_commitments, unresolved_questions, referenced_entities, and last_verified_facts. Do not invent facts.',
          options.memoryScope?.scopeType === 'channel'
            ? [
                'This is a shared room. Extract only durable room or participant facts that are safe and useful in this room.',
                'Do not infer or store facts about the authenticated owner from another participant’s message.',
                options.context?.socialIntelligence?.message?.sender
                  ? `For facts about the current speaker, use the canonical subject "${options.source}:${options.context.socialIntelligence.message.sender}".`
                  : '',
              ].filter(Boolean).join(' ')
            : '',
          buildMemoryConsolidationInstructions(new Date().toISOString()),
          'Schema:',
          JSON.stringify({
            summary: '',
            open_commitments: [],
            unresolved_questions: [],
            referenced_entities: [],
            last_verified_facts: [],
            memory_candidates: [{
              memory: 'Concise standalone fact for future context.',
              subject: 'Canonical entity or person.',
              predicate: 'Normalized relationship or attribute.',
              object: 'Current atomic value.',
              relation: 'new | updates | extends | derives',
              category: 'identity | preferences | projects | contacts | events | tasks | episodic | assistant_self',
              confidence: 0.9,
              importance: 7,
              is_static: false,
              valid_from: null,
              valid_to: null,
              forget_after: null,
              evidence: 'Short source-grounded evidence.',
            }],
          }, null, 2),
        ].join('\n\n')
      },
      {
        role: 'user',
        content: [
          existingState?.summary ? `Existing state:\n${JSON.stringify(existingState, null, 2)}` : 'Existing state: none',
          context.summary ? `Conversation summary:\n${context.summary}` : 'Conversation summary: none',
          `Recent thread messages:\n${JSON.stringify(context.recentMessages.slice(-8), null, 2)}`,
          `Latest final reply:\n${finalReply || '(empty)'}`,
          verification?.status ? `Verification status: ${verification.status}` : '',
          verification?.final_reply && verification.final_reply !== finalReply ? `Verified reply:\n${verification.final_reply}` : '',
          analysis?.goal ? `Thread goal: ${analysis.goal}` : '',
        ].filter(Boolean).join('\n\n')
      }
    ];

    const response = await runAbortableModelCall(
      (signal) => provider.chat(promptMessages, [], {
        model,
        maxTokens: 800,
        reasoningEffort: this.getReasoningEffort(providerName, options),
        signal,
      }),
      options,
      'Conversation state refresh',
    );
    const parsed = parseJsonObject(response.content || '') || {};
    const nextState = {
      summary: String(parsed.summary || existingState?.summary || '').trim(),
      open_commitments: Array.isArray(parsed.open_commitments) ? parsed.open_commitments.slice(0, 8).map((item) => String(item || '').trim()).filter(Boolean) : [],
      unresolved_questions: Array.isArray(parsed.unresolved_questions) ? parsed.unresolved_questions.slice(0, 8).map((item) => String(item || '').trim()).filter(Boolean) : [],
      referenced_entities: Array.isArray(parsed.referenced_entities) ? parsed.referenced_entities.slice(0, 12).map((item) => String(item || '').trim()).filter(Boolean) : [],
      last_verified_facts: Array.isArray(parsed.last_verified_facts) ? parsed.last_verified_facts.slice(0, 10).map((item) => String(item || '').trim()).filter(Boolean) : [],
    };

    if (verification?.status === 'verified' && String(finalReply || '').trim()) {
      nextState.last_verified_facts = [...new Set([
        ...nextState.last_verified_facts,
        clampRunContext(verification.final_reply || finalReply, 280),
      ])].slice(-10);
    }

    memoryManager.updateConversationState(conversationId, nextState);
    const memoryCandidates = normalizeMemoryCandidates(parsed.memory_candidates);
    if (memoryCandidates.length) {
      await memoryManager.consolidateMemoryCandidates(
        options.userId,
        memoryCandidates,
        {
          agentId: options.agentId || null,
          conversationId,
          runId,
          scope: options.memoryScope || undefined,
          metadata: options.memoryScope
            ? {
                trustLevel: 'shared_room_conversation',
                platform: options.source || null,
                chatId: options.chatId || null,
              }
            : undefined,
          signal: options.signal,
        },
      );
      const { invalidateSystemPromptCache } = require('../systemPrompt');
      invalidateSystemPromptCache(options.userId, options.agentId || null);
    }
    return nextState;
  }

  getAvailableTools(app, options = {}) {
    return getAvailableToolsImpl(this, app, options);
  }

  async executeTool(toolName, args, context) {
    return executeToolImpl(this, toolName, args, context);
  }

  isReadOnlyToolCall(toolCall, toolDefinition = null) {
    return isReadOnlyToolCallImpl(toolCall, toolDefinition);
  }

  async executeReadOnlyBatch(toolCalls, context = {}) {
    return executeReadOnlyBatchImpl(this, toolCalls, context);
  }

  async persistRunContext(userId, {
    triggerSource,
    runTitle,
    userMessage,
    lastContent,
    stepIndex,
    skipPersistence = false
  }) {
    if (skipPersistence) {
      return;
    }
    void userId;
    void triggerSource;
    void runTitle;
    void userMessage;
    void lastContent;
    void stepIndex;
    // Run receipts belong in agent_runs/session history, not long-term memory.
    // Long-term memory should only contain durable facts or explicitly saved context.
    return;
  }

  getRunMeta(runId) {
    return this.activeRuns.get(runId) || null;
  }

  initializeToolRuntime(runId, allTools, initialTools, options = {}) {
    return initializeToolRuntimeImpl(this, runId, allTools, initialTools, options);
  }

  getActiveTools(runId) {
    return getActiveToolsImpl(this, runId);
  }

  searchToolsForRun(runId, query, limit = 8) {
    return searchToolsForRunImpl(this, runId, query, limit);
  }

  activateToolsForRun(runId, names = []) {
    return activateToolsForRunImpl(this, runId, names);
  }

  findActiveRunForUser(userId, predicate = null) {
    return findActiveRunForUserImpl(this, userId, predicate);
  }

  findSteerableRunForUser(userId, triggerSource = 'web', conversationId = null) {
    return findSteerableRunForUserImpl(this, userId, triggerSource, conversationId);
  }

  enqueueSteering(runId, content, metadata = {}) {
    return enqueueSteeringImpl(this, runId, content, metadata);
  }

  enqueueSystemSteering(runId, content, metadata = {}) {
    return enqueueSystemSteeringImpl(this, runId, content, metadata);
  }

  applyQueuedSystemSteering(runId, messages) {
    return applyQueuedSystemSteeringImpl(this, runId, messages);
  }

  applyQueuedSteering(runId, messages, { userId, conversationId }) {
    return applyQueuedSteeringImpl(this, runId, messages, { userId, conversationId });
  }

  shouldSendMessagingFinalFallback(runMeta, content, platform = null) {
    return shouldSendMessagingFinalFallbackImpl(this, runMeta, content, platform);
  }

  async deliverMessagingFinalFallback(args) {
    return deliverMessagingFinalFallbackImpl(this, args);
  }

  isRunStopped(runId) {
    return isRunStoppedImpl(this, runId);
  }

  async checkpointLifecycle(runId, phase, state = {}) {
    const runMeta = this.activeRuns.get(runId);
    if (!runMeta) return { action: 'stop' };
    const control = getRunControl(runId);
    if (!control) return null;
    if (control.action !== 'pause') return control;

    checkpointRun(runId, phase, {
      iteration: Number(state.iteration) || 0,
      stepIndex: Number(state.stepIndex) || 0,
      currentPhase: runMeta.progressLedger?.currentPhase || phase,
      activeTools: (runMeta.activeTools || []).map((tool) => tool.name),
      goalContract: runMeta.goalContract || null,
      progressLedger: this.buildProgressLedgerSnapshot(runMeta),
    });
    transitionRun(runId, 'paused', {}, ['running', 'pausing']);
    db.transaction(() => {
      db.prepare(
        `UPDATE agent_steps
         SET status = 'paused', error = COALESCE(NULLIF(error, ''), 'Paused by request.'), completed_at = COALESCE(completed_at, datetime('now'))
         WHERE run_id = ? AND status = 'running'`,
      ).run(runId);
      db.prepare(
        `UPDATE pending_approvals
         SET status = 'expired', decided_at = COALESCE(decided_at, datetime('now')), updated_at = datetime('now')
         WHERE run_id = ? AND status = 'pending'`,
      ).run(runId);
    })();
    runMeta.status = 'paused';
    runMeta.abortController = null;
    this.emit(runMeta.userId, 'run:paused', { runId, reason: control.reason || null });
    this.recordRunEvent(runMeta.userId, runId, 'run_paused', {
      phase,
      reason: control.reason || null,
    }, { agentId: runMeta.agentId });

    await new Promise((resolve) => { runMeta.resumeRun = resolve; });
    runMeta.resumeRun = null;
    if (runMeta.status === 'stopped' || runMeta.status === 'interrupted') {
      return { action: runMeta.status === 'interrupted' ? 'interrupt' : 'stop' };
    }
    const persistedStatus = db.prepare('SELECT status FROM agent_runs WHERE id = ?').get(runId)?.status;
    if (persistedStatus !== 'running') {
      const action = persistedStatus === 'interrupted' ? 'interrupt' : 'stop';
      runMeta.status = persistedStatus || 'stopped';
      return { action };
    }
    runMeta.abortController = new AbortController();
    runMeta.status = 'running';
    return null;
  }

  completeRun(runId, fields = {}) {
    const runMeta = this.activeRuns.get(runId);
    const closed = closeRun(runId, 'completed', fields, ['running']);
    if (closed && runMeta?.userId != null) this.runtimeManager?.releaseControl?.(runMeta.userId, runId);
    return closed;
  }

  failRun(runId, fields = {}) {
    const runMeta = this.activeRuns.get(runId);
    const closed = closeRun(runId, 'failed', fields, ['running']);
    if (closed && runMeta?.userId != null) this.runtimeManager?.releaseControl?.(runMeta.userId, runId);
    return closed;
  }

  attachProcessToRun(runId, pid) {
    return attachProcessToRunImpl(this, runId, pid);
  }

  detachProcessFromRun(runId, pid) {
    return detachProcessFromRunImpl(this, runId, pid);
  }

  // getIterationLimit() removed — use buildLoopPolicy() directly.
  // maxIterations is derived in runWithModel from loopPolicy.maxIterations.

  getReasoningEffort(providerName, options = {}) {
    if (providerName === 'google') return undefined;
    if (options.latencyProfile === 'voice') {
      return 'low';
    }
    return options.reasoningEffort || process.env.REASONING_EFFORT || 'low';
  }

  getMessagingRetryLimit(maxIterations) {
    // Cap at 3: more than 3 autonomous messaging retries indicates a structural
    // problem (model unavailable, bad config) that more retries won't solve.
    return Math.min(3, Math.max(1, maxIterations));
  }

  buildContextMessages(systemPrompt, summaryMessage, historyMessages, recallMsg) {
    const messages = [];
    if (systemPrompt && typeof systemPrompt === 'object') {
      if (systemPrompt.stable) {
        messages.push({
          role: 'system',
          content: systemPrompt.stable,
        });
      }
      if (systemPrompt.dynamic) {
        messages.push({ role: 'system', content: systemPrompt.dynamic });
      }
    } else {
      messages.push({ role: 'system', content: systemPrompt });
    }
    if (summaryMessage) messages.push(summaryMessage);
    if (Array.isArray(historyMessages)) messages.push(...historyMessages);
    if (recallMsg) messages.push({ role: 'system', content: recallMsg });
    return messages;
  }

  buildUserMessage(userMessage, options = {}) {
    if (!options.mediaAttachments || options.mediaAttachments.length === 0) {
      return { role: 'user', content: userMessage };
    }

    const contentArr = [{ type: 'text', text: userMessage }];
    for (const att of options.mediaAttachments) {
      if ((att.type === 'image' || att.type === 'video') && att.path) {
        try {
          if (fs.existsSync(att.path)) {
            const b64 = fs.readFileSync(att.path).toString('base64');
            const mime = att.path.endsWith('.png') ? 'image/png' : att.path.endsWith('.gif') ? 'image/gif' : 'image/jpeg';
            contentArr.push({ type: 'image_url', image_url: { url: `data:${mime};base64,${b64}` } });
          }
        } catch (err) {
          console.warn(`[AgentEngine] Failed to read attachment at ${att.path}:`, err?.message);
        }
      }
    }

    return { role: 'user', content: contentArr.length > 1 ? contentArr : userMessage };
  }

  estimatePromptMetrics(messages, tools) {
    const metrics = {
      systemPromptTokens: 0,
      toolSchemaTokens: estimateTokenValue(tools),
      historyTokens: 0,
      recalledMemoryTokens: 0,
      toolReplayTokens: 0,
      totalEstimatedTokens: 0
    };

    messages.forEach((msg, index) => {
      const contentTokens = estimateTokenValue(msg.content);
      const callTokens = estimateTokenValue(msg.tool_calls);
      const total = contentTokens + callTokens;

      if (msg.role === 'tool') {
        metrics.toolReplayTokens += total;
      } else if (msg.role === 'system' && index === 0) {
        metrics.systemPromptTokens += total;
      } else if (msg.role === 'system' && /^\[Recalled memory/.test(msg.content || '')) {
        metrics.recalledMemoryTokens += total;
      } else {
        metrics.historyTokens += total;
      }
    });

    metrics.totalEstimatedTokens = metrics.systemPromptTokens
      + metrics.toolSchemaTokens
      + metrics.historyTokens
      + metrics.recalledMemoryTokens
      + metrics.toolReplayTokens;

    return metrics;
  }

  mergePromptMetrics(summary, metrics, iteration, toolCount) {
    return {
      iterationsObserved: Math.max(summary.iterationsObserved || 0, iteration),
      toolCount,
      maxEstimatedTokens: Math.max(summary.maxEstimatedTokens || 0, metrics.totalEstimatedTokens),
      maxSystemPromptTokens: Math.max(summary.maxSystemPromptTokens || 0, metrics.systemPromptTokens),
      maxToolSchemaTokens: Math.max(summary.maxToolSchemaTokens || 0, metrics.toolSchemaTokens),
      maxHistoryTokens: Math.max(summary.maxHistoryTokens || 0, metrics.historyTokens),
      maxRecalledMemoryTokens: Math.max(summary.maxRecalledMemoryTokens || 0, metrics.recalledMemoryTokens),
      maxToolReplayTokens: Math.max(summary.maxToolReplayTokens || 0, metrics.toolReplayTokens),
      lastEstimate: metrics
    };
  }

  async persistPromptMetrics(runId, metrics) {
    db.prepare('UPDATE agent_runs SET prompt_metrics = ? WHERE id = ?')
      .run(JSON.stringify(metrics), runId);
  }

  async run(userId, userMessage, options = {}) {
    return this.runWithModel(
      userId,
      userMessage,
      options,
      typeof options.model === 'string' && options.model.trim()
        ? options.model.trim()
        : null,
    );
  }

  async runWithModel(userId, userMessage, options = {}, _modelOverride = null) {
    if (this.shuttingDown || this.lifecycleAbortController.signal.aborted) {
      const error = createAbortError(
        this.lifecycleAbortController.signal,
        'Agent engine is shutting down.',
      );
      error.code = error.code || 'AGENT_ENGINE_SHUTTING_DOWN';
      throw error;
    }
    const runPromise = runConversation(this, userId, userMessage, options, _modelOverride);
    this.activeRunPromises.add(runPromise);
    try {
      return await runPromise;
    } finally {
      this.activeRunPromises.delete(runPromise);
    }
  }

  async spawnSubagent(userId, parentRunId, task, options = {}) {
    if (this.shuttingDown || this.lifecycleAbortController.signal.aborted) {
      throw createAbortError(this.lifecycleAbortController.signal, 'Agent engine is shutting down.');
    }

    let parentRunMeta = this.getRunMeta(parentRunId);
    if (
      !parentRunMeta
      || parentRunMeta.userId !== userId
      || parentRunMeta.status !== 'running'
      || parentRunMeta.aborted === true
    ) {
      return { error: 'The parent run is no longer active, so a sub-agent cannot be started.' };
    }
    const parentDepth = Math.max(0, Number(parentRunMeta?.subagentDepth) || 0);
    if (parentDepth >= 1) {
      return {
        error: 'Sub-agents cannot spawn additional sub-agents. Continue the current child run or return results to the parent run.',
      };
    }

    const aiSettings = getAiSettings(userId, options.agentId || null);
    const maxSubagentsPerRun = Math.max(1, Number(aiSettings.subagent_max_children_per_run) || 10);
    const countExistingSubagents = () => Array.from(this.subagents.values())
      .filter((record) => record.parentRunId === parentRunId).length;
    if (countExistingSubagents() >= maxSubagentsPerRun) {
      return {
        error: `This run has already spawned ${countExistingSubagents()} sub-agents. The limit for one run is ${maxSubagentsPerRun}.`,
      };
    }

    const handle = uuidv4();
    const childRunId = uuidv4();
    let relevantMemories = [];
    const startupLink = createLinkedAbortController([
      this.lifecycleAbortController.signal,
      parentRunMeta.abortController?.signal,
      options.signal,
    ]);
    let memoryRecall = null;
    try {
      throwIfAborted(startupLink.signal, 'Sub-agent startup was aborted.');
      memoryRecall = this.memoryManager
        ? runWithAbortTimeout(
          (signal) => this.memoryManager.recallMemory(userId, task, 4, {
            agentId: options.agentId || null,
            signal,
          }),
          {
            label: 'Sub-agent memory recall',
            signal: startupLink.signal,
          },
        )
        : Promise.resolve([]);
      this.subagentStartupTasks.add(memoryRecall);
      relevantMemories = await memoryRecall;
      throwIfAborted(startupLink.signal, 'Sub-agent startup was aborted.');
    } catch (error) {
      if (isAbortError(error, startupLink.signal)) throw error;
      console.warn('[AgentEngine] Sub-agent memory recall failed:', error?.message || error);
    } finally {
      if (memoryRecall) this.subagentStartupTasks.delete(memoryRecall);
      startupLink.cleanup();
    }

    parentRunMeta = this.getRunMeta(parentRunId);
    if (
      this.shuttingDown
      || this.lifecycleAbortController.signal.aborted
      || !parentRunMeta
      || parentRunMeta.userId !== userId
      || parentRunMeta.status !== 'running'
      || parentRunMeta.aborted === true
    ) {
      throw createAbortError(
        this.lifecycleAbortController.signal.aborted
          ? this.lifecycleAbortController.signal
          : parentRunMeta?.abortController?.signal,
        'The parent run stopped before the sub-agent could start.',
      );
    }
    const currentSubagentCount = countExistingSubagents();
    if (currentSubagentCount >= maxSubagentsPerRun) {
      return {
        error: `This run has already spawned ${currentSubagentCount} sub-agents. The limit for one run is ${maxSubagentsPerRun}.`,
      };
    }

    const childLink = createLinkedAbortController([
      this.lifecycleAbortController.signal,
      parentRunMeta.abortController?.signal,
      options.signal,
    ]);
    throwIfAborted(childLink.signal, 'Sub-agent startup was aborted.');
    const subEngine = new AgentEngine(this.io, {
      app: options.app || this.app,
      browserController: this.browserController,
      androidController: this.androidController,
      runtimeManager: this.runtimeManager,
      workspaceManager: this.workspaceManager,
      messagingManager: this.messagingManager,
      mcpManager: this.mcpManager,
      skillRunner: this.skillRunner,
      taskRuntime: this.taskRuntime,
      memoryManager: this.memoryManager,
    });

    const subagentContract = [
      `Goal: ${String(task || '').trim()}`,
      options.context ? `Constraints and relevant context:\n${String(options.context).trim()}` : '',
      relevantMemories.length > 0
        ? `Top relevant memories: ${JSON.stringify(relevantMemories.map((memory) => ({
          content: memory.content,
          confidence: memory.confidence,
        })))}`
        : '',
      Array.isArray(options.requiredArtifacts) && options.requiredArtifacts.length > 0
        ? `Required artifacts: ${JSON.stringify(options.requiredArtifacts)}`
        : '',
      Array.isArray(options.selectedTools) && options.selectedTools.length > 0
        ? `Selected tools: ${JSON.stringify(options.selectedTools.slice(0, 20))}`
        : '',
      'Return a single JSON object with exactly these top-level fields: status, findings, evidence, artifacts, confidence, remaining_blockers.',
      'status must be completed, partial, or blocked. findings, evidence, artifacts, and remaining_blockers must be arrays. confidence must be low, medium, or high.',
    ].filter(Boolean).join('\n\n');
    const record = {
      handle,
      parentRunId,
      childRunId,
      userId,
      agentId: options.agentId || null,
      task: subagentContract,
      model: options.model || null,
      status: 'running',
      createdAt: new Date().toISOString(),
      result: null,
      error: null,
      engine: subEngine,
      promise: null,
      settled: false,
      deleteWhenSettled: false,
    };
    this.subagents.set(handle, record);
    this.emit(userId, 'run:subagent', {
      runId: parentRunId,
      handle,
      childRunId,
      status: 'running',
      task: clampRunContext(task, 180),
    });

    record.promise = (async () => {
      try {
        const result = await subEngine.runWithModel(
          userId,
          subagentContract,
          {
            app: options.app || this.app,
            triggerType: 'subagent',
            triggerSource: 'agent',
            runId: childRunId,
            agentId: options.agentId || null,
            subagentDepth: parentDepth + 1,
            disallowedToolNames: ['spawn_subagent'],
            signal: childLink.signal,
          },
          options.model || null
        );
        if (record.status === 'cancelled' || childLink.signal.aborted) return record;
        record.status = result.status || 'completed';
        let structured = null;
        try {
          const raw = String(result.content || '').trim().replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/, '');
          const parsed = JSON.parse(raw);
          if (parsed && typeof parsed === 'object') structured = parsed;
        } catch {}
        record.result = {
          runId: result.runId,
          status: structured?.status || result.status || 'completed',
          findings: Array.isArray(structured?.findings) ? structured.findings : [String(result.content || '').trim()].filter(Boolean),
          evidence: Array.isArray(structured?.evidence) ? structured.evidence : [],
          artifacts: Array.isArray(structured?.artifacts) ? structured.artifacts : [],
          confidence: ['low', 'medium', 'high'].includes(structured?.confidence) ? structured.confidence : 'medium',
          remainingBlockers: Array.isArray(structured?.remaining_blockers) ? structured.remaining_blockers : [],
          totalTokens: result.totalTokens,
          iterations: result.iterations,
        };
        this.emit(userId, 'run:subagent', {
          runId: parentRunId,
          handle,
          childRunId,
          status: record.status,
          result: record.result,
        });
        return record;
      } catch (err) {
        const cancelled = record.status === 'cancelled' || isAbortError(err, childLink.signal);
        record.status = cancelled ? 'cancelled' : 'failed';
        record.error = cancelled ? null : (err?.message || String(err));
        this.emit(userId, 'run:subagent', {
          runId: parentRunId,
          handle,
          childRunId,
          status: record.status,
          error: record.error,
        });
        return record;
      } finally {
        record.settled = true;
        childLink.cleanup();
        if (record.deleteWhenSettled && this.subagents.get(handle) === record) {
          this.subagents.delete(handle);
        }
      }
    })();

    return {
      handle,
      status: 'running',
      childRunId,
      task: clampRunContext(task, 180),
    };
  }

  async delegateToAgent({
    userId,
    parentAgentId,
    parentRunId,
    target,
    task,
    context = '',
    app = null,
    allowExternalSideEffects = false,
  } = {}) {
    const { agentCanDelegateTo, getAgentById, getAgentBySlug, resolveAgentId } = require('../../agents/manager');
    const targetText = String(target || '').trim();
    const taskText = String(task || '').trim();
    if (!targetText || !taskText) {
      throw new Error('Target agent and task are required.');
    }

    let targetAgent = getAgentById(userId, targetText) || getAgentBySlug(userId, targetText);
    if (!targetAgent) {
      targetAgent = db.prepare(
        "SELECT * FROM agents WHERE user_id = ? AND status = 'active' AND lower(display_name) = lower(?)"
      ).get(userId, targetText);
    }
    if (!targetAgent || targetAgent.status !== 'active') {
      throw new Error(`No active specialist agent matches "${targetText}".`);
    }

    const scopedParentAgentId = resolveAgentId(userId, parentAgentId);
    const parentAgent = getAgentById(userId, scopedParentAgentId);
    if (targetAgent.id === scopedParentAgentId) {
      throw new Error('An agent cannot delegate to itself.');
    }
    if (!agentCanDelegateTo(parentAgent, targetAgent)) {
      throw new Error(`${parentAgent?.display_name || 'This agent'} is not allowed to delegate tasks to ${targetAgent.display_name}.`);
    }

    const delegationId = uuidv4();
    const childRunId = uuidv4();
    db.prepare(
      `INSERT INTO agent_delegations (
        id, user_id, parent_agent_id, target_agent_id, parent_run_id, child_run_id, task, context, status
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'running')`
    ).run(
      delegationId,
      userId,
      scopedParentAgentId,
      targetAgent.id,
      parentRunId || null,
      childRunId,
      taskText,
      context || null,
    );

    const delegatedPrompt = [
      '[SYSTEM: Delegated specialist-agent task]',
      `You are running as ${targetAgent.display_name} (${targetAgent.slug}).`,
      'Complete this delegated task using only your own agent memory, settings, credentials, and available tools.',
      allowExternalSideEffects
        ? 'External side effects are allowed only when they directly satisfy the delegated task.'
        : 'Do not send external messages, make calls, or change external shared systems. Return findings and recommendations to the parent agent instead.',
      '',
      `Task:\n${taskText}`,
      context ? `\nContext from parent agent:\n${context}` : '',
    ].filter(Boolean).join('\n');

    try {
      const result = await this.runWithModel(
        userId,
        delegatedPrompt,
        {
          app: app || this.app,
          runId: childRunId,
          agentId: targetAgent.id,
          triggerType: 'agent_delegation',
          triggerSource: 'agent_delegation',
          skipConversationHistory: true,
          skipConversationMaintenance: true,
          context: { additionalContext: `Parent run: ${parentRunId || 'unknown'}` },
          allowExternalSideEffects,
        },
        null,
      );
      const summary = String(result?.content || '').trim();
      db.prepare(
        `UPDATE agent_delegations
         SET status = ?, result_summary = ?, updated_at = datetime('now'), completed_at = datetime('now')
         WHERE id = ?`
      ).run(result?.status || 'completed', summary.slice(0, 20000), delegationId);
      return {
        delegationId,
        targetAgent: {
          id: targetAgent.id,
          slug: targetAgent.slug,
          name: targetAgent.display_name,
        },
        childRunId: result?.runId || childRunId,
        status: result?.status || 'completed',
        summary,
        totalTokens: result?.totalTokens || 0,
      };
    } catch (err) {
      db.prepare(
        `UPDATE agent_delegations
         SET status = 'failed', error = ?, updated_at = datetime('now'), completed_at = datetime('now')
         WHERE id = ?`
      ).run(String(err?.message || err).slice(0, 20000), delegationId);
      throw err;
    }
  }

  listSubagents(parentRunId = null) {
    return Array.from(this.subagents.values())
      .filter((record) => !parentRunId || record.parentRunId === parentRunId)
      .map((record) => ({
        handle: record.handle,
        parentRunId: record.parentRunId,
        childRunId: record.childRunId,
        status: record.status,
        task: clampRunContext(record.task, 180),
        result: record.result,
        error: record.error,
        createdAt: record.createdAt,
      }));
  }

  async cleanupSubagentsForRun(parentRunId, options = {}) {
    if (!parentRunId) return { cancelled: 0, timedOut: 0 };
    const cancelRunning = options.cancelRunning !== false;
    const shutdowns = [];
    const records = [];
    for (const [handle, record] of Array.from(this.subagents.entries())) {
      if (record.parentRunId !== parentRunId) continue;
      records.push([handle, record]);
      record.deleteWhenSettled = true;
      if (cancelRunning && record.status === 'running') {
        record.status = 'cancelled';
        this.emit(record.userId, 'run:subagent', {
          runId: record.parentRunId,
          handle,
          childRunId: record.childRunId,
          status: 'cancelled',
        });
        shutdowns.push(Promise.resolve(record.engine?.shutdown?.({
          reason: 'Parent run finished before the sub-agent completed.',
          timeoutMs: Math.max(100, Number(options.timeoutMs) || 10000),
        })));
      } else if (record.status === 'running') {
        record.deleteWhenSettled = false;
      }
    }
    const results = await Promise.allSettled(shutdowns);
    for (const [handle, record] of records) {
      if ((record.settled || !record.promise) && this.subagents.get(handle) === record) {
        this.subagents.delete(handle);
      }
    }
    return {
      cancelled: shutdowns.length,
      timedOut: results.filter((result) => (
        result.status === 'fulfilled' && result.value?.timedOut === true
      )).length,
    };
  }

  async waitForSubagent(handle, options = {}) {
    const record = this.subagents.get(handle);
    if (!record) {
      return { error: `Unknown sub-agent handle: ${handle}` };
    }
    if (options.parentRunId && record.parentRunId !== options.parentRunId) {
      return { error: 'That sub-agent does not belong to the current parent run.' };
    }

    if (record.status !== 'running' || !record.promise) {
      return {
        handle,
        status: record.status,
        result: record.result,
        error: record.error,
      };
    }

    const timeoutMs = Math.max(1000, Number(options.timeoutMs) || 30000);
    const timeout = new Promise((resolve) => {
      setTimeout(() => resolve(null), timeoutMs);
    });
    const settled = await Promise.race([
      record.promise.then(() => record).catch(() => record),
      timeout,
    ]);

    if (!settled) {
      return {
        handle,
        status: 'running',
        timedOut: true,
      };
    }

    return {
      handle,
      status: record.status,
      result: record.result,
      error: record.error,
    };
  }

  async cancelSubagent(handle, options = {}) {
    const record = this.subagents.get(handle);
    if (!record) {
      return { error: `Unknown sub-agent handle: ${handle}` };
    }
    if (options.parentRunId && record.parentRunId !== options.parentRunId) {
      return { error: 'That sub-agent does not belong to the current parent run.' };
    }
    if (record.status !== 'running') {
      return {
        handle,
        status: record.status,
        result: record.result,
        error: record.error,
      };
    }

    record.status = 'cancelled';
    this.emit(record.userId, 'run:subagent', {
      runId: record.parentRunId,
      handle,
      childRunId: record.childRunId,
      status: 'cancelled',
    });

    const shutdown = await record.engine?.shutdown?.({
      reason: 'Sub-agent cancelled by its parent run.',
      timeoutMs: Math.max(100, Number(options.timeoutMs) || 10000),
    });
    return {
      handle,
      status: 'cancelled',
      timedOut: shutdown?.timedOut === true,
    };
  }

  interruptRun(runId, reason = 'Server shutting down while run was in progress.') {
    const runMeta = this.activeRuns.get(runId);
    const persistedRun = runMeta || db.prepare('SELECT user_id AS userId FROM agent_runs WHERE id = ?').get(runId);
    if (persistedRun?.userId != null) {
      requestRunControl(runId, persistedRun.userId, 'interrupt', reason);
    }
    const delegatedChildren = db.prepare(
      "SELECT child_run_id FROM agent_delegations WHERE parent_run_id = ? AND status = 'running'"
    ).all(runId);
    if (runMeta) {
      runMeta.status = 'interrupted';
      runMeta.stopReason = reason;
      runMeta.aborted = true;
      runMeta.abortController?.abort(reason);
      runMeta.resumeRun?.();
      this.emit(runMeta.userId, 'run:stopping', { runId });
      for (const pid of runMeta.toolPids) {
        if (this.runtimeManager && typeof this.runtimeManager.killCommand === 'function') {
          void this.runtimeManager.killCommand(runMeta.userId, pid, 'aborted', {
            deviceTarget: runMeta.deviceTarget,
          });
        }
      }
      runMeta.toolPids.clear();
    }
    for (const child of delegatedChildren) {
      if (child.child_run_id && child.child_run_id !== runId) {
        this.interruptRun(child.child_run_id, reason);
      }
    }
    db.prepare(
      `UPDATE agent_delegations
       SET status = 'interrupted',
           error = COALESCE(NULLIF(error, ''), ?),
           updated_at = datetime('now'),
           completed_at = datetime('now')
       WHERE parent_run_id = ? AND status = 'running'`
    ).run(reason, runId);
    closeRun(runId, 'interrupted', { error: reason }, ['running', 'pausing', 'paused', 'resuming']);
    if (persistedRun?.userId != null) this.runtimeManager?.releaseControl?.(persistedRun.userId, runId);
  }

  interruptAllActiveRuns(reason = 'Server shutting down while run was in progress.') {
    for (const runId of Array.from(this.activeRuns.keys())) {
      this.interruptRun(runId, reason);
    }
  }

  stopRun(runId, reason = 'Stopped by request.') {
    const stopReason = String(reason || 'Stopped by request.').slice(0, 1000);
    const runMeta = this.activeRuns.get(runId);
    const persistedRun = runMeta || db.prepare(
      'SELECT user_id AS userId, status FROM agent_runs WHERE id = ?',
    ).get(runId);
    if (!persistedRun || TERMINAL_STATUSES.has(persistedRun.status)) return false;
    if (persistedRun?.userId != null) {
      requestRunControl(runId, persistedRun.userId, 'stop', stopReason);
    }
    const delegatedChildren = db.prepare(
      "SELECT child_run_id FROM agent_delegations WHERE parent_run_id = ? AND status = 'running'"
    ).all(runId);
    if (runMeta) {
      runMeta.status = 'stopped';
      runMeta.stopReason = stopReason;
      runMeta.aborted = true;
      runMeta.abortController?.abort(stopReason);
      runMeta.resumeRun?.();
      this.emit(runMeta.userId, 'run:stopping', { runId, reason: stopReason });
      for (const pid of runMeta.toolPids) {
        if (this.runtimeManager && typeof this.runtimeManager.killCommand === 'function') {
          void this.runtimeManager.killCommand(runMeta.userId, pid, 'aborted', {
            deviceTarget: runMeta.deviceTarget,
          });
        }
      }
      runMeta.toolPids.clear();
    }
    for (const child of delegatedChildren) {
      if (child.child_run_id && child.child_run_id !== runId) {
        this.stopRun(child.child_run_id, stopReason);
      }
    }
    db.prepare(
      `UPDATE agent_delegations
       SET status = 'stopped', error = COALESCE(NULLIF(error, ''), ?),
           updated_at = datetime('now'), completed_at = datetime('now')
       WHERE parent_run_id = ? AND status = 'running'`
    ).run(stopReason, runId);
    closeRun(
      runId,
      'stopped',
      { error: stopReason },
      ['running', 'pausing', 'paused', 'resuming'],
    );
    if (persistedRun?.userId != null) this.runtimeManager?.releaseControl?.(persistedRun.userId, runId);
    return true;
  }

  pauseRun(runId, { userId, reason = '' } = {}) {
    if (!runId || userId == null) return false;
    const runMeta = this.activeRuns.get(runId);
    if (
      !runMeta
      || Number(runMeta.userId) !== Number(userId)
      || runMeta.status !== 'running'
      || runMeta.pauseAvailable !== true
    ) return false;
    const result = requestRunControl(runId, userId, 'pause', reason);
    if (!result.accepted) return false;
    transitionRun(runId, 'pausing', {}, ['running']);
    runMeta.status = 'pausing';
    runMeta.abortController?.abort('Run paused.');
    for (const pid of runMeta.toolPids) {
      if (this.runtimeManager && typeof this.runtimeManager.killCommand === 'function') {
        void this.runtimeManager.killCommand(runMeta.userId, pid, 'paused', {
          deviceTarget: runMeta.deviceTarget,
        });
      }
    }
    this.emit(runMeta.userId, 'run:pausing', { runId, reason: reason || null });
    this.runtimeManager?.releaseControl?.(runMeta.userId, runId);
    return true;
  }

  resumeRun(runId, { userId } = {}) {
    if (!runId || userId == null) return false;
    const runMeta = this.activeRuns.get(runId);
    if (!runMeta || Number(runMeta.userId) !== Number(userId) || runMeta.status !== 'paused') return false;
    if (!transitionRun(runId, 'resuming', {}, ['paused'])) return false;
    db.prepare(
      `UPDATE agent_run_controls SET consumed_at = datetime('now')
       WHERE run_id = ? AND action = 'pause' AND consumed_at IS NULL`,
    ).run(runId);
    transitionRun(runId, 'running', {}, ['resuming']);
    this.emit(runMeta.userId, 'run:resumed', { runId });
    this.recordRunEvent(runMeta.userId, runId, 'run_resumed', {}, { agentId: runMeta.agentId });
    runMeta.resumeRun?.();
    return true;
  }

  abort(runId, { userId, reason = 'Stopped by request.' } = {}) {
    if (!runId) return false;
    const runMeta = this.activeRuns.get(runId);
    const persistedRun = runMeta
      || db.prepare('SELECT user_id AS userId, status FROM agent_runs WHERE id = ?').get(runId);
    if (!persistedRun || TERMINAL_STATUSES.has(persistedRun.status)) return false;
    if (userId != null) {
      // Ownership gate applies to both active and persisted runs.
      if (Number(persistedRun.userId) !== Number(userId)) return false;
    }
    return this.stopRun(runId, reason);
  }

  abortAll(userId) {
    for (const [runId, run] of this.activeRuns) {
      if (run.userId === userId) this.stopRun(runId);
    }
  }

  getStepType(toolName) {
    if (toolName.startsWith('browser_')) return 'browser';
    if (toolName.startsWith('desktop_')) return 'desktop';
    if (toolName.startsWith('android_')) return 'android';
    if (toolName === 'execute_command') return 'cli';
    if (FILE_TOOL_NAMES.has(toolName)) return 'files';
    if (toolName.startsWith('memory_')) return 'memory';
    if (toolName === 'send_interim_update') return 'note';
    if (toolName === 'request_user_input') return 'question';
    if (toolName === 'send_message') return 'messaging';
    if (toolName === 'call_user') return 'voice';
    if (toolName.startsWith('mcp_') || toolName.includes('mcp')) return 'mcp';
    if (toolName === 'create_task' || toolName === 'update_task' || toolName === 'delete_task' || toolName === 'list_tasks') return 'tasks';
    if (toolName.includes('subagent')) return 'subagent';
    if (toolName === 'think') return 'thinking';
    return 'tool';
  }

  emit(userId, event, data) {
    let payload = data && typeof data === 'object' && !Array.isArray(data)
      ? { ...data }
      : data;
    if (payload?.runId && !payload.conversationId) {
      const runMeta = this.activeRuns.get(payload.runId);
      let persisted = null;
      if (!runMeta) {
        persisted = db.prepare(
          `SELECT conversation_id, interaction_mode, device_target
           FROM agent_runs WHERE id = ?`,
        ).get(payload.runId);
      }
      const conversationId = runMeta?.conversationId || persisted?.conversation_id || null;
      if (conversationId) {
        payload.conversationId = conversationId;
        payload.interactionMode = runMeta?.interactionMode
          || persisted?.interaction_mode
          || 'agent';
        payload.deviceTarget = runMeta?.deviceTarget
          || persisted?.device_target
          || null;
      }
    }
    if (
      ['run:complete', 'run:error', 'run:stopped', 'run:interrupted'].includes(event)
      && payload?.runId
    ) {
      this.voiceRuntimeManager?.handleRunTerminal?.(payload.runId);
    }
    if (this.io) {
      this.io.to(`user:${userId}`).emit(event, payload);
    }
  }
}

module.exports = { AgentEngine, buildInitialRunMetadata, getProviderForUser };
