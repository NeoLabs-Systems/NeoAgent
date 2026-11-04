'use strict';

const { randomUUID } = require('crypto');
const db = require('../../../db/database');
const { buildStoredUserContent } = require('../history');
const { ensureDefaultAiSettings, getAiSettings } = require('../settings');
const { getCapabilityHealth } = require('../capabilityHealth');
const { summarizeProgressToolExecutions } = require('../toolEvidence');
const { enforceRateLimits } = require('../rate_limits');
const { parseModelSelectionId } = require('../model_identity');
const { getProviderRuntimeConfig } = require('../models');
const { ToolRepetitionGuard } = require('../repetitionGuard');
const {
  announceBackgroundRunEnded,
  isBackgroundEligible,
  moveRunToBackground,
} = require('../loop/background_runs');
const { shortenRunId } = require('../logFormat');
const { getProviderForUser } = require('../provider_selector');
const { globalHooks } = require('../hooks');
const { isAbortError, throwIfAborted } = require('../../../utils/abort');
const { createServiceLogger } = require('../../../utils/logger');
const { publicErrorCode } = require('../../../utils/http_error');

const { RUNTIME_STATES } = require('./constants');
const { RunEventBus } = require('./events/run_event_bus');
const { EVENT_TYPES } = require('./events/event_types');
const { persistRunMetrics } = require('./events/run_metrics');
const stateMachine = require('./run_state_machine');
const leases = require('./leases');
const { saveCheckpoint } = require('./checkpoint_service');
const { createProgressBroker } = require('./delivery/progress_broker');
const { requestFinalDelivery } = require('./delivery/delivery_worker');
const { createRunDelivery } = require('./delivery/run_delivery');
const {
  allowsProgressUpdates,
  progressDeliveryMetadata,
  resolveDeliveryChannel,
  resolveDeliveryRecipient,
} = require('./delivery/delivery_channel');
const { createContextPressureController } = require('./context/context_pressure');
const { createRunGuards } = require('./run_guards');
const { runAgentLoop, setSteeringIntake } = require('./agent_loop');
const { buildResumeEnvelope, clearResumeEnvelope } = require('./restart_resume');
const { assembleRunContext } = require('./context_builder');
const { narrateProgress, writeWrapUp } = require('./side_turns');
const { captureFailure, decideCapture } = require('./run_capture');

const logger = createServiceLogger('Runtime');

function isoNow() {
  return new Date().toISOString();
}

function generateTitle(message) {
  const text = String(message || '').replace(/\s+/g, ' ').trim();
  if (!text) return 'Agent run';
  return text.length > 80 ? `${text.slice(0, 77)}...` : text;
}

/**
 * Apply a state transition and surface illegal/failed transitions in logs.
 * Callers may still continue when a transition is rejected (best-effort),
 * but silent failures hide protocol bugs.
 */
function applyTransition(args) {
  const result = stateMachine.transition(args);
  if (!result?.ok) {
    console.warn(
      `[Runtime] Transition rejected run=${args.runId} ${args?.run?.runtimeState || '?'}->${args.toState} reason=${result?.reason || 'unknown'}`,
    );
  }
  return result;
}

function collectProgressDelta(toolExecutions = []) {
  return { evidence: summarizeProgressToolExecutions(toolExecutions, 5) };
}

/**
 * One agent run, the same on every surface: accept the request, assemble the
 * context (system prompt with the agent's persona, memory, history, tools),
 * let the agent loop work until the model answers, and deliver that answer
 * through the run's channel exactly as the model wrote it.
 */
class DurableRunRuntime {
  constructor(engine) {
    this.engine = engine;
    this.eventBus = new RunEventBus({ engine });
  }

