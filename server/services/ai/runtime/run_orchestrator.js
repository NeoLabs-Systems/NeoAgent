'use strict';

const { randomUUID } = require('crypto');
const db = require('../../../db/database');
const {
  getConversationContext,
  buildStoredUserContent,
  buildSummaryCarrier,
  sanitizeConversationMessages,
} = require('../history');
const { ensureDefaultAiSettings, getAiSettings } = require('../settings');
const { buildToolDiscoverySummary, selectInitialTools } = require('../toolSelector');
const { sanitizeModelOutput } = require('../outputSanitizer');
const { getCapabilityHealth, summarizeCapabilityHealth } = require('../capabilityHealth');
const { summarizeProgressToolExecutions } = require('../toolEvidence');
const { enforceRateLimits } = require('../rate_limits');
const { getPublicRunScope } = require('../../messaging/public_audience');
const { createRunTrust } = require('../../security/run_trust');
const { parseModelSelectionId } = require('../model_identity');
const { getProviderRuntimeConfig } = require('../models');
const { ToolRepetitionGuard } = require('../repetitionGuard');
const {
  announceBackgroundRunEnded,
  buildBackgroundRunsNote,
  isBackgroundEligible,
  listBackgroundRuns,
} = require('../loop/background_runs');
const { shortenRunId } = require('../logFormat');
const { getProviderForUser } = require('../provider_selector');
const {
  buildProgressUpdatePrompt,
  buildWrapUpPrompt,
  normalizeOutgoingMessage,
} = require('../messagingFallback');
const { globalHooks } = require('../hooks');
const { isAbortError, throwIfAborted } = require('../../../utils/abort');
const { createServiceLogger } = require('../../../utils/logger');

const { NARRATION_MAX_TOKENS, RUNTIME_STATES } = require('./constants');
const { RunEventBus } = require('./events/run_event_bus');
const { EVENT_TYPES, VISIBILITY } = require('./events/event_types');
const stateMachine = require('./run_state_machine');
const leases = require('./leases');
const { saveCheckpoint } = require('./checkpoint_service');
const { createProgressBroker } = require('./delivery/progress_broker');
const { requestFinalDelivery } = require('./delivery/delivery_worker');
const {
  resolveDeliveryChannel,
  resolveDeliveryRecipient,
} = require('./delivery/delivery_channel');
const { createContextPressureController } = require('./context/context_pressure');
const { createRunGuards } = require('./run_guards');
const { runAgentLoop, setSteeringIntake } = require('./agent_loop');

const logger = createServiceLogger('Runtime');

