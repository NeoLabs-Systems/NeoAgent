'use strict';

const { randomUUID } = require('crypto');
const db = require('../../../db/database');
const {
  getConversationContext,
  buildSummaryCarrier,
  sanitizeConversationMessages,
} = require('../history');
const { ensureDefaultAiSettings, getAiSettings } = require('../settings');
const {
  buildToolDiscoverySummary,
  searchTools,
  selectInitialTools,
  selectToolsForTask,
} = require('../toolSelector');
const { resolveToolResultLimits } = require('../loopPolicy');
const { compactToolResult } = require('../toolResult');
const { sanitizeModelOutput } = require('../outputSanitizer');
const {
  buildExecutionGuidance,
  buildInteractiveExecutionGuidance,
  normalizeTaskAnalysis,
  shouldRunVerifier,
  buildVerifierPrompt,
  normalizeVerificationResult,
} = require('../taskAnalysis');
const { getCapabilityHealth, summarizeCapabilityHealth } = require('../capabilityHealth');
const {
  classifyToolExecution,
  gatheredNewEvidence,
  summarizeProgressToolExecutions,
} = require('../toolEvidence');
const { enforceRateLimits } = require('../rate_limits');
const { ToolRepetitionGuard } = require('../repetitionGuard');
const { shortenRunId, summarizeForLog } = require('../logFormat');
const {
  recordModelFailure,
  recordModelSuccess,
} = require('../model_failure_cache');
const { getProviderForUser } = require('../provider_selector');
const {
  buildDeterministicMessagingFallback,
  buildMaxIterationWrapupPrompt,
  buildProgressUpdatePrompt,
  buildRunAcknowledgementPrompt,
  normalizeOutgoingMessage,
} = require('../messagingFallback');
const { globalHooks } = require('../hooks');
const {
  isAbortError,
  throwIfAborted,
} = require('../../../utils/abort');

const { RUNTIME_STATES, MESSAGE_KINDS } = require('./constants');
const { RunEventBus } = require('./events/run_event_bus');
const { EVENT_TYPES, VISIBILITY } = require('./events/event_types');
const stateMachine = require('./run_state_machine');
const leases = require('./leases');
const {
  contractFromAnalysis,
  evaluateOpenObligations,
  saveContract,
  loadLatestContract,
} = require('./task_contract');
const workGraph = require('./work_graph');
const { createBudgetManager } = require('./budget_manager');
const {
  decisionFromModelResponse,
  protocolRepairDecision,
  DECISION_KINDS,
} = require('./decision_engine');
const { verifyRun } = require('./verification_service');
const { planRecovery, classifyError } = require('./recovery_manager');
const { saveCheckpoint } = require('./checkpoint_service');
const { createProgressBroker } = require('./delivery/progress_broker');
const {
  requestFinalDelivery,
  requestProgressDelivery,
} = require('./delivery/delivery_worker');
const {
  resolveDeliveryChannel,
  resolveDeliveryRecipient,
} = require('./delivery/delivery_channel');
const { buildContextView } = require('./context/context_view_builder');
const {
  createContextPressureController,
  isContextOverflowError,
} = require('./context/context_pressure');
const {
  buildEvidencePacket,
  appendToolEvidence,
} = require('./context/evidence_packet_builder');
const { createWorkingMemory } = require('./memory/working_memory');
const memoryWritePipeline = require('./memory/memory_write_pipeline');
const { getFailureFallbackModelId } = require('./model_fallback');
const { buildBlankOutputGuidance } = require('../loop/blank_recovery');
const { scheduleToolCalls } = require('../loop/tool_scheduler');

const PLAN_MODE_SAFE_CONTROL_TOOLS = new Set([
  'search_tools',
  'activate_tools',
  'request_user_input',
  'send_interim_update',
  'task_complete',
]);

function isoNow() {
  return new Date().toISOString();
}

function generateTitle(message) {
  const text = String(message || '').replace(/\s+/g, ' ').trim();
  if (!text) return 'Agent run';
  return text.length > 80 ? `${text.slice(0, 77)}...` : text;
}

