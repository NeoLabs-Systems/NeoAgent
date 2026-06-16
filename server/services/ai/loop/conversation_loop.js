'use strict';

const { v4: uuidv4 } = require('uuid');
const fs = require('fs');
const db = require('../../../db/database');
const { compact } = require('../compaction');
const { compactPayloadForModel } = require('../preModelCompaction');
const {
  getConversationContext,
  buildSummaryCarrier,
  refreshConversationSummary,
  sanitizeConversationMessages
} = require('../history');
const { ensureDefaultAiSettings, getAiSettings } = require('../settings');
const {
  buildToolCatalog,
  selectInitialTools,
  selectToolsForTask,
} = require('../toolSelector');
const { compactToolResult } = require('../toolResult');
const { salvageTextToolCalls } = require('../toolCallSalvage');
const { sanitizeModelOutput } = require('../outputSanitizer');
const {
  buildAnalysisPrompt,
  buildExecutionGuidance,
  buildPlanPrompt,
  buildVerifierPrompt,
  isDirectAnswerEligibleAnalysis,
  normalizeExecutionPlan,
  normalizeTaskAnalysis,
  normalizeVerificationResult,
  parseJsonObject,
  promoteAnalysisMode,
  shouldRunVerifier,
} = require('../taskAnalysis');
const { getCapabilityHealth, summarizeCapabilityHealth } = require('../capabilityHealth');
const {
  buildPlatformFormattingGuide,
} = require('../../messaging/formatting_guides');
const {
  buildInterimSignature,
  normalizeInterimKind,
} = require('../interim');
const {
  buildDeliverableWorkflowGuidance,
  DeliverableValidationError,
  extractArtifactsFromResult,
  getDeliverableWorkflow,
  selectDeliverableWorkflow,
  validateDeliverableExecution,
} = require('../deliverables');
const { buildLoopPolicy, resolveToolResultLimits } = require('../loopPolicy');
const { globalHooks } = require('../hooks');
const { normalizeCompletionConfidence, shouldAcceptTaskComplete } = require('../completion');
const { enforceRateLimits } = require('../rate_limits');
const { ToolRepetitionGuard } = require('../repetitionGuard');
const { shortenRunId, summarizeForLog } = require('../logFormat');
const { IterationBudget } = require('./iteration_budget');
const {
  buildBlankAfterToolFailureGuidance,
  shouldContinueAfterBlankToolFailure,
} = require('./blank_recovery');
const {
  shouldRetryMessagingRun,
  shouldSendMessagingErrorFallback,
} = require('./error_recovery');
const {
  buildCompletionDecisionPrompt,
  buildGoalContractPrompt,
  goalContractFromAnalysis,
  goalContractFromPlan,
  mergeGoalContracts,
  normalizeCompletionDecision,
  normalizeGoalContract,
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
  updateRunGoalContract: updateRunGoalContractImpl,
  updateRunProgress: updateRunProgressImpl,
} = require('./run_state');
const {
  buildInitialProgressLedger,
} = require('./progress_monitor');
const {
  deliverMessagingFinalFallback: deliverMessagingFinalFallbackImpl,
  requireSuccessfulMessagingDelivery,
  sendRuntimeMessagingHeartbeat: sendRuntimeMessagingHeartbeatImpl,
  shouldSendMessagingFinalFallback: shouldSendMessagingFinalFallbackImpl,
  startMessagingProgressSupervisor: startMessagingProgressSupervisorImpl,
  stopMessagingProgressSupervisor: stopMessagingProgressSupervisorImpl,
  tickMessagingProgressSupervisor: tickMessagingProgressSupervisorImpl,
} = require('./messaging_delivery');
const {
  createDeliveryState,
} = require('./delivery_state');
const {
  requestModelResponse: requestModelResponseImpl,
  requestStructuredJson: requestStructuredJsonImpl,
  withModelCallTimeout,
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
  joinSentMessages,
  buildBlankMessagingReplyPrompt,
  buildDeterministicMessagingFallback,
  buildMessagingFailureScenario,
  buildDeterministicMessagingErrorReply,
  buildModelFailureLoopPrompt,
} = require('../messagingFallback');
const {
  classifyToolExecution,
  summarizeToolExecutions,
  summarizeAvailableTools,
  inferToolFailureMessage,
  buildAutonomousRecoveryContext,
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

function generateTitle(task) {
  if (!task || typeof task !== 'string') return 'Untitled';
  const msgMatch = task.match(/received a (?:message|media|image|video|file|audio)[^:]*:\s*(.+)/is);
  if (msgMatch) {
    const body = msgMatch[1].replace(/\n[\s\S]*/s, '').trim();
    return body.slice(0, 90) || 'Incoming message';
  }
  const cleaned = task.replace(/^\[.*?\]\s*/i, '').replace(/^(system|task|prompt)[:\s]+/i, '').trim();
  return cleaned.slice(0, 90);
}

function buildInitialRunMetadata(options = {}) {
  const metadata = {};
  if (options.taskId != null && String(options.taskId).trim()) {
    metadata.taskId = options.taskId;
  }
  if (options.widgetId != null && String(options.widgetId).trim()) {
    metadata.widgetId = options.widgetId;
  }
  return metadata;
}

function isoNow() {
  return new Date().toISOString();
}

function normalizeErrorKey(errorMsg) {
  const msg = String(errorMsg || '').toLowerCase();
  if (/outside.*(workspace|per-user)/i.test(msg)) return 'outside_workspace';
  if (/eisdir|illegal operation on a directory/i.test(msg)) return 'eisdir';
  if (/enoent|no such file/i.test(msg)) return 'enoent';
  if (/can.?t cd to|no such directory/i.test(msg)) return 'bad_cwd';
  if (/not found/i.test(msg)) return 'not_found';
  if (/owner_repo.*format|must be.*owner.*repo|owner.*repo.*string|owner.*repo.*combined/i.test(msg)) return 'owner_repo_format';
  return msg.slice(0, 60);
}

function trackErrorPattern(errorMsg, runMeta) {
  if (!errorMsg) return;
  const key = normalizeErrorKey(errorMsg);
  if (!runMeta.errorPatterns) runMeta.errorPatterns = new Map();
  runMeta.errorPatterns.set(key, (runMeta.errorPatterns.get(key) || 0) + 1);
}

function buildErrorPatternGuidance(key, count) {
  // Immediate guidance on first occurrence for high-signal patterns that waste
  // multiple iterations before self-correcting.
  const immediateGuides = {
    eisdir: 'That path is a directory (or a VM-only path like /tmp that read_file cannot reach). Use execute_command with `cat <path>` to read files inside VMs, or list_directory to inspect a directory.',
    owner_repo_format: 'The parameter "owner_repo" expects a single combined string like "NeoLabs-Systems/NeoAgent" — not separate owner/repo fields. Pass the full "owner/repo" as one value.',
  };
  if (immediateGuides[key]) {
    const prefix = count > 1 ? `REPEATED ERROR (${count}×): ` : 'ERROR GUIDANCE: ';
    return `${prefix}${immediateGuides[key]}`;
  }

  if (count < 3) return null;
  const guides = {
    outside_workspace: 'read_file cannot access /tmp paths. Use execute_command with `cat <path>` instead.',
    enoent: 'That path does not exist. Use execute_command with `find . -name "..."` to locate the correct path first.',
    bad_cwd: 'The VM home directory is not ~/. Use absolute paths starting from /tmp or discover the workspace root first.',
    not_found: 'This path or resource was not found. Try listing the parent directory or checking with a broader search first.',
  };
  const guide = guides[key];
  if (!guide) return null;
  return `REPEATED ERROR (${count}×): ${guide}`;
}

const OUTPUT_FINGERPRINT_TOOLS = /^(list_|search_|read_|get_|find_|github_list|github_get|github_search)/;

function fingerprintOutput(toolName, result) {
  if (!toolName || !OUTPUT_FINGERPRINT_TOOLS.test(toolName)) return null;
  const raw = typeof result === 'string' ? result : JSON.stringify(result ?? '');
  if (raw.length < 200) return null;
  // djb2 hash over first 3000 chars — fast, collision-unlikely for our sizes
  let h = 5381;
  const limit = Math.min(raw.length, 3000);
  for (let i = 0; i < limit; i++) h = ((h << 5) + h) ^ raw.charCodeAt(i);
  return h >>> 0;
}

// Tools that represent concrete forward progress (write, create, send, update, run).
// Anything NOT in this set is considered read-only for the analysis-paralysis gate.
// execute_command counts as progress — it can do anything, including modify state.
function isProgressTool(toolName) {
  if (!toolName) return false;
  // Neutral / bookkeeping — don't count either way
  if (toolName === 'activate_tools' || toolName === 'save_widget_snapshot') return false;
  // Explicitly read-only patterns
  if (/^(list_|search_|read_file|get_file|find_files?|github_list|github_get|github_search|browser_get|browser_read)/.test(toolName)) return false;
  return true;
}

function cloneInterimHistory(history = []) {
  if (!Array.isArray(history)) return [];
  return history.map((item) => ({
    content: String(item?.content || '').trim(),
    kind: normalizeInterimKind(item?.kind),
    expectsReply: item?.expectsReply === true,
    deferFollowUp: item?.deferFollowUp === true,
    createdAt: item?.createdAt || isoNow(),
  })).filter((item) => item.content);
}

function createInterimSignatureSet(history = [], platform = null) {
  const signatures = new Set();
  for (const item of cloneInterimHistory(history)) {
    signatures.add(buildInterimSignature({
      content: item.content,
      kind: item.kind,
      expectsReply: item.expectsReply === true,
      platform,
    }));
  }
  return signatures;
}

function hasVisibleInterimActivity(runMeta) {
  return Boolean(
    runMeta?.lastInterimMessage
    || (Array.isArray(runMeta?.interimMessages) && runMeta.interimMessages.length > 0)
    || Number(runMeta?.progressLedger?.heartbeatCount || 0) > 0
  );
}

function planningDepthForForceMode(forceMode) {
  return forceMode === 'plan_execute' ? 'deep' : 'light';
}

function buildSkipTaskAnalysisResult(forceMode) {
  return {
    mode: forceMode === 'plan_execute' ? 'plan_execute' : 'execute',
    reply_mode: 'task',
    freshness_risk: 'none',
    verification_need: 'none',
    planning_depth: planningDepthForForceMode(forceMode),
    confidence: 0.5,
    suggested_tools: [],
    needs_subagents: false,
    draft_reply: '',
    goal: 'Complete the user request accurately.',
    success_criteria: [],
    complexity: forceMode === 'plan_execute' ? 'complex' : 'standard',
    autonomy_level: forceMode === 'plan_execute' ? 'high' : 'normal',
    progress_update_policy: 'optional',
    parallel_work: false,
    completion_confidence_required: forceMode === 'plan_execute' ? 'high' : 'medium',
  };
}

function buildAnalyzeTaskFallback(forceMode, userMessage = '') {
  return {
    mode: forceMode || 'execute',
    verification_need: 'light',
    planning_depth: planningDepthForForceMode(forceMode),
    goal: userMessage ? String(userMessage).trim().slice(0, 300) : '',
    complexity: forceMode === 'plan_execute' ? 'complex' : 'standard',
    autonomy_level: forceMode === 'plan_execute' ? 'high' : 'normal',
    progress_update_policy: 'optional',
    parallel_work: false,
    completion_confidence_required: forceMode === 'plan_execute' ? 'high' : 'medium',
  };
}

function applyForcedAnalysisMode(analysis, forceMode) {
  if (!analysis || typeof analysis !== 'object') return analysis;
  if (forceMode !== 'plan_execute') return analysis;
  return {
    ...analysis,
    mode: 'plan_execute',
    planning_depth: 'deep',
    complexity: 'complex',
    autonomy_level: 'high',
    completion_confidence_required: analysis.completion_confidence_required || 'high',
  };
}

function buildAutonomyPolicyFromAnalysis(analysis = {}) {
  return {
    complexity: analysis.complexity || 'standard',
    autonomy_level: analysis.autonomy_level || 'normal',
    progress_update_policy: analysis.progress_update_policy || 'optional',
    parallel_work: analysis.parallel_work === true,
    completion_confidence_required: analysis.completion_confidence_required || 'medium',
  };
}

async function getProviderForUser(userId, task = '', isSubagent = false, modelOverride = null, providerConfig = {}) {
  const { getSupportedModels, createProviderInstance } = require('../models');
  const agentId = providerConfig.agentId || null;
  const aiSettings = getAiSettings(userId, agentId);
  const models = await getSupportedModels(userId, agentId);

  let enabledIds = Array.isArray(aiSettings.enabled_models) ? aiSettings.enabled_models : [];
  const defaultChatModel = aiSettings.default_chat_model || 'auto';
  const defaultSubagentModel = aiSettings.default_subagent_model || 'auto';
  const smarterSelection = aiSettings.smarter_model_selector !== false && aiSettings.smarter_model_selector !== 'false';

  const knownModelIds = new Set(models.map((m) => m.id));
  const selectableModels = models.filter((m) => m.available !== false);

  enabledIds = Array.isArray(enabledIds)
    ? enabledIds
      .map((id) => String(id))
      .filter((id) => knownModelIds.has(id))
    : [];

  let availableModels = selectableModels.filter((m) => enabledIds.includes(m.id));
  if (availableModels.length === 0) {
    enabledIds = selectableModels.map((m) => m.id);
    availableModels = [...selectableModels];
  }

  const fallbackModel = availableModels.length > 0 ? availableModels[0] : selectableModels[0];

  if (!fallbackModel) {
    throw new Error('No AI providers are currently available. Open Settings and configure at least one provider.');
  }

  let selectedModelDef = fallbackModel;
  const userSelectedDefault = isSubagent ? defaultSubagentModel : defaultChatModel;

  if (modelOverride && typeof modelOverride === 'string') {
    const requested = models.find((m) => m.id === modelOverride.trim());
    if (requested && requested.available !== false && enabledIds.includes(requested.id)) {
      selectedModelDef = requested;
      return {
        provider: createProviderInstance(selectedModelDef.provider, userId, providerConfig),
        model: selectedModelDef.id,
        providerName: selectedModelDef.provider
      };
    }
  }

  if (userSelectedDefault && userSelectedDefault !== 'auto') {
    selectedModelDef = models.find((m) => m.id === userSelectedDefault) || fallbackModel;
  } else {
    const selectionHint = providerConfig.selectionHint && typeof providerConfig.selectionHint === 'object'
      ? providerConfig.selectionHint
      : {};
    const preferredPurpose = String(selectionHint.purpose || '').trim().toLowerCase();
    const highAutonomy = selectionHint.autonomyLevel === 'high' || selectionHint.complexity === 'complex';
    const requiredConfidence = String(selectionHint.requiredConfidence || '').trim().toLowerCase();
    const costMode = String(selectionHint.costMode || aiSettings.cost_mode || 'balanced_auto').trim().toLowerCase();
    const requestedPurpose = ['planning', 'coding', 'general', 'fast'].includes(preferredPurpose)
      ? preferredPurpose
      : '';
    const priceRank = { free: 0, cheap: 1, medium: 2, expensive: 3 };
    const chooseForPurpose = (purpose) => {
      const candidates = availableModels.filter((model) => model.purpose === purpose);
      if (candidates.length === 0) return null;
      if (['economy', 'cost_saver', 'lowest_cost'].includes(costMode)) {
        return [...candidates].sort((left, right) => (
          (priceRank[left.priceTier] ?? 99) - (priceRank[right.priceTier] ?? 99)
        ))[0];
      }
      if (['quality', 'highest_quality'].includes(costMode) || requiredConfidence === 'high') {
        return candidates.find((model) => model.priceTier !== 'free' && model.priceTier !== 'cheap') || candidates[0];
      }
      return candidates[0];
    };

    if (smarterSelection && requestedPurpose) {
      selectedModelDef = chooseForPurpose(requestedPurpose) || fallbackModel;
    } else if (smarterSelection && highAutonomy) {
      selectedModelDef = chooseForPurpose('planning') || chooseForPurpose('general') || fallbackModel;
    } else if (isSubagent) {
      selectedModelDef = chooseForPurpose('fast') || fallbackModel;
    } else {
      selectedModelDef = chooseForPurpose('general') || fallbackModel;
    }
  }

  return {
    provider: createProviderInstance(selectedModelDef.provider, userId, providerConfig),
    model: selectedModelDef.id,
    providerName: selectedModelDef.provider
  };
}

async function getFailureFallbackModelId(userId, agentId, currentModelId, preferredFallbackId = null, failureError = null) {
  const { getSupportedModels } = require('../models');
  const aiSettings = getAiSettings(userId, agentId);
  const models = await getSupportedModels(userId, agentId);
  const availableModels = models.filter((model) => model.available !== false);
  const knownIds = new Set(availableModels.map((model) => model.id));
  const enabledIds = Array.isArray(aiSettings.enabled_models)
    ? aiSettings.enabled_models.map((id) => String(id)).filter((id) => knownIds.has(id))
    : [];
  const pool = enabledIds.length > 0
    ? availableModels.filter((model) => enabledIds.includes(model.id))
    : availableModels;
  const currentModel = pool.find((model) => model.id === currentModelId)
    || availableModels.find((model) => model.id === currentModelId)
    || null;

  // When the failure is a provider-level rate limit, the preferred fallback is
  // likely on the same provider and will hit the same limit. Skip it and prefer
  // a fallback from a different provider instead.
  const isProviderRateLimit = /429|rate.?limit|free-models-per/i.test(String(failureError?.message || ''));

  if (preferredFallbackId && preferredFallbackId !== currentModelId && !isProviderRateLimit) {
    const preferred = pool.find((model) => model.id === preferredFallbackId)
      || availableModels.find((model) => model.id === preferredFallbackId);
    if (preferred) return preferred.id;
  }

  if (currentModel?.provider) {
    const differentProvider = pool.find((model) => model.id !== currentModelId && model.provider !== currentModel.provider)
      || availableModels.find((model) => model.id !== currentModelId && model.provider !== currentModel.provider);
    if (differentProvider) return differentProvider.id;
  }

  // If no different-provider model exists, still try the preferred fallback
  // even on rate limits (it's better than nothing).
  if (preferredFallbackId && preferredFallbackId !== currentModelId) {
    const preferred = pool.find((model) => model.id === preferredFallbackId)
      || availableModels.find((model) => model.id === preferredFallbackId);
    if (preferred) return preferred.id;
  }

  const differentModel = pool.find((model) => model.id !== currentModelId)
    || availableModels.find((model) => model.id !== currentModelId);
  return differentModel?.id || null;
}

function estimateTokenValue(value) {
  if (!value) return 0;
  if (typeof value === 'string') return Math.ceil(value.length / 4);
  return Math.ceil(JSON.stringify(value).length / 4);
}

async function runConversation(engine, userId, userMessage, options = {}, _modelOverride = null) {
  const triggerType = options.triggerType || 'user';
  const { resolveAgentId } = require('../../agents/manager');
  const agentId = resolveAgentId(userId, options.agentId || options.agent_id || null);
  ensureDefaultAiSettings(userId, agentId);
  const aiSettings = getAiSettings(userId, agentId);

  enforceRateLimits(userId);

  const runId = options.runId || uuidv4();
  const conversationId = options.conversationId;
  const app = options.app || engine.app;
  const triggerSource = options.triggerSource || 'web';
  const historyWindow = Math.max(
    1,
    Number(options.historyWindow || aiSettings.chat_history_window) || aiSettings.chat_history_window,
  );
  // loopPolicy is built after task analysis so analysisMode can be passed in;
  // we build a provisional policy now (with default mode) and rebuild after
  // analysis when the mode is known. See the post-analysis policy rebuild below.
  let loopPolicy = buildLoopPolicy(aiSettings, triggerType, 'execute', options);
  let maxIterations = loopPolicy.maxIterations;
  const providerStatusConfig = {
    agentId,
    onStatus: (status) => {
      if (!status?.message) return;
      engine.emit(userId, 'run:interim', {
        runId,
        message: status.message,
        phase: status.phase
      });
    }
  };
  const selectedProvider = await getProviderForUser(
    userId,
    userMessage,
    triggerType === 'subagent',
    _modelOverride,
    providerStatusConfig
  );
  let provider = selectedProvider.provider;
  let model = selectedProvider.model;
  let providerName = selectedProvider.providerName;
  const switchToFallbackModel = async (failedModel, error, phase) => {
    const fallbackModelId = await getFailureFallbackModelId(userId, agentId, failedModel, aiSettings.fallback_model_id, error);
    if (!fallbackModelId || fallbackModelId === failedModel) return false;
    console.log(`[Engine] ${phase} failed on ${failedModel}; attempting fallback to: ${fallbackModelId}`);
    engine.emit(userId, 'run:interim', {
      runId,
      message: `Model service failed on ${failedModel}; retrying with ${fallbackModelId}.`,
      phase: 'model_fallback'
    });
    const fallback = await getProviderForUser(
      userId,
      userMessage,
      triggerType === 'subagent',
      fallbackModelId,
      providerStatusConfig
    );
    provider = fallback.provider;
    model = fallback.model;
    providerName = fallback.providerName;
    return true;
  };
  const runWithModelFallback = async (phase, fn) => {
    try {
      return await fn();
    } catch (err) {
      const failedModel = model;
      const switched = await switchToFallbackModel(failedModel, err, phase);
      if (!switched) throw err;
      return await fn();
    }
  };

  const runTitle = generateTitle(userMessage);
  const initialRunMetadata = buildInitialRunMetadata(options);
  db.prepare(`INSERT INTO agent_runs(
    id, user_id, agent_id, title, status, trigger_type, trigger_source, model, metadata_json
  ) VALUES(?, ?, ?, ?, 'running', ?, ?, ?, ?)
  ON CONFLICT(id) DO UPDATE SET
    status = 'running',
    model = excluded.model,
    updated_at = datetime('now'),
    completed_at = NULL,
    error = NULL,
    metadata_json = COALESCE(agent_runs.metadata_json, excluded.metadata_json)`).run(
    runId,
    userId,
    agentId,
    runTitle,
    triggerType,
    triggerSource,
    model,
    Object.keys(initialRunMetadata).length ? JSON.stringify(initialRunMetadata) : null,
  );

  const retryMessagingState = options.messagingRetryState || {};
  const carriedFinalMessage = String(retryMessagingState.lastFinalMessage || '').trim();
  const carriedExplicitMessageSent = retryMessagingState.explicitMessageSent === true;
  const carriedInterimHistory = cloneInterimHistory(retryMessagingState.interimHistory);
  const carriedLastInterimMessage = carriedInterimHistory[carriedInterimHistory.length - 1]?.content || '';
  const carriedGoalContract = mergeGoalContracts(
    normalizeGoalContract({
      goal: clampRunContext(userMessage, 1200),
    }),
    retryMessagingState.goalContract,
  );
  const startedAtIso = isoNow();
  const progressLedger = buildInitialProgressLedger({
    startedAt: startedAtIso,
    retryState: retryMessagingState,
  });

  engine.activeRuns.set(runId, {
    userId,
    agentId,
    title: runTitle,
    status: 'running',
    aborted: false,
    messagingSent: false,
    noResponse: false,
    explicitMessageSent: carriedExplicitMessageSent,
    finalDeliverySent: carriedExplicitMessageSent,
    lastSentMessage: carriedExplicitMessageSent ? carriedFinalMessage : '',
    sentMessages: [],
    widgetSnapshotSaved: false,
    triggerType,
    triggerSource,
    startedAt: Date.now(),
    startedAtIso,
    lastToolName: null,
    lastToolTarget: null,
    lastInterimMessage: carriedExplicitMessageSent ? '' : carriedLastInterimMessage,
    interimMessages: carriedExplicitMessageSent ? [] : carriedInterimHistory,
    interimSignatures: carriedExplicitMessageSent
      ? new Set()
      : createInterimSignatureSet(carriedInterimHistory, options.source || null),
    terminalInterim: null,
    voiceSessionId: options.voiceSessionId || null,
    steeringQueue: [],
    systemSteeringQueue: [],
    toolPids: new Set(),
    repetitionGuard: new ToolRepetitionGuard(),
    seenOutputHashes: new Map(),
    consecutiveReadOnlyIterations: 0,
    messagingContext: triggerSource === 'messaging'
      ? {
        platform: options.source || null,
        chatId: options.chatId || null,
      }
      : null,
    goalContract: carriedGoalContract,
    progressLedger,
    deliveryState: createDeliveryState({
      alreadySent: carriedInterimHistory.length > 0 || carriedExplicitMessageSent,
      finalResponseSent: carriedExplicitMessageSent,
      finalContentDelivered: carriedExplicitMessageSent,
    }),
  });
  engine.persistRunMetadata(runId, {
    progressLedger,
    goalContract: carriedGoalContract,
  });
  engine.startMessagingProgressSupervisor(runId);
  engine.emit(userId, 'run:start', { runId, agentId, title: runTitle, model, triggerType, triggerSource });
  engine.recordRunEvent(userId, runId, 'run_started', {
    title: runTitle,
    model,
    triggerType,
    triggerSource,
  }, { agentId });
  console.info(
    `[Run ${shortenRunId(runId)}] started trigger=${triggerSource} type=${triggerType} model=${model} title=${summarizeForLog(runTitle, 120)}`
  );

  const systemPrompt = await engine.buildSystemPrompt(userId, {
    ...(options.context || {}),
    userMessage,
    agentId,
    triggerSource,
  });
  // Pass short descriptions so the model always knows every available tool.
  // compactToolDefinition caps tool desc at 120 chars, param desc at 70 chars.
  const builtInTools = engine.getAvailableTools(app, {
    includeDescriptions: true,
    userId,
    agentId,
    triggerType,
    triggerSource,
    widgetId: options.widgetId || null,
  });
  const mcpManager = app?.locals?.mcpManager || app?.locals?.mcpClient || engine.mcpManager;
  const integrationManager = app?.locals?.integrationManager || null;
  const mcpTools = mcpManager ? mcpManager.getAllTools(userId, { agentId }) : [];
  const allTools = selectToolsForTask(userMessage, builtInTools, mcpTools, options);
  let tools = allTools;
  const toolNames = allTools.map((tool) => tool.name).filter(Boolean);
  const coreToolStatus = {
    send_message: toolNames.includes('send_message'),
    create_task: toolNames.includes('create_task'),
    list_tasks: toolNames.includes('list_tasks'),
    update_task: toolNames.includes('update_task'),
    delete_task: toolNames.includes('delete_task'),
  };
  engine.recordRunEvent(userId, runId, 'tool_inventory', {
    total: toolNames.length,
    builtInTotal: builtInTools.length,
    mcpTotal: mcpTools.length,
    core: coreToolStatus,
  }, { agentId });
  console.info(
    `[Run ${shortenRunId(runId)}] tools total=${toolNames.length} builtIns=${builtInTools.length} mcp=${mcpTools.length} core=${JSON.stringify(coreToolStatus)}`
  );
  const capabilityHealth = await getCapabilityHealth({ userId, agentId, app, engine });
  const capabilitySummary = summarizeCapabilityHealth(capabilityHealth);
  const integrationSummary = integrationManager?.summarizeConnectedProviders?.(userId, agentId) || '';

  const { MemoryManager } = require('../../memory/manager');
  const memoryManager = engine.memoryManager || new MemoryManager();
  const recallQuery = options.context?.rawUserMessage || userMessage;
  const recallMsg = options.skipGlobalRecall === true
    ? null
    : await engine.buildMemoryRecall({
      memoryManager,
      userId,
      agentId,
      query: recallQuery,
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

  let messages = engine.buildContextMessages(systemPrompt, summaryMessage, historyMessages, recallMsg);
  if (capabilitySummary) {
    messages.push({ role: 'system', content: `[Capability health]\n${capabilitySummary}` });
  }
  if (integrationSummary) {
    messages.push({ role: 'system', content: `[Official integrations]\n${integrationSummary}` });
  }
  const threadStateMessage = conversationId ? memoryManager.buildConversationStateMessage(conversationId) : null;
  if (threadStateMessage) {
    messages.push({ role: 'system', content: threadStateMessage });
  }
  if (carriedGoalContract) {
    messages.push({
      role: 'system',
      content: buildGoalContractPrompt(carriedGoalContract, 'Persisted run goal'),
    });
  }
  engine.recordRunEvent(userId, runId, 'memory_injected', {
    hasRecallContext: Boolean(recallMsg),
    hasThreadState: Boolean(threadStateMessage),
    recallPreview: recallMsg ? String(recallMsg).slice(0, 240) : '',
  }, { agentId });
  messages.push(engine.buildUserMessage(userMessage, options));
  messages = sanitizeConversationMessages(messages);

  if (conversationId) {
    db.prepare('INSERT INTO conversation_messages (conversation_id, role, content) VALUES (?, ?, ?)')
      .run(conversationId, 'user', userMessage);
  }

  let iteration = 0;
  let totalTokens = 0;
  let lastContent = '';
  let stepIndex = Number(options.messagingRetryStepOffset || 0);
  if (!Number.isFinite(stepIndex) || stepIndex < 0) {
    stepIndex = 0;
  }
  if (options.messagingAutonomousRetryCount > 0) {
    const existingStep = db.prepare('SELECT COALESCE(MAX(step_index), 0) AS maxStep FROM agent_steps WHERE run_id = ?').get(runId);
    stepIndex = Math.max(stepIndex, Number(existingStep?.maxStep || 0));
  }
  let failedStepCount = 0;
  let modelFailureRecoveries = 0;
  let promptMetrics = {};
  let toolExecutions = [];
  let compactionMetrics = [];
  let analysis = null;
  let plan = null;
  let verification = null;
  let deliverableWorkflow = null;
  let deliverablePlan = null;
  let deliverableArtifacts = [];
  let deliverableValidation = null;
  let directAnswerEligible = false;
  let analysisUsage = 0;

  try {
    if (options.skipTaskAnalysis === true) {
      analysis = buildSkipTaskAnalysisResult(options.forceMode);
    } else {
      const analysisResult = await runWithModelFallback('task analysis', () => engine.analyzeTask({
        provider,
        providerName,
        model,
        messages,
        tools,
        capabilityHealth,
        forceMode: options.forceMode || null,
        userMessage,
        options: { ...options, triggerSource, runId, userId, agentId },
      }));
      analysisUsage = analysisResult.usage || 0;
      totalTokens += analysisUsage;
      analysis = applyForcedAnalysisMode({ ...analysisResult.analysis }, options.forceMode);
      if (!analysis.goal && userMessage) {
        analysis.goal = String(userMessage).trim().slice(0, 300);
      }
      analysis.mode = promoteAnalysisMode(analysis.mode, {
        verificationNeed: analysis.verification_need,
        freshnessRisk: analysis.freshness_risk,
        draftReply: analysis.draft_reply,
        planningDepth: analysis.planning_depth,
      });

      stepIndex += 1;
      const analysisStepId = uuidv4();
      db.prepare(`INSERT INTO agent_steps
        (id, run_id, step_index, type, description, status, result, started_at, completed_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, datetime('now'), datetime('now'))`)
        .run(
          analysisStepId,
          runId,
          stepIndex,
          'analysis',
          'Task analysis contract',
          'completed',
          JSON.stringify(analysis).slice(0, 20000)
        );
      engine.persistRunMetadata(runId, {
        taskAnalysis: analysis,
        capabilityHealth,
      });
      engine.updateRunGoalContract(runId, goalContractFromAnalysis(analysis));
      engine.emit(userId, 'run:analysis', {
        runId,
        ...analysis,
        capabilitySummary,
      });

    }

    tools = selectInitialTools(allTools, analysis.suggested_tools, {
      widgetId: options.widgetId || null,
    });
    engine.initializeToolRuntime(runId, allTools, tools, options);
    messages.push({
      role: 'system',
      content: [
        '[Available tool catalog]',
        buildToolCatalog(allTools),
        '',
        `Active tools: ${tools.map((tool) => tool.name).join(', ')}`,
        'Use activate_tools with exact catalog names when another schema is required.',
      ].join('\n'),
    });
    engine.recordRunEvent(userId, runId, 'tool_selection_applied', {
      activeToolNames: tools.map((tool) => tool.name),
      catalogSize: allTools.length,
    }, { agentId });

    const activeDefaultModelSetting = triggerType === 'subagent'
      ? aiSettings.default_subagent_model
      : aiSettings.default_chat_model;
    if (!_modelOverride && activeDefaultModelSetting === 'auto' && aiSettings.smarter_model_selector !== false) {
      const requestedPurpose = analysis?.mode === 'plan_execute' || analysis?.complexity === 'complex' || analysis?.autonomy_level === 'high'
        ? 'planning'
        : triggerType === 'subagent'
          ? 'fast'
          : '';
      if (requestedPurpose) {
        const selectedAfterAnalysis = await getProviderForUser(
          userId,
          userMessage,
          triggerType === 'subagent',
          null,
          {
            ...providerStatusConfig,
            selectionHint: {
              purpose: requestedPurpose,
              complexity: analysis?.complexity,
              autonomyLevel: analysis?.autonomy_level,
              requiredConfidence: analysis?.completion_confidence_required,
              costMode: aiSettings.cost_mode,
            },
          }
        );
        if (selectedAfterAnalysis.model !== model) {
          provider = selectedAfterAnalysis.provider;
          model = selectedAfterAnalysis.model;
          providerName = selectedAfterAnalysis.providerName;
          db.prepare('UPDATE agent_runs SET model = ?, updated_at = datetime(\'now\') WHERE id = ?')
            .run(model, runId);
          engine.emit(userId, 'run:interim', {
            runId,
            message: `Switched to ${model} for this run after task analysis.`,
            phase: 'model_selection'
          });
        }
      }
    }

    // Rebuild loop policy with the resolved analysis mode. Runs in both the
    // normal path and the skipTaskAnalysis path so that forceMode='plan_execute'
    // (or any mode set by buildSkipTaskAnalysisResult) raises the iteration
    // ceiling correctly.
    loopPolicy = buildLoopPolicy(aiSettings, triggerType, analysis.mode || 'execute', {
      ...options,
      autonomyPolicy: buildAutonomyPolicyFromAnalysis(analysis),
    });
    maxIterations = loopPolicy.maxIterations;

    if (options.skipDeliverableWorkflow !== true) {
      try {
        const deliverableSelectionResult = await selectDeliverableWorkflow({
          engine,
          provider,
          providerName,
          model,
          messages,
          tools,
          options: { ...options, runId, userId, agentId },
        });
        totalTokens += deliverableSelectionResult.usage || 0;
        const selectedWorkflow = getDeliverableWorkflow(deliverableSelectionResult.selection.type);
        if (selectedWorkflow?.canHandle(deliverableSelectionResult.selection)) {
          deliverableWorkflow = {
            workflow: selectedWorkflow,
            selection: deliverableSelectionResult.selection,
            request: selectedWorkflow.normalizeRequest({
              ...deliverableSelectionResult.selection,
              userMessage,
            }),
          };
          deliverablePlan = selectedWorkflow.buildExecutionPlan(deliverableWorkflow.request, {
            analysis,
            tools,
            options,
          });
          await selectedWorkflow.run(deliverablePlan, {
            engine,
            userId,
            agentId,
            runId,
            app,
          });
          engine.persistRunMetadata(runId, {
            deliverableWorkflow: {
              ...deliverableWorkflow.selection,
              plan: deliverablePlan,
            },
          });
          engine.updateRunGoalContract(runId, {
            goal: deliverableWorkflow.selection.goal,
          });
          engine.recordRunEvent(userId, runId, 'deliverable_workflow_selected', {
            type: deliverableWorkflow.selection.type,
            confidence: deliverableWorkflow.selection.confidence,
            goal: deliverableWorkflow.selection.goal,
            requestedOutputs: deliverableWorkflow.selection.requestedOutputs,
          }, { agentId });
        }
      } catch (error) {
        engine.recordRunEvent(userId, runId, 'deliverable_workflow_skipped', {
          reason: summarizeForLog(error?.message || error, 240),
        }, { agentId });
        messages.push({
          role: 'system',
          content: 'The optional deliverable workflow classifier failed. Continue with the normal agent loop; do not stop or retry the whole run just because this classifier failed.',
        });
      }
    }

    if (analysis.mode === 'plan_execute') {
      const planResult = await runWithModelFallback('execution planning', () => engine.createExecutionPlan({
        provider,
        providerName,
        model,
        messages,
        analysis,
        capabilitySummary,
        options: { ...options, runId, userId, agentId },
      }));
      totalTokens += planResult.usage || 0;
      plan = planResult.plan;
      stepIndex += 1;
      const planStepId = uuidv4();
      db.prepare(`INSERT INTO agent_steps
        (id, run_id, step_index, type, description, status, result, started_at, completed_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, datetime('now'), datetime('now'))`)
        .run(
          planStepId,
          runId,
          stepIndex,
          'planning',
          'Execution plan',
          'completed',
          JSON.stringify(plan).slice(0, 20000)
        );
      engine.persistRunMetadata(runId, { executionPlan: plan });
      engine.updateRunGoalContract(runId, goalContractFromPlan(plan));
      engine.emit(userId, 'run:plan', {
        runId,
        steps: plan.steps,
        successCriteria: plan.success_criteria,
        verificationFocus: plan.verification_focus,
      });
    }

    const runGoalContract = engine.getRunMeta(runId)?.goalContract || null;
    if (runGoalContract) {
      messages.push({
        role: 'system',
        content: buildGoalContractPrompt(runGoalContract, 'Run goal contract'),
      });
    }
    messages.push({
      role: 'system',
      content: buildExecutionGuidance({
        analysis,
        plan,
        capabilityHealth: capabilitySummary,
      }),
    });
    if (deliverablePlan) {
      messages.push({
        role: 'system',
        content: buildDeliverableWorkflowGuidance(deliverablePlan),
      });
      engine.recordRunEvent(userId, runId, 'deliverable_execution_started', {
        type: deliverableWorkflow?.selection?.type,
        preferredTools: deliverablePlan.preferredTools || [],
        expectedOutputs: deliverablePlan.expectedOutputs || [],
      }, { agentId });
    }
    messages = sanitizeConversationMessages(messages);

    directAnswerEligible = isDirectAnswerEligibleAnalysis(analysis)
      && Boolean(normalizeOutgoingMessage(analysis.draft_reply));

    if (directAnswerEligible) {
      iteration = 1;
      lastContent = analysis.draft_reply.trim();
      messages.push({ role: 'assistant', content: lastContent });
      if (conversationId) {
        db.prepare('INSERT INTO conversation_messages (conversation_id, role, content, tokens) VALUES (?, ?, ?, ?)')
          .run(conversationId, 'assistant', lastContent, analysisUsage);
      }
    }

    // BUG FIX: consecutiveToolFailures was previously declared INSIDE the
    // while loop (resetting each iteration). It is now tracked across the
    // full run so the failure guard fires correctly after 5 consecutive failures
    // regardless of which iteration they fall in.
    let consecutiveToolFailures = 0;
    const iterationBudget = new IterationBudget(maxIterations);

    while (!directAnswerEligible && iterationBudget.consume()) {
      if (engine.isRunStopped(runId)) break;
      iteration = iterationBudget.used;

      const systemSteeringAtLoopStart = engine.applyQueuedSystemSteering(runId, messages);
      messages = systemSteeringAtLoopStart.messages;
      const steeringAtLoopStart = engine.applyQueuedSteering(runId, messages, {
        userId,
        conversationId
      });
      messages = steeringAtLoopStart.messages;
      messages = sanitizeConversationMessages(messages);

      // Analysis-paralysis gate: fire at the start of every iteration where
      // the agent has spent N turns only reading/listing/searching without
      // taking any concrete action. Escalates in urgency each turn.
      if (analysis.mode === 'execute' || analysis.mode === 'plan_execute') {
        const readOnlyCount = engine.getRunMeta(runId)?.consecutiveReadOnlyIterations || 0;
        if (readOnlyCount >= 3) {
          const urgency = readOnlyCount >= 6 ? 'CRITICAL' : 'ACTION REQUIRED';
          messages.push({
            role: 'system',
            content: `${urgency} — ${readOnlyCount} consecutive read-only turns: You have been gathering information for ${readOnlyCount} turns without writing, creating, sending, or running anything. You must take ONE concrete action this turn (create a file, open a PR, run a command that modifies state, send a message) or call task_complete to report what you found and why you cannot proceed. Do not read or list anything further.`,
          });
        }
      }

      engine.updateRunProgress(runId, {
        currentPhase: 'model',
        currentStep: `model:${iteration}`,
        currentTool: null,
        currentStepStartedAt: isoNow(),
      });

      let metrics = engine.estimatePromptMetrics(messages, tools);
      const contextWindow = provider.getContextWindow(model);
      if (metrics.totalEstimatedTokens > contextWindow * loopPolicy.compactionThreshold) {
        messages = await withModelCallTimeout(
          compact(messages, provider, model, contextWindow),
          options,
          `Context compaction before iteration ${iteration}`,
        );
        messages = sanitizeConversationMessages(messages);
        engine.emit(userId, 'run:compaction', { runId, iteration });
        metrics = engine.estimatePromptMetrics(messages, tools);
      }

      promptMetrics = engine.mergePromptMetrics(promptMetrics, metrics, iteration, tools.length);
      engine.persistPromptMetrics(runId, promptMetrics).catch(() => { });
      engine.emit(userId, 'run:thinking', { runId, iteration });
      engine.recordRunEvent(userId, runId, 'model_turn_started', {
        iteration,
        toolCount: tools.length,
      }, { agentId });

      let response;
      let responseModel = model;
      let streamContent = '';

      const tryModelCall = async (retryForFallback = true) => {
        try {
          const modelCall = await engine.requestModelResponse({
            provider,
            providerName,
            model,
            messages,
            tools,
            options: { ...options, userId, agentId, runId, phase: 'model_turn' },
            runId,
            iteration,
          });
          response = modelCall.response;
          responseModel = modelCall.responseModel;
          streamContent = modelCall.streamContent;
        } catch (err) {
          console.error(`[Engine] Model call failed (${model}):`, err.message);
          const fallbackModelId = retryForFallback
            ? await getFailureFallbackModelId(userId, agentId, model, aiSettings.fallback_model_id, err)
            : null;
          if (fallbackModelId) {
            const failedModel = model;
            console.log(`[Engine] Attempting fallback to: ${fallbackModelId}`);
            const fallback = await getProviderForUser(
              userId,
              userMessage,
              triggerType === 'subagent',
              fallbackModelId,
              providerStatusConfig
            );
            provider = fallback.provider;
            model = fallback.model;
            providerName = fallback.providerName;

            const retryMessages = sanitizeConversationMessages([
              ...messages,
              {
                role: 'system',
                content: buildModelFailureLoopPrompt({
                  failedModel,
                  nextModel: model,
                  errorMessage: err.message
                })
              }
            ]);

            const fallbackCall = await engine.requestModelResponse({
              provider,
              providerName,
              model,
              messages: retryMessages,
              tools,
              options: { ...options, userId },
              runId,
              iteration,
            });
            response = fallbackCall.response;
            responseModel = fallbackCall.responseModel;
            streamContent = fallbackCall.streamContent;
          } else {
            throw err;
          }
        }
      };

      try {
        await tryModelCall();
      } catch (err) {
        const modelError = String(err?.message || 'Model call failed');

        if (modelFailureRecoveries < loopPolicy.maxModelFailureRecoveries) {
          const failedModel = model;
          const switched = await switchToFallbackModel(failedModel, err, 'model turn');
          if (!switched) throw err;
          modelFailureRecoveries += 1;
          failedStepCount += 1;
          messages.push({
            role: 'system',
            content: buildModelFailureLoopPrompt({
              failedModel,
              nextModel: model,
              errorMessage: modelError
            })
          });
          engine.emit(userId, 'run:interim', {
            runId,
            message: 'Model call failed; adapting and retrying autonomously.',
            phase: 'recovering'
          });
          continue;
        }

        throw err;
      }

      if (!response) {
        response = { content: streamContent, toolCalls: [], finishReason: 'stop', usage: null };
      }

      if (response.usage) {
        totalTokens += response.usage.totalTokens || 0;
      }

      lastContent = sanitizeModelOutput(response.content || streamContent || '', { model: responseModel });

      if ((!response.toolCalls || response.toolCalls.length === 0) && lastContent) {
        const salvaged = salvageTextToolCalls(lastContent, tools);
        if (salvaged.toolCalls.length > 0) {
          response.toolCalls = salvaged.toolCalls;
          response.finishReason = 'tool_calls';
          response.content = salvaged.content;
          lastContent = salvaged.content;
        }
      }

      engine.recordRunEvent(userId, runId, 'model_turn_completed', {
        iteration,
        toolCallCount: response.toolCalls?.length || 0,
        contentPreview: String(lastContent || streamContent || '').slice(0, 240),
      }, { agentId });
      engine.updateRunProgress(runId, {}, {
        verified: true,
      });

      const assistantMessage = { role: 'assistant', content: lastContent };
      if (response.toolCalls?.length) assistantMessage.tool_calls = response.toolCalls;
      if (response.providerContentBlocks?.length) assistantMessage.providerContentBlocks = response.providerContentBlocks;
      messages.push(assistantMessage);

      if (conversationId) {
        db.prepare('INSERT INTO conversation_messages (conversation_id, role, content, tool_calls, tokens) VALUES (?, ?, ?, ?, ?)')
          .run(
            conversationId,
            'assistant',
            lastContent,
            response.toolCalls?.length ? JSON.stringify(response.toolCalls) : null,
            response.usage?.totalTokens || 0
          );
      }

      if (!response.toolCalls || response.toolCalls.length === 0) {
        engine.updateRunProgress(runId, {
          currentPhase: 'idle',
          currentStep: null,
          currentTool: null,
          currentStepStartedAt: null,
        });
        // Check for queued steering first — if something was injected while the
        // model was responding (e.g. a heartbeat nudge), give the model a chance
        // to act on it before we treat this as a final answer.
        const systemSteeringAfterResponse = engine.applyQueuedSystemSteering(runId, messages);
        messages = systemSteeringAfterResponse.messages;
        if (systemSteeringAfterResponse.appliedCount > 0) {
          iterationBudget.refund();
          iteration = iterationBudget.used;
          lastContent = '';
          continue;
        }
        const steeringAfterResponse = engine.applyQueuedSteering(runId, messages, {
          userId,
          conversationId
        });
        messages = steeringAfterResponse.messages;
        if (steeringAfterResponse.appliedCount > 0) {
          iterationBudget.refund();
          iteration = iterationBudget.used;
          lastContent = '';
          continue;
        }
        if (engine.shouldFastCompleteVoiceReply({
          options,
          toolExecutions,
          failedStepCount,
          messagingSent: engine.activeRuns.get(runId)?.messagingSent || false,
          lastReply: lastContent,
        })) {
          break;
        }
        if (shouldContinueAfterBlankToolFailure({
          lastContent,
          failedStepCount,
          remainingIterations: iterationBudget.remaining,
          toolExecutions,
        })) {
          engine.recordRunEvent(userId, runId, 'blank_after_tool_failure_continued', {
            iteration,
            remainingIterations: iterationBudget.remaining,
          }, { agentId });
          messages.push({
            role: 'system',
            content: buildBlankAfterToolFailureGuidance(toolExecutions),
          });
          lastContent = '';
          continue;
        }
        const loopDecision = await engine.decideLoopState({
          provider,
          providerName,
          model,
          messages,
          analysis,
          plan,
          tools,
          toolExecutions,
          lastReply: lastContent,
          iteration,
          maxIterations,
          options: { ...options, triggerSource, runId, userId, agentId },
          messagingSent: engine.activeRuns.get(runId)?.messagingSent || false,
        });
        totalTokens += loopDecision.usage || 0;
        engine.recordRunEvent(userId, runId, 'loop_completion_checked', {
          status: loopDecision.decision.status,
          reason: loopDecision.decision.reason,
          iteration,
        }, { agentId });
        if (loopDecision.decision.status === 'continue') {
          messages.push({
            role: 'system',
            content: [
              'The run self-check determined the latest assistant text is not terminal.',
              'Continue with the next safe tool/model step.',
              'If the text was only a progress note, do not repeat it; either make progress or provide a real final/blocker reply.',
            ].join(' '),
          });
          lastContent = '';
          continue;
        }
        directAnswerEligible = true;
        break;
      }

      const canRunParallelBatch = (
        response.toolCalls.length > 1
        && response.toolCalls.every((toolCall) => engine.isReadOnlyToolCall(toolCall))
      );
      if (canRunParallelBatch) {
        const parallelToolNames = response.toolCalls
          .map((toolCall) => toolCall.function?.name)
          .filter(Boolean);
        engine.updateRunProgress(runId, {
          currentPhase: 'tool',
          currentStep: `parallel:${iteration}`,
          currentTool: parallelToolNames.join(', ') || 'parallel tools',
          currentStepStartedAt: isoNow(),
        });
        const batch = await engine.executeReadOnlyBatch(response.toolCalls, {
          userId,
          runId,
          agentId,
          app,
          triggerType,
          triggerSource,
          conversationId,
          startingStepIndex: stepIndex,
          iteration,
          options,
        });
        stepIndex = batch.endingStepIndex;
        for (const item of batch.results) {
          const execution = classifyToolExecution(
            item.toolName,
            item.toolArgs,
            item.result,
            item.error || '',
          );
          execution.input = item.toolArgs;
          execution.artifacts = await extractArtifactsFromResult(item.toolName, item.result);
          toolExecutions.push(execution);
          engine.getRunMeta(runId)?.repetitionGuard?.observe(item.toolName, item.toolArgs, item.result);
          if (item.error) failedStepCount += 1;
          const modelPayload = compactPayloadForModel(item.toolName, item.result);
          const toolResultLimits = resolveToolResultLimits(item.toolName, loopPolicy);
          const toolMessage = {
            role: 'tool',
            name: item.toolName,
            tool_call_id: item.toolCall.id,
            content: compactToolResult(item.toolName, item.toolArgs, modelPayload.result, {
              softLimit: toolResultLimits.softLimit,
              hardLimit: toolResultLimits.hardLimit,
            }),
          };
          messages.push(toolMessage);
          if (conversationId) {
            db.prepare(
              `INSERT INTO conversation_messages (
                conversation_id, role, content, tool_call_id, name
              ) VALUES (?, 'tool', ?, ?, ?)`
            ).run(conversationId, toolMessage.content, item.toolCall.id, item.toolName);
          }
        }
        engine.persistRunMetadata(runId, {
          evidenceSources: [...new Set(toolExecutions.map((item) => item.evidenceSource).filter(Boolean))],
          subagentState: engine.listSubagents(runId),
          deliverableArtifacts,
          compactionMetrics: compactionMetrics.slice(-20),
        });
        engine.updateRunProgress(runId, {
          currentPhase: 'idle',
          currentStep: null,
          currentTool: null,
          currentStepStartedAt: null,
        }, {
          verified: true,
        });
        continue;
      }

      for (const toolCall of response.toolCalls) {
        if (engine.isRunStopped(runId)) break;
        stepIndex++;
        const stepId = uuidv4();
        const toolName = toolCall.function.name;
        const stepStartedAt = Date.now();
        let toolArgs;
        try {
          toolArgs = JSON.parse(toolCall.function.arguments || '{}');
        } catch {
          toolArgs = {};
        }

        // ── task_complete: AI explicitly signals the task is fully done ──
        if (toolName === 'task_complete') {
          const finalMessage = String(toolArgs.message || '').trim();
          const completionDecision = await engine.evaluateTaskCompleteSignal({
            provider,
            providerName,
            model,
            messages,
            analysis,
            plan,
            tools,
            toolExecutions,
            finalMessage,
            confidence: toolArgs.confidence,
            iteration,
            maxIterations,
            options: { ...options, triggerSource, runId, userId, agentId },
            messagingSent: engine.activeRuns.get(runId)?.messagingSent || false,
          });
          totalTokens += completionDecision.usage || 0;
          engine.recordRunEvent(userId, runId, 'task_complete_signaled', {
            accepted: completionDecision.accepted,
            status: completionDecision.status,
            reason: completionDecision.reason,
            iteration,
            messageLength: finalMessage.length,
          }, { agentId });
          if (!completionDecision.accepted) {
            const rejectedResult = {
              tool: 'task_complete',
              status: 'continue',
              reason: completionDecision.reason || 'The completion self-check determined more work is still required.',
            };
            messages.push({
              role: 'tool',
              name: toolName,
              tool_call_id: toolCall.id,
              content: JSON.stringify(rejectedResult),
            });
            messages.push({
              role: 'system',
              content: 'The task_complete signal was rejected by the run self-check. Continue autonomously with the next safe step, or provide a truthful blocker only if no safe next step remains.',
            });
            continue;
          }
          console.info(
            `[Run ${shortenRunId(runId)}] task_complete accepted status=${completionDecision.status} iteration=${iteration}`
          );
          lastContent = finalMessage;
          directAnswerEligible = true;
          break;
        }

        const repetitionGuard = engine.getRunMeta(runId)?.repetitionGuard;
        if (repetitionGuard?.shouldBlock(toolName, toolArgs)) {
          const blockedResult = {
            tool: toolName,
            status: 'blocked',
            reason: 'The same tool call already returned an unchanged result twice. Change the approach or complete with the available evidence.',
          };
          messages.push({
            role: 'tool',
            name: toolName,
            tool_call_id: toolCall.id,
            content: JSON.stringify(blockedResult),
          });
          engine.recordRunEvent(userId, runId, 'repetition_blocked', {
            toolName,
            toolArgs,
          }, { agentId });
          engine.emit(userId, 'run:tool_end', {
            runId,
            toolName,
            status: 'blocked',
            result: blockedResult,
          });
          messages.push({
            role: 'system',
            content: 'The repeated call was blocked because it made no progress. Use a different tool, change the arguments, or finish with a truthful result.',
          });
          continue;
        }

        // ── before_tool_call hook ──
        // Plugins can block a tool call (e.g. security policy) or mutate args.
        if (globalHooks.has('before_tool_call')) {
          const hookCtx = { toolName, toolArgs, runId, userId, agentId, iteration };
          const hookResult = await globalHooks.run('before_tool_call', hookCtx);
          if (hookResult.block) {
            const blockReason = hookResult.reason || 'Blocked by policy.';
            const blockedBy = hookResult.blocked_by || 'policy';
            console.warn(`[Run ${shortenRunId(runId)}] before_tool_call hook blocked tool=${toolName} reason="${blockReason}"`);
            messages.push({
              role: 'tool',
              name: toolName,
              tool_call_id: toolCall.id,
              content: JSON.stringify({ tool: toolName, status: 'blocked', reason: blockReason, blocked_by: blockedBy }),
            });
            continue;
          }
          if (hookResult.toolArgs) toolArgs = hookResult.toolArgs;
        }

        db.prepare('INSERT INTO agent_steps (id, run_id, step_index, type, description, status, tool_name, tool_input, started_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, datetime(\'now\'))')
          .run(stepId, runId, stepIndex, engine.getStepType(toolName), `${toolName}: ${JSON.stringify(toolArgs).slice(0, 200)} `, 'running', toolName, JSON.stringify(toolArgs));
        engine.updateRunProgress(runId, {
          currentPhase: 'tool',
          currentStep: stepId,
          currentTool: toolName,
          currentStepStartedAt: isoNow(),
        }, {
          stepId,
        });

        engine.emit(userId, 'run:tool_start', {
          runId, stepId, stepIndex, toolName, toolArgs,
          type: engine.getStepType(toolName)
        });
        engine.recordRunEvent(userId, runId, 'tool_started', {
          stepIndex,
          toolName,
          toolArgs,
          type: engine.getStepType(toolName),
        }, { agentId, stepId });
        console.info(
          `[Run ${shortenRunId(runId)}] step=${stepIndex} start tool=${toolName} args=${summarizeForLog(toolArgs)}`
        );

        let toolResult;
        let toolErrorMessage = '';
        try {
          toolResult = await engine.executeTool(toolName, toolArgs, {
            userId,
            runId,
            agentId,
            app,
            triggerType,
            triggerSource,
            conversationId,
            source: options.source || null,
            chatId: options.chatId || null,
            taskId: options.taskId || null,
            widgetId: options.widgetId || null,
            deliveryState: options.deliveryState || null,
            allowMultipleProactiveMessages: options.allowMultipleProactiveMessages === true,
            allowExternalSideEffects: options.allowExternalSideEffects === true,
          });
          engine.detachProcessFromRun(runId, toolResult?.pid);
          toolErrorMessage = inferToolFailureMessage(toolName, toolResult);
          if (toolErrorMessage) {
            failedStepCount++;
          }
          const screenshotPath = toolResult?.screenshotPath || null;
          const stepStatus = engine.isRunStopped(runId) ? 'stopped' : (toolErrorMessage ? 'failed' : 'completed');
          db.prepare('UPDATE agent_steps SET status = ?, result = ?, error = ?, screenshot_path = ?, completed_at = datetime(\'now\') WHERE id = ?')
            .run(stepStatus, JSON.stringify(toolResult).slice(0, 20000), toolErrorMessage || null, screenshotPath, stepId);
          if (toolErrorMessage) {
            engine.emit(userId, 'run:tool_end', { runId, stepId, toolName, error: toolErrorMessage, result: toolResult, screenshotPath, status: stepStatus });
            engine.recordRunEvent(userId, runId, 'tool_failed', {
              toolName,
              status: stepStatus,
              error: toolErrorMessage,
              durationMs: Date.now() - stepStartedAt,
              resultPreview: summarizeForLog(toolResult),
            }, { agentId, stepId });
            console.warn(
              `[Run ${shortenRunId(runId)}] step=${stepIndex} failed tool=${toolName} durationMs=${Date.now() - stepStartedAt} error=${summarizeForLog(toolErrorMessage, 160)}`
            );
          } else {
            engine.emit(userId, 'run:tool_end', { runId, stepId, toolName, result: toolResult, screenshotPath, status: stepStatus });
            engine.recordRunEvent(userId, runId, 'tool_completed', {
              toolName,
              status: stepStatus,
              durationMs: Date.now() - stepStartedAt,
              resultPreview: summarizeForLog(toolResult),
            }, { agentId, stepId });
            console.info(
              `[Run ${shortenRunId(runId)}] step=${stepIndex} done tool=${toolName} status=${stepStatus} durationMs=${Date.now() - stepStartedAt} result=${summarizeForLog(toolResult)}`
            );
          }
        } catch (err) {
          toolResult = { error: err.message };
          toolErrorMessage = String(err.message || 'Tool execution failed');
          failedStepCount++;
          engine.detachProcessFromRun(runId, toolResult?.pid);
          db.prepare('UPDATE agent_steps SET status = ?, error = ?, completed_at = datetime(\'now\') WHERE id = ?')
            .run('failed', err.message, stepId);
          engine.emit(userId, 'run:tool_end', { runId, stepId, toolName, error: err.message, status: 'failed' });
          engine.recordRunEvent(userId, runId, 'tool_failed', {
            toolName,
            status: 'failed',
            error: err.message,
            durationMs: Date.now() - stepStartedAt,
          }, { agentId, stepId });
          console.warn(
            `[Run ${shortenRunId(runId)}] step=${stepIndex} failed tool=${toolName} durationMs=${Date.now() - stepStartedAt} error=${summarizeForLog(err.message, 160)}`
          );
        }

        const execution = classifyToolExecution(toolName, toolArgs, toolResult, toolErrorMessage);
        execution.input = toolArgs;
        repetitionGuard?.observe(toolName, toolArgs, toolResult);
        execution.artifacts = await extractArtifactsFromResult(toolName, toolResult);
        toolExecutions.push(execution);
        if (deliverableWorkflow && Array.isArray(execution.artifacts) && execution.artifacts.length > 0) {
          for (const artifact of execution.artifacts) {
            if (!deliverableArtifacts.some((existing) => (
              (existing.path && artifact.path && existing.path === artifact.path)
              || (existing.uri && artifact.uri && existing.uri === artifact.uri)
            ))) {
              deliverableArtifacts.push(artifact);
              engine.recordRunEvent(userId, runId, 'deliverable_artifact_produced', {
                type: deliverableWorkflow.selection.type,
                toolName,
                artifact,
              }, { agentId, stepId });
            }
          }
        }
        engine.persistRunMetadata(runId, {
          evidenceSources: [...new Set(toolExecutions.map((item) => item.evidenceSource).filter(Boolean))],
          subagentState: engine.listSubagents(runId),
          deliverableArtifacts,
          compactionMetrics: compactionMetrics.slice(-20),
        });
        const modelPayload = compactPayloadForModel(toolName, toolResult);
        if (modelPayload.metrics?.applied) {
          const metric = {
            toolName,
            stepId,
            ...modelPayload.metrics,
            createdAt: new Date().toISOString(),
          };
          compactionMetrics.push(metric);
          engine.persistRunMetadata(runId, {
            compactionMetrics: compactionMetrics.slice(-20),
          });
          engine.recordRunEvent(userId, runId, 'pre_model_compaction_applied', {
            toolName,
            metrics: modelPayload.metrics,
          }, { agentId, stepId });
        }

        const toolResultLimits = resolveToolResultLimits(toolName, loopPolicy);
        const toolMessage = {
          role: 'tool',
          name: toolName,
          tool_call_id: toolCall.id,
          content: compactToolResult(toolName, toolArgs, modelPayload.result, {
            softLimit: toolResultLimits.softLimit,
            hardLimit: toolResultLimits.hardLimit,
          })
        };
        messages.push(toolMessage);
        if (toolName === 'activate_tools' && !toolErrorMessage) {
          tools = engine.getActiveTools(runId);
        }

        if (toolErrorMessage) {
          consecutiveToolFailures += 1;
          const currentRunMeta = engine.getRunMeta(runId);
          trackErrorPattern(toolErrorMessage, currentRunMeta);
          const errorKey = normalizeErrorKey(toolErrorMessage);
          const errorCount = currentRunMeta?.errorPatterns?.get(errorKey) || 0;
          const patternGuide = buildErrorPatternGuidance(errorKey, errorCount);
          const alternativeTools = summarizeAvailableTools(tools, { exclude: toolName });
          messages.push({
            role: 'system',
            content: [
              `Tool "${toolName}" failed with error: ${summarizeForLog(toolErrorMessage, 240)}.`,
              'This tool failure is not, by itself, a user-facing blocker.',
              'Continue autonomously: retry with corrected arguments, try an alternative tool/path, or verify the outcome using other available tools.',
              alternativeTools ? `Other available tools in this run: ${alternativeTools}.` : '',
              patternGuide || '',
              'Only stop and tell the user you are blocked if the remaining issue truly requires an external dependency or user action outside this run.'
            ].filter(Boolean).join(' ')
          });

          if (consecutiveToolFailures >= loopPolicy.maxConsecutiveToolFailures) {
            messages.push({
              role: 'system',
              content: `There were ${consecutiveToolFailures} consecutive tool failures. Stop calling tools now and return a clear blocker response that summarizes attempted actions and concrete errors.`
            });
            break;
          }
        } else {
          consecutiveToolFailures = 0;
          // Output fingerprint guard: steer away from re-fetching data already seen.
          if (!toolErrorMessage) {
            const currentRunMeta = engine.getRunMeta(runId);
            const fp = fingerprintOutput(toolName, toolResult);
            if (fp !== null && currentRunMeta?.seenOutputHashes) {
              const prior = currentRunMeta.seenOutputHashes.get(fp);
              if (prior) {
                messages.push({
                  role: 'system',
                  content: `DUPLICATE DATA: This response is identical to what "${prior.toolName}" returned in iteration ${prior.iteration}. You already have this information. Stop fetching and use what you have — proceed to the next concrete action.`,
                });
              } else {
                currentRunMeta.seenOutputHashes.set(fp, { toolName, iteration });
                // External state: persist large read results to disk so the
                // model can reference them after context compaction without
                // re-fetching. Only for significant payloads.
                const persistRaw = typeof toolResult === 'string' ? toolResult : JSON.stringify(toolResult ?? '');
                if (persistRaw.length >= 1000 && runId) {
                  const persistPath = `/tmp/run-${runId.slice(0, 8)}-${toolName}.json`;
                  try {
                    require('fs').writeFileSync(persistPath, persistRaw.slice(0, 40000));
                    if (!currentRunMeta.persistedDataPaths) currentRunMeta.persistedDataPaths = [];
                    if (!currentRunMeta.persistedDataPaths.includes(persistPath)) {
                      currentRunMeta.persistedDataPaths.push(persistPath);
                      messages.push({
                        role: 'system',
                        content: `Data from "${toolName}" (iteration ${iteration}) persisted to ${persistPath}. If context compacts and you need this data again, use execute_command with \`cat ${persistPath}\` instead of re-fetching.`,
                      });
                    }
                  } catch { /* non-fatal — disk full or permissions */ }
                }
              }
            }
          }
        }

        if (toolName === 'send_interim_update') {
          messages.push({
            role: 'system',
            content: 'An interim user-visible update was already sent. Do not later output meta commentary about having already replied. When you have the final answer, give the answer itself. If you need to deliver that final answer to the user in messaging, use send_message.'
          });
        }

        if (toolName === 'execute_command' && (toolResult?.timedOut || toolResult?.killed)) {
          messages.push({
            role: 'system',
            content: 'The previous shell command did not finish cleanly. Keep working until you rerun it with enough time or verify the requested outcome with follow-up commands.'
          });
        }

        if (
          toolName === 'execute_command'
          && toolResult?.exitCode !== undefined
          && toolResult.exitCode !== 0
        ) {
          messages.push({
            role: 'system',
            content: 'The previous shell command exited non-zero. Treat its output as partial evidence only. If it chained multiple shell segments, later segments may not have run. Do not summarize missing sections as observed facts; rerun or verify them separately first.'
          });
        }

        if (conversationId) {
          db.prepare('INSERT INTO conversation_messages (conversation_id, role, content, tool_call_id, name) VALUES (?, ?, ?, ?, ?)')
            .run(conversationId, 'tool', toolMessage.content, toolCall.id, toolName);
        }

        engine.updateRunProgress(runId, {
          currentPhase: 'idle',
          currentStep: null,
          currentTool: null,
          currentStepStartedAt: null,
        }, {
          verified: true,
          stepId,
        });

        const runMeta = engine.activeRuns.get(runId);
        if (runMeta) {
          runMeta.lastToolName = toolName;
          runMeta.lastToolTarget = toolName === 'send_message' ? toolArgs.to : null;
          if (toolName === 'save_widget_snapshot' && !toolErrorMessage) {
            runMeta.widgetSnapshotSaved = true;
          }
        }

        if (toolName === 'save_widget_snapshot' && !toolErrorMessage) {
          lastContent = 'Widget snapshot updated.';
          break;
        }

        if (runMeta?.terminalInterim) {
          break;
        }
      }

      // Update analysis-paralysis counter after each iteration's tool calls.
      // Resets to 0 when any progress tool was called; otherwise increments.
      if (!directAnswerEligible && response?.toolCalls?.length > 0
        && (analysis.mode === 'execute' || analysis.mode === 'plan_execute')) {
        const iterMeta = engine.getRunMeta(runId);
        if (iterMeta) {
          const calledProgress = response.toolCalls.some((tc) => isProgressTool(tc.function?.name || ''));
          iterMeta.consecutiveReadOnlyIterations = calledProgress
            ? 0
            : (iterMeta.consecutiveReadOnlyIterations || 0) + 1;
        }
      }

      if (engine.isRunStopped(runId)) break;
      if (engine.getRunMeta(runId)?.terminalInterim) break;
      if (engine.getRunMeta(runId)?.widgetSnapshotSaved) break;
      if (!engine.activeRuns.has(runId)) break;
    }

    if (engine.isRunStopped(runId)) {
      db.prepare('UPDATE agent_runs SET status = ?, updated_at = datetime(\'now\'), completed_at = datetime(\'now\') WHERE id = ?')
        .run('stopped', runId);
      console.warn(
        `[Run ${shortenRunId(runId)}] stopped trigger=${triggerSource} steps=${stepIndex} tokens=${totalTokens}`
      );
      engine.stopMessagingProgressSupervisor(runId);
      engine.activeRuns.delete(runId);
      engine.emit(userId, 'run:stopped', { runId, triggerSource });
      engine.recordRunEvent(userId, runId, 'run_stopped', {
        triggerSource,
        totalTokens,
        iterations: iteration,
      }, { agentId });
      return { runId, content: '', totalTokens, iterations: iteration, status: 'stopped' };
    }

    const runMeta = engine.activeRuns.get(runId);
    if (runMeta?.terminalInterim) {
      lastContent = '';
    }
    if (runMeta?.widgetSnapshotSaved && !lastContent) {
      lastContent = 'Widget snapshot updated.';
    }
    const messagingSent = runMeta?.messagingSent || false;
    const lastToolWasMessaging = runMeta?.lastToolName === 'send_message' || runMeta?.lastToolName === 'make_call';

    if (triggerSource === 'messaging' && !normalizeOutgoingMessage(lastContent, options?.source || null) && !messagingSent) {
      // Simplified blank reply recovery: one model call with direct instruction,
      // then fall back to a deterministic message. No multi-attempt LLM loop.
      console.warn(`[Run ${shortenRunId(runId)}] blank_reply_recovery model=${model}`);
      let recoveredTokens = 0;
      try {
        const recoveryResponse = await withModelCallTimeout(
          provider.chat(
            sanitizeConversationMessages([
              ...messages,
              {
                role: 'system',
                content: buildBlankMessagingReplyPrompt(1, options?.source || null)
              }
            ]),
            [],
            {
              model,
              reasoningEffort: engine.getReasoningEffort(providerName, options)
            }
          ),
          options,
          'Blank messaging reply recovery',
        );
        recoveredTokens = recoveryResponse.usage?.totalTokens || 0;
        lastContent = sanitizeModelOutput(recoveryResponse.content || '', { model });
      } catch (recoverErr) {
        console.warn(`[Run ${shortenRunId(runId)}] blank_reply_recovery failed: ${summarizeForLog(recoverErr?.message || recoverErr, 180)}`);
      }
      totalTokens += recoveredTokens;
      if (!normalizeOutgoingMessage(lastContent, options?.source || null)) {
        lastContent = buildDeterministicMessagingFallback({ failedStepCount, stepIndex, toolExecutions });
      }
      if (normalizeOutgoingMessage(lastContent, options?.source || null)) {
        const recoveryDecision = await engine.decideLoopState({
          provider,
          providerName,
          model,
          messages,
          analysis,
          plan,
          tools,
          toolExecutions,
          lastReply: lastContent,
          iteration,
          maxIterations,
          options: { ...options, triggerSource, runId, userId, agentId },
          messagingSent: false,
        });
        totalTokens += recoveryDecision.usage || 0;
        engine.recordRunEvent(userId, runId, 'blank_reply_recovery_checked', {
          status: recoveryDecision.decision.status,
          reason: recoveryDecision.decision.reason,
        }, { agentId });
        if (recoveryDecision.decision.status === 'continue') {
          throw new Error('Messaging run ended without a judged terminal reply.');
        }
        messages.push({ role: 'assistant', content: lastContent });
        if (conversationId) {
          db.prepare('INSERT INTO conversation_messages (conversation_id, role, content, tokens) VALUES (?, ?, ?, ?)')
            .run(conversationId, 'assistant', lastContent, recoveredTokens);
        }
      }
    }

    if (
      !normalizeOutgoingMessage(lastContent, options?.source || null)
      && !messagingSent
      && runMeta?.widgetSnapshotSaved !== true
    ) {
      const explicitNoResponse = (
        runMeta?.noResponse === true
        || options.deliveryState?.noResponse === true
      );
      if (
        (triggerSource === 'schedule' || triggerSource === 'tasks')
        && !explicitNoResponse
      ) {
        throw new Error(
          'Background run ended without producing a result or an explicit no-response decision.',
        );
      }
      if (iteration >= maxIterations) {
        engine.recordRunEvent(userId, runId, 'loop_budget_exhausted', {
          maxIterations,
          stepIndex,
          failedStepCount,
        }, { agentId });
        throw new Error(`Iteration budget exhausted before judged completion after ${maxIterations} iterations.`);
      }
      if (stepIndex > 0 && !lastToolWasMessaging && iteration < maxIterations) {
        throw new Error('Run ended without an explicit completion or blocker reply.');
      }
    }

    const sentMessageText = joinSentMessages(runMeta?.sentMessages);
    const normalizedLastContent = normalizeOutgoingMessage(lastContent, options?.source || null);
    let finalResponseText = messagingSent
      ? (sentMessageText || (normalizedLastContent ? lastContent.trim() : ''))
      : (normalizedLastContent ? lastContent.trim() : sentMessageText);
    const lastFinalDeliveryMessage = normalizeOutgoingMessage(
      runMeta?.lastSentMessage
      || (Array.isArray(runMeta?.sentMessages) ? runMeta.sentMessages[runMeta.sentMessages.length - 1] : '')
      || '',
      options?.source || null
    );

    if (
      options.skipVerifier !== true
      && shouldRunVerifier({
      analysis,
      toolExecutions,
      finalReply: finalResponseText,
    })) {
      const verificationResult = await runWithModelFallback('final verification', () => engine.verifyFinalResponse({
        provider,
        providerName,
        model,
        messages,
        analysis,
        tools,
        toolExecutions,
        finalReply: finalResponseText,
        options: { ...options, runId, userId, agentId },
      }));
      totalTokens += verificationResult.usage || 0;
      verification = verificationResult.verification;
      if (verification.final_reply) {
        finalResponseText = verification.final_reply;
        lastContent = verification.final_reply;
      }

      stepIndex += 1;
      const verificationStepId = uuidv4();
      db.prepare(`INSERT INTO agent_steps
        (id, run_id, step_index, type, description, status, result, started_at, completed_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, datetime('now'), datetime('now'))`)
        .run(
          verificationStepId,
          runId,
          stepIndex,
          'verification',
          'Evidence verification',
          verification.status === 'verified' ? 'completed' : 'failed',
          JSON.stringify(verification).slice(0, 20000)
        );
      engine.persistRunMetadata(runId, {
        verification,
        evidenceSources: verificationResult.evidenceSources,
      });
      engine.emit(userId, 'run:verification', {
        runId,
        ...verification,
        evidenceSources: verificationResult.evidenceSources,
      });
    }

    if (deliverableWorkflow && deliverablePlan) {
      engine.recordRunEvent(userId, runId, 'deliverable_validation_started', {
        type: deliverableWorkflow.selection.type,
        artifactCount: deliverableArtifacts.length,
      }, { agentId });
      const validationResult = await validateDeliverableExecution({
        workflow: deliverableWorkflow.workflow,
        request: deliverableWorkflow.request,
        plan: deliverablePlan,
        finalReply: finalResponseText,
        artifacts: deliverableArtifacts,
        toolExecutions,
        runId,
      });
      deliverableValidation = validationResult.validation;
      engine.persistRunMetadata(runId, {
        deliverable: validationResult.result,
      });
      if (deliverableValidation.status !== 'passed') {
        engine.recordRunEvent(userId, runId, 'deliverable_validation_failed', {
          type: deliverableWorkflow.selection.type,
          errors: deliverableValidation.errors,
          warnings: deliverableValidation.warnings,
        }, { agentId });
        throw new DeliverableValidationError(
          deliverableValidation.summary || `Deliverable validation failed for ${deliverableWorkflow.selection.type}.`,
          {
            validation: deliverableValidation,
            result: validationResult.result,
          },
        );
      }
      await engine.persistDeliverableMemory(userId, runId, agentId, validationResult.result);
      engine.recordRunEvent(userId, runId, 'deliverable_completed', {
        type: deliverableWorkflow.selection.type,
        artifactCount: validationResult.result.artifacts.length,
        summary: validationResult.result.summary,
      }, { agentId });
    }

    if (conversationId) {
      db.prepare('UPDATE conversations SET total_tokens = total_tokens + ?, updated_at = datetime(\'now\') WHERE id = ?')
        .run(totalTokens, conversationId);
      if (options.skipConversationMaintenance !== true) {
        refreshConversationSummary(conversationId, provider, model, historyWindow).catch((err) => {
          console.error('[AI] Conversation summary refresh failed:', err.message);
        });
      }
    }

    await engine.persistPromptMetrics(runId, {
      ...promptMetrics,
      finalTotalTokens: totalTokens
    });

    await engine.persistRunContext(userId, {
      triggerSource,
      runTitle,
      userMessage,
      lastContent: finalResponseText,
      stepIndex,
      skipPersistence: options.skipRunContextPersistence === true
    });

    // Fallback: if this was a messaging-triggered run and no final delivery
    // was already sent in this run, auto-send the final assistant text.
    // Interim progress updates do not suppress this final delivery.
    if (triggerSource === 'messaging' && options.source && options.chatId) {
      if (engine.shouldSendMessagingFinalFallback(runMeta, lastContent || '', options.source) && !lastFinalDeliveryMessage) {
        await engine.deliverMessagingFinalFallback({
          runId,
          userId,
          agentId,
          platform: options.source,
          chatId: options.chatId,
          content: lastContent || '',
        });
      }
    }

    db.prepare('UPDATE agent_runs SET status = ?, total_tokens = ?, final_response = ?, updated_at = datetime(\'now\'), completed_at = datetime(\'now\') WHERE id = ?')
      .run('completed', totalTokens, finalResponseText || null, runId);

    if (conversationId && options.skipConversationMaintenance !== true) {
      await engine.refreshConversationState({
        conversationId,
        runId,
        provider,
        providerName,
        model,
        finalReply: finalResponseText,
        analysis,
        verification,
        historyWindow,
        options: { ...options, userId, agentId },
      }).catch((err) => {
        console.error('[AI] Conversation working state refresh failed:', err.message);
      });
    }

    console.info(
      `[Run ${shortenRunId(runId)}] completed trigger=${triggerSource} steps=${stepIndex} tokens=${totalTokens} durationMs=${runMeta?.startedAt ? Date.now() - runMeta.startedAt : 0} finalResponse=${finalResponseText ? 'yes' : 'no'} sentMessages=${runMeta?.sentMessages?.length || 0}`
    );
    engine.cleanupSubagentsForRun(runId, { cancelRunning: true });
    engine.stopMessagingProgressSupervisor(runId);
    engine.activeRuns.delete(runId);
    engine.emit(userId, 'run:complete', {
      runId,
      content: lastContent,
      totalTokens,
      iterations: iteration,
      triggerSource,
      executionMode: analysis?.mode || 'execute',
      verificationStatus: verification?.status || 'skipped',
    });
    engine.recordRunEvent(userId, runId, 'run_completed', {
      contentPreview: String(finalResponseText || lastContent || '').slice(0, 240),
      totalTokens,
      iterations: iteration,
      triggerSource,
      executionMode: analysis?.mode || 'execute',
      verificationStatus: verification?.status || 'skipped',
    }, { agentId });
    // ── on_loop_end hook ──
    // Fire-and-forget: plugins can use this for self-improvement, memory
    // consolidation, analytics, or other post-run housekeeping.
    if (globalHooks.has('on_loop_end')) {
      globalHooks.run('on_loop_end', {
        userId, runId, agentId, status: 'completed',
        iterations: iteration, totalTokens,
        taskAnalysis: analysis,
        finalContent: finalResponseText,
      }).catch(() => {});
    }
    if (engine.learningManager) {
      try {
        const learningSteps = db.prepare(
          `SELECT tool_name, tool_input, result, status
           FROM agent_steps WHERE run_id = ? ORDER BY step_index ASC`
        ).all(runId);
        engine.learningManager.maybeCaptureDraft({
          userId,
          agentId,
          runId,
          triggerSource,
          triggerType,
          task: userMessage,
          title: runTitle,
          finalContent: finalResponseText || lastContent,
          steps: learningSteps,
        });
      } catch (learningError) {
        console.warn('[Engine] Skill reflection failed:', learningError.message);
      }
    }

    return { runId, content: lastContent, totalTokens, iterations: iteration, status: 'completed' };
  } catch (err) {
    if (engine.isRunStopped(runId)) {
      db.prepare('UPDATE agent_runs SET status = ?, updated_at = datetime(\'now\'), completed_at = datetime(\'now\') WHERE id = ?')
        .run('stopped', runId);
      console.warn(
        `[Run ${shortenRunId(runId)}] stopped trigger=${triggerSource} steps=${stepIndex} tokens=${totalTokens}`
      );
      engine.cleanupSubagentsForRun(runId, { cancelRunning: true });
      engine.stopMessagingProgressSupervisor(runId);
      engine.activeRuns.delete(runId);
      engine.emit(userId, 'run:stopped', { runId, triggerSource });
      engine.recordRunEvent(userId, runId, 'run_stopped', {
        triggerSource,
        totalTokens,
        iterations: iteration,
      }, { agentId });
      return { runId, content: '', totalTokens, iterations: iteration, status: 'stopped' };
    }

    const runMeta = engine.activeRuns.get(runId);
    const retryCount = Number(options.messagingAutonomousRetryCount || 0);
    // Rate-limit errors (429) must not trigger messaging retries: the model
    // won't be available in the milliseconds between retries, so spawning new
    // runs just compounds the rate-limit pressure with no benefit.
    const canRetryMessagingRun = shouldRetryMessagingRun({
      triggerSource,
      options,
      runMeta,
      error: err,
      retryCount,
      retryLimit: engine.getMessagingRetryLimit(maxIterations),
    });

    if (canRetryMessagingRun) {
      const recoveryContext = buildAutonomousRecoveryContext({
        err,
        toolExecutions,
        tools,
        userMessage,
        visibleMessageSent: Boolean(
          runMeta?.lastSentMessage
          || runMeta?.lastInterimMessage
          || runMeta?.messagingSent === true
        ),
      });
      db.prepare('UPDATE agent_runs SET status = ?, error = ?, updated_at = datetime(\'now\') WHERE id = ?')
        .run('retrying', err.message, runId);
      console.warn(
        `[Run ${shortenRunId(runId)}] retrying_messaging_attempt=${retryCount + 1} reason=${summarizeForLog(err.message, 140)}`
      );
      engine.cleanupSubagentsForRun(runId, { cancelRunning: true });
      engine.stopMessagingProgressSupervisor(runId);
      engine.activeRuns.delete(runId);
      engine.emit(userId, 'run:interim', {
        runId,
        message: 'Retrying internally after a transient failure.',
        phase: 'retrying'
      });

      const retryOptions = {
        ...options,
        runId,
        messagingRetryStepOffset: stepIndex,
        messagingAutonomousRetryCount: retryCount + 1,
        messagingRetryState: {
          lastFinalMessage: String(runMeta?.lastSentMessage || options?.messagingRetryState?.lastFinalMessage || '').trim(),
          explicitMessageSent: runMeta?.explicitMessageSent === true || options?.messagingRetryState?.explicitMessageSent === true,
          interimHistory: cloneInterimHistory([
            ...(Array.isArray(options?.messagingRetryState?.interimHistory) ? options.messagingRetryState.interimHistory : []),
            ...(Array.isArray(runMeta?.interimMessages) ? runMeta.interimMessages : []),
          ]),
          goalContract: mergeGoalContracts(
            options?.messagingRetryState?.goalContract || null,
            runMeta?.goalContract || null,
          ),
          lastUserVisibleUpdateAt: runMeta?.progressLedger?.lastUserVisibleUpdateAt || options?.messagingRetryState?.lastUserVisibleUpdateAt || null,
          lastFinalDeliveryAt: runMeta?.progressLedger?.lastFinalDeliveryAt || options?.messagingRetryState?.lastFinalDeliveryAt || null,
          heartbeatCount: Number(runMeta?.progressLedger?.heartbeatCount || options?.messagingRetryState?.heartbeatCount || 0),
          progressState: runMeta?.progressLedger?.progressState || options?.messagingRetryState?.progressState || 'active',
          lastVerifiedProgressAt: runMeta?.progressLedger?.lastVerifiedProgressAt || options?.messagingRetryState?.lastVerifiedProgressAt || null,
        },
        context: {
          ...(options.context || {}),
          additionalContext: [
            options.context?.additionalContext || '',
            recoveryContext,
          ].filter(Boolean).join('\n\n')
        }
      };

      return engine.runWithModel(userId, userMessage, retryOptions, _modelOverride);
    }

    const deliverableFailureResponse = err?.deliverableResult?.summary
      || err?.deliverableValidation?.summary
      || '';
    let messagingFailureContent = '';
    let sendSucceeded = false;
    if (shouldSendMessagingErrorFallback({ triggerSource, options, runMeta })) {
      const manager = engine.messagingManager;
      if (manager) {
        const failureScenario = buildMessagingFailureScenario({
          err,
          failedStepCount,
          stepIndex,
          toolExecutions,
        });
        try {
          const failedMessage = sanitizeConversationMessages([
            ...messages,
            {
              role: 'system',
              content: `The run encountered a runtime error and cannot continue reliably. Use the actual run scenario below to explain the blocker naturally.\n\nScenario:\n${failureScenario || 'No additional scenario details were captured.'}\n\nDo not call tools. Write exactly one short user message. Do not ask the user to resend or restate the same task. Only ask the user for something if a specific external input, permission, or configuration change is actually required. Do not promise future work unless it will happen automatically before this reply is sent.\n\n${buildPlatformFormattingGuide(options?.source || null)}`
            }
          ]);
          const modelReply = await withModelCallTimeout(
            provider.chat(failedMessage, [], {
              model,
              reasoningEffort: engine.getReasoningEffort(providerName, options)
            }),
            options,
            'Messaging failure reply',
          );
          const drafted = sanitizeModelOutput(modelReply.content || '', { model });
          if (normalizeOutgoingMessage(drafted, options?.source || null)) {
            messagingFailureContent = drafted.trim();
          }
        } catch {
          // Fall back to deterministic text below.
        }

        if (!messagingFailureContent) {
          messagingFailureContent = buildDeterministicMessagingErrorReply({
            err,
            failedStepCount,
            stepIndex,
            toolExecutions,
          });
        }

        try {
          const deliveryResult = await manager.sendMessage(
            userId,
            options.source,
            options.chatId,
            messagingFailureContent,
            { runId, agentId },
          );
          requireSuccessfulMessagingDelivery(deliveryResult, 'Messaging failure delivery');
          sendSucceeded = true;
          if (runMeta) {
            runMeta.lastSentMessage = messagingFailureContent;
            if (!Array.isArray(runMeta.sentMessages)) runMeta.sentMessages = [];
            runMeta.sentMessages.push(messagingFailureContent);
          }
          engine.markRunFinalDelivery(runId, messagingFailureContent);
        } catch (sendErr) {
          console.error('[Engine] Messaging error fallback failed:', sendErr.message);
          messagingFailureContent = '';
        }
      }
    }

    db.prepare('UPDATE agent_runs SET status = ?, error = ?, final_response = ?, updated_at = datetime(\'now\') WHERE id = ?')
      .run(
        'failed',
        err.message,
        sendSucceeded
          ? (messagingFailureContent || null)
          : (deliverableFailureResponse || null),
        runId,
      );
    console.error(
      `[Run ${shortenRunId(runId)}] failed trigger=${triggerSource} steps=${stepIndex} tokens=${totalTokens} error=${summarizeForLog(err.message, 180)}`
    );

    engine.cleanupSubagentsForRun(runId, { cancelRunning: true });
    engine.stopMessagingProgressSupervisor(runId);
    engine.activeRuns.delete(runId);
    engine.emit(userId, 'run:error', { runId, error: err.message });
    engine.recordRunEvent(userId, runId, 'run_failed', {
      error: err.message,
      totalTokens,
      iterations: iteration,
      deliverableType: deliverableWorkflow?.selection?.type || null,
    }, { agentId });

    if (messagingFailureContent) {
      return {
        runId,
        content: messagingFailureContent,
        totalTokens,
        iterations: iteration,
        status: 'failed'
      };
    }

    throw err;
  }
}

module.exports = { runConversation };