// The last messages a wrap-up turn sees next to the system prompt.
const WRAP_UP_HISTORY_MESSAGES = 24;

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
    const runTitle = generateTitle(userMessage);
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
          visibility: VISIBILITY.USER,
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
      // Prefer the caller-owned deliveryState (background tasks share it with the
      // task runtime for staged send_message + final delivery bookkeeping).
      const deliveryState = options.deliveryState && typeof options.deliveryState === 'object'
        ? options.deliveryState
        : {
          messagingSent: false,
          noResponse: false,
          proactiveMessageStaged: false,
          stagedProactiveMessage: null,
          lastSentMessage: '',
          sentMessages: [],
        };

      this.engine.activeRuns.set(runId, {
        userId,
        agentId,
        title: runTitle,
        status: 'running',
        runtimeState: RUNTIME_STATES.ACCEPTED,
        aborted: false,
        messagingSent: false,
        finalDeliverySent: false,
        lastSentMessage: '',
        sentMessages: [],
        deliveryState,
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
        userId,
        agentId,
        eventBus: this.eventBus,
        channel: resolveDeliveryChannel(triggerSource),
        recipient: resolveDeliveryRecipient(triggerSource, options),
        deliveryMetadata: options.sessionBinding || null,
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
          // terminalInterim means the agent asked the user something and is
          // waiting; anything after that would talk over the question.
          if (meta.finalDeliverySent || meta.noResponse || meta.terminalInterim) return true;
          return meta.deliveryState?.finalContentDelivered === true
            || meta.deliveryState?.noResponse === true;
        },
        getLastVisibleAt: () => Date.parse(
          this.engine.getRunMeta(runId)?.progressLedger?.lastUserVisibleUpdateAt || '',
        ) || 0,
        // A model turn that is still streaming has produced nothing to report;
        // narrating it can only tell the user that nothing has happened.
        narrator: async ({ delta, liveness }) => (
          liveness?.phase === 'model_started' && !Number(liveness?.runningTools) && !delta?.evidence
            ? ''
            : this.#narrateProgress(session, { delta, liveness, signal: abortController.signal })
        ),
      });
      session.progressBroker.markAccepted();

      this.eventBus.publish({
        runId,
        userId,
        agentId,
        eventType: EVENT_TYPES.RUN_ACCEPTED,
        actor: workerId,
        payload: {
          acceptedAt: isoNow(),
          title: runTitle,
          triggerType,
          triggerSource,
        },
        visibility: VISIBILITY.USER,
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
          }
          this.eventBus.publish({
            runId,
            userId,
            agentId,
            eventType: kind === 'compacted' ? EVENT_TYPES.CONTEXT_COMPACTED : EVENT_TYPES.CONTEXT_PRESSURE,
            payload,
            visibility: VISIBILITY.OPERATOR,
          });
        },
      });

      // ── Context assembly ───────────────────────────────────────────────
      session.emitPhase('context', 'Gathering context');
      const historyWindow = Math.max(
        1,
        Number(options.historyWindow || aiSettings.chat_history_window) || aiSettings.chat_history_window,
      );
      const { MemoryManager } = require('../../memory/manager');
      const memoryManager = this.engine.memoryManager || new MemoryManager();
      const recallPromise = options.skipGlobalRecall === true
        ? null
        : startConcurrently(this.engine.buildMemoryRecall({
          memoryManager,
          userId,
          agentId,
          query: options.context?.rawUserMessage || userMessage,
          provider: session.model.provider,
          providerName: session.model.providerName,
          model: session.model.model,
          runId,
          options,
        }));
      session.systemPrompt = await systemPromptPromise;

      const publicScope = getPublicRunScope(runId);
      const builtInTools = this.engine.getAvailableTools(app, {
        includeDescriptions: true,
        userId,
        agentId,
        triggerType,
        triggerSource,
        publicScope,
      });
      const mcpManager = app?.locals?.mcpManager || app?.locals?.mcpClient || this.engine.mcpManager;
      const mcpTools = mcpManager && !publicScope ? mcpManager.getAllTools(userId, { agentId }) : [];
      const disallowedToolNames = new Set(
        (Array.isArray(options.disallowedToolNames) ? options.disallowedToolNames : [])
          .map((name) => String(name || '').trim())
          .filter(Boolean),
      );
      const allTools = [...builtInTools, ...mcpTools]
        .filter((tool) => !disallowedToolNames.has(tool?.name));

      const recallMsg = recallPromise ? await recallPromise : null;

      let summaryMessage = null;
      let historyMessages = [];
      if (conversationId && options.skipConversationHistory !== true) {
        const conversationContext = getConversationContext(conversationId, historyWindow);
        summaryMessage = buildSummaryCarrier(conversationContext.summary || options.priorSummary || '');
        historyMessages = conversationContext.recentMessages.length > 0
          ? conversationContext.recentMessages
          : (options.priorMessages || []).slice(-historyWindow).filter((pm) => pm.role && pm.content);
      } else {
        summaryMessage = buildSummaryCarrier(options.priorSummary || '');
        historyMessages = (options.priorMessages || []).slice(-historyWindow).filter((pm) => pm.role && pm.content);
      }

      const messages = this.engine.buildContextMessages(
        session.systemPrompt,
        summaryMessage,
        historyMessages,
        recallMsg,
      );
      const capabilityHealth = await capabilityHealthPromise;
      // A public run must not learn what the owner has connected.
      const capabilitySummary = publicScope ? '' : summarizeCapabilityHealth(capabilityHealth);
      const connectedIntegrations = publicScope
        ? null
        : app?.locals?.integrationManager?.listConnectedProviderLabels?.(userId, agentId);
      if (capabilitySummary || connectedIntegrations) {
        messages.push({
          role: 'system',
          content: [
            '[Runtime status]',
            connectedIntegrations
              ? `Connected integrations: ${connectedIntegrations}. search_tools returns their tools with usage notes.`
              : '',
            capabilitySummary ? `Needs attention:\n${capabilitySummary}` : '',
          ].filter(Boolean).join('\n'),
        });
      }
      const backgroundRuns = this.engine.getRunMeta(runId)?.backgroundEligible
        ? listBackgroundRuns(this.engine, { userId, agentId, excludeRunId: runId })
        : [];
      if (backgroundRuns.length > 0) {
        messages.push({ role: 'system', content: buildBackgroundRunsNote(backgroundRuns) });
      }

      // A fixed core starts active; the rest of the catalog is listed for the
      // model to activate itself. Guessing tools from the request's words picks
      // noise, especially outside English.
      const toolSelectionOptions = {
        triggerSource,
        triggerType,
      };
      // When NeoRecall is connected, keep day/search tools active so personal
      // recall questions do not wait on an activation turn.
      const preferredNeoRecallTools = [
        'neorecall_list_daily_summaries',
        'neorecall_search',
        'neorecall_list_conversations',
      ].filter((name) => allTools.some((tool) => tool?.name === name));
      session.tools = selectInitialTools(allTools, [
        ...preferredNeoRecallTools,
        ...(backgroundRuns.length > 0 ? ['background_task'] : []),
      ], toolSelectionOptions);
      this.engine.initializeToolRuntime?.(runId, allTools, session.tools, toolSelectionOptions);
      // The tool catalog carries third-party descriptions (MCP, skills), so
      // it is not part of what the owner wrote.
      const openingMessages = [...messages];
      messages.push({
        role: 'system',
        content: [
          '[Tool discovery]',
          buildToolDiscoverySummary(allTools, session.tools),
          'Your shell (execute_command) starts in your workspace, and the file tools operate on that same workspace. Keep checkouts and generated files there; clone a repo once and reuse it.',
          'For workspace file inspection/editing, prefer read_files, read_file, search_files, list_directory, edit_file, replace_file_range, and write_file over shell cat/sed/python snippets. Use execute_command for git, tests, package managers, builds, and other shell-native actions.',
          this.engine.describeIntegrationsForRun?.(runId, session.tools) || '',
        ].filter(Boolean).join('\n'),
      });
      this.engine.recordRunEvent?.(userId, runId, 'tool_selection_applied', {
        activeToolNames: session.tools.map((tool) => tool.name),
        catalogSize: allTools.length,
      }, { agentId });

      const userTurn = this.engine.buildUserMessage(userMessage, options);
      messages.push(userTurn);
      session.messages = sanitizeConversationMessages(messages);
      if (conversationId) this.#storeUserMessage(session);
      this.engine.getRunMeta(runId).trust = options.parentTrust || createRunTrust({
        audience: publicScope ? 'public' : (options.audience || 'owner'),
        triggerSource,
        messages: [...openingMessages, userTurn],
        origin: triggerSource === 'messaging'
          ? {
            platform: options.source,
            chatId: options.chatId,
            senderId: options.context?.socialIntelligence?.message?.sender,
          }
          : null,
        mediaPaths: (options.mediaAttachments || []).map((attachment) => attachment?.path),
      });

      applyTransition({
        runId,
        toState: RUNTIME_STATES.EXECUTING,
        reason: 'context_ready',
        workerId,
        eventBus: this.eventBus,
      });
      this.engine.recordRunEvent?.(userId, runId, 'startup_timing', {
        providerMs,
        totalMs: Date.now() - startedAtMs,
      }, { agentId });

      // ── Agent loop ─────────────────────────────────────────────────────
      // The heartbeat keeps a run that sits inside a long tool or model call
      // from going silent. Background automation reports through its own
      // delivery target, so it stays off there.
      if (triggerSource !== 'schedule' && triggerSource !== 'tasks' && triggerType !== 'subagent') {
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
      const answer = outcome.type === 'wrap_up'
        ? await this.#wrapUp(session, outcome.reason)
        : outcome.content;
      applyTransition({
        runId,
        toState: RUNTIME_STATES.DELIVERING,
        reason: outcome.type === 'wrap_up' ? outcome.reason : 'answer',
        workerId,
        eventBus: this.eventBus,
      });
      const delivery = await this.#deliverFinal(session, answer);
      const content = delivery.content || answer;
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
          payload: { error: error?.message || String(error) },
          visibility: VISIBILITY.USER,
        });
        this.engine.emit(userId, interrupted
          ? (interruptedByCaller ? 'run:interrupted' : 'run:stopped')
          : 'run:error', {
          runId,
          error: error?.message || String(error),
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
        totalTokens: session.totalTokens,
        iterations: session.iterations,
        contentPreview: String(content || '').slice(0, 240),
      },
      visibility: VISIBILITY.USER,
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

  /**
   * The last turn of a run a runaway guard ended. The model writes it from
   * the conversation, in its own voice: what it got done, what is missing,
   * and why. Only when it returns nothing does the run fall back to its last
   * written text, then to a description of the observed tool executions.
   */
  async #wrapUp(session, reason) {
    const { runId, userId, agentId, options } = session;
    // The wrap-up is the run's last model turn, so it must see any follow-up
    // still waiting; nothing sent after this point can reach this run.
    setSteeringIntake(this.engine, runId, false);
    this.engine.applyQueuedSteering?.(runId, session.messages, {
      userId,
      conversationId: session.conversationId,
    });
    const leadingSystem = [];
    for (const message of session.messages) {
      if (message.role !== 'system') break;
      leadingSystem.push(message);
    }
    const history = [
      ...leadingSystem,
      ...session.messages.slice(leadingSystem.length).slice(-WRAP_UP_HISTORY_MESSAGES),
    ];
    try {
      const wrapUp = await this.engine.requestModelResponse({
        provider: session.model.provider,
        providerName: session.model.providerName,
        model: session.model.model,
        messages: sanitizeConversationMessages([
          ...history,
          { role: 'system', content: buildWrapUpPrompt(reason, options.source || null) },
        ]),
        tools: [],
        options: {
          ...options,
          stream: false,
          phase: 'wrap_up',
          signal: session.getActiveSignal(),
          runId,
          userId,
          agentId,
        },
        runId,
        iteration: session.iterations,
      });
      const text = sanitizeModelOutput(
        String(wrapUp?.response?.content || wrapUp?.streamContent || '').trim(),
        { model: session.model.model },
      );
      if (normalizeOutgoingMessage(text, options.source || null)) return text;
    } catch (error) {
      if (isAbortError(error, session.getActiveSignal())) throw error;
      console.warn('[Runtime] Wrap-up generation failed:', error?.message || error);
    }

    // No reply the model wrote: the run fails visibly rather than sending the
    // user text nobody wrote.
    throw new Error(`Run stopped (${reason}) and the model could not write a reply`);
  }

  /**
   * Phrase an observed progress delta. The run's own system prompt supplies the
   * voice and formatting rules, so an update reads like every other message; the
   * delta is the only permitted source of facts, and an empty answer means "no
   * useful update", not "send something generic".
   */
  async #narrateProgress(session, { delta, liveness, signal }) {
    const { runId, userId, agentId, options } = session;
    if (!session.model) return '';
    const systemPrompt = [session.systemPrompt?.stable, session.systemPrompt?.dynamic]
      .filter(Boolean)
      .join('\n\n');
    const response = await this.engine.requestModelResponse({
      provider: session.model.provider,
      providerName: session.model.providerName,
      model: session.model.model,
      messages: [
        ...(systemPrompt ? [{ role: 'system', content: systemPrompt }] : []),
        {
          role: 'system',
          content: [
            buildProgressUpdatePrompt(),
            liveness?.status === 'stalled'
              ? 'No verified activity has been recorded for the stall threshold. State that plainly if it matters; do not reassure or imply activity beyond the evidence.'
              : '',
          ].filter(Boolean).join(' '),
        },
        {
          role: 'user',
          content: [
            `Original request: ${String(session.userMessage || '').slice(0, 320)}`,
            delta?.evidence
              ? `Actual recent tool activity (newest last) — describe ONLY this:\n${delta.evidence}`
              : '',
          ].filter(Boolean).join('\n\n'),
        },
      ],
      tools: [],
      options: {
        ...options,
        maxTokens: NARRATION_MAX_TOKENS,
        stream: false,
        phase: 'progress_narration',
        signal,
        runId,
        userId,
        agentId,
      },
      runId,
      iteration: 0,
    });
    const text = sanitizeModelOutput(
      String(response?.response?.content || response?.streamContent || '').trim(),
      { model: session.model.model },
    );
    if (!normalizeOutgoingMessage(text, options.source || null)) return '';
    return text.split(/\n+/).map((line) => line.trim()).filter(Boolean).join(' ').slice(0, 400);
  }

  // A stop noticed between steps ends here instead of in the abort handler,
  // so clients still need the terminal event.
  #cancelledResult(session) {
    const { runId } = session;
    const run = stateMachine.loadRun(runId);
    if (run && !stateMachine.isTerminal(run)) {
      applyTransition({
        runId,
        toState: RUNTIME_STATES.CANCELLED,
        reason: 'cancelled',
        eventBus: this.eventBus,
        patch: { totalTokens: session.totalTokens },
      });
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