  async run(userId, userMessage, options = {}, modelOverride = null) {
    throwIfAborted(options.signal, 'Agent run aborted before startup.');
    const triggerType = options.triggerType || 'user';
    const { resolveAgentId } = require('../../agents/manager');
    const agentId = resolveAgentId(userId, options.agentId || options.agent_id || null);
    ensureDefaultAiSettings(userId, agentId);
    const aiSettings = getAiSettings(userId, agentId);
    const runId = options.runId || randomUUID();
    const conversationId = options.conversationId;
    const deviceTarget = ['local', 'cloud'].includes(options.deviceTarget)
      ? options.deviceTarget
      : null;
    const workspaceRoot = typeof options.workspaceRoot === 'string' && options.workspaceRoot.trim()
      ? options.workspaceRoot.trim()
      : null;
    const app = options.app || this.engine.app;
    const triggerSource = options.triggerSource || 'web';
    const workerId = `worker_${randomUUID()}`;
    // Callers that wrap the request in instructions name the run themselves.
    const runTitle = generateTitle(options.title || userMessage);
    const startedAtMs = Date.now();

    // Everything the agent loop and the tool turns read and update.
    const session = {
      engine: this.engine,
      eventBus: this.eventBus,
      runId,
      userId,
      agentId,
      workerId,
      options,
      app,
      triggerType,
      triggerSource,
      conversationId,
      deviceTarget,
      workspaceRoot,
      userMessage,
      model: null,
      // A model chosen for this run (message, schedule, parent agent) wins over task pins.
      explicitModel: Boolean(modelOverride),
      messages: [],
      // The user turn this run answers, kept for its wrap-up turn.
      requestTurn: null,
      tools: [],
      systemPrompt: '',
      toolExecutions: [],
      stepIndex: 0,
      iterations: 0,
      totalTokens: 0,
      failedModelIds: new Set(),
      guards: createRunGuards({ aiSettings, options }),
      progressBroker: null,
      contextPressure: null,
      providerStatusConfig: null,
      collectProgressDelta: () => collectProgressDelta(session.toolExecutions),
      getActiveSignal: null,
      emitPhase: (phase, label) => {
        this.engine.emit(userId, 'run:phase', {
          runId,
          conversationId: conversationId || null,
          phase,
          label,
        });
      },
      stopForIterationHook: async (iteration) => {
        const iterationHook = await globalHooks.run('on_loop_iteration', {
          userId,
          runId,
          agentId,
          iteration,
          triggerType,
          triggerSource,
          totalTokens: session.totalTokens,
        });
        if (iterationHook?.stop !== true) return null;

        const reason = String(iterationHook.reason || 'Stopped by policy hook.');
        const meta = this.engine.getRunMeta(runId);
        if (meta) meta.aborted = true;
        db.prepare(
          `UPDATE agent_runs
           SET status = 'stopped',
               runtime_state = ?,
               error = ?,
               completed_at = COALESCE(completed_at, datetime('now')),
               updated_at = datetime('now')
           WHERE id = ?`,
        ).run(RUNTIME_STATES.CANCELLED, reason, runId);
        this.eventBus.publish({
          runId,
          userId,
          agentId,
          eventType: EVENT_TYPES.RUN_CANCELLED,
          payload: { reason, source: 'on_loop_iteration' },
        });
        return {
          runId,
          content: '',
          totalTokens: session.totalTokens,
          iterations: session.iterations,
          status: 'stopped',
        };
      },
    };
    let detachExternalAbort = null;
    let runRecordCreated = false;
    let runSignal = null;

    // Server usage limits don't apply when the run's explicitly selected
    // model resolves to a provider the user configured with their own (BYOK)
    // credentials -- only they pay for those calls. This only covers an
    // explicit model selection; 'auto' selection can still land on a
    // server-funded model, so it stays rate-limited.
    let byokRateLimitBypass = false;
    const requestedModelId = String(modelOverride || aiSettings.default_chat_model || '').trim();
    const requestedModelParsed = parseModelSelectionId(requestedModelId);
    if (requestedModelParsed) {
      try {
        byokRateLimitBypass = Boolean(
          getProviderRuntimeConfig(userId, requestedModelParsed.provider, agentId).isByok,
        );
      } catch {
        byokRateLimitBypass = false;
      }
    }

    const { releaseReservation } = enforceRateLimits(userId, {
      bypass: options.bypassUserRateLimits === true || byokRateLimitBypass,
    });

    try {
      // ── Accept immediately ─────────────────────────────────────────────
      const resume = buildResumeEnvelope(userMessage, options);
      try {
        db.prepare(
          `INSERT INTO agent_runs(
            id, user_id, agent_id, title, status, runtime_state, version,
            trigger_type, trigger_source, model, metadata_json,
            conversation_id, device_target
          ) VALUES(?, ?, ?, ?, 'running', ?, 0, ?, ?, ?, ?, ?, ?)`,
        ).run(
          runId,
          userId,
          agentId,
          runTitle,
          RUNTIME_STATES.ACCEPTED,
          triggerType,
          triggerSource,
          String(modelOverride || aiSettings.default_chat_model || 'auto'),
          JSON.stringify({
            ...(options.taskId ? { taskId: options.taskId } : {}),
            ...(options.sessionBinding ? { sessionBinding: options.sessionBinding } : {}),
            ...(options.latencyPriority ? { latencyPriority: options.latencyPriority } : {}),
            ...(conversationId ? { conversationId } : {}),
            ...(deviceTarget ? { deviceTarget } : {}),
            ...(resume ? { resume } : {}),
            ...(options.resumedFromRunId ? { resumedFromRunId: options.resumedFromRunId } : {}),
            runtimeKernel: 'v2',
          }),
          conversationId || null,
          deviceTarget,
        );
        runRecordCreated = true;
      } catch (error) {
        if (/unique|primary key|constraint/i.test(String(error?.message || ''))) {
          const conflict = new Error(`A run with id "${runId}" already exists.`);
          conflict.code = 'RUN_ID_CONFLICT';
          throw conflict;
        }
        throw error;
      }

      const lease = leases.acquire(runId, { workerId });
      if (!lease) {
        throw new Error('Failed to acquire run lease');
      }

      const abortController = new AbortController();
      runSignal = abortController.signal;
      session.getActiveSignal = () => (
        this.engine.getRunMeta(runId)?.abortController?.signal || abortController.signal
      );
      // A caller that owns the delivery view (a background task resolves the
      // target and sends what the run staged) shares it with the run.
      const delivery = options.delivery && typeof options.delivery === 'object'
        ? options.delivery
        : createRunDelivery();

      this.engine.activeRuns.set(runId, {
        userId,
        agentId,
        title: runTitle,
        status: 'running',
        runtimeState: RUNTIME_STATES.ACCEPTED,
        aborted: false,
        delivery,
        // A resumed run continues the cut-off run's conversation with the user,
        // so what that run already sent still counts.
        deliveryScopeId: options.resumedFromRunId || runId,
        capture: decideCapture({ userId, agentId, options }),
        session,
        triggerType,
        triggerSource,
        request: String(options.context?.rawUserMessage || userMessage || '').trim().slice(0, 600),
        backgroundEligible: isBackgroundEligible({
          triggerType,
          triggerSource,
          memoryAudience: options.memoryAudience,
        }),
        background: null,
        onBackground: typeof options.onBackground === 'function' ? options.onBackground : null,
        conversationId: conversationId || null,
        deviceTarget,
        workspaceRoot,
        voiceSessionId: options.voiceSessionId || options.sessionBinding?.sessionId || null,
        sessionBinding: options.sessionBinding || null,
        latencyPriority: options.latencyPriority || null,
        startedAt: startedAtMs,
        startedAtIso: isoNow(),
        abortController,
        pauseAvailable: true,
        toolPids: new Set(),
        subagentDepth: Math.max(0, Number(options.subagentDepth) || 0),
        repetitionGuard: new ToolRepetitionGuard(),
        steeringQueue: [],
        systemSteeringQueue: [],
        workerId,
        messagingContext: triggerSource === 'messaging'
          ? {
            platform: options.source || null,
            chatId: options.chatId || null,
            behavior: options.context?.socialIntelligence || null,
          }
          : null,
      });
      // The call that handed this off keeps talking while it works.
      if (triggerSource === 'voice_live') moveRunToBackground(this.engine, runId);

      if (options.signal) {
        const abortFromExternal = () => {
          this.engine.interruptRun?.(
            runId,
            String(options.signal.reason || 'Agent run interrupted by its caller.'),
          );
        };
        if (options.signal.aborted) abortFromExternal();
        else options.signal.addEventListener('abort', abortFromExternal, { once: true });
        detachExternalAbort = () => options.signal.removeEventListener('abort', abortFromExternal);
      }

      session.progressBroker = createProgressBroker({
        engine: this.engine,
        runId,
        scopeId: options.resumedFromRunId || runId,
        channel: resolveDeliveryChannel(triggerSource),
        recipient: resolveDeliveryRecipient(triggerSource, options),
        deliveryMetadata: progressDeliveryMetadata(triggerSource, options),
        maxSilenceSeconds: Number(options.maxSilenceSeconds)
          || (options.latencyPriority === 'interactive' ? 45 : 90),
        firstUpdateSeconds: options.latencyPriority === 'interactive' ? 15 : 25,
        repeatUpdateSeconds: options.latencyPriority === 'interactive' ? 45 : 90,
        collectDelta: session.collectProgressDelta,
        // A run that already delivered, was cancelled, or decided to stay silent
        // must never emit another visible update.
        isSuppressed: () => {
          const meta = this.engine.getRunMeta(runId);
          if (!meta || meta.aborted || meta.status === 'paused') return true;
          if (!allowsProgressUpdates(triggerSource, options)) return true;
          // awaitingReply means the agent asked the user something and is
          // waiting; anything after that would talk over the question. A chat
          // reply that is still the run's last word is its answer, not a pause.
          const state = meta.delivery;
          return Boolean(state?.finalDelivered || state?.noResponse || state?.awaitingReply || state?.lastWordSent);
        },
        getLastVisibleAt: () => Date.parse(this.engine.getRunMeta(runId)?.lastUserVisibleAt || '') || 0,
        // A model turn that is still streaming has produced nothing to report;
        // narrating it can only tell the user that nothing has happened.
        narrator: async ({ delta, liveness }) => (
          liveness?.phase === 'model_started' && !Number(liveness?.runningTools) && !delta?.evidence
            ? ''
            : narrateProgress(this.engine, session, { delta, liveness, signal: abortController.signal })
        ),
      });
      session.progressBroker.markAccepted();

      this.eventBus.publish({
        runId,
        userId,
        agentId,
        eventType: EVENT_TYPES.RUN_STARTED,
        actor: workerId,
        payload: {
          trigger_type: triggerType,
          trigger_source: triggerSource,
          resumed_from: options.resumedFromRunId || null,
          capture: this.engine.getRunMeta(runId)?.capture?.reason || null,
        },
      });

      this.engine.emit(userId, 'run:start', {
        runId,
        agentId,
        conversationId: conversationId || null,
        title: runTitle,
        triggerType,
        triggerSource,
        deviceTarget,
        runtimeKernel: 'v2',
      });
      session.emitPhase('model', 'Choosing a model');

      // Independent startup work runs concurrently with provider selection.
      // A rejected branch is still surfaced by its await below; the no-op
      // catch only keeps an early failure elsewhere from leaving it unhandled.
      const startConcurrently = (promise) => {
        promise.catch(() => {});
        return promise;
      };
      const capabilityHealthPromise = startConcurrently(getCapabilityHealth({
        userId,
        agentId,
        app,
        engine: this.engine,
        deviceTarget,
        triggerSource,
        sourcePlatform: triggerSource === 'messaging' ? options.source || null : null,
        workspaceRoot,
      }));
      const systemPromptPromise = startConcurrently(this.engine.buildSystemPrompt(userId, {
        ...(options.context || {}),
        userMessage,
        agentId,
        triggerSource,
        memoryAudience: options.memoryAudience || 'owner',
        latencyProfile: options.latencyProfile || null,
        deviceTarget,
        workspaceRoot,
      }));

      // ── Provider selection ─────────────────────────────────────────────
      session.providerStatusConfig = {
        agentId,
        onStatus: (status) => {
          if (!status?.message) return;
          this.engine.emit(userId, 'run:interim', {
            runId,
            message: status.message,
            phase: status.phase,
          });
        },
      };
      const selectedProvider = await getProviderForUser(
        userId,
        userMessage,
        triggerType === 'subagent',
        modelOverride,
        { ...session.providerStatusConfig, signal: abortController.signal },
      );
      session.model = {
        provider: selectedProvider.provider,
        providerName: selectedProvider.providerName,
        model: selectedProvider.model,
        modelSelectionId: selectedProvider.modelSelectionId,
      };
      db.prepare('UPDATE agent_runs SET model = ?, updated_at = datetime(\'now\') WHERE id = ?')
        .run(session.model.modelSelectionId, runId);
      Object.assign(this.engine.getRunMeta(runId) || {}, {
        model: session.model.model,
        modelSelectionId: session.model.modelSelectionId,
        providerName: session.model.providerName,
      });
      const providerMs = Date.now() - startedAtMs;
      session.contextPressure = createContextPressureController({
        summarize: async (summaryMessages) => {
          const result = await this.engine.requestModelResponse({
            provider: session.model.provider,
            providerName: session.model.providerName,
            model: session.model.model,
            messages: summaryMessages,
            tools: [],
            options: {
              ...options,
              stream: false,
              maxTokens: 1600,
              phase: 'context_compaction',
              signal: session.getActiveSignal(),
              runId,
              userId,
              agentId,
            },
            runId,
            iteration: Math.max(1, session.iterations),
          });
          const summary = String(result?.response?.content || result?.streamContent || '').trim();
          if (!summary) throw new Error('Context compaction returned an empty summary.');
          return summary;
        },
        onEvent: (kind, payload) => {
          if (kind === 'pressure') {
            saveCheckpoint(runId, 'pre_compaction', {
              iterations: session.iterations,
            }, { eventBus: this.eventBus, userId, agentId });
            return;
          }
          this.eventBus.publish({
            runId,
            userId,
            agentId,
            eventType: EVENT_TYPES.CONTEXT_COMPACTED,
            payload,
          });
        },
      });

      // ── Context assembly ───────────────────────────────────────────────
      const { MemoryManager } = require('../../memory/manager');
      const memoryManager = this.engine.memoryManager || new MemoryManager();
      const { historyWindow } = await assembleRunContext(session, {
        engine: this.engine,
        aiSettings,
        memoryManager,
        systemPromptPromise,
        capabilityHealthPromise,
        startConcurrently,
        startedAtMs,
        providerMs,
      });
      // A resumed run's request is the turn the interrupted run already stored.
      if (conversationId && !options.resumedFromRunId) this.#storeUserMessage(session);

      applyTransition({
        runId,
        toState: RUNTIME_STATES.EXECUTING,
        reason: 'context_ready',
        workerId,
        eventBus: this.eventBus,
      });

      // ── Agent loop ─────────────────────────────────────────────────────
      // The heartbeat keeps a run that sits inside a long tool or model call
      // from going silent. Background automation reports through its own
      // delivery target, so it stays off there.
      if (!options.taskId && triggerType !== 'subagent') {
        session.progressBroker.start();
      }
      const outcome = await runAgentLoop(session);
      session.progressBroker.stop();

      if (outcome.type === 'cancelled') return this.#cancelledResult(session);
      if (outcome.type === 'stopped') return outcome.result;
      if (outcome.type === 'ended') {
        return {
          runId,
          content: '',
          totalTokens: session.totalTokens,
          iterations: session.iterations,
          status: outcome.status,
        };
      }
      if (outcome.type === 'wrap_up') {
        const state = this.engine.getRunMeta(runId)?.delivery;
        if (state) state.wrappedUp = true;
      }
      const answer = outcome.type === 'wrap_up'
        ? await writeWrapUp(this.engine, session, outcome.reason)
        : outcome.content;
      applyTransition({
        runId,
        toState: RUNTIME_STATES.DELIVERING,
        reason: outcome.type === 'wrap_up' ? outcome.reason : 'answer',
        workerId,
        eventBus: this.eventBus,
      });
      const finalDelivery = await this.#deliverFinal(session, answer);
      const content = finalDelivery.content || answer;
      if (!finalDelivery.ok) {
        const reason = finalDelivery.reason === 'ambiguous' ? 'delivery_ambiguous' : 'delivery_failed';
        const error = finalDelivery.error || reason;
        this.eventBus.publish({ runId, userId, agentId, eventType: EVENT_TYPES.RUN_FAILED,
          payload: { error_code: reason, execution_completed: true } });
        this.engine.emit(userId, 'run:error', { runId, error, content, deliveryStatus: reason, executionCompleted: true });
        return { runId, content, totalTokens: session.totalTokens, iterations: session.iterations,
          status: 'failed', error, deliveryStatus: reason, executionCompleted: true };
      }
      await this.#finalizeSuccess(session, { content, historyWindow, memoryManager });
      return {
        runId,
        content,
        totalTokens: session.totalTokens,
        iterations: session.iterations,
        status: 'completed',
      };
    } catch (error) {
      if (runRecordCreated) {
        const runMeta = this.engine.getRunMeta(runId);
        const interrupted = isAbortError(error, runSignal) || runMeta?.aborted;
        const interruptedByCaller = runMeta?.status === 'interrupted';
        const terminalTransition = applyTransition({
          runId,
          toState: interrupted ? RUNTIME_STATES.CANCELLED : RUNTIME_STATES.FAILED,
          reason: interrupted ? 'interrupted' : 'error',
          workerId,
          eventBus: this.eventBus,
          patch: {
            error: error?.message || String(error),
            totalTokens: session.totalTokens,
          },
        });
        if (interruptedByCaller && terminalTransition?.ok) {
          db.prepare(
            "UPDATE agent_runs SET status = 'interrupted' WHERE id = ? AND runtime_state = ?",
          ).run(runId, RUNTIME_STATES.CANCELLED);
        }
        this.eventBus.publish({
          runId,
          userId,
          agentId,
          eventType: interrupted ? EVENT_TYPES.RUN_CANCELLED : EVENT_TYPES.RUN_FAILED,
          payload: { error: String(error?.message || error).slice(0, 500), error_code: publicErrorCode(error) || null },
        });
        if (!interrupted) {
          captureFailure({ runId, userId, capture: runMeta?.capture, session });
        }
        this.engine.emit(userId, interrupted
          ? (interruptedByCaller ? 'run:interrupted' : 'run:stopped')
          : 'run:error', {
          runId,
          error: error?.message || String(error),
          code: publicErrorCode(error),
        });
      }
      if (isAbortError(error, runSignal)) {
        const status = this.engine.getRunMeta(runId)?.status === 'interrupted'
          ? 'interrupted'
          : 'stopped';
        return { runId, content: '', totalTokens: session.totalTokens, iterations: session.iterations, status };
      }
      throw error;
    } finally {
      session.progressBroker?.stop();
      // Only a run the shutdown cut off is resumed; one that ended while the
      // process keeps going is finished, however it ended.
      if (runRecordCreated && !this.engine.shuttingDown) clearResumeEnvelope(runId);
      if (runRecordCreated) {
        const promptMetrics = this.engine.getRunMeta(runId)?.promptMetrics;
        if (promptMetrics) {
          db.prepare('UPDATE agent_runs SET prompt_metrics = ? WHERE id = ?').run(JSON.stringify(promptMetrics), runId);
        }
        persistRunMetrics(runId);
      }
      try {
        leases.release(runId, workerId);
      } catch {
        // ignore
      }
      const endedRunMeta = this.engine.getRunMeta(runId);
      this.engine.activeRuns.delete(runId);
      announceBackgroundRunEnded(this.engine, runId, endedRunMeta);
      // Sub-agents report only to their parent; once it ends nothing reads them.
      this.engine.cleanupSubagentsForRun(runId).catch((error) => {
        console.warn('[Runtime] Sub-agent cleanup failed:', error?.message || error);
      });
      detachExternalAbort?.();
      releaseReservation();
    }
  }

