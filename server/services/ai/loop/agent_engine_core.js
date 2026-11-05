'use strict';

const { isAdminUser } = require('../../access/admin');
const { GENERIC_ERROR_MESSAGE, nonAdminErrorMessage } = require('../../../utils/public_error');
const fs = require('fs');
const db = require('../../../db/database');
const { getProviderForUser } = require('../provider_selector');
const {
  recordModelFailure,
  recordModelSuccess,
} = require('../model_failure_cache');
const { runOrchestrator } = require('../runtime/run_orchestrator');
const {
  activateToolsForRun: activateToolsForRunImpl,
  applyQueuedSteering: applyQueuedSteeringImpl,
  applyQueuedSystemSteering: applyQueuedSystemSteeringImpl,
  describeIntegrationsForRun: describeIntegrationsForRunImpl,
  enqueueSteering: enqueueSteeringImpl,
  enqueueSystemSteering: enqueueSystemSteeringImpl,
  findSteerableRunForUser: findSteerableRunForUserImpl,
  getActiveTools: getActiveToolsImpl,
  initializeToolRuntime: initializeToolRuntimeImpl,
  markRunFinalDelivery: markRunFinalDeliveryImpl,
  markRunVisibleProgress: markRunVisibleProgressImpl,
  markRunVisibleReply: markRunVisibleReplyImpl,
  persistRunMetadata: persistRunMetadataImpl,
  recordRunEventSafe,
  searchToolsForRun: searchToolsForRunImpl,
} = require('./run_state');
const { EVENT_TYPES } = require('../runtime/events/event_types');
const { recordEventSafe } = require('../runtime/events/run_event_store');
const { decideMemoryRecall, filterRecalled, memoryTokens } = require('../runtime/memory_policy');
const {
  extractDocumentFacts: extractDocumentFactsImpl,
  refreshConversationState: refreshConversationStateImpl,
} = require('./memory_writer');
const {
  hasWritingSubagent: hasWritingSubagentImpl,
  spawnSubagent: spawnSubagentImpl,
  delegateToAgent: delegateToAgentImpl,
  listSubagents: listSubagentsImpl,
  cleanupSubagentsForRun: cleanupSubagentsForRunImpl,
  waitForSubagent: waitForSubagentImpl,
  cancelSubagent: cancelSubagentImpl,
} = require('./subagents');
const {
  checkpointLifecycle: checkpointLifecycleImpl,
  interruptRun: interruptRunImpl,
  interruptAllActiveRuns: interruptAllActiveRunsImpl,
  stopRun: stopRunImpl,
  pauseRun: pauseRunImpl,
  resumeRun: resumeRunImpl,
  abort: abortImpl,
  abortAll: abortAllImpl,
} = require('./run_controls');
const { manageBackgroundRun: manageBackgroundRunImpl } = require('./background_runs');
const {
  deliverMessagingFinalFallback: deliverMessagingFinalFallbackImpl,
  shouldSendMessagingFinalFallback: shouldSendMessagingFinalFallbackImpl,
} = require('./messaging_delivery');
const {
  requestModelResponse: requestModelResponseImpl,
  requestStructuredJson: requestStructuredJsonImpl,
} = require('./model_io');
const {
  publishInterimUpdate: publishInterimUpdateImpl,
} = require('./callbacks');
const {
  executeTool: executeToolImpl,
  getAvailableTools: getAvailableToolsImpl,
  isReadOnlyToolCall: isReadOnlyToolCallImpl,
} = require('./tool_dispatch');
const { stepTypeFor } = require('../tools/metadata');
const systemOne = require('../system_one');
const {
  createAbortError,
  createLinkedAbortController,
  isAbortError,
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
      promptVersion: promptSections.promptVersion,
    };
  }

  // Memories relevant to the request, found by direct search and handed to the
  // agent before its first turn. Deeper recall (other phrasings, a past point
  // in time) is the agent's own call through memory_recall.
  async buildMemoryRecall({
    memoryManager,
    userId,
    agentId,
    query,
    runId,
    options = {},
  }) {
    const startedAt = Date.now();
    const decision = decideMemoryRecall(query);
    const runMeta = this.getRunMeta(runId);
    const record = (payload) => {
      if (!runMeta) return;
      recordEventSafe({
        runId,
        userId,
        agentId,
        eventType: EVENT_TYPES.MEMORY_RECALL,
        payload: { trigger: decision.trigger, duration_ms: Date.now() - startedAt, ...payload },
      });
    };
    if (!decision.recall) {
      record({ recalled: false, candidates: 0, kept: 0, tokens: 0 });
      return null;
    }
    const signal = options.signal || runMeta?.abortController?.signal || null;
    // buildRecallMessage reinforces what it actually injects.
    const found = await memoryManager.recallMemory(userId, query, 5, {
      agentId,
      signal,
      reinforce: false,
    });
    const recalled = filterRecalled(found, { minSignal: decision.minSignal });
    const message = await memoryManager.buildRecallMessage(userId, query, { agentId, recalled });
    record({
      recalled: true,
      candidates: found.length,
      kept: recalled.length,
      dropped: found.length - recalled.length,
      scores: recalled.map((memory) => Number(Number(memory.score || 0).toFixed(3))),
      // Real embedding scores for checking the thresholds; no memory content.
      cosines: found.map((memory) => Number(Number(memory.scoreBreakdown?.cosine || 0).toFixed(3))),
      tokens: memoryTokens(message),
    });
    return message;
  }

  extractDocumentFacts(...args) {
    return extractDocumentFactsImpl(this, ...args);
  }

  persistRunMetadata(runId, patch = {}) {
    return persistRunMetadataImpl(this, runId, patch);
  }

  markRunVisibleProgress(runId, timestamp = isoNow()) {
    return markRunVisibleProgressImpl(this, runId, timestamp);
  }

  markRunVisibleReply(runId, timestamp = isoNow()) {
    return markRunVisibleReplyImpl(this, runId, timestamp);
  }

  markRunFinalDelivery(runId, content = '', timestamp = isoNow()) {
    return markRunFinalDeliveryImpl(this, runId, content, timestamp);
  }

  recordRunEvent(userId, runId, eventType, payload = {}, options = {}) {
    return recordRunEventSafe(this, userId, runId, eventType, payload, options);
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

  // A SystemOne decision for a behind-the-scenes choice. Null means SystemOne
  // is off or did not answer, and the caller takes its model path.
  decide(request) {
    return systemOne.decide(request);
  }

  // Whether a SystemOne model can answer for this agent right now.
  isSystemOneReady(userId, agentId, signal) {
    return systemOne.isSystemOneReady(userId, agentId, signal);
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

    async refreshConversationState(...args) {
    return refreshConversationStateImpl(this, ...args);
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

  getRunMeta(runId) {
    return this.activeRuns.get(runId) || null;
  }

  initializeToolRuntime(runId, allTools, initialTools, options = {}) {
    return initializeToolRuntimeImpl(this, runId, allTools, initialTools, options);
  }

  getActiveTools(runId) {
    return getActiveToolsImpl(this, runId);
  }

  describeIntegrationsForRun(runId, tools = []) {
    return describeIntegrationsForRunImpl(this, runId, tools);
  }

  searchToolsForRun(runId, query, limit = 8) {
    return searchToolsForRunImpl(this, runId, query, limit);
  }

  activateToolsForRun(runId, names = []) {
    return activateToolsForRunImpl(this, runId, names);
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

  manageBackgroundRun(callerRunId, args = {}) {
    return manageBackgroundRunImpl(this, callerRunId, args);
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

    async checkpointLifecycle(runId, phase, state = {}) {
    return checkpointLifecycleImpl(this, runId, phase, state);
  }

  // getIterationLimit() removed — use buildLoopPolicy() directly.
  // maxIterations is derived in runWithModel from loopPolicy.maxIterations.

  getReasoningEffort(providerName, options = {}) {
    if (options.latencyProfile === 'voice') {
      return 'low';
    }
    return options.reasoningEffort || process.env.REASONING_EFFORT || 'low';
  }

  // Stable text first, then what changes per run, so providers can cache the head
  // of the prompt across runs. Recalled memory sits right before the request it
  // was recalled for.
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
    const runPromise = runOrchestrator(this, userId, userMessage, options, _modelOverride);
    this.activeRunPromises.add(runPromise);
    try {
      return await runPromise;
    } finally {
      this.activeRunPromises.delete(runPromise);
    }
  }

    hasWritingSubagent(parentRunId) {
    return hasWritingSubagentImpl(this, parentRunId);
  }

    async spawnSubagent(userId, parentRunId, task, options = {}) {
    return spawnSubagentImpl(this, userId, parentRunId, task, options);
  }

    async delegateToAgent(...args) {
    return delegateToAgentImpl(this, ...args);
  }

    listSubagents(parentRunId = null) {
    return listSubagentsImpl(this, parentRunId);
  }

    async cleanupSubagentsForRun(parentRunId, options = {}) {
    return cleanupSubagentsForRunImpl(this, parentRunId, options);
  }

    async waitForSubagent(handle, options = {}) {
    return waitForSubagentImpl(this, handle, options);
  }

    async cancelSubagent(handle, options = {}) {
    return cancelSubagentImpl(this, handle, options);
  }

    interruptRun(runId, reason = 'Server shutting down while run was in progress.') {
    return interruptRunImpl(this, runId, reason);
  }

    interruptAllActiveRuns(reason = 'Server shutting down while run was in progress.') {
    return interruptAllActiveRunsImpl(this, reason);
  }

    stopRun(runId, reason = 'Stopped by request.') {
    return stopRunImpl(this, runId, reason);
  }

    pauseRun(...args) {
    return pauseRunImpl(this, ...args);
  }

    resumeRun(...args) {
    return resumeRunImpl(this, ...args);
  }

    abort(...args) {
    return abortImpl(this, ...args);
  }

    abortAll(userId) {
    return abortAllImpl(this, userId);
  }

  getStepType(toolName) {
    return stepTypeFor(toolName);
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
          `SELECT conversation_id, device_target
           FROM agent_runs WHERE id = ?`,
        ).get(payload.runId);
      }
      const conversationId = runMeta?.conversationId || persisted?.conversation_id || null;
      if (conversationId) {
        payload.conversationId = conversationId;
        payload.deviceTarget = runMeta?.deviceTarget
          || persisted?.device_target
          || null;
      }
    }
    if (this.io) {
      this.io.to(`user:${userId}`).emit(event, redactRunEventForUser(userId, event, payload));
    }
  }
}

// A run event carrying a failure, as this account may read it.
function redactRunEventForUser(userId, event, payload) {
  if (typeof payload?.error !== 'string' || !payload.error || isAdminUser(userId)) return payload;
  if (event !== 'run:tool_end') return { ...payload, error: nonAdminErrorMessage(payload.error) };
  // A failed tool's own output is the same raw text as its error.
  return { ...payload, error: GENERIC_ERROR_MESSAGE, result: null };
}

module.exports = { AgentEngine, buildInitialRunMetadata, getProviderForUser };