function usageTokens(usage) {
  usage = usage || {};
  return {
    input: Number(usage.input_tokens || usage.prompt_tokens || usage.inputTokens || 0) || 0,
    output: Number(usage.output_tokens || usage.completion_tokens || usage.outputTokens || 0) || 0,
    total: Number(usage.total_tokens || usage.totalTokens || 0) || 0,
  };
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
    const interactionMode = options.interactionMode === 'plan' ? 'plan' : 'agent';
    const deviceTarget = ['local', 'cloud'].includes(options.deviceTarget)
      ? options.deviceTarget
      : null;
    const workspaceRoot = typeof options.workspaceRoot === 'string' && options.workspaceRoot.trim()
      ? options.workspaceRoot.trim()
      : null;
    const app = options.app || this.engine.app;
    const triggerSource = options.triggerSource || 'web';
    const deliveryChannel = resolveDeliveryChannel(triggerSource);
    const deliveryRecipient = resolveDeliveryRecipient(triggerSource, options);
    const workerId = `worker_${randomUUID()}`;
    const runTitle = generateTitle(userMessage);
    let totalTokens = 0;
    let iterations = 0;
    let stepIndex = 0;
    let detachExternalAbort = null;
    let provider = null;
    let model = null;
    let modelSelectionId = null;
    let providerName = null;
    let messages = [];
    let ackContextMessages = [];
    let tools = [];
    let systemPrompt = '';
    let analysis = null;
    // Canonical tool-execution records (shared shape with the evidence helpers)
    // used for progress narration and the no-progress guard.
    const toolExecutions = [];
    let contract = null;
    let finalContent = '';
    let path = 'durable';
    const workingMemory = createWorkingMemory();
    let evidencePacket = buildEvidencePacket({ queryIntent: 'current_task' });
    const startedAtMs = Date.now();
    let budget = null;
    let progressBroker = null;
    let contextPressure = null;
    let runRecordCreated = false;
    let runSignal = null;

    const { releaseReservation } = enforceRateLimits(userId, {
      bypass: options.bypassUserRateLimits === true,
    });

    try {
      // ── Accept immediately ─────────────────────────────────────────────
      try {
        db.prepare(
          `INSERT INTO agent_runs(
            id, user_id, agent_id, title, status, runtime_state, version,
            trigger_type, trigger_source, model, metadata_json,
            conversation_id, interaction_mode, device_target
          ) VALUES(?, ?, ?, ?, 'running', ?, 0, ?, ?, ?, ?, ?, ?, ?)`,
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
            interactionMode,
            ...(deviceTarget ? { deviceTarget } : {}),
            runtimeKernel: 'v2',
          }),
          conversationId || null,
          interactionMode,
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
        conversationId: conversationId || null,
        interactionMode,
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

      progressBroker = createProgressBroker({
        engine: this.engine,
        runId,
        userId,
        agentId,
        eventBus: this.eventBus,
        channel: deliveryChannel,
        recipient: deliveryRecipient,
        deliveryMetadata: options.sessionBinding || null,
        maxSilenceSeconds: Number(options.maxSilenceSeconds)
          || (options.latencyPriority === 'interactive' ? 45 : 90),
        firstUpdateSeconds: options.latencyPriority === 'interactive' ? 15 : 25,
        repeatUpdateSeconds: options.latencyPriority === 'interactive' ? 45 : 90,
        collectDelta: () => this.#collectProgressDelta(runId, toolExecutions),
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
        narrator: async ({ delta, liveness }) => this.#narrateProgress({
          provider,
          providerName,
          model,
          systemPrompt,
          delta,
          liveness,
          userMessage,
          options,
          runId,
          userId,
          agentId,
          signal: abortController.signal,
        }),
      });
      progressBroker.markAccepted();

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
        interactionMode,
        deviceTarget,
        runtimeKernel: 'v2',
      });

      // Opening line for work that will keep the user waiting. The runtime only
      // decides whether to speak; the model writes the line from the real
      // conversation and may decline. Background automation reports through its
      // own delivery target and never gets one.
      const maybeAck = async (force = false, analysisAck = '') => {
        if (!force) return;
        // Background schedule/task automation delivers via send_message only.
        if (triggerSource === 'schedule' || triggerSource === 'tasks') return;
        if (triggerType === 'subagent') return;

        let ackText = options.latencyPriority === 'interactive'
          ? String(analysisAck || '').trim()
          : '';
        try {
          if (!ackText) {
            const ackResponse = await this.engine.requestModelResponse({
            provider,
            providerName,
            model,
            // The real conversation, not a synthetic prompt: system persona,
            // recalled memory, recent history, and the message being answered.
            // Without it the line has no voice and no way to differ from the
            // last one, which is what made acknowledgements read as canned.
            messages: sanitizeConversationMessages([
              ...ackContextMessages,
              { role: 'system', content: buildRunAcknowledgementPrompt() },
            ]),
            tools: [],
            options: {
              ...options,
              stream: false,
              signal: abortController.signal,
              runId,
              userId,
              agentId,
            },
            runId,
            iteration: 0,
          });
            ackText = sanitizeModelOutput(
              String(ackResponse?.response?.content || ackResponse?.streamContent || '').trim(),
              { model },
            );
            // Strip accidental multi-paragraph model output to one line.
            ackText = ackText.split(/\n+/).map((line) => line.trim()).filter(Boolean)[0] || '';
            if (ackText.length > 220) ackText = `${ackText.slice(0, 217).trimEnd()}...`;
          }
        } catch (error) {
          console.warn('[Runtime] Ack generation failed; continuing without hard-coded text:', error?.message || error);
          ackText = '';
        }
        // An empty answer means the model had nothing worth saying yet. Staying
        // quiet is the natural outcome; the progress heartbeat still covers a
        // run that then goes long.
        if (!normalizeOutgoingMessage(ackText, options.source || null)) return;

        await requestProgressDelivery({
          engine: this.engine,
          runId,
          content: ackText,
          channel: deliveryChannel,
          recipient: deliveryRecipient,
          messageKind: MESSAGE_KINDS.ACK,
          metadata: {
            platform: options.source || null,
            chatId: options.chatId || null,
            ...(options.sessionBinding || {}),
            idempotencyKey: `${runId}:ack:1`,
          },
        });
      };

      // ── Provider selection ─────────────────────────────────────────────
      const providerStatusConfig = {
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
        { ...providerStatusConfig, signal: abortController.signal },
      );
      provider = selectedProvider.provider;
      model = selectedProvider.model;
      modelSelectionId = selectedProvider.modelSelectionId;
      providerName = selectedProvider.providerName;
      db.prepare('UPDATE agent_runs SET model = ?, updated_at = datetime(\'now\') WHERE id = ?')
        .run(modelSelectionId, runId);
      Object.assign(this.engine.getRunMeta(runId) || {}, {
        model,
        modelSelectionId,
        providerName,
      });
      contextPressure = createContextPressureController({
        summarize: async (summaryMessages) => {
          const result = await this.engine.requestModelResponse({
            provider,
            providerName,
            model,
            messages: summaryMessages,
            tools: [],
            options: {
              ...options,
              stream: false,
              maxTokens: 1600,
              phase: 'context_compaction',
              signal: this.engine.getRunMeta(runId)?.abortController?.signal
                || abortController.signal,
              runId,
              userId,
              agentId,
            },
            runId,
            iteration: Math.max(1, iterations),
          });
          const summary = String(
            result?.response?.content || result?.streamContent || '',
          ).trim();
          if (!summary) throw new Error('Context compaction returned an empty summary.');
          return summary;
        },
        onEvent: (kind, payload) => {
          const eventType = kind === 'compacted'
            ? EVENT_TYPES.CONTEXT_COMPACTED
            : EVENT_TYPES.CONTEXT_PRESSURE;
          if (kind === 'pressure') {
            saveCheckpoint(runId, 'pre_compaction', {
              workingMemory: workingMemory.snapshot(),
              contractVersion: contract?.version || 0,
              iterations,
              finalContent,
            }, { eventBus: this.eventBus, userId, agentId });
          }
          this.eventBus.publish({
            runId,
            userId,
            agentId,
            eventType,
            payload,
            visibility: VISIBILITY.OPERATOR,
          });
        },
      });

      // ── Context assembly ───────────────────────────────────────────────
      const historyWindow = Math.max(
        1,
        Number(options.historyWindow || aiSettings.chat_history_window) || aiSettings.chat_history_window,
      );
      systemPrompt = await this.engine.buildSystemPrompt(userId, {
        ...(options.context || {}),
        userMessage,
        agentId,
        triggerSource,
        memoryAudience: options.memoryAudience || 'owner',
        interactionMode,
        deviceTarget,
        workspaceRoot,
      });

      const builtInTools = this.engine.getAvailableTools(app, {
        includeDescriptions: true,
        userId,
        agentId,
        triggerType,
        triggerSource,
      });
      const mcpManager = app?.locals?.mcpManager || app?.locals?.mcpClient || this.engine.mcpManager;
      const mcpTools = mcpManager ? mcpManager.getAllTools(userId, { agentId }) : [];
      const disallowedToolNames = new Set(
        (Array.isArray(options.disallowedToolNames) ? options.disallowedToolNames : [])
          .map((name) => String(name || '').trim())
          .filter(Boolean),
      );
      const allTools = selectToolsForTask(userMessage, builtInTools, mcpTools, options)
        .filter((tool) => !disallowedToolNames.has(tool?.name));

      const { MemoryManager } = require('../../memory/manager');
      const memoryManager = this.engine.memoryManager || new MemoryManager();
      const recallMsg = options.skipGlobalRecall === true
        ? null
        : await this.engine.buildMemoryRecall({
          memoryManager,
          userId,
          agentId,
          query: options.context?.rawUserMessage || userMessage,
          provider,
          providerName,
          model,
          runId,
          options,
        });

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

      messages = this.engine.buildContextMessages(systemPrompt, summaryMessage, historyMessages, recallMsg);
      const capabilityHealth = await getCapabilityHealth({
        userId,
        agentId,
        app,
        engine: this.engine,
        deviceTarget,
        triggerSource,
        workspaceRoot,
      });
      const capabilitySummary = summarizeCapabilityHealth(capabilityHealth);
      if (capabilitySummary) {
        messages.push({ role: 'system', content: `[Capability health]\n${capabilitySummary}` });
      }
      messages.push(this.engine.buildUserMessage(userMessage, options));
      messages = sanitizeConversationMessages(messages);
      // Snapshot before the tool catalog and execution guidance are appended:
      // the acknowledgement should read the conversation, not the runtime's
      // internal scaffolding.
      ackContextMessages = [...messages];

      if (conversationId) {
        const sharedAttachments = triggerSource === 'cowork'
          && Array.isArray(options.coworkSharedAttachments)
          ? options.coworkSharedAttachments
          : [];
        db.prepare(
          `INSERT INTO conversation_messages (
            conversation_id, run_id, agent_id, role, content, metadata_json
          ) VALUES (?, ?, ?, 'user', ?, ?)`,
        ).run(
          conversationId,
          runId,
          agentId,
          String(userMessage || ''),
          JSON.stringify({
            interactionMode,
            deviceTarget,
            ...(triggerSource === 'cowork' && options.coworkDisplayContent
              ? { displayContent: String(options.coworkDisplayContent) }
              : {}),
            ...(sharedAttachments.length > 0 ? { sharedAttachments } : {}),
          }),
        );
      }

      // ── Triage ─────────────────────────────────────────────────────────
      applyTransition({
        runId,
        toState: RUNTIME_STATES.TRIAGING,
        reason: 'worker_started',
        workerId,
        eventBus: this.eventBus,
      });
      leases.heartbeat(runId, workerId);
      progressBroker.noteActivity('triaging');

      // One model loop owns both routing and execution. The previous mandatory
      // structured triage call added latency, duplicated the user's request, and
      // could disagree with the agent that performed the work. Runtime-only
      // facts remain deterministic; the first ordinary model turn decides
      // whether to answer, discover tools, or act.
      const requestedPlan = options.forceMode === 'plan_execute';
      analysis = normalizeTaskAnalysis({
        mode: requestedPlan ? 'plan_execute' : 'execute',
        verification_need: requestedPlan ? 'light' : 'none',
        needs_verification: requestedPlan,
        goal: String(userMessage || '').trim().slice(0, 500),
        draft_reply: '',
        draft_status: 'needs_execution',
        complexity: requestedPlan ? 'complex' : 'standard',
        autonomy_level: triggerSource === 'cowork' || requestedPlan ? 'high' : 'normal',
        progress_update_policy: requestedPlan ? 'required' : 'optional',
      }, { goal: String(userMessage || '').trim().slice(0, 500) });

      // Tool schemas are capped per model turn. Seed the active slice with a
      // generic registry search; search_tools provides exact on-demand discovery
      // without copying the complete catalog into every request.
      const toolSelectionOptions = {
        triggerSource,
        triggerType,
        includeCoreFileTools: triggerSource === 'cowork' || requestedPlan,
      };
      const initialMatches = searchTools(allTools, userMessage, { limit: 4 });
      tools = selectInitialTools(
        allTools,
        initialMatches.map((tool) => tool.name),
        toolSelectionOptions,
      );
      this.engine.initializeToolRuntime?.(runId, allTools, tools, toolSelectionOptions);
      messages.push({
        role: 'system',
        content: [
          '[Tool discovery]',
          buildToolDiscoverySummary(allTools, tools),
          'For workspace file inspection/editing, prefer read_files, read_file, search_files, list_directory, edit_file, replace_file_range, and write_file over shell cat/sed/python snippets. Use execute_command for git, tests, package managers, builds, and other shell-native actions.',
        ].join('\n'),
      });
      this.engine.recordRunEvent?.(userId, runId, 'tool_selection_applied', {
        activeToolNames: tools.map((tool) => tool.name),
        matchedToolNames: initialMatches.map((tool) => tool.name),
        catalogSize: allTools.length,
      }, { agentId });

      contract = contractFromAnalysis(analysis, userMessage);
      const savedContract = saveContract(runId, contract, {
        eventBus: this.eventBus,
        userId,
        agentId,
      });
      contract = savedContract.contract;
      workingMemory.setContractVersion(savedContract.version);

      budget = createBudgetManager({
        aiSettings,
        triggerType,
        analysisMode: analysis.mode || 'execute',
        options,
        startedAtMs,
      });

      await maybeAck(requestedPlan, analysis.acknowledgement);
      applyTransition({
        runId,
        toState: RUNTIME_STATES.PLANNING,
        reason: 'single_loop_started',
        workerId,
        eventBus: this.eventBus,
      });

      // ── Planning / work graph ──────────────────────────────────────────
      const graphNodes = workGraph.graphFromContract(contract);
      workGraph.createGraph(runId, graphNodes, {
        eventBus: this.eventBus,
        userId,
        agentId,
      });
      saveCheckpoint(runId, 'plan_ready', {
        contractVersion: contract.version,
        graphNodeCount: graphNodes.length,
        workingSummary: `Plan ready for: ${contract.goal}`,
      }, { eventBus: this.eventBus, userId, agentId });

      messages.push({
        role: 'system',
        content: buildExecutionGuidance({
          analysis,
          plan: {
            steps: graphNodes.map((node) => ({
              title: node.id,
              objective: node.objective,
              success_criteria: node.success_criteria,
            })),
            success_criteria: contract.success_criteria,
          },
          capabilityHealth: capabilitySummary,
          triggerSource,
        }),
      });
      if (options.latencyPriority === 'interactive') {
        messages.push({
          role: 'system',
          content: buildInteractiveExecutionGuidance(),
        });
      }

      applyTransition({
        runId,
        toState: RUNTIME_STATES.EXECUTING,
        reason: 'work_graph_ready',
        workerId,
        eventBus: this.eventBus,
      });

      // ── Execution loop ─────────────────────────────────────────────────
      // The heartbeat runs only while the run is executing: it keeps a run that
      // sits inside a long tool or model call from going silent, and must never
      // race verification or final delivery. Background automation reports
      // through its own delivery target, so it stays off there.
      const heartbeatWanted = triggerSource !== 'schedule'
        && triggerSource !== 'tasks'
        && triggerType !== 'subagent';
      let consecutiveProtocolRepairs = 0;
      const maxProtocolRepairs = 3;
      let verificationRepairs = 0;
      let lastSemanticVerificationFailure = null;
      const maxVerificationRepairs = 3;
      let blankOutputRecoveries = 0;
      const maxBlankOutputRecoveries = 2;
      const getActiveSignal = () => (
        this.engine.getRunMeta(runId)?.abortController?.signal || abortController.signal
      );

      while (true) {
        const activeSignal = getActiveSignal();
        if (this.engine.getRunMeta(runId)?.aborted) {
          return this.#cancelledResult(runId, totalTokens, iterations);
        }
        if (activeSignal.aborted) {
          const boundary = await this.engine.checkpointLifecycle?.(runId, 'signal_boundary', {
            iteration: iterations,
          });
          if (boundary?.action === 'stop' || boundary?.action === 'interrupt') {
            return this.#cancelledResult(runId, totalTokens, iterations);
          }
          if (this.engine.getRunMeta(runId)?.status === 'paused') {
            // Still waiting to resume inside checkpointLifecycle normally.
            continue;
          }
        }

        leases.heartbeat(runId, workerId);
        progressBroker.noteActivity('loop_tick');

        const run = stateMachine.loadRun(runId);
        if (!run || stateMachine.isTerminal(run)) {
          return {
            runId,
            content: finalContent,
            totalTokens,
            iterations,
            status: run?.status || 'completed',
            path,
          };
        }

        if (heartbeatWanted && run.runtimeState === RUNTIME_STATES.EXECUTING) {
          progressBroker.start();
        } else {
          progressBroker.stop();
        }

        // Handle pause / stop controls through the engine lifecycle fence so
        // resume can continue the same in-memory run.
        const control = db.prepare(
          `SELECT action, reason FROM agent_run_controls
           WHERE run_id = ? AND consumed_at IS NULL`,
        ).get(runId);
        if (control?.action === 'pause') {
          const boundary = await this.engine.checkpointLifecycle?.(runId, 'loop_boundary', {
            iteration: iterations,
          });
          if (boundary?.action === 'stop' || boundary?.action === 'interrupt') {
            return this.#cancelledResult(runId, totalTokens, iterations);
          }
          // Resumed — refresh local controller reference and continue.
          continue;
        }
        if (control?.action === 'stop' || control?.action === 'interrupt') {
          this.engine.interruptRun?.(runId, control.reason || control.action);
          return this.#cancelledResult(runId, totalTokens, iterations);
        }

        // Reliability / policy hooks: may stop the loop before a model call.
        const iterationHook = await globalHooks.run('on_loop_iteration', {
          userId,
          runId,
          agentId,
          iteration: iterations + 1,
          triggerType,
          triggerSource,
          totalTokens,
        });
        if (iterationHook?.stop === true) {
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
            totalTokens,
            iterations,
            status: 'stopped',
            path,
          };
        }

        if (run.runtimeState === RUNTIME_STATES.VERIFYING) {
          // When callers explicitly skip verification (tests / trusted short runs),
          // accept the final response if content exists.
          if (options.skipVerifier === true && String(finalContent || '').trim()) {
            for (const node of workGraph.requiredOpenNodes(runId)) {
              workGraph.completeNode(node.id, {
                evidence: [{ summary: 'Accepted with skipVerifier', kind: 'response' }],
              });
            }
            applyTransition({
              runId,
              toState: RUNTIME_STATES.DELIVERING,
              reason: 'skip_verifier',
              workerId,
              eventBus: this.eventBus,
            });
            continue;
          }

          const verification = await verifyRun({
            runId,
            contract: loadLatestContract(runId)?.contract || contract,
            contractVersion: workingMemory.snapshot().contractVersion,
            claim: {
              summary: finalContent,
              confidence: 0.75,
              completed_node_ids: workGraph.listNodes(runId)
                .filter((n) => n.status === 'completed')
                .map((n) => n.nodeKey),
            },
            evidence: workingMemory.snapshot().evidence,
            artifacts: workingMemory.snapshot().artifacts,
            finalContent,
            finalDeliveryId: run.finalDeliveryId,
            sideEffects: workingMemory.snapshot().sideEffects,
            path: 'durable',
            semanticVerifier: shouldRunVerifier({
              analysis,
              toolExecutions: workingMemory.snapshot().evidence,
              finalReply: finalContent,
            })
              ? async ({ finalContent: reply }) => this.#semanticVerify({
                provider,
                providerName,
                model,
                messages,
                tools,
                analysis,
                finalContent: reply,
                options: { ...options, signal: getActiveSignal(), runId, userId, agentId },
              })
              : null,
            previousSemanticFailure: lastSemanticVerificationFailure,
            eventBus: this.eventBus,
            userId,
            agentId,
          });

          if (verification.status === 'repair_required') {
            if (verification.semanticFailure) {
              lastSemanticVerificationFailure = verification.semanticFailure;
            }
            verificationRepairs += 1;
            // Repair is bounded per run: a defect the model cannot close would
            // otherwise reopen the same nodes until the whole budget is spent,
            // and the user would still get a partial answer at the end.
            if (verificationRepairs > maxVerificationRepairs) {
              this.eventBus.publish({
                runId,
                userId,
                agentId,
                eventType: EVENT_TYPES.VERIFICATION_FAILED,
                payload: {
                  reason: 'repair_budget_exhausted',
                  attempts: verificationRepairs,
                  defects: verification.defects || [],
                },
                visibility: VISIBILITY.OPERATOR,
              });
              finalContent = await this.#partialDeliveryText({
                runId,
                contract,
                workingMemory,
                reason: 'verification_repair_budget_exhausted',
                provider,
                providerName,
                model,
                messages,
                options,
                signal: getActiveSignal(),
                userId,
                agentId,
              });
              applyTransition({
                runId,
                toState: RUNTIME_STATES.DELIVERING,
                reason: 'repair_budget_exhausted',
                workerId,
                eventBus: this.eventBus,
              });
              continue;
            }
            applyTransition({
              runId,
              toState: RUNTIME_STATES.REPAIRING,
              reason: 'verification_defects',
              workerId,
              eventBus: this.eventBus,
            });
            workingMemory.clearDefects();
            for (const defect of verification.defects || []) {
              workingMemory.addDefect(defect);
            }
            messages.push({
              role: 'system',
              content: [
                'Verification found defects. Repair the reopened work nodes.',
                `Defects: ${JSON.stringify(verification.defects || []).slice(0, 3000)}`,
                verification.unchanged
                  ? 'The verification fingerprint is unchanged. Change the final response, evidence, artifact set, work-node state, or side-effect status before requesting verification again.'
                  : '',
                'Do not claim completion until defects are resolved with evidence.',
              ].filter(Boolean).join('\n'),
            });
            if (verification.final_reply) {
              finalContent = verification.final_reply;
              workingMemory.setDraftResponse(finalContent);
            }
            applyTransition({
              runId,
              toState: RUNTIME_STATES.EXECUTING,
              reason: 'repair_nodes_ready',
              workerId,
              eventBus: this.eventBus,
            });
            continue;
          }

          lastSemanticVerificationFailure = null;

          if (verification.status === 'blocked') {
            applyTransition({
              runId,
              toState: RUNTIME_STATES.BLOCKED,
              reason: 'verification_blocked',
              workerId,
              eventBus: this.eventBus,
              patch: { error: 'Verification blocked without safe repair path' },
            });
            finalContent = await this.#partialDeliveryText({
              runId,
              contract,
              workingMemory,
              reason: 'Verification could not be completed safely',
              provider,
              providerName,
              model,
              messages,
              options,
              signal: getActiveSignal(),
              userId,
              agentId,
            });
            await this.#deliverFinal({
              runId,
              userId,
              agentId,
              workerId,
              content: finalContent,
              options,
              triggerSource,
              totalTokens,
              asError: true,
            });
            return {
              runId,
              content: finalContent,
              totalTokens,
              iterations,
              status: 'failed',
              path,
            };
          }

          finalContent = verification.final_reply || finalContent;
          applyTransition({
            runId,
            toState: RUNTIME_STATES.DELIVERING,
            reason: 'completion_verified',
            workerId,
            eventBus: this.eventBus,
          });
          const delivery = await this.#deliverFinal({
            runId,
            userId,
            agentId,
            workerId,
            content: finalContent,
            options,
            triggerSource,
            totalTokens,
          });
          await this.#finalizeSuccess({
            runId,
            userId,
            agentId,
            conversationId,
            content: delivery.content || finalContent,
            totalTokens,
            iterations,
            memoryManager,
            messages,
            task: userMessage,
            taskId: options.taskId || null,
            triggerType,
            triggerSource,
          });
          return {
            runId,
            content: delivery.content || finalContent,
            totalTokens,
            iterations,
            status: 'completed',
            path,
          };
        }

        if (run.runtimeState === RUNTIME_STATES.REPAIRING) {
          applyTransition({
            runId,
            toState: RUNTIME_STATES.EXECUTING,
            reason: 'repair_nodes_ready',
            workerId,
            eventBus: this.eventBus,
          });
          continue;
        }

        if (run.runtimeState === RUNTIME_STATES.DELIVERING) {
          const delivery = await this.#deliverFinal({
            runId,
            userId,
            agentId,
            workerId,
            content: finalContent,
            options,
            triggerSource,
            totalTokens,
          });
          await this.#finalizeSuccess({
            runId,
            userId,
            agentId,
            conversationId,
            content: delivery.content || finalContent,
            totalTokens,
            iterations,
            memoryManager,
            messages,
            task: userMessage,
            taskId: options.taskId || null,
            triggerType,
            triggerSource,
          });
          return {
            runId,
            content: delivery.content || finalContent,
            totalTokens,
            iterations,
            status: 'completed',
            path,
          };
        }

        if (run.runtimeState !== RUNTIME_STATES.EXECUTING) {
          // waiting/blocked handling
          if (run.runtimeState === RUNTIME_STATES.BLOCKED) {
            finalContent = await this.#partialDeliveryText({
              runId,
              contract,
              workingMemory,
              reason: run.error || 'Run blocked',
              provider,
              providerName,
              model,
              messages,
              options,
              signal: getActiveSignal(),
              userId,
              agentId,
            });
            await this.#deliverFinal({
              runId,
              userId,
              agentId,
              workerId,
              content: finalContent,
              options,
              triggerSource,
              totalTokens,
            });
            return {
              runId,
              content: finalContent,
              totalTokens,
              iterations,
              status: 'completed',
              path,
            };
          }
          break;
        }

        // Budget gate
        const openNodes = workGraph.requiredOpenNodes(runId);
        const nextNodes = workGraph.nextActionableNodes(runId);
        const obligations = evaluateOpenObligations(
          loadLatestContract(runId)?.contract || contract,
          {
            completedNodeKeys: workGraph.listNodes(runId)
              .filter((n) => n.status === 'completed')
              .map((n) => n.nodeKey),
            evidence: workingMemory.snapshot().evidence,
            artifacts: workingMemory.snapshot().artifacts,
            finalContent,
          },
        );
        const continuation = budget.shouldContinue({
          openObligations: obligations.open.length ? obligations.open : openNodes,
          hasNextAction: nextNodes.length > 0 || obligations.open.length > 0,
        });
        if (!continuation.continue) {
          if (continuation.reason === 'hard_budget' || continuation.reason === 'no_progress_delta') {
            finalContent = await this.#partialDeliveryText({
              runId,
              contract,
              workingMemory,
              reason: continuation.reason,
              provider,
              providerName,
              model,
              messages,
              options,
              signal: getActiveSignal(),
              userId,
              agentId,
            });
            applyTransition({
              runId,
              toState: RUNTIME_STATES.DELIVERING,
              reason: continuation.reason,
              workerId,
              eventBus: this.eventBus,
            });
            continue;
          }
          if (continuation.reason === 'no_open_obligations' || nextNodes.length === 0) {
            applyTransition({
              runId,
              toState: RUNTIME_STATES.VERIFYING,
              reason: 'no_ready_nodes',
              workerId,
              eventBus: this.eventBus,
            });
            continue;
          }
        }
        if (continuation.softWarning) {
          this.eventBus.publish({
            runId,
            userId,
            agentId,
            eventType: EVENT_TYPES.BUDGET_SOFT_LIMIT,
            payload: { dimensions: continuation.snapshot.softDimensions },
            visibility: VISIBILITY.OPERATOR,
          });
        }

        // Steering
        const steered = this.engine.applyQueuedSteering?.(runId, messages, {
          userId,
          conversationId,
        });
        if (steered?.messages) messages = steered.messages;
        const systemSteered = this.engine.applyQueuedSystemSteering?.(runId, messages);
        if (systemSteered?.messages) messages = systemSteered.messages;

        const activeNode = nextNodes[0] || null;
        if (activeNode && activeNode.status !== 'running') {
          workGraph.updateNode(activeNode.id, { status: 'running', assignedWorker: workerId });
          this.eventBus.publish({
            runId,
            userId,
            agentId,
            eventType: EVENT_TYPES.NODE_STARTED,
            payload: { node_id: activeNode.id, node_key: activeNode.nodeKey },
            visibility: VISIBILITY.OPERATOR,
          });
        }

        // Durable-state notes are rebuilt every turn and appended to the live
        // transcript. They must never replace it: `messages` carries the agent
        // system prompt, memory recall, tool catalog, and tool-call/result pairs.
        const contextView = buildContextView({
          runId,
          systemPrompt: '',
          messages: [],
          evidencePacket,
          activeNodeIds: activeNode ? [activeNode.id] : [],
          budgetSnapshot: budget.snapshot(),
        });
        try {
          const pressure = await contextPressure.prepare({
            provider,
            model,
            messages,
            fixedMessages: contextView.messages,
            tools,
            maxOutputTokens: options.maxTokens,
          });
          if (pressure.changed) messages = pressure.messages;
        } catch (error) {
          if (isAbortError(error, getActiveSignal())) throw error;
          console.warn('[Runtime] Proactive context compaction failed:', error?.message || error);
        }
        let turnMessages = sanitizeConversationMessages([
          ...messages,
          ...contextView.messages,
        ]);

        iterations += 1;
        progressBroker.noteActivity('model_started', { iteration: iterations });
        this.eventBus.publish({
          runId,
          userId,
          agentId,
          eventType: EVENT_TYPES.MODEL_STARTED,
          payload: { iteration: iterations, model: modelSelectionId },
          visibility: VISIBILITY.OPERATOR,
        });

        let modelTurn;
        try {
          const signal = getActiveSignal();
          let overflowRetried = false;
          while (true) {
            try {
              modelTurn = await this.engine.requestModelResponse({
                provider,
                providerName,
                model,
                messages: turnMessages.length ? turnMessages : messages,
                tools,
                options: {
                  ...options,
                  signal,
                  runId,
                  userId,
                  agentId,
                },
                runId,
                iteration: iterations,
              });
              break;
            } catch (error) {
              const canRecover = isContextOverflowError(error)
                && !overflowRetried
                && contextPressure.claimOverflowRecovery();
              if (!canRecover) {
                if (isContextOverflowError(error)) error.contextPressureExhausted = true;
                throw error;
              }

              let recovered;
              try {
                recovered = await contextPressure.prepare({
                  provider,
                  model,
                  messages,
                  fixedMessages: contextView.messages,
                  tools,
                  maxOutputTokens: options.maxTokens,
                  force: true,
                  reason: 'provider_overflow',
                });
              } catch (compactionError) {
                if (isAbortError(compactionError, signal)) throw compactionError;
                error.contextPressureExhausted = true;
                error.compactionError = compactionError?.message || String(compactionError);
                throw error;
              }
              if (!recovered.changed) {
                error.contextPressureExhausted = true;
                error.compactionError = recovered.reason || 'irreducible_context';
                throw error;
              }
              messages = recovered.messages;
              turnMessages = sanitizeConversationMessages([
                ...messages,
                ...contextView.messages,
              ]);
              overflowRetried = true;
              this.eventBus.publish({
                runId,
                userId,
                agentId,
                eventType: EVENT_TYPES.CONTEXT_OVERFLOW_RECOVERED,
                payload: {
                  recovery_count: contextPressure.overflowRecoveries,
                  before_tokens: recovered.beforeTokens,
                  after_tokens: recovered.afterTokens,
                },
                visibility: VISIBILITY.OPERATOR,
              });
            }
          }
          recordModelSuccess(userId, agentId, modelSelectionId);
        } catch (error) {
          if (isAbortError(error, getActiveSignal())) {
            if (this.engine.getRunMeta(runId)?.aborted) {
              return this.#cancelledResult(runId, totalTokens, iterations);
            }
            const boundary = await this.engine.checkpointLifecycle?.(runId, 'model_boundary', {
              iteration: iterations,
            });
            if (boundary?.action === 'stop' || boundary?.action === 'interrupt') {
              return this.#cancelledResult(runId, totalTokens, iterations);
            }
            // Pause completed and run resumed — retry the model turn.
            continue;
          }
          if (error.contextPressureExhausted === true) {
            budget.recordToolFailure(true, 'context_overflow');
            this.eventBus.publish({
              runId,
              userId,
              agentId,
              eventType: EVENT_TYPES.CONTEXT_OVERFLOW_EXHAUSTED,
              payload: {
                recovery_count: contextPressure.overflowRecoveries,
                reason: error.compactionError || error.message,
              },
              visibility: VISIBILITY.OPERATOR,
            });
            finalContent = await this.#partialDeliveryText({
              runId,
              contract,
              workingMemory,
              reason: 'context_overflow',
              provider,
              providerName,
              model,
              messages,
              options,
              signal: getActiveSignal(),
              userId,
              agentId,
            });
            applyTransition({
              runId,
              toState: RUNTIME_STATES.DELIVERING,
              reason: 'context_overflow_exhausted',
              workerId,
              eventBus: this.eventBus,
            });
            continue;
          }
          const recovery = planRecovery(error, {
            attemptsForClass: budget.usage.failuresByClass[classifyError(error)] || 0,
          });
          budget.recordToolFailure(true, recovery.errorClass);
          recordModelFailure(userId, agentId, modelSelectionId, error);

          if (recovery.retryable && recovery.action === 'switch_provider_or_backoff') {
            const fallbackId = await getFailureFallbackModelId(
              userId,
              agentId,
              modelSelectionId,
              aiSettings.fallback_model_id,
              error,
              getActiveSignal(),
              [modelSelectionId],
            );
            if (fallbackId) {
              const fallback = await getProviderForUser(
                userId,
                userMessage,
                triggerType === 'subagent',
                fallbackId,
                { ...providerStatusConfig, signal: getActiveSignal() },
              );
              provider = fallback.provider;
              model = fallback.model;
              modelSelectionId = fallback.modelSelectionId;
              providerName = fallback.providerName;
              db.prepare('UPDATE agent_runs SET model = ?, updated_at = datetime(\'now\') WHERE id = ?')
                .run(modelSelectionId, runId);
              continue;
            }
          }
          throw error;
        }

        const modelResponse = modelTurn?.response || {};
        const tokenParts = usageTokens(modelResponse.usage);
        totalTokens += tokenParts.total || (tokenParts.input + tokenParts.output);
        budget.recordModelTurn({
          inputTokens: tokenParts.input,
          outputTokens: tokenParts.output,
        });
        progressBroker.noteActivity('model_completed', { iteration: iterations });

        let decisionResult = decisionFromModelResponse({
          content: modelResponse.content || modelTurn?.streamContent || '',
          tool_calls: modelResponse.toolCalls || modelResponse.tool_calls || [],
          toolCalls: modelResponse.toolCalls || modelResponse.tool_calls || [],
        }, {
          nodeId: activeNode?.id || null,
          // Like DeepSeek's loop, a normal assistant response without tool calls
          // ends the turn. The completion gate still checks durable obligations.
          expectTerminalResponse: true,
        });
        if (!decisionResult.ok) {
          consecutiveProtocolRepairs += 1;
          decisionResult = protocolRepairDecision(decisionResult.error, modelResponse);
          if (consecutiveProtocolRepairs > maxProtocolRepairs) {
            messages.push({
              role: 'system',
              content: 'Repeated invalid model protocol. Provide a final partial answer with evidence only.',
            });
            finalContent = await this.#partialDeliveryText({
              runId,
              contract,
              workingMemory,
              reason: 'model_protocol_error',
              provider,
              providerName,
              model,
              messages,
              options,
              signal: getActiveSignal(),
              userId,
              agentId,
            });
            applyTransition({
              runId,
              toState: RUNTIME_STATES.DELIVERING,
              reason: 'protocol_repair_exhausted',
              workerId,
              eventBus: this.eventBus,
            });
            continue;
          }
          messages.push({
            role: 'system',
            content: decisionResult.decision.repairHint,
          });
          continue;
        }
        consecutiveProtocolRepairs = 0;
        const decision = decisionResult.decision;
        workingMemory.addDecision(decision);
        this.eventBus.publish({
          runId,
          userId,
          agentId,
          eventType: EVENT_TYPES.DECISION_PERSISTED,
          payload: { kind: decision.kind, nodeId: decision.nodeId },
          visibility: VISIBILITY.INTERNAL,
        });

        if (decision.kind === DECISION_KINDS.RESPOND) {
          const content = sanitizeModelOutput(decision.content, { model });
          if (content) {
            finalContent = content;
            workingMemory.setDraftResponse(content);
            messages.push({ role: 'assistant', content });
          }
          // Text is not auto-complete unless obligations are satisfied, no work
          // nodes remain, or no tools are available to act further.
          const canOnlyRespond = !tools.length
            || decision.terminal === true
            || options.skipVerifier === true;
          if (obligations.satisfied || openNodes.length === 0 || canOnlyRespond) {
            // Mark remaining ready nodes complete when the model can only respond.
            if (canOnlyRespond && openNodes.length > 0) {
              for (const node of openNodes) {
                workGraph.completeNode(node.id, {
                  evidence: [{ summary: 'Completed via final response', kind: 'response' }],
                });
              }
            }
            applyTransition({
              runId,
              toState: RUNTIME_STATES.VERIFYING,
              reason: canOnlyRespond
                ? 'respond_without_further_tools'
                : 'respond_with_satisfied_obligations',
              workerId,
              eventBus: this.eventBus,
            });
          } else {
            messages.push({
              role: 'system',
              content: [
                'A draft response was produced but required obligations remain open.',
                `Open: ${obligations.open.map((o) => o.id || o.type).join(', ')}`,
                'Continue working or call tools. Do not treat the draft as final yet.',
              ].join('\n'),
            });
          }
          continue;
        }

        if (decision.kind === DECISION_KINDS.COMPLETE) {
          finalContent = sanitizeModelOutput(
            decision.completionClaim?.summary || decision.content || finalContent,
            { model },
          );
          workingMemory.setDraftResponse(finalContent);
          messages.push({ role: 'assistant', content: finalContent });
          // A completion claim asserts remaining required work is done; mark
          // non-verification nodes complete so the gate can evaluate evidence.
          for (const node of workGraph.requiredOpenNodes(runId)) {
            if (node.kind === 'verification') continue;
            workGraph.completeNode(node.id, {
              evidence: [{
                summary: finalContent.slice(0, 300) || 'Completed via task_complete claim',
                kind: 'completion_claim',
              }],
            });
          }
          applyTransition({
            runId,
            toState: RUNTIME_STATES.VERIFYING,
            reason: 'completion_claim',
            workerId,
            eventBus: this.eventBus,
          });
          continue;
        }

        if (decision.kind === DECISION_KINDS.BLOCK) {
          // A blank turn is a provider hiccup, not a blocker. Terminating on it
          // would end healthy runs on one empty Gemini/OpenAI response, so it is
          // recovered like any other protocol fault: nudge, then switch model.
          if (decision.blocker?.code === 'blank_model_output') {
            blankOutputRecoveries += 1;
            if (blankOutputRecoveries <= maxBlankOutputRecoveries) {
              const fallbackId = await getFailureFallbackModelId(
                userId,
                agentId,
                modelSelectionId,
                aiSettings.fallback_model_id,
                new Error('Model returned no content and no tool calls'),
                getActiveSignal(),
                [modelSelectionId],
              );
              if (fallbackId) {
                const fallback = await getProviderForUser(
                  userId,
                  userMessage,
                  triggerType === 'subagent',
                  fallbackId,
                  { ...providerStatusConfig, signal: getActiveSignal() },
                );
                provider = fallback.provider;
                model = fallback.model;
                modelSelectionId = fallback.modelSelectionId;
                providerName = fallback.providerName;
                db.prepare('UPDATE agent_runs SET model = ?, updated_at = datetime(\'now\') WHERE id = ?')
                  .run(modelSelectionId, runId);
              }
              messages.push({
                role: 'system',
                content: buildBlankOutputGuidance(toolExecutions),
              });
              continue;
            }
          }
          applyTransition({
            runId,
            toState: RUNTIME_STATES.BLOCKED,
            reason: decision.blocker?.code || 'blocked',
            workerId,
            eventBus: this.eventBus,
            patch: { error: decision.blocker?.message || 'Blocked' },
          });
          continue;
        }

        if (decision.kind === DECISION_KINDS.ACT) {
          // Continuation intent without tools ("I'll do X") is not completion
          // and must not spin forever without a real action.
          if (!decision.toolCalls.length) {
            if (decision.content) {
              messages.push({
                role: 'assistant',
                content: sanitizeModelOutput(decision.content, { model }),
              });
            }
            messages.push({
              role: 'system',
              content: [
                decision.protocolNote
                  ? `Protocol note: ${decision.protocolNote}.`
                  : 'An act decision was produced without tool calls.',
                'Call the concrete tools needed next, or provide a final answer only if all required work is already evidenced.',
                'Do not claim future work as completed.',
              ].join(' '),
            });
            continue;
          }

          // Always store OpenAI wire-format tool_calls so every provider can
          // convert history on subsequent turns (never rely on raw alone).
          const wireToolCalls = decision.toolCalls.map((call) => (
            call.raw?.function?.name
              ? call.raw
              : {
                id: call.id,
                type: 'function',
                function: {
                  name: call.name,
                  arguments: JSON.stringify(call.arguments || {}),
                },
              }
          ));
          messages.push({
            role: 'assistant',
            content: decision.content
              ? sanitizeModelOutput(decision.content, { model })
              : '',
            tool_calls: wireToolCalls,
          });

          // Classify once. Read-only calls may overlap only while they are
          // contiguous in model order; a mutation is a barrier. Moving every
          // read ahead of every mutation changes the program the model asked
          // us to execute (for example read -> edit -> verify-read).
          const plannedCalls = decision.toolCalls.map((call) => {
            const definition = tools.find((tool) => tool?.name === call.name) || null;
            const callShape = call.raw?.function?.name
              ? call.raw
              : {
                id: call.id,
                type: 'function',
                function: {
                  name: call.name,
                  arguments: JSON.stringify(call.arguments || {}),
                },
              };
            return {
              call,
              definition,
              isReadOnly: Boolean(this.engine.isReadOnlyToolCall?.(callShape, definition)),
            };
          });
          const turnArtifactIds = [];

          const executeOne = async ({ call, definition, isReadOnly }) => {
            const stepId = randomUUID();
            const started = Date.now();
            stepIndex += 1;
            const currentStepIndex = stepIndex;
            const stepType = this.engine.getStepType?.(call.name) || 'tool';
            db.prepare(
              `INSERT INTO agent_steps (
                id, run_id, step_index, type, description, status, tool_name, tool_input, started_at
              ) VALUES (?, ?, ?, ?, ?, 'running', ?, ?, datetime('now'))`,
            ).run(
              stepId,
              runId,
              currentStepIndex,
              stepType,
              `${call.name}: ${JSON.stringify(call.arguments || {}).slice(0, 200)}`,
              call.name,
              JSON.stringify(call.arguments || {}),
            );
            this.eventBus.publish({
              runId,
              userId,
              agentId,
              eventType: EVENT_TYPES.TOOL_STARTED,
              stepId,
              payload: { tool: call.name, node_id: activeNode?.id || null },
              visibility: VISIBILITY.OPERATOR,
            });
            this.engine.recordRunEvent?.(userId, runId, 'tool_started', {
              stepIndex: currentStepIndex,
              toolName: call.name,
              toolArgs: call.arguments || {},
              type: stepType,
            }, { agentId, stepId });
            this.engine.emit(userId, 'run:tool_start', {
              runId,
              stepId,
              stepIndex: currentStepIndex,
              toolName: call.name,
              toolArgs: call.arguments || {},
              type: stepType,
            });
            progressBroker.noteToolStarted(call.name);

            let result;
            let success = true;
            let errorMessage = null;
            const repetitionGuard = this.engine.getRunMeta(runId)?.repetitionGuard;
            try {
              if (
                interactionMode === 'plan'
                && !isReadOnly
                && !PLAN_MODE_SAFE_CONTROL_TOOLS.has(call.name)
              ) {
                success = false;
                errorMessage = 'Plan mode blocks tools that can mutate state.';
                result = {
                  error: errorMessage,
                  blocked: true,
                  blockedBy: 'cowork_plan_mode',
                };
              } else {
                const hookResult = await globalHooks.run('before_tool_call', {
                  runId,
                  toolName: call.name,
                  args: call.arguments,
                  userId,
                  agentId,
                });
                if (hookResult?.block === true) {
                  success = false;
                  errorMessage = hookResult.reason || 'Blocked by policy hook';
                  result = { error: errorMessage, blocked: true };
                } else if (isReadOnly && repetitionGuard?.shouldBlock(call.name, call.arguments)) {
                  success = false;
                  errorMessage = 'The same read-only call already returned an unchanged result twice.';
                  result = { status: 'blocked', reason: errorMessage };
                } else {
                  // Flatten run options the same way the legacy loop did so
                  // background staging, messaging origin, and delivery bookkeeping work.
                  result = await this.engine.executeTool(call.name, call.arguments, {
                    userId,
                    agentId,
                    runId,
                    stepId,
                    app,
                    triggerType,
                    triggerSource,
                    conversationId,
                    deviceTarget,
                    workspaceRoot,
                    interactionMode,
                    source: options.source || null,
                    chatId: options.chatId || null,
                    taskId: options.taskId || null,
                    deliveryState: options.deliveryState || this.engine.getRunMeta(runId)?.deliveryState || null,
                    stageProactiveMessages: options.stageProactiveMessages === true,
                    allowMultipleProactiveMessages: options.allowMultipleProactiveMessages === true
                      || options.allow_multiple_messages === true,
                    allowExternalSideEffects: options.allowExternalSideEffects === true,
                    signal: getActiveSignal(),
                  });
                }
              }
            } catch (error) {
              success = false;
              errorMessage = error?.message || String(error);
              result = { error: errorMessage };
              const recovery = planRecovery(error);
              budget.recordToolFailure(true, recovery.errorClass);
              if (recovery.response?.blindRetryForbidden) {
                workingMemory.addSideEffect({
                  id: stepId,
                  tool_name: call.name,
                  status: 'unknown',
                });
              }
            }

            const elapsed = Date.now() - started;
            budget.recordToolRuntime(elapsed);

            const execution = classifyToolExecution(
              call.name,
              call.arguments || {},
              result,
              errorMessage,
              definition,
            );
            const observed = repetitionGuard?.observe(call.name, call.arguments, result);
            // "No progress" means the turn changed no state and surfaced no new
            // evidence. Reads that pull in new information are progress, so a long
            // research run is never mistaken for churn.
            budget.recordNoProgressTurn(
              !execution.stateChanged && !gatheredNewEvidence(execution, observed),
            );
            if (success) budget.recordToolFailure(false);

            // Signature: compactToolResult(toolName, toolArgs, toolResult, options)
            const compacted = compactToolResult(
              call.name,
              call.arguments || {},
              result,
              resolveToolResultLimits(call.name, budget.loopPolicy),
            );
            const commandArtifact = result?.outputArtifact;
            if (commandArtifact?.artifactId) {
              turnArtifactIds.push(commandArtifact.artifactId);
              workingMemory.addArtifact({
                ...commandArtifact,
                kind: 'command-output',
                stepId,
                runId,
              });
              this.eventBus.publish({
                runId,
                userId,
                agentId,
                eventType: EVENT_TYPES.ARTIFACT_CREATED,
                stepId,
                payload: {
                  artifact_id: commandArtifact.artifactId,
                  kind: 'command-output',
                  byte_size: commandArtifact.byteSize,
                  complete: commandArtifact.complete !== false,
                },
                visibility: VISIBILITY.OPERATOR,
              });
            }
            evidencePacket = appendToolEvidence(evidencePacket, call.name, compacted, { success });
            workingMemory.addEvidence({
              id: stepId,
              tool: call.name,
              summary: execution.summary,
              success,
              artifactIds: commandArtifact?.artifactId ? [commandArtifact.artifactId] : [],
            });
            if (execution.stateChanged) {
              budget.recordSideEffect(1);
              workingMemory.addSideEffect({
                id: stepId,
                tool_name: call.name,
                status: success ? 'confirmed' : 'failed',
              });
            }

            db.prepare(
              `UPDATE agent_steps
               SET status = ?, result = ?, error = ?, screenshot_path = ?, completed_at = datetime('now')
               WHERE id = ?`,
            ).run(
              success ? 'completed' : 'failed',
              JSON.stringify(call.name === 'execute_command' ? compacted : (result ?? null)).slice(0, 20000),
              errorMessage,
              result?.screenshotPath || null,
              stepId,
            );
            this.eventBus.publish({
              runId,
              userId,
              agentId,
              eventType: success ? EVENT_TYPES.TOOL_COMPLETED : EVENT_TYPES.TOOL_FAILED,
              stepId,
              payload: {
                tool: call.name,
                success,
                error: errorMessage,
                elapsed_ms: elapsed,
              },
              visibility: VISIBILITY.OPERATOR,
            });
            this.engine.recordRunEvent?.(userId, runId, success ? 'tool_completed' : 'tool_failed', {
              toolName: call.name,
              status: success ? 'completed' : 'failed',
              durationMs: elapsed,
              error: errorMessage,
              resultPreview: summarizeForLog(compacted),
            }, { agentId, stepId });
            this.engine.emit(userId, 'run:tool_end', {
              runId,
              stepId,
              toolName: call.name,
              result: compacted,
              status: success ? 'completed' : 'failed',
              error: errorMessage,
            });
            progressBroker.noteToolFinished(call.name);

            const toolMessage = {
              role: 'tool',
              name: call.name,
              tool_call_id: call.id,
              content: typeof compacted === 'string' ? compacted : JSON.stringify(compacted),
            };

            // Newly activated schemas only reach the model if the active set is
            // re-read; otherwise activate_tools silently does nothing.
            if (call.name === 'activate_tools' && success) {
              const activeTools = this.engine.getActiveTools?.(runId);
              if (Array.isArray(activeTools) && activeTools.length) tools = activeTools;
            }

            // task_complete / send_message special handling
            if (call.name === 'task_complete' && success) {
              finalContent = String(
                call.arguments?.message
                || call.arguments?.summary
                || call.arguments?.result
                || result?.message
                || finalContent
                || '',
              ).trim();
              workingMemory.setDraftResponse(finalContent);
            }
            if (call.name === 'send_message' && success) {
              // Tool schema uses `content`; models also emit message/text aliases.
              // Staged proactive replies return content on the tool result.
              const sent = String(
                call.arguments?.content
                || call.arguments?.message
                || call.arguments?.text
                || result?.content
                || '',
              ).trim();
              const noResponse = sent === '[NO RESPONSE]'
                || result?.reason === 'no_response'
                || call.arguments?.purpose === 'no_response';
              if (noResponse) {
                const runMeta = this.engine.getRunMeta(runId);
                if (runMeta) runMeta.noResponse = true;
                if (runMeta?.deliveryState) runMeta.deliveryState.noResponse = true;
              } else if (sent) {
                // Visible interim/final channel messages still require outbox final authority.
                // Treat tool-sent messages as interim unless completion gate accepts.
                finalContent = sent;
                workingMemory.setDraftResponse(sent);
                const runMeta = this.engine.getRunMeta(runId);
                if (runMeta) {
                  runMeta.lastSentMessage = sent;
                  runMeta.messagingSent = true;
                  if (!Array.isArray(runMeta.sentMessages)) runMeta.sentMessages = [];
                  runMeta.sentMessages.push(sent);
                  // Staged schedule messages count as proactive progress for the task runtime.
                  if (result?.staged === true) {
                    runMeta.proactiveMessageStaged = true;
                    runMeta.stagedProactiveMessage = runMeta.deliveryState?.stagedProactiveMessage
                      || {
                        platform: call.arguments?.platform,
                        to: call.arguments?.to,
                        content: sent,
                        purpose: call.arguments?.purpose,
                      };
                  }
                }
              }
            }

            return { success, result: compacted, errorMessage, execution, toolMessage };
          };

          await scheduleToolCalls(plannedCalls, {
            isParallelSafe: (planned) => planned.isReadOnly,
            execute: executeOne,
            maxParallel: options.maxParallelToolCalls,
            commit: async (outcome) => {
              toolExecutions.push(outcome.execution);
              messages.push(outcome.toolMessage);
            },
          });

          const inputRequest = this.engine.getRunMeta(runId)?.awaitingInput;
          if (inputRequest) {
            applyTransition({
              runId,
              toState: RUNTIME_STATES.WAITING,
              reason: 'structured_input_required',
              workerId,
              eventBus: this.eventBus,
              patch: {
                metadata: { awaitingInputRequestId: inputRequest.id },
              },
            });
            db.prepare(
              `UPDATE agent_runs
               SET status = 'waiting_input', updated_at = datetime('now')
               WHERE id = ?`,
            ).run(runId);
            return {
              runId,
              content: '',
              totalTokens,
              iterations,
              status: 'waiting_input',
              inputRequest,
              path,
            };
          }

          // Mark active node progress
          if (activeNode) {
            const nodeEvidence = workingMemory.snapshot().evidence.slice(-5);
            const nodeArtifactIds = [...new Set([
              ...(activeNode.artifactIds || []),
              ...turnArtifactIds,
            ])];
            workGraph.updateNode(activeNode.id, {
              status: 'ready',
              evidence: nodeEvidence,
              artifactIds: nodeArtifactIds,
            });
            // Complete simple nodes when tools succeeded and no defects
            if (budget.usage.consecutiveToolFailures === 0 && nodeEvidence.some((e) => e.success !== false)) {
              workGraph.completeNode(activeNode.id, {
                evidence: nodeEvidence,
                artifactIds: nodeArtifactIds,
              });
              this.eventBus.publish({
                runId,
                userId,
                agentId,
                eventType: EVENT_TYPES.NODE_COMPLETED,
                payload: { node_id: activeNode.id, node_key: activeNode.nodeKey },
                visibility: VISIBILITY.OPERATOR,
              });
            }
          }

          await progressBroker.maybePublish({
            delta: this.#collectProgressDelta(runId, toolExecutions),
          });

          // If model included terminal complete with tools, check next loop.
          if (decision.terminalHint) {
            // Ensure execute-class nodes are closed when a terminal send/complete
            // decision was already produced with successful tools.
            if (String(finalContent || '').trim() || decision.toolCalls.some((c) => c.name === 'task_complete')) {
              for (const node of workGraph.requiredOpenNodes(runId)) {
                if (node.kind === 'verification') continue;
                workGraph.completeNode(node.id, {
                  evidence: [{
                    summary: String(finalContent || 'Terminal tool decision').slice(0, 300),
                    kind: 'terminal_hint',
                  }],
                });
              }
            }
            applyTransition({
              runId,
              toState: RUNTIME_STATES.VERIFYING,
              reason: 'terminal_hint_after_tools',
              workerId,
              eventBus: this.eventBus,
            });
          }
          continue;
        }

        // Unknown decision kinds are rejected by validator; defensive continue.
        messages.push({
          role: 'system',
          content: `Unsupported decision kind ${decision.kind}. Continue with a valid action.`,
        });
      }

      // Fallback exit
      if (!finalContent) {
        finalContent = await this.#partialDeliveryText({
          runId,
          contract,
          workingMemory,
          reason: 'run_exited_without_final',
          provider,
          providerName,
          model,
          messages,
          options,
          signal: getActiveSignal(),
          userId,
          agentId,
        });
      }
      const delivery = await this.#deliverFinal({
        runId,
        userId,
        agentId,
        workerId,
        content: finalContent,
        options,
        triggerSource,
        totalTokens,
      });
      await this.#finalizeSuccess({
        runId,
        userId,
        agentId,
        conversationId,
        content: delivery.content || finalContent,
        totalTokens,
        iterations,
        memoryManager: this.engine.memoryManager,
        messages,
        task: userMessage,
        taskId: options.taskId || null,
        triggerType,
        triggerSource,
      });
      return {
        runId,
        content: delivery.content || finalContent,
        totalTokens,
        iterations,
        status: 'completed',
        path,
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
            totalTokens,
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
        return { runId, content: '', totalTokens, iterations, status };
      }
      throw error;
    } finally {
      progressBroker?.stop();
      try {
        leases.release(runId, workerId);
      } catch {
        // ignore
      }
      this.engine.activeRuns.delete(runId);
      detachExternalAbort?.();
      releaseReservation();
    }
  }

  async #deliverFinal({
    runId,
    userId,
    agentId,
    workerId,
    content,
    options,
    triggerSource,
    totalTokens,
    asError = false,
  }) {
    const channel = resolveDeliveryChannel(triggerSource);
    const recipient = resolveDeliveryRecipient(triggerSource, options);
    const result = await requestFinalDelivery({
      engine: this.engine,
      runId,
      content,
      channel,
      recipient,
      workerId,
      eventBus: this.eventBus,
      metadata: {
        platform: options.source || null,
        chatId: options.chatId || null,
        ...(options.sessionBinding || {}),
        totalTokens,
        asError,
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
          totalTokens,
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
          patch: {
            finalResponse: content,
            totalTokens,
          },
        });
        // The delivery worker normally emits this; it did not get that far, and
        // the client still needs exactly one run:complete to close the run out.
        this.engine.emit(userId, 'run:complete', { runId, content, totalTokens });
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
          totalTokens,
        },
      });
    }
    return result;
  }

  async #finalizeSuccess({
    runId,
    userId,
    agentId,
    conversationId,
    content,
    totalTokens,
    iterations,
    memoryManager,
    messages,
    task,
    taskId,
    triggerType,
    triggerSource,
  }) {
    if (conversationId && content) {
      try {
        db.prepare(
          `INSERT INTO conversation_messages (
            conversation_id, run_id, agent_id, role, content, metadata_json
          ) VALUES (?, ?, ?, 'assistant', ?, ?)`,
        ).run(
          conversationId,
          runId,
          agentId,
          content,
          JSON.stringify({ final: true }),
        );
      } catch {
        // ignore
      }
    }

    db.prepare(
      `UPDATE agent_runs
       SET total_tokens = ?, final_response = COALESCE(final_response, ?), updated_at = datetime('now')
       WHERE id = ?`,
    ).run(totalTokens, content || null, runId);

    this.eventBus.publish({
      runId,
      userId,
      agentId,
      eventType: EVENT_TYPES.RUN_COMPLETED,
      payload: {
        totalTokens,
        iterations,
        contentPreview: String(content || '').slice(0, 240),
      },
      visibility: VISIBILITY.USER,
    });

    // No run:complete here: the delivery worker already emitted it as part of
    // committing the final message. Emitting again made clients see the same
    // answer arrive twice — harmless for a foreground chat that dedupes on the
    // previous bubble, but background runs consume the first event and then
    // render the second one into the chat they were never meant to touch.

    // Episodic memory candidate (not semantic fact dump of run state).
    if (memoryManager) {
      memoryWritePipeline.enqueueCandidate({
        userId,
        agentId,
        runId,
        writeClass: memoryWritePipeline.WRITE_CLASSES.EPISODIC,
        candidate: {
          content: `Run ${shortenRunId(runId)} completed: ${String(content || '').slice(0, 400)}`,
          category: 'episode',
          confidence: 0.6,
          source: 'runtime_episode',
        },
        eventBus: this.eventBus,
      });
      try {
        await memoryWritePipeline.flushQueue({
          memoryManager,
          userId,
          agentId,
          limit: 5,
          eventBus: this.eventBus,
        });
      } catch (error) {
        console.warn('[Runtime] Memory flush failed:', error?.message || error);
      }
    }

    console.info(
      `[Run ${shortenRunId(runId)}] completed kernel=v2 steps=${iterations} tokens=${totalTokens} finalResponse=${content ? 'yes' : 'no'}`,
    );

    this.engine.skillLearningService?.enqueueCompletedRun({
      userId,
      agentId,
      runId,
      triggerType,
      triggerSource,
      task,
      taskId,
      finalContent: content,
      iterations,
      messages,
    });
  }

  /**
   * Honest partial result for a run that cannot complete.
   *
   * The wording is the model's: it writes the wrap-up from the evidence already
   * in this conversation, in the user's language. Only when the model returns
   * nothing usable does the runtime fall back to a description derived from the
   * observed tool executions — never to a canned status message.
   */
  async #partialDeliveryText({
    runId,
    contract,
    workingMemory,
    reason,
    provider,
    providerName,
    model,
    messages,
    options,
    signal,
    userId,
    agentId,
  }) {
    const snap = workingMemory.snapshot();
    const open = evaluateOpenObligations(contract, {
      completedNodeKeys: workGraph.listNodes(runId)
        .filter((node) => node.status === 'completed')
        .map((node) => node.nodeKey),
      evidence: snap.evidence,
      artifacts: snap.artifacts,
      finalContent: snap.draftResponse,
    }).open;

    if (provider && model) {
      try {
        const wrapUp = await this.engine.requestModelResponse({
          provider,
          providerName,
          model,
          messages: sanitizeConversationMessages([
            ...(Array.isArray(messages) ? messages.slice(-24) : []),
            {
              role: 'system',
              content: [
                buildMaxIterationWrapupPrompt(options?.source || null),
                `Runtime stop reason: ${reason}.`,
                open.length
                  ? `Obligations still open: ${open.map((item) => item.id || item.type).join(', ')}.`
                  : 'No required obligation is recorded as open.',
              ].join('\n\n'),
            },
          ]),
          tools: [],
          options: {
            ...options,
            stream: false,
            signal,
            runId,
            userId,
            agentId,
          },
          runId,
          iteration: 0,
        });
        const text = sanitizeModelOutput(
          String(wrapUp?.response?.content || wrapUp?.streamContent || '').trim(),
          { model },
        );
        if (normalizeOutgoingMessage(text, options?.source || null)) return text;
      } catch (error) {
        console.warn('[Runtime] Partial wrap-up generation failed:', error?.message || error);
      }
    }

    if (snap.draftResponse) return snap.draftResponse;
    return buildDeterministicMessagingFallback({
      failedStepCount: (snap.evidence || []).filter((item) => item.success === false).length,
      stepIndex: (snap.evidence || []).length,
      toolExecutions: (snap.evidence || []).map((item) => ({
        toolName: item.tool,
        summary: item.summary,
      })),
    });
  }

  /**
   * Deterministic view of what actually changed. The narrator may only phrase
   * these facts, so a progress update can never claim work the runtime did not
   * observe.
   */
  #collectProgressDelta(runId, toolExecutions = []) {
    const nodes = workGraph.listNodes(runId);
    return {
      completed_since_last_update: nodes
        .filter((node) => node.status === 'completed')
        .map((node) => node.nodeKey)
        .slice(-5),
      currently_running: nodes
        .filter((node) => node.status === 'running' || node.status === 'ready')
        .map((node) => node.nodeKey)
        .slice(0, 5),
      new_artifacts: [],
      blockers: nodes.flatMap((node) => node.blockers || []).slice(0, 5),
      plan_changes: [],
      next_milestone: workGraph.nextActionableNodes(runId)[0]?.objective || null,
      evidence: summarizeProgressToolExecutions(toolExecutions, 5),
    };
  }

  /**
   * Phrase an observed progress delta. The run's own system prompt supplies the
   * voice and formatting rules, so an update reads like every other message; the
   * delta is the only permitted source of facts, and an empty answer means "no
   * useful update", not "send something generic".
   */
  async #narrateProgress({
    provider,
    providerName,
    model,
    systemPrompt,
    delta,
    liveness,
    userMessage,
    options,
    runId,
    userId,
    agentId,
    signal,
  }) {
    if (!provider || !model) return '';
    const stable = systemPrompt && typeof systemPrompt === 'object'
      ? [systemPrompt.stable, systemPrompt.dynamic].filter(Boolean).join('\n\n')
      : String(systemPrompt || '');
    const response = await this.engine.requestModelResponse({
      provider,
      providerName,
      model,
      messages: [
        ...(stable ? [{ role: 'system', content: stable }] : []),
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
            `Original request: ${String(userMessage || '').slice(0, 320)}`,
            delta?.evidence
              ? `Actual recent tool activity (newest last) — describe ONLY this:\n${delta.evidence}`
              : '',
            delta?.currently_running?.length ? `Working on: ${delta.currently_running.join(', ')}` : '',
            delta?.next_milestone ? `Next milestone: ${delta.next_milestone}` : '',
          ].filter(Boolean).join('\n\n'),
        },
      ],
      tools: [],
      options: {
        ...options,
        stream: false,
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
      { model },
    );
    if (!normalizeOutgoingMessage(text, options?.source || null)) return '';
    return text.split(/\n+/).map((line) => line.trim()).filter(Boolean).join(' ').slice(0, 400);
  }

  async #semanticVerify({
    provider,
    providerName,
    model,
    messages,
    tools,
    analysis,
    finalContent,
    options,
  }) {
    const toolExecutionSummary = messages
      .filter((m) => m.role === 'tool')
      .slice(-12)
      .map((m) => String(m.content || '').slice(0, 300))
      .join('\n');
    const prompt = buildVerifierPrompt({
      analysis,
      tools,
      toolExecutionSummary,
      finalReply: finalContent,
    });
    const response = await this.engine.requestStructuredJson({
      provider,
      providerName,
      model,
      messages: sanitizeConversationMessages(messages.slice(-20)),
      prompt,
      maxTokens: 1400,
      normalize: (value) => normalizeVerificationResult(value, finalContent),
      fallback: {
        status: 'verified',
        final_reply: finalContent,
        safe_to_deliver: true,
      },
      telemetry: {
        runId: options.runId,
        userId: options.userId,
        agentId: options.agentId,
        signal: options.signal,
      },
      phase: 'verification',
    });
    const parsed = response.value || normalizeVerificationResult({}, finalContent);
    if (parsed.status === 'verified' || parsed.safe_to_deliver === true) {
      return {
        status: 'verified',
        final_reply: parsed.final_reply || finalContent,
      };
    }
    return {
      status: 'needs_revision',
      reason: parsed.notes || parsed.reason || 'Semantic verifier rejected reply',
      final_reply: parsed.final_reply || finalContent,
      reopen_nodes: ['execute', 'verify'],
      defects: (parsed.missing_evidence || []).map((item) => ({
        severity: 'major',
        criterion: String(item),
        evidence: 'Missing evidence flagged by verifier',
        suggested_next_actions: ['collect missing evidence', 'rewrite unsupported claims'],
      })),
    };
  }

  #cancelledResult(runId, totalTokens, iterations) {
    const run = stateMachine.loadRun(runId);
    if (run && !stateMachine.isTerminal(run)) {
      applyTransition({
        runId,
        toState: RUNTIME_STATES.CANCELLED,
        reason: 'cancelled',
        eventBus: this.eventBus,
        patch: { totalTokens },
      });
    }
    return {
      runId,
      content: '',
      totalTokens,
      iterations,
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