  #storeUserMessage(session) {
    const { options, triggerSource } = session;
    const socialMessage = options.context?.socialIntelligence?.message || null;
    db.prepare(
      `INSERT INTO conversation_messages (
        conversation_id, run_id, agent_id, role, content, metadata_json
      ) VALUES (?, ?, ?, 'user', ?, ?)`,
    ).run(
      session.conversationId,
      session.runId,
      session.agentId,
      buildStoredUserContent({
        userMessage: session.userMessage,
        rawUserMessage: triggerSource === 'messaging' ? options.context?.rawUserMessage : null,
        platform: options.source || null,
        speaker: socialMessage?.senderName || socialMessage?.sender || null,
        isGroup: Boolean(socialMessage?.isGroup),
      }),
      JSON.stringify({
        deviceTarget: session.deviceTarget,
      }),
    );
  }

  async #deliverFinal(session, content) {
    const { runId, userId, agentId, workerId, options, triggerSource } = session;
    setSteeringIntake(this.engine, runId, false);
    const channel = resolveDeliveryChannel(triggerSource);
    const result = await requestFinalDelivery({
      engine: this.engine,
      runId,
      scopeId: options.resumedFromRunId || runId,
      content,
      channel,
      recipient: resolveDeliveryRecipient(triggerSource, options),
      workerId,
      eventBus: this.eventBus,
      metadata: {
        platform: options.source || null,
        chatId: options.chatId || null,
        ...(options.sessionBinding || {}),
        totalTokens: session.totalTokens,
        agentId,
      },
    });

    if (!result.ok && result.reason === 'already_committed') {
      return { ok: true, content, alreadyCommitted: true };
    }
    if (!result.ok && result.reason === 'ambiguous') {
      // Do not retry blindly.
      applyTransition({
        runId,
        toState: RUNTIME_STATES.FAILED,
        reason: 'delivery_ambiguous',
        workerId,
        eventBus: this.eventBus,
        patch: {
          error: result.error || 'Final delivery state is ambiguous',
          metadata: { executionCompleted: true, deliveryStatus: 'ambiguous' },
          finalResponse: content,
          totalTokens: session.totalTokens,
        },
      });
      return result;
    }
    if (!result.ok) {
      // For web channel, still complete with content even if emit path failed.
      if (channel === 'web') {
        applyTransition({
          runId,
          toState: RUNTIME_STATES.COMPLETED,
          reason: 'local_final_without_external',
          workerId,
          eventBus: this.eventBus,
          patch: { finalResponse: content, totalTokens: session.totalTokens },
        });
        // The delivery worker normally emits this; it did not get that far, and
        // the client still needs exactly one run:complete to close the run out.
        this.engine.emit(userId, 'run:complete', { runId, content, totalTokens: session.totalTokens });
        return { ok: true, content };
      }
      applyTransition({
        runId,
        toState: RUNTIME_STATES.FAILED,
        reason: 'delivery_failed',
        workerId,
        eventBus: this.eventBus,
        patch: {
          error: result.error || result.reason || 'delivery failed',
          metadata: { executionCompleted: true, deliveryStatus: 'failed' },
          finalResponse: content,
          totalTokens: session.totalTokens,
        },
      });
    }
    return result;
  }

  async #finalizeSuccess(session, { content, historyWindow, memoryManager }) {
    const { runId, userId, agentId, conversationId, options } = session;
    if (conversationId && content) {
      try {
        db.prepare(
          `INSERT INTO conversation_messages (
            conversation_id, run_id, agent_id, role, content, metadata_json
          ) VALUES (?, ?, ?, 'assistant', ?, ?)`,
        ).run(conversationId, runId, agentId, content, JSON.stringify({ final: true }));
      } catch {
        // ignore
      }
    }

    // The running sum only sees the calls the loop itself made; the usage
    // ledger has every recorded call for the run (narration, compaction, ...).
    const ledgerTokens = Number(db.prepare(
      'SELECT COALESCE(SUM(total_tokens), 0) AS total FROM agent_model_usage WHERE run_id = ?',
    ).get(runId)?.total) || 0;
    session.totalTokens = Math.max(Number(session.totalTokens) || 0, ledgerTokens);

    db.prepare(
      `UPDATE agent_runs
       SET total_tokens = ?, final_response = COALESCE(final_response, ?), updated_at = datetime('now')
       WHERE id = ?`,
    ).run(session.totalTokens, content || null, runId);

    this.eventBus.publish({
      runId,
      userId,
      agentId,
      eventType: EVENT_TYPES.RUN_COMPLETED,
      payload: {
        total_tokens: session.totalTokens,
        iterations: session.iterations,
        answer_chars: String(content || '').length,
      },
    });

    // No run:complete here: the delivery worker already emitted it as part of
    // committing the final message. Emitting again made clients see the same
    // answer arrive twice.

    // Conversation learning is serialized per thread and runs after delivery.
    if (conversationId && memoryManager) {
      this.engine.trackBackgroundTask(
        (signal) => this.engine.refreshConversationState({
          conversationId,
          runId,
          provider: session.model.provider,
          providerName: session.model.providerName,
          model: session.model.model,
          finalReply: content,
          historyWindow,
          options: { ...options, runId, userId, agentId, signal },
        }),
        { key: `conversation-learning:${userId}:${agentId || 'main'}:${conversationId}` },
      ).catch((error) => {
        if (!isAbortError(error) && !this.engine.shuttingDown) {
          logger.warn('Conversation learning failed:', error?.message || error);
        }
      });
    }

    console.info(
      `[Run ${shortenRunId(runId)}] completed kernel=v2 steps=${session.iterations} tokens=${session.totalTokens} finalResponse=${content ? 'yes' : 'no'}`,
    );

    this.engine.skillLearningService?.enqueueCompletedRun({
      userId,
      agentId,
      runId,
      triggerType: session.triggerType,
      triggerSource: session.triggerSource,
      task: session.userMessage,
      taskId: options.taskId || null,
      finalContent: content,
      iterations: session.iterations,
      messages: session.messages,
    });
  }

  // A stop noticed between steps ends here instead of in the abort handler,
  // so clients still need the terminal event.
  #cancelledResult(session) {
    const { runId } = session;
    const run = stateMachine.loadRun(runId);
    if (run && !stateMachine.isTerminal(run)) {
      const cancelled = applyTransition({
        runId,
        toState: RUNTIME_STATES.CANCELLED,
        reason: 'cancelled',
        eventBus: this.eventBus,
        patch: { totalTokens: session.totalTokens },
      });
      // As in the abort path: an interruption (a shutdown) stays recorded as
      // one, not as a stop, so a restart can tell it apart.
      if (cancelled?.ok && this.engine.getRunMeta(runId)?.status === 'interrupted') {
        db.prepare(
          "UPDATE agent_runs SET status = 'interrupted' WHERE id = ? AND runtime_state = ?",
        ).run(runId, RUNTIME_STATES.CANCELLED);
      }
    }
    if (run) {
      this.engine.emit(run.userId, 'run:stopped', {
        runId,
        conversationId: this.engine.getRunMeta(runId)?.conversationId || null,
      });
    }
    return {
      runId,
      content: '',
      totalTokens: session.totalTokens,
      iterations: session.iterations,
      status: 'stopped',
    };
  }
}

async function runOrchestrator(engine, userId, userMessage, options = {}, modelOverride = null) {
  const runtime = new DurableRunRuntime(engine);
  return runtime.run(userId, userMessage, options, modelOverride);
}

module.exports = {
  DurableRunRuntime,
  runOrchestrator,
};
