'use strict';

const { randomUUID } = require('crypto');
const db = require('../../../db/database');
const { compact } = require('../compaction');
const {
  getConversationContext,
  buildSummaryCarrier,
  sanitizeConversationMessages,
} = require('../history');
const { ensureDefaultAiSettings, getAiSettings } = require('../settings');
const {
  selectInitialTools,
  selectToolsForTask,
} = require('../toolSelector');
const { compactToolResult } = require('../toolResult');
const { sanitizeModelOutput } = require('../outputSanitizer');
const {
  buildAnalysisPrompt,
  buildExecutionGuidance,
  isDirectAnswerEligibleAnalysis,
  normalizeTaskAnalysis,
  shouldRunVerifier,
  buildVerifierPrompt,
  normalizeVerificationResult,
} = require('../taskAnalysis');
const { getCapabilityHealth, summarizeCapabilityHealth } = require('../capabilityHealth');
const { enforceRateLimits } = require('../rate_limits');
const { ToolRepetitionGuard } = require('../repetitionGuard');
const { shortenRunId } = require('../logFormat');
const {
  recordModelFailure,
  recordModelSuccess,
} = require('../model_failure_cache');
const { getProviderForUser } = require('../provider_selector');
const { normalizeOutgoingMessage } = require('../messagingFallback');
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
  evaluateFastPathEligibility,
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
const { buildContextView } = require('./context/context_view_builder');
const {
  buildEvidencePacket,
  appendToolEvidence,
} = require('./context/evidence_packet_builder');
const { createWorkingMemory } = require('./memory/working_memory');
const memoryWritePipeline = require('./memory/memory_write_pipeline');
const { getFailureFallbackModelId } = require('./model_fallback');

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
    const app = options.app || this.engine.app;
    const triggerSource = options.triggerSource || 'web';
    const workerId = `worker_${randomUUID()}`;
    const runTitle = generateTitle(userMessage);
    let totalTokens = 0;
    let iterations = 0;
    let detachExternalAbort = null;
    let provider = null;
    let model = null;
    let modelSelectionId = null;
    let providerName = null;
    let messages = [];
    let tools = [];
    let analysis = null;
    let contract = null;
    let finalContent = '';
    let path = 'durable';
    const workingMemory = createWorkingMemory();
    let evidencePacket = buildEvidencePacket({ queryIntent: 'current_task' });
    const startedAtMs = Date.now();
    let budget = null;
    let progressBroker = null;
    let runRecordCreated = false;

    const { releaseReservation } = enforceRateLimits(userId, {
      bypass: options.bypassUserRateLimits === true,
    });

    try {
      // ── Accept immediately ─────────────────────────────────────────────
      try {
        db.prepare(
          `INSERT INTO agent_runs(
            id, user_id, agent_id, title, status, runtime_state, version,
            trigger_type, trigger_source, model, metadata_json
          ) VALUES(?, ?, ?, ?, 'running', ?, 0, ?, ?, ?, ?)`,
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
            runtimeKernel: 'v2',
          }),
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
        eventBus: this.eventBus,
        maxSilenceSeconds: Number(options.maxSilenceSeconds) || 90,
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
        title: runTitle,
        triggerType,
        triggerSource,
        runtimeKernel: 'v2',
      });

      // Immediate acknowledgement for durable user-facing surfaces.
      // Wording is model-authored (strategy stays model-controlled); the runtime
      // only decides whether an ack is required. Schedule/automation runs do not
      // get a silent hard-coded "Accepted. Working on..." spam message.
      const maybeAck = async (force = false) => {
        if (!force) return;
        // Background schedule/task automation delivers via send_message only.
        if (triggerSource === 'schedule' || triggerSource === 'tasks') return;
        if (triggerType === 'subagent') return;

        let ackText = '';
        try {
          const ackResponse = await this.engine.requestModelResponse({
            provider,
            providerName,
            model,
            messages: [
              {
                role: 'system',
                content: [
                  'Write a single short acknowledgement (1 sentence, max ~180 chars).',
                  'Confirm you accepted the request and will report concrete milestones or blockers.',
                  'Use only known facts from the user request. Do not invent progress or tools used.',
                  'No greeting fluff, no markdown, no tool calls.',
                ].join(' '),
              },
              {
                role: 'user',
                content: `User request to acknowledge:\n${String(userMessage || runTitle).slice(0, 1200)}`,
              },
            ],
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
        } catch (error) {
          console.warn('[Runtime] Ack generation failed; continuing without hard-coded text:', error?.message || error);
          ackText = '';
        }
        if (!ackText) return;

        await requestProgressDelivery({
          engine: this.engine,
          runId,
          content: ackText,
          channel: triggerSource === 'messaging' ? 'messaging' : 'web',
          recipient: options.chatId || null,
          messageKind: MESSAGE_KINDS.ACK,
          metadata: {
            platform: options.source || null,
            chatId: options.chatId || null,
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

      // ── Context assembly ───────────────────────────────────────────────
      const historyWindow = Math.max(
        1,
        Number(options.historyWindow || aiSettings.chat_history_window) || aiSettings.chat_history_window,
      );
      const systemPrompt = await this.engine.buildSystemPrompt(userId, {
        ...(options.context || {}),
        userMessage,
        agentId,
        triggerSource,
        memoryAudience: options.memoryAudience || 'owner',
      });

      const builtInTools = this.engine.getAvailableTools(app, {
        includeDescriptions: true,
        userId,
        agentId,
        triggerType,
        triggerSource,
        widgetId: options.widgetId || null,
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
      tools = selectInitialTools(allTools, [], {
        widgetId: options.widgetId || null,
        triggerSource,
        triggerType,
      });
      if (!tools.length) {
        tools = allTools.slice(0, 24);
      }
      this.engine.initializeToolRuntime?.(runId, allTools, tools, {
        widgetId: options.widgetId || null,
      });

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
      const capabilityHealth = await getCapabilityHealth({ userId, agentId, app, engine: this.engine });
      const capabilitySummary = summarizeCapabilityHealth(capabilityHealth);
      if (capabilitySummary) {
        messages.push({ role: 'system', content: `[Capability health]\n${capabilitySummary}` });
      }
      messages.push(this.engine.buildUserMessage(userMessage, options));
      messages = sanitizeConversationMessages(messages);

      if (conversationId) {
        db.prepare('INSERT INTO conversation_messages (conversation_id, role, content) VALUES (?, ?, ?)')
          .run(conversationId, 'user', String(userMessage || ''));
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

      if (options.skipTaskAnalysis === true && options.forceMode) {
        analysis = normalizeTaskAnalysis({
          mode: options.forceMode,
          goal: String(userMessage || '').slice(0, 300),
          draft_reply: '',
          draft_status: 'needs_execution',
          complexity: options.forceMode === 'plan_execute' ? 'complex' : 'standard',
        }, { goal: String(userMessage || '').slice(0, 300) });
      } else if (options.skipTaskAnalysis === true) {
        analysis = normalizeTaskAnalysis({
          mode: 'execute',
          goal: String(userMessage || '').slice(0, 300),
          draft_status: 'needs_execution',
        }, { goal: String(userMessage || '').slice(0, 300) });
      } else {
        try {
          const analysisPrompt = buildAnalysisPrompt({
            capabilityHealth: capabilitySummary,
            tools: allTools.slice(0, 40),
            forceMode: options.forceMode || null,
          });
          const analysisResponse = await this.engine.requestStructuredJson({
            provider,
            providerName,
            model,
            messages,
            prompt: analysisPrompt,
            maxTokens: 1400,
            normalize: (value, fallback) => normalizeTaskAnalysis(value, fallback),
            fallback: {
              mode: 'execute',
              goal: String(userMessage || '').slice(0, 300),
              draft_status: 'needs_execution',
            },
            telemetry: {
              runId,
              userId,
              agentId,
              signal: abortController.signal,
            },
            phase: 'task_analysis',
          });
          totalTokens += Number(analysisResponse.usage || 0);
          analysis = analysisResponse.value || normalizeTaskAnalysis({
            mode: 'execute',
            goal: String(userMessage || '').slice(0, 300),
          });
        } catch (error) {
          console.warn('[Runtime] Task analysis failed; defaulting to execute:', error?.message || error);
          analysis = normalizeTaskAnalysis({
            mode: 'execute',
            goal: String(userMessage || '').slice(0, 300),
            draft_status: 'needs_execution',
            complexity: 'standard',
          }, { goal: String(userMessage || '').slice(0, 300) });
        }
      }

      // Re-select tools using analysis hints once triage completes.
      {
        const suggested = Array.isArray(analysis?.suggested_tools) ? analysis.suggested_tools : [];
        const reselected = selectInitialTools(allTools, suggested, {
          widgetId: options.widgetId || null,
          triggerSource,
          triggerType,
        });
        if (reselected.length) {
          tools = reselected;
          this.engine.initializeToolRuntime?.(runId, allTools, tools, {
            widgetId: options.widgetId || null,
          });
        }
      }

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

      const draftReply = String(analysis.draft_reply || '').trim();
      const fastGate = evaluateFastPathEligibility(contract, {
        draftReply,
        analysis,
      });
      const directEligible = isDirectAnswerEligibleAnalysis(analysis)
        && Boolean(normalizeOutgoingMessage(draftReply));

      if (fastGate.eligible && directEligible) {
        path = 'fast';
        applyTransition({
          runId,
          toState: RUNTIME_STATES.RESPONDING,
          reason: 'no_execution_obligations',
          workerId,
          eventBus: this.eventBus,
        });
        finalContent = sanitizeModelOutput(draftReply, { model });
        messages.push({ role: 'assistant', content: finalContent });
        workingMemory.setDraftResponse(finalContent);
        iterations = 1;

        const gate = await verifyRun({
          runId,
          contract,
          claim: { summary: finalContent, confidence: contract.classification_confidence },
          finalContent,
          path: 'fast',
          eventBus: this.eventBus,
          userId,
          agentId,
        });

        if (gate.status === 'verified') {
          const delivery = await this.#deliverFinal({
            runId,
            userId,
            agentId,
            workerId,
            content: gate.final_reply || finalContent,
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
          });
          return {
            runId,
            content: delivery.content || finalContent,
            totalTokens,
            iterations,
            status: 'completed',
            path: 'fast',
          };
        }

        // Fast path rejected — fall through to durable execution.
        path = 'durable';
        applyTransition({
          runId,
          toState: RUNTIME_STATES.PLANNING,
          reason: 'fast_path_rejected',
          workerId,
          eventBus: this.eventBus,
        });
      } else {
        await maybeAck(triggerSource === 'messaging' || analysis.progress_update_policy === 'required');
        applyTransition({
          runId,
          toState: RUNTIME_STATES.PLANNING,
          reason: 'durable_work_required',
          workerId,
          eventBus: this.eventBus,
          patch: {
            metadata: { fastPathRejected: fastGate.reasons },
          },
        });
      }

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
        }),
      });

      applyTransition({
        runId,
        toState: RUNTIME_STATES.EXECUTING,
        reason: 'work_graph_ready',
        workerId,
        eventBus: this.eventBus,
      });

      // ── Execution loop ─────────────────────────────────────────────────
      let consecutiveProtocolRepairs = 0;
      const maxProtocolRepairs = 3;
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
            eventBus: this.eventBus,
            userId,
            agentId,
          });

          if (verification.status === 'repair_required') {
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
                'Do not claim completion until defects are resolved with evidence.',
              ].join('\n'),
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

          if (verification.status === 'blocked') {
            applyTransition({
              runId,
              toState: RUNTIME_STATES.BLOCKED,
              reason: 'verification_blocked',
              workerId,
              eventBus: this.eventBus,
              patch: { error: 'Verification blocked without safe repair path' },
            });
            finalContent = this.#partialDeliveryText({
              contract,
              workingMemory,
              reason: 'Verification could not be completed safely',
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
            finalContent = this.#partialDeliveryText({
              contract,
              workingMemory,
              reason: run.error || 'Run blocked',
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
          progressDelta: budget.usage.consecutiveReadOnly === 0,
        });
        if (!continuation.continue) {
          if (continuation.reason === 'hard_budget' || continuation.reason === 'no_progress_delta') {
            finalContent = this.#partialDeliveryText({
              contract,
              workingMemory,
              reason: continuation.reason,
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

        const contextView = buildContextView({
          runId,
          systemPrompt: '',
          messages,
          evidencePacket,
          activeNodeIds: activeNode ? [activeNode.id] : [],
          budgetSnapshot: budget.snapshot(),
        });
        // Keep user/tool history; prepend graph/contract system notes once per turn.
        const turnMessages = sanitizeConversationMessages([
          ...contextView.messages.filter((m) => m.role === 'system'),
          ...messages.filter((m) => m.role !== 'system' || /steering|follow-up|Repair|Verification|Budget/i.test(m.content || '')),
        ]);

        // Compaction invariant: persist working state first.
        if (turnMessages.length > 48) {
          saveCheckpoint(runId, 'pre_compaction', {
            workingMemory: workingMemory.snapshot(),
            contractVersion: contract.version,
            iterations,
            finalContent,
          }, { eventBus: this.eventBus, userId, agentId });
          try {
            // compact(messages, provider, model, contextWindow, options)
            const compacted = await compact(
              turnMessages,
              provider,
              model,
              null,
              { signal: getActiveSignal() },
            );
            if (Array.isArray(compacted) && compacted.length) {
              messages = compacted;
            }
          } catch {
            // Compaction failure is non-fatal.
          }
        }

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
          expectTerminalResponse: false,
        });
        if (!decisionResult.ok) {
          consecutiveProtocolRepairs += 1;
          decisionResult = protocolRepairDecision(decisionResult.error, modelResponse);
          if (consecutiveProtocolRepairs > maxProtocolRepairs) {
            messages.push({
              role: 'system',
              content: 'Repeated invalid model protocol. Provide a final partial answer with evidence only.',
            });
            finalContent = this.#partialDeliveryText({
              contract,
              workingMemory,
              reason: 'model_protocol_error',
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

        if (decision.kind === DECISION_KINDS.REQUEST_INPUT) {
          finalContent = decision.question || decision.content || 'Need additional input to continue.';
          applyTransition({
            runId,
            toState: RUNTIME_STATES.BLOCKED,
            reason: 'request_input',
            workerId,
            eventBus: this.eventBus,
          });
          continue;
        }

        if (decision.kind === DECISION_KINDS.WAIT) {
          applyTransition({
            runId,
            toState: RUNTIME_STATES.WAITING,
            reason: decision.reason || 'wait',
            workerId,
            eventBus: this.eventBus,
          });
          // Immediate return to executing for in-process waits; durable waits would park.
          applyTransition({
            runId,
            toState: RUNTIME_STATES.EXECUTING,
            reason: 'wait_elapsed',
            workerId,
            eventBus: this.eventBus,
          });
          continue;
        }

        if (decision.kind === DECISION_KINDS.CHECKPOINT) {
          saveCheckpoint(runId, decision.reason || 'model_checkpoint', {
            workingMemory: workingMemory.snapshot(),
            iterations,
            finalContent,
          }, { eventBus: this.eventBus, userId, agentId });
          continue;
        }

        if (decision.kind === DECISION_KINDS.REVISE_PLAN) {
          const revised = workGraph.graphFromContract({
            ...contract,
            ...(decision.patch || {}),
          });
          workGraph.createGraph(runId, revised, {
            eventBus: this.eventBus,
            userId,
            agentId,
          });
          continue;
        }

        if (decision.kind === DECISION_KINDS.VERIFY) {
          applyTransition({
            runId,
            toState: RUNTIME_STATES.VERIFYING,
            reason: 'model_requested_verify',
            workerId,
            eventBus: this.eventBus,
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

          const toolCalls = decision.toolCalls;
          const readOnlyCalls = [];
          const mutatingCalls = [];
          for (const call of toolCalls) {
            const def = tools.find((tool) => tool?.name === call.name) || null;
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
            if (this.engine.isReadOnlyToolCall?.(callShape, def)) {
              readOnlyCalls.push(call);
            } else {
              mutatingCalls.push(call);
            }
          }

          const executeOne = async (call) => {
            const stepId = randomUUID();
            const started = Date.now();
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
            this.eventBus.publish({
              runId,
              userId,
              agentId,
              eventType: EVENT_TYPES.TOOL_STARTED,
              stepId,
              payload: { tool: call.name, node_id: activeNode?.id || null },
              visibility: VISIBILITY.OPERATOR,
            });
            this.engine.emit(userId, 'run:tool_start', {
              runId,
              stepId,
              toolName: call.name,
            });

            let result;
            let success = true;
            let errorMessage = null;
            try {
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
              } else {
                // Flatten run options the same way the legacy loop did so
                // background staging, messaging origin, and delivery bookkeeping work.
                result = await this.engine.executeTool(call.name, call.arguments, {
                  userId,
                  agentId,
                  runId,
                  app,
                  triggerType,
                  triggerSource,
                  conversationId,
                  source: options.source || null,
                  chatId: options.chatId || null,
                  taskId: options.taskId || null,
                  widgetId: options.widgetId || null,
                  deliveryState: options.deliveryState || this.engine.getRunMeta(runId)?.deliveryState || null,
                  stageProactiveMessages: options.stageProactiveMessages === true,
                  allowMultipleProactiveMessages: options.allowMultipleProactiveMessages === true
                    || options.allow_multiple_messages === true,
                  allowExternalSideEffects: options.allowExternalSideEffects === true,
                  signal: getActiveSignal(),
                });
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
            const isReadOnly = this.engine.isReadOnlyToolCall?.(
              callShape,
              tools.find((tool) => tool?.name === call.name),
            );
            budget.recordReadOnly(Boolean(isReadOnly) && success);
            if (success) budget.recordToolFailure(false);

            // Signature: compactToolResult(toolName, toolArgs, toolResult, options)
            const compacted = compactToolResult(
              call.name,
              call.arguments || {},
              result,
              {},
            );
            evidencePacket = appendToolEvidence(evidencePacket, call.name, compacted, { success });
            workingMemory.addEvidence({
              id: stepId,
              tool: call.name,
              summary: typeof compacted === 'string' ? compacted.slice(0, 500) : JSON.stringify(compacted).slice(0, 500),
              success,
            });
            if (!isReadOnly) {
              budget.recordSideEffect(1);
              workingMemory.addSideEffect({
                id: stepId,
                tool_name: call.name,
                status: success ? 'confirmed' : 'failed',
              });
            }

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
            this.engine.emit(userId, 'run:tool_end', {
              runId,
              stepId,
              toolName: call.name,
              result: compacted,
              status: success ? 'completed' : 'failed',
              error: errorMessage,
            });

            messages.push({
              role: 'tool',
              name: call.name,
              tool_call_id: call.id,
              content: typeof compacted === 'string' ? compacted : JSON.stringify(compacted),
            });

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

            return { success, result: compacted, errorMessage };
          };

          // Parallel read-only, sequential mutating.
          if (readOnlyCalls.length > 1) {
            await Promise.all(readOnlyCalls.map((call) => executeOne(call)));
          } else if (readOnlyCalls.length === 1) {
            await executeOne(readOnlyCalls[0]);
          }
          for (const call of mutatingCalls) {
            await executeOne(call);
          }

          // Mark active node progress
          if (activeNode) {
            const nodeEvidence = workingMemory.snapshot().evidence.slice(-5);
            workGraph.updateNode(activeNode.id, {
              status: 'ready',
              evidence: nodeEvidence,
            });
            // Complete simple nodes when tools succeeded and no defects
            if (budget.usage.consecutiveToolFailures === 0 && nodeEvidence.some((e) => e.success !== false)) {
              workGraph.completeNode(activeNode.id, { evidence: nodeEvidence });
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
            delta: progressBroker.buildDelta({
              completed: workGraph.listNodes(runId)
                .filter((n) => n.status === 'completed')
                .map((n) => n.nodeKey)
                .slice(-5),
              running: workGraph.listNodes(runId)
                .filter((n) => n.status === 'running' || n.status === 'ready')
                .map((n) => n.nodeKey)
                .slice(0, 5),
              nextMilestone: workGraph.nextActionableNodes(runId)[0]?.objective || null,
            }),
            channel: triggerSource === 'messaging' ? 'messaging' : 'web',
            recipient: options.chatId || null,
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
        finalContent = this.#partialDeliveryText({
          contract,
          workingMemory,
          reason: 'run_exited_without_final',
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
        const interrupted = isAbortError(error) || runMeta?.aborted;
        applyTransition({
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
        this.eventBus.publish({
          runId,
          userId,
          agentId,
          eventType: interrupted ? EVENT_TYPES.RUN_CANCELLED : EVENT_TYPES.RUN_FAILED,
          payload: { error: error?.message || String(error) },
          visibility: VISIBILITY.USER,
        });
        this.engine.emit(userId, interrupted ? 'run:stopped' : 'run:error', {
          runId,
          error: error?.message || String(error),
        });
      }
      if (isAbortError(error)) {
        return { runId, content: '', totalTokens, iterations, status: 'stopped' };
      }
      throw error;
    } finally {
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
    const channel = triggerSource === 'messaging' ? 'messaging' : 'web';
    const result = await requestFinalDelivery({
      engine: this.engine,
      runId,
      content,
      channel,
      recipient: options.chatId || null,
      workerId,
      eventBus: this.eventBus,
      metadata: {
        platform: options.source || null,
        chatId: options.chatId || null,
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
  }) {
    if (conversationId && content) {
      try {
        db.prepare(
          'INSERT INTO conversation_messages (conversation_id, role, content) VALUES (?, ?, ?)',
        ).run(conversationId, 'assistant', content);
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

    this.engine.emit(userId, 'run:complete', {
      runId,
      content,
      totalTokens,
      iterations,
    });

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
  }

  #partialDeliveryText({ contract, workingMemory, reason }) {
    const snap = workingMemory.snapshot();
    const completedEvidence = (snap.evidence || []).filter((e) => e.success !== false).slice(-5);
    const open = evaluateOpenObligations(contract, {
      evidence: snap.evidence,
      artifacts: snap.artifacts,
      finalContent: snap.draftResponse,
    }).open;
    const lines = [
      snap.draftResponse || 'I could not fully complete the request.',
      '',
      `Status: partial (${reason})`,
      contract?.goal ? `Goal: ${contract.goal}` : null,
      completedEvidence.length
        ? `Evidence gathered:\n${completedEvidence.map((e) => `- ${e.tool || 'item'}: ${e.summary}`).join('\n')}`
        : 'Evidence gathered: none yet',
      open.length
        ? `Still open:\n${open.map((o) => `- ${o.id || o.type}`).join('\n')}`
        : null,
      'This is not a claim that the full task is done.',
    ].filter(Boolean);
    return lines.join('\n');
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
