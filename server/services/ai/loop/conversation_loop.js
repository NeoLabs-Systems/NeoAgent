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
const { buildLoopPolicy, resolveToolResultLimits, resolveChurnNudgeThreshold } = require('../loopPolicy');
const { globalHooks } = require('../hooks');
const { normalizeCompletionConfidence, shouldAcceptTaskComplete } = require('../completion');
const { enforceRateLimits } = require('../rate_limits');
const { ToolRepetitionGuard } = require('../repetitionGuard');
const { shortenRunId, summarizeForLog } = require('../logFormat');
const {
  normalizeModelSelections,
  resolveModelSelection,
} = require('../model_identity');
const { getProviderForUser } = require('../provider_selector');
const { IterationBudget } = require('./iteration_budget');
const {
  buildBlankAfterToolFailureGuidance,
  buildRecoverableToolFailureGuidance,
  isRecoverableInternalToolFailure,
  shouldContinueAfterBlankToolFailure,
  shouldContinueAfterRecoverableToolFailure,
} = require('./blank_recovery');
const {
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
  buildReadOnlyChurnGuidance,
  isProgressToolCall,
} = require('./progress_classification');
const {
  normalizeOutgoingMessage,
  clampRunContext,
  joinSentMessages,
  buildBlankMessagingReplyPrompt,
  buildMaxIterationWrapupPrompt,
  buildProgressUpdatePrompt,
  buildDeterministicMessagingFallback,
  buildMessagingFailureScenario,
  buildDeterministicMessagingErrorReply,
  buildModelFailureLoopPrompt,
} = require('../messagingFallback');
const { isDeferredWorkReply } = require('../terminal_reply');
const {
  classifyToolExecution,
  gatheredNewEvidence,
  isSubstantiveProgressToolName,
  summarizeProgressToolExecutions,
  summarizeToolExecutions,
  summarizeAvailableTools,
  inferToolFailureMessage,
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
const { isAbortError, throwIfAborted } = require('../../../utils/abort');

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
    eisdir: 'That path is a directory or outside the workspace file-tool boundary. Use list_directory for workspace directories. Keep source files in the shared workspace before reading them with file tools.',
    enoent: 'That path does not exist. Do not keep retrying the same missing file. Locate the correct file first with list_directory/search_files or verify whether the evidence only exists in the user-provided logs.',
    outside_workspace: 'That path is outside the shared workspace. Use the workspace root and its file tools, or rely on the user-provided evidence if the file only exists on another server.',
    bad_cwd: 'The current working directory is wrong for that path. Reconfirm the workspace root with pwd/list_directory before reading files.',
    owner_repo_format: 'The parameter "owner_repo" expects a single combined string like "NeoLabs-Systems/NeoAgent" — not separate owner/repo fields. Pass the full "owner/repo" as one value.',
  };
  if (immediateGuides[key]) {
    const prefix = count > 1 ? `REPEATED ERROR (${count}×): ` : 'ERROR GUIDANCE: ';
    return `${prefix}${immediateGuides[key]}`;
  }

  if (count < 3) return null;
  const guides = {
    outside_workspace: 'read_file/read_files only access the shared workspace. Put the relevant files there, then use read_files/search_files/edit_file instead of repeatedly extracting snippets through shell commands.',
    enoent: 'That path does not exist. Use execute_command with `find . -name "..."` to locate the correct path first.',
    bad_cwd: 'The VM home directory is not ~/. Discover the workspace root with pwd/list_directory and keep working files there so file tools can inspect them.',
    not_found: 'This path or resource was not found. Try listing the parent directory or checking with a broader search first.',
  };
  const guide = guides[key];
  if (!guide) return null;
  return `REPEATED ERROR (${count}×): ${guide}`;
}

const OUTPUT_FINGERPRINT_TOOLS = /^(list_|search_|read_|get_|find_|github_list|github_get|github_search)/;

function fingerprintOutput(toolName, result, toolArgs = {}) {
  const name = String(toolName || '');
  if (
    !name
    || (
      !OUTPUT_FINGERPRINT_TOOLS.test(name)
      && !(name === 'execute_command' && !isProgressToolCall(name, toolArgs))
    )
  ) {
    return null;
  }
  const raw = typeof result === 'string' ? result : JSON.stringify(result ?? '');
  if (raw.length < 200) return null;
  // djb2 hash over first 3000 chars — fast, collision-unlikely for our sizes
  let h = 5381;
  const limit = Math.min(raw.length, 3000);
  for (let i = 0; i < limit; i++) h = ((h << 5) + h) ^ raw.charCodeAt(i);
  return h >>> 0;
}

// Concise list of files/targets the run has already read or searched, so the
// analysis-paralysis nudge can name them and tell the model not to re-read them.
function summarizeReadTargets(toolExecutions = []) {
  const targets = [];
  const seen = new Set();
  for (const item of toolExecutions) {
    if (!item || item.stateChanged) continue; // only read-only steps
    const input = item.input || {};
    let target = '';
    if (Array.isArray(input.files) && input.files.length) {
      target = input.files
        .map((file) => (typeof file === 'string' ? file : file?.path || file?.file_path || ''))
        .filter(Boolean)
        .slice(0, 3)
        .join(', ');
    } else if (typeof input.path === 'string' && input.path.trim()) {
      target = input.path.trim();
    } else if (typeof input.command === 'string') {
      const files = input.command.match(/[\w./-]+\.(?:js|ts|tsx|jsx|py|dart|json|md|kt|c|h|ya?ml|sql|txt|sh)\b/g);
      if (files && files.length) target = [...new Set(files)].slice(0, 2).join(', ');
    } else if (typeof input.query === 'string' && input.query.trim()) {
      target = `search:${input.query.trim().slice(0, 30)}`;
    }
    if (!target) continue;
    const key = target.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    targets.push(target);
    if (targets.length >= 8) break;
  }
  return targets.join('; ');
}

function buildNoProgressWrapupPrompt({ readOnlyCount = 0, alreadyRead = '', platform = null } = {}) {
  return [
    `This is the final turn for this run (no further tool calls; ${Math.max(0, Number(readOnlyCount) || 0)} read-only turns without a state change).`,
    alreadyRead ? `Already gathered: ${alreadyRead}.` : '',
    'Write the answer now from everything you have already gathered in this conversation. Deliver the useful result you DO have — calendar, weather, emails, search findings, whatever was collected — formatted as the actual answer to the original request.',
    'If one part could not be retrieved, still deliver everything else and note the missing part in at most one short clause. Never withhold a useful answer because a single detail is missing.',
    'Only report a pure blocker if you genuinely gathered nothing usable at all. Do not describe the result as unfinished, unconfirmed, "blocked", or "still working" when you have something useful — this IS the final answer.',
    buildMaxIterationWrapupPrompt(platform),
  ].filter(Boolean).join('\n\n');
}

function isDeliveryTerminated(runMeta, deliveryState) {
  return runMeta?.noResponse === true
    || deliveryState?.noResponse === true
    || runMeta?.finalDeliverySent === true
    || deliveryState?.finalDeliverySent === true;
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

async function getFailureFallbackModelId(
  userId,
  agentId,
  currentModelId,
  preferredFallbackId = null,
  failureError = null,
  signal = null,
) {
  const { getSupportedModels } = require('../models');
  const aiSettings = getAiSettings(userId, agentId);
  const models = await getSupportedModels(userId, agentId, { signal });
  const availableModels = models.filter((model) => model.available !== false);
  const configuredEnabledIds = Array.isArray(aiSettings.enabled_models)
    ? aiSettings.enabled_models.map((id) => String(id).trim()).filter(Boolean)
    : [];
  const enabledIds = normalizeModelSelections(availableModels, configuredEnabledIds);
  const pool = configuredEnabledIds.length > 0
    ? availableModels.filter((model) => enabledIds.includes(model.id))
    : availableModels;
  const fallbackSearchPool = pool;
  const currentModel = resolveModelSelection(pool, currentModelId)
    || resolveModelSelection(availableModels, currentModelId);

  // When the failure is a provider-level rate limit, the preferred fallback is
  // likely on the same provider and will hit the same limit. Skip it and prefer
  // a fallback from a different provider instead.
  const isProviderRateLimit = /429|rate.?limit|free-models-per/i.test(String(failureError?.message || ''));

  if (preferredFallbackId && !isProviderRateLimit) {
    const preferred = resolveModelSelection(fallbackSearchPool, preferredFallbackId)
      || resolveModelSelection(availableModels, preferredFallbackId);
    if (preferred && preferred.id !== currentModel?.id) return preferred.id;
  }

  if (currentModel?.provider) {
    const differentProvider = fallbackSearchPool.find((model) =>
      model.id !== currentModel.id && model.provider !== currentModel.provider);
    if (differentProvider) return differentProvider.id;
  }

  // If no different-provider model exists, still try the preferred fallback
  // even on rate limits (it's better than nothing).
  if (preferredFallbackId) {
    const preferred = resolveModelSelection(fallbackSearchPool, preferredFallbackId)
      || resolveModelSelection(availableModels, preferredFallbackId);
    if (preferred && preferred.id !== currentModel?.id) return preferred.id;
  }

  const differentModel = fallbackSearchPool.find((model) => model.id !== currentModel?.id);
  return differentModel?.id || null;
}

function estimateTokenValue(value) {
  if (!value) return 0;
  if (typeof value === 'string') return Math.ceil(value.length / 4);
  return Math.ceil(JSON.stringify(value).length / 4);
}

async function runConversation(engine, userId, userMessage, options = {}, _modelOverride = null) {
  throwIfAborted(options.signal, 'Agent run aborted before startup.');
  const triggerType = options.triggerType || 'user';
  const { resolveAgentId } = require('../../agents/manager');
  const agentId = resolveAgentId(userId, options.agentId || options.agent_id || null);
  ensureDefaultAiSettings(userId, agentId);
  const aiSettings = getAiSettings(userId, agentId);
  const runId = options.runId || uuidv4();
  const conversationId = options.conversationId;
  const app = options.app || engine.app;
  const triggerSource = options.triggerSource || 'web';
  let provider = null;
  let model = null;
  let modelSelectionId = null;
  let providerName = null;
  let messages = [];
  let iteration = 0;
  let totalTokens = 0;
  let lastContent = '';
  let stepIndex = 0;
  let failedStepCount = 0;
  let toolExecutions = [];
  let deliverableWorkflow = null;
  let detachExternalAbort = null;
  const runTitle = generateTitle(userMessage);
  let runRecordCreated = false;
  const timelineService = app?.locals?.timelineService || null;

  const { releaseReservation } = enforceRateLimits(userId, {
    bypass: options.bypassUserRateLimits === true,
  });

  try {
  const historyWindow = Math.max(
    1,
    Number(options.historyWindow || aiSettings.chat_history_window) || aiSettings.chat_history_window,
  );
  // loopPolicy is built after task analysis so analysisMode can be passed in;
  // we build a provisional policy now (with default mode) and rebuild after
  // analysis when the mode is known. See the post-analysis policy rebuild below.
  let loopPolicy = buildLoopPolicy(aiSettings, triggerType, 'execute', options);
  let maxIterations = loopPolicy.maxIterations;
  const initialRunMetadata = buildInitialRunMetadata(options);
  const requestedModel = String(
    _modelOverride
    || (triggerType === 'subagent' ? aiSettings.default_subagent_model : aiSettings.default_chat_model)
    || 'auto',
  ).trim();
  try {
    db.prepare(`INSERT INTO agent_runs(
      id, user_id, agent_id, title, status, trigger_type, trigger_source, model, metadata_json
    ) VALUES(?, ?, ?, ?, 'running', ?, ?, ?, ?)`).run(
      runId,
      userId,
      agentId,
      runTitle,
      triggerType,
      triggerSource,
      requestedModel,
      Object.keys(initialRunMetadata).length ? JSON.stringify(initialRunMetadata) : null,
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
  const startupAbortController = new AbortController();
  engine.activeRuns.set(runId, {
    userId,
    agentId,
    title: runTitle,
    status: 'running',
    aborted: false,
    abortController: startupAbortController,
    pauseAvailable: false,
    toolPids: new Set(),
    subagentDepth: Math.max(0, Number(options.subagentDepth) || 0),
  });
  if (options.signal) {
    const abortFromExternal = () => {
      engine.interruptRun(
        runId,
        String(options.signal.reason || 'Agent run interrupted by its caller.'),
      );
    };
    if (options.signal.aborted) abortFromExternal();
    else options.signal.addEventListener('abort', abortFromExternal, { once: true });
    detachExternalAbort = () => {
      options.signal.removeEventListener('abort', abortFromExternal);
    };
  }
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
    { ...providerStatusConfig, signal: startupAbortController.signal }
  );
  provider = selectedProvider.provider;
  model = selectedProvider.model;
  modelSelectionId = selectedProvider.modelSelectionId;
  providerName = selectedProvider.providerName;
  if (
    startupAbortController.signal.aborted
    || engine.getRunMeta(runId)?.status !== 'running'
  ) {
    const startupError = new Error(
      String(startupAbortController.signal.reason || 'Run stopped during model selection.'),
    );
    startupError.name = 'AbortError';
    startupError.code = 'ABORT_ERR';
    throw startupError;
  }
  db.prepare('UPDATE agent_runs SET model = ?, updated_at = datetime(\'now\') WHERE id = ?')
    .run(modelSelectionId, runId);
  const switchToFallbackModel = async (failedSelectionId, error, phase) => {
    const fallbackModelId = await getFailureFallbackModelId(
      userId,
      agentId,
      failedSelectionId,
      aiSettings.fallback_model_id,
      error,
      engine.getRunMeta(runId)?.abortController?.signal,
    );
    if (!fallbackModelId || fallbackModelId === failedSelectionId) return false;
    console.log(`[Engine] ${phase} failed on ${failedSelectionId}; attempting fallback to: ${fallbackModelId}`);
    engine.emit(userId, 'run:interim', {
      runId,
      message: `Model service failed on ${failedSelectionId}; retrying with ${fallbackModelId}.`,
      phase: 'model_fallback'
    });
    const fallback = await getProviderForUser(
      userId,
      userMessage,
      triggerType === 'subagent',
      fallbackModelId,
      {
        ...providerStatusConfig,
        signal: engine.getRunMeta(runId)?.abortController?.signal,
      }
    );
    provider = fallback.provider;
    model = fallback.model;
    modelSelectionId = fallback.modelSelectionId;
    providerName = fallback.providerName;
    db.prepare('UPDATE agent_runs SET model = ?, updated_at = datetime(\'now\') WHERE id = ?')
      .run(modelSelectionId, runId);
    Object.assign(engine.getRunMeta(runId) || {}, {
      model,
      modelSelectionId,
      providerName,
    });
    return true;
  };
  const runWithModelFallback = async (phase, fn) => {
    try {
      return await fn();
    } catch (err) {
      const failedSelectionId = modelSelectionId;
      const switched = await switchToFallbackModel(failedSelectionId, err, phase);
      if (!switched) throw err;
      return await fn();
    }
  };

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
    model,
    modelSelectionId,
    providerName,
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
    abortController: startupAbortController,
    pauseAvailable: false,
    toolPids: new Set(),
    subagentDepth: Math.max(0, Number(options.subagentDepth) || 0),
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
  engine.emit(userId, 'run:start', {
    runId,
    agentId,
    title: runTitle,
    model,
    modelSelectionId,
    provider: providerName,
    triggerType,
    triggerSource,
  });
  engine.recordRunEvent(userId, runId, 'run_started', {
    title: runTitle,
    model,
    modelSelectionId,
    provider: providerName,
    triggerType,
    triggerSource,
  }, { agentId });
  timelineService?.recordRunLifecycle?.({
    userId,
    agentId,
    runId,
    title: runTitle,
    eventKind: 'run_started',
    status: 'running',
    triggerSource,
  });
  console.info(
    `[Run ${shortenRunId(runId)}] started trigger=${triggerSource} type=${triggerType} model=${modelSelectionId} title=${summarizeForLog(runTitle, 120)}`
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
  const disallowedToolNames = new Set(
    (Array.isArray(options.disallowedToolNames) ? options.disallowedToolNames : [])
      .map((name) => String(name || '').trim())
      .filter(Boolean),
  );
  const allTools = selectToolsForTask(userMessage, builtInTools, mcpTools, options)
    .filter((tool) => !disallowedToolNames.has(tool?.name));
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

  messages = engine.buildContextMessages(systemPrompt, summaryMessage, historyMessages, recallMsg);
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

  iteration = 0;
  totalTokens = 0;
  lastContent = '';
  stepIndex = 0;
  failedStepCount = 0;
  let modelFailureRecoveries = 0;
  let promptMetrics = {};
  toolExecutions = [];
  let compactionMetrics = [];
  let analysis = null;
  let plan = null;

  // Model-authored progress updates: the messaging supervisor calls this to get a
  // dynamic "what I'm doing right now" line instead of a hard-coded string. It runs
  // a tiny tool-less model call over the current run activity. `provider`/`model` are
  // `let` (closure tracks fallbacks) and `toolExecutions` is push-only.
  if (triggerSource === 'messaging') {
    const runMetaForCompose = engine.getRunMeta(runId);
    if (runMetaForCompose) {
      runMetaForCompose.composeProgressUpdate = async ({ stalled = false, signal = null } = {}) => {
        try {
          const rm = engine.getRunMeta(runId);
          const ledger = rm?.progressLedger || {};
          // Real, specific evidence (actual commands + their output) so the update is
          // grounded in what happened, not invented. Bare tool names make a weak model
          // confabulate generic activity ("running the build", "training").
          const recent = summarizeProgressToolExecutions(toolExecutions, 5);
          const currentTool = isSubstantiveProgressToolName(ledger.currentTool)
            ? ledger.currentTool
            : '';
          if (!recent && !currentTool) {
            return '';
          }
          const priorUpdate = String(rm?.lastInterimMessage || '').trim();
          const contextBlock = [
            buildProgressUpdatePrompt(),
            stalled ? 'No verified progress has occurred for the stall threshold. State that fact plainly if it matters; do not reassure, promise continued work, or imply activity beyond the evidence.' : '',
            '',
            `Original request: ${summarizeForLog(userMessage, 320)}`,
            currentTool ? `Doing now: using ${currentTool}` : '',
            recent ? `Actual recent tool activity (newest last) — describe ONLY this, do not extrapolate:\n${recent}` : '',
            priorUpdate ? `Your previous update (say something different): ${summarizeForLog(priorUpdate, 160)}` : '',
          ].filter(Boolean).join('\n');
          // Reuse the run's real system prompt so the update follows the same voice and
          // formatting guidelines as every other message (single source of truth).
          const sysContent = [systemPrompt?.stable, systemPrompt?.dynamic].filter(Boolean).join('\n\n')
            || 'You are a helpful assistant.';
          const resp = await runAbortableModelCall(
            (signal) => provider.chat(
              [
                { role: 'system', content: sysContent },
                { role: 'user', content: contextBlock },
              ],
              [],
              {
                model,
                reasoningEffort: engine.getReasoningEffort(providerName, options),
                signal,
              },
            ),
            {
              ...options,
              signals: [rm?.abortController?.signal, signal],
            },
            'Progress update compose',
          );
          return sanitizeModelOutput(resp.content || '', { model });
        } catch (composeErr) {
          console.warn(`[Run ${shortenRunId(runId)}] progress_update_compose failed: ${summarizeForLog(composeErr?.message || composeErr, 140)}`);
          return '';
        }
      };
    }
  }
  let verification = null;
  deliverableWorkflow = null;
  let deliverablePlan = null;
  let deliverableArtifacts = [];
  let deliverableValidation = null;
  let directAnswerEligible = false;
  let analysisUsage = 0;

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
      includeCoreFileTools: analysis.mode === 'execute' || analysis.mode === 'plan_execute',
    });
    engine.initializeToolRuntime(runId, allTools, tools, options);
    messages.push({
      role: 'system',
      content: [
        '[Available tool catalog]',
        buildToolCatalog(allTools),
        '',
        `Active tools: ${tools.map((tool) => tool.name).join(', ')}`,
        'For workspace file inspection/editing, prefer read_files, read_file, search_files, list_directory, edit_file, replace_file_range, and write_file over shell cat/sed/python snippets. Use execute_command for git, tests, package managers, builds, and other shell-native actions.',
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
            signal: engine.getRunMeta(runId)?.abortController?.signal,
            selectionHint: {
              purpose: requestedPurpose,
              complexity: analysis?.complexity,
              autonomyLevel: analysis?.autonomy_level,
              requiredConfidence: analysis?.completion_confidence_required,
              costMode: aiSettings.cost_mode,
            },
          }
        );
        if (selectedAfterAnalysis.modelSelectionId !== modelSelectionId) {
          provider = selectedAfterAnalysis.provider;
          model = selectedAfterAnalysis.model;
          modelSelectionId = selectedAfterAnalysis.modelSelectionId;
          providerName = selectedAfterAnalysis.providerName;
          db.prepare('UPDATE agent_runs SET model = ?, updated_at = datetime(\'now\') WHERE id = ?')
            .run(modelSelectionId, runId);
          Object.assign(engine.getRunMeta(runId) || {}, {
            model,
            modelSelectionId,
            providerName,
          });
          engine.emit(userId, 'run:interim', {
            runId,
            message: `Switched to ${modelSelectionId} for this run after task analysis.`,
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
    const activeRunMeta = engine.getRunMeta(runId);
    if (activeRunMeta) activeRunMeta.pauseAvailable = !directAnswerEligible;

    while (!directAnswerEligible && iterationBudget.consume()) {
      const lifecycleAtStart = await engine.checkpointLifecycle(runId, 'iteration_boundary', {
        iteration: iterationBudget.used,
        stepIndex,
      });
      if (lifecycleAtStart?.action === 'stop' || lifecycleAtStart?.action === 'interrupt') break;
      if (engine.isRunStopped(runId)) break;
      iteration = iterationBudget.used;

      if (globalHooks.has('on_loop_iteration')) {
        const hookResult = await globalHooks.run('on_loop_iteration', {
          userId,
          runId,
          agentId,
          iteration,
          triggerType,
          triggerSource,
          totalTokens,
          taskAnalysis: analysis,
        });
        if (hookResult?.stop === true) {
          const reason = String(hookResult.reason || 'loop_iteration_hook_stop').slice(0, 200);
          engine.recordRunEvent(userId, runId, 'loop_iteration_stopped', {
            iteration,
            reason,
            stoppedBy: hookResult.stopped_by || hookResult.stoppedBy || null,
          }, { agentId });
          engine.stopRun(runId, reason);
          break;
        }
        const systemSteering = String(hookResult?.systemSteering || hookResult?.system_steering || '').trim();
        if (systemSteering) {
          messages.push({ role: 'system', content: systemSteering });
          engine.recordRunEvent(userId, runId, 'loop_iteration_steering', {
            iteration,
            source: hookResult.source || null,
          }, { agentId });
        }
      }

      const systemSteeringAtLoopStart = engine.applyQueuedSystemSteering(runId, messages);
      messages = systemSteeringAtLoopStart.messages;
      const steeringAtLoopStart = engine.applyQueuedSteering(runId, messages, {
        userId,
        conversationId
      });
      messages = steeringAtLoopStart.messages;
      messages = sanitizeConversationMessages(messages);

      // Analysis-paralysis gate: AI self-assesses at churnNudgeThreshold; hard
      // force-wrap-up fires at maxConsecutiveReadOnlyIterations unconditionally.
      if (analysis.mode === 'execute' || analysis.mode === 'plan_execute') {
        const readOnlyCount = engine.getRunMeta(runId)?.consecutiveReadOnlyIterations || 0;
        const iterMeta = engine.getRunMeta(runId);
        const latestFailedExecution = toolExecutions.length > 0
          ? [...toolExecutions].reverse().find((item) => item && item.ok === false) || null
          : null;

        if (readOnlyCount >= 2) {
          const runGoalCtx = resolveRunGoalContext(engine.getRunMeta(runId), analysis, plan);
          const churnNudgeThreshold = resolveChurnNudgeThreshold(runGoalCtx.goalContract);

          let triggerForceWrapup = false;
          let forceWrapupSource = 'hard_limit';
          let alreadyRead = '';

          if (readOnlyCount >= loopPolicy.maxConsecutiveReadOnlyIterations) {
            if (
              isRecoverableInternalToolFailure(latestFailedExecution)
              && iterMeta
              && iterMeta.recoverableReadOnlyDeferralUsed !== true
            ) {
              iterMeta.recoverableReadOnlyDeferralUsed = true;
              iterMeta.consecutiveReadOnlyIterations = Math.max(0, loopPolicy.maxConsecutiveReadOnlyIterations - 2);
              messages.push({
                role: 'system',
                content: buildRecoverableToolFailureGuidance(toolExecutions),
              });
              engine.recordRunEvent(userId, runId, 'read_only_wrapup_deferred_for_recovery', {
                iteration,
                readOnlyCount,
                toolName: latestFailedExecution?.toolName || null,
              }, { agentId });
              continue;
            }
            alreadyRead = summarizeReadTargets(toolExecutions);
            triggerForceWrapup = true;
          } else if (readOnlyCount >= churnNudgeThreshold) {
            alreadyRead = summarizeReadTargets(toolExecutions);
            let churnResult;
            try {
              churnResult = await engine.assessChurnState({
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
                options: { ...options, triggerSource, runId, userId, agentId },
              });
            } catch (churnErr) {
              console.warn(`[Run ${shortenRunId(runId)}] churn_assessment failed: ${summarizeForLog(churnErr?.message || churnErr, 120)}`);
              churnResult = { assessment: { assessment: 'churn', reason: '' }, usage: 0 };
            }
            totalTokens += churnResult.usage || 0;
            engine.recordRunEvent(userId, runId, 'churn_assessment', {
              assessment: churnResult.assessment.assessment,
              reason: churnResult.assessment.reason,
              readOnlyCount,
              churnNudgeThreshold,
              iteration,
            }, { agentId });

            const churnVerdict = churnResult.assessment.assessment;
            if (churnVerdict === 'blocked') {
              triggerForceWrapup = true;
              forceWrapupSource = 'ai_blocked';
            } else if (churnVerdict === 'progressing') {
              // Model is genuinely on track — partially reset so it gets
              // re-assessed after one more read-only turn rather than immediately.
              const iterMeta = engine.getRunMeta(runId);
              if (iterMeta) {
                iterMeta.consecutiveReadOnlyIterations = Math.max(0, churnNudgeThreshold - 1);
              }
            } else {
              // 'churn' — model acknowledges it is spinning; inject the nudge
              // so it can course-correct in the next iteration.
              messages.push({
                role: 'system',
                content: buildReadOnlyChurnGuidance({ readOnlyCount, alreadyRead }),
              });
            }
          }

          if (triggerForceWrapup) {
            console.warn(
              `[Run ${shortenRunId(runId)}] no_progress_wrapup source=${forceWrapupSource} readOnlyCount=${readOnlyCount}`
            );
            engine.updateRunProgress(runId, {
              currentPhase: 'model',
              currentStep: 'model:no_progress_wrapup',
              currentTool: null,
              currentStepStartedAt: isoNow(),
            });
            let wrapTokens = 0;
            try {
              const wrapResponse = await runAbortableModelCall(
                (signal) => provider.chat(
                  sanitizeConversationMessages([
                    ...messages,
                    {
                      role: 'system',
                      content: buildNoProgressWrapupPrompt({
                        readOnlyCount,
                        alreadyRead,
                        platform: options?.source || null,
                      }),
                    },
                  ]),
                  [],
                  {
                    model,
                    reasoningEffort: engine.getReasoningEffort(providerName, options),
                    signal,
                  },
                ),
                { ...options, signal: engine.getRunMeta(runId)?.abortController?.signal },
                'No-progress wrap-up',
              );
              wrapTokens = wrapResponse.usage?.totalTokens || 0;
              lastContent = sanitizeModelOutput(wrapResponse.content || '', { model });
            } catch (wrapErr) {
              console.warn(`[Run ${shortenRunId(runId)}] no_progress_wrapup failed: ${summarizeForLog(wrapErr?.message || wrapErr, 180)}`);
            }
            totalTokens += wrapTokens;
            const usableWrap = normalizeOutgoingMessage(lastContent, options?.source || null)
              && !isDeferredWorkReply(lastContent);
            if (!usableWrap) {
              lastContent = buildDeterministicMessagingFallback({ failedStepCount, stepIndex, toolExecutions });
            }
            messages.push({ role: 'assistant', content: lastContent });
            if (conversationId) {
              db.prepare('INSERT INTO conversation_messages (conversation_id, role, content, tokens) VALUES (?, ?, ?, ?)')
                .run(conversationId, 'assistant', lastContent, usableWrap ? wrapTokens : 0);
            }
            engine.recordRunEvent(userId, runId, 'no_progress_wrapup_delivered', {
              iteration,
              readOnlyCount,
              source: usableWrap ? 'model' : 'deterministic',
              forceWrapupSource,
              stepIndex,
            }, { agentId });
            // This wrap-up is a forced, tool-less terminal answer: the model had no
            // way to call send_message itself. On automatic background runs the plain
            // result is normally gated, which would silently drop this. Mark it so the
            // task runtime delivers it — a stuck/blocked scheduled task must still
            // surface its result instead of going silent.
            if (
              (triggerSource === 'schedule' || triggerSource === 'tasks')
              && options.deliveryState
              && !engine.activeRuns.get(runId)?.messagingSent
            ) {
              options.deliveryState.terminalWrapup = true;
            }
            directAnswerEligible = true;
            break;
          }
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
        messages = await runAbortableModelCall(
          (signal) => compact(messages, provider, model, contextWindow, { signal }),
          { ...options, signal: engine.getRunMeta(runId)?.abortController?.signal },
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
            options: {
              ...options,
              userId,
              agentId,
              runId,
              phase: 'model_turn',
              signal: engine.getRunMeta(runId)?.abortController?.signal,
            },
            runId,
            iteration,
          });
          response = modelCall.response;
          responseModel = modelCall.responseModel;
          streamContent = modelCall.streamContent;
        } catch (err) {
          console.error(`[Engine] Model call failed (${model}):`, err.message);
          const fallbackModelId = retryForFallback
            ? await getFailureFallbackModelId(
              userId,
              agentId,
              modelSelectionId,
              aiSettings.fallback_model_id,
              err,
              engine.getRunMeta(runId)?.abortController?.signal,
            )
            : null;
          if (fallbackModelId) {
            const failedModel = model;
            console.log(`[Engine] Attempting fallback to: ${fallbackModelId}`);
            const fallback = await getProviderForUser(
              userId,
              userMessage,
              triggerType === 'subagent',
              fallbackModelId,
              {
                ...providerStatusConfig,
                signal: engine.getRunMeta(runId)?.abortController?.signal,
              }
            );
            provider = fallback.provider;
            model = fallback.model;
            modelSelectionId = fallback.modelSelectionId;
            providerName = fallback.providerName;
            db.prepare('UPDATE agent_runs SET model = ?, updated_at = datetime(\'now\') WHERE id = ?')
              .run(modelSelectionId, runId);
            Object.assign(engine.getRunMeta(runId) || {}, {
              model,
              modelSelectionId,
              providerName,
            });

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
              options: {
                ...options,
                userId,
                agentId,
                runId,
                phase: 'model_turn_fallback',
                signal: engine.getRunMeta(runId)?.abortController?.signal,
              },
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
        const lifecycleAbort = err?.name === 'AbortError'
          || err?.code === 'ABORT_ERR'
          || /abort/i.test(String(err?.name || ''))
          || engine.getRunMeta(runId)?.abortController?.signal?.aborted === true;
        const lifecycleControl = await engine.checkpointLifecycle(runId, 'model_boundary', {
          iteration,
          stepIndex,
        });
        if (engine.isRunStopped(runId)) break;
        if (lifecycleAbort && !lifecycleControl && engine.getRunMeta(runId)?.status === 'running') {
          iterationBudget.refund();
          iteration = iterationBudget.used;
          continue;
        }
        if (lifecycleControl?.action === 'stop' || lifecycleControl?.action === 'interrupt') break;
        const modelError = String(err?.message || 'Model call failed');

        if (modelFailureRecoveries < loopPolicy.maxModelFailureRecoveries) {
          const failedModel = model;
          const switched = await switchToFallbackModel(modelSelectionId, err, 'model turn');
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

      const lifecycleAfterModel = await engine.checkpointLifecycle(runId, 'model_boundary', {
        iteration,
        stepIndex,
      });
      if (lifecycleAfterModel?.action === 'stop' || lifecycleAfterModel?.action === 'interrupt') break;

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
        if (shouldContinueAfterRecoverableToolFailure({
          lastContent,
          remainingIterations: iterationBudget.remaining,
          toolExecutions,
        })) {
          engine.recordRunEvent(userId, runId, 'recoverable_tool_failure_continued', {
            iteration,
            remainingIterations: iterationBudget.remaining,
          }, { agentId });
          messages.push({
            role: 'system',
            content: buildRecoverableToolFailureGuidance(toolExecutions),
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
        && response.toolCalls.every((toolCall) => engine.isReadOnlyToolCall(
          toolCall,
          tools.find((tool) => tool?.name === toolCall?.function?.name) || null,
        ))
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
        const lifecycleAfterBatch = await engine.checkpointLifecycle(runId, 'tool_boundary', {
          iteration,
          stepIndex: batch.endingStepIndex,
        });
        if (lifecycleAfterBatch?.action === 'stop' || lifecycleAfterBatch?.action === 'interrupt') break;
        stepIndex = batch.endingStepIndex;
        let batchGatheredNewEvidence = false;
        for (const item of batch.results) {
          const execution = classifyToolExecution(
            item.toolName,
            item.toolArgs,
            item.result,
            item.error || '',
            tools.find((tool) => tool?.name === item.toolName) || null,
          );
          execution.input = item.toolArgs;
          execution.artifacts = await extractArtifactsFromResult(item.toolName, item.result);
          toolExecutions.push(execution);
          const observation = engine.getRunMeta(runId)?.repetitionGuard?.observe(item.toolName, item.toolArgs, item.result);
          if (gatheredNewEvidence(execution, observation)) batchGatheredNewEvidence = true;
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
          verified: batchGatheredNewEvidence,
        });
        if (analysis.mode === 'execute' || analysis.mode === 'plan_execute') {
          const iterMeta = engine.getRunMeta(runId);
          if (iterMeta) {
            iterMeta.consecutiveReadOnlyIterations = batchGatheredNewEvidence
              ? 0
              : (iterMeta.consecutiveReadOnlyIterations || 0) + 1;
          }
        }
        continue;
      }

      let iterationConcreteProgress = false;
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
        let toolInterruptedForPause = false;
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
            signal: engine.getRunMeta(runId)?.abortController?.signal,
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
          const currentRunMeta = engine.getRunMeta(runId);
          toolInterruptedForPause = currentRunMeta?.status === 'pausing'
            && currentRunMeta.abortController?.signal?.aborted === true;
          toolErrorMessage = toolInterruptedForPause
            ? 'The tool was interrupted for pause after dispatch; its external outcome is unknown.'
            : String(err.message || 'Tool execution failed');
          toolResult = toolInterruptedForPause
            ? { status: 'outcome_unknown', error: toolErrorMessage }
            : { error: err.message };
          if (!toolInterruptedForPause) failedStepCount++;
          engine.detachProcessFromRun(runId, toolResult?.pid);
          db.prepare('UPDATE agent_steps SET status = ?, error = ?, completed_at = datetime(\'now\') WHERE id = ?')
            .run(toolInterruptedForPause ? 'paused' : 'failed', toolErrorMessage, stepId);
          engine.emit(userId, 'run:tool_end', {
            runId,
            stepId,
            toolName,
            error: toolErrorMessage,
            status: toolInterruptedForPause ? 'paused' : 'failed',
          });
          engine.recordRunEvent(userId, runId, toolInterruptedForPause ? 'tool_paused' : 'tool_failed', {
            toolName,
            status: toolInterruptedForPause ? 'paused' : 'failed',
            error: toolErrorMessage,
            durationMs: Date.now() - stepStartedAt,
          }, { agentId, stepId });
          console.warn(
            `[Run ${shortenRunId(runId)}] step=${stepIndex} failed tool=${toolName} durationMs=${Date.now() - stepStartedAt} error=${summarizeForLog(err.message, 160)}`
          );
        }

        const lifecycleAfterTool = await engine.checkpointLifecycle(runId, 'tool_boundary', {
          iteration,
          stepIndex,
        });
        if (lifecycleAfterTool?.action === 'stop' || lifecycleAfterTool?.action === 'interrupt') break;

        const execution = classifyToolExecution(
          toolName,
          toolArgs,
          toolResult,
          toolErrorMessage,
          tools.find((tool) => tool?.name === toolName) || null,
        );
        execution.input = toolArgs;
        const repetitionObservation = repetitionGuard?.observe(toolName, toolArgs, toolResult);
        const toolMadeConcreteProgress = (
          (execution.stateChanged && isProgressToolCall(toolName, toolArgs))
          || gatheredNewEvidence(execution, repetitionObservation)
        );
        if (toolMadeConcreteProgress) {
          iterationConcreteProgress = true;
        }
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

        if (toolInterruptedForPause) {
          consecutiveToolFailures = 0;
          messages.push({
            role: 'system',
            content: `The outcome of "${toolName}" is unknown because pause interrupted it after dispatch. Do not repeat the call. First inspect or query the affected state with a safe read-only tool, then continue based on verified evidence.`,
          });
        } else if (toolErrorMessage) {
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
            const fp = fingerprintOutput(toolName, toolResult, toolArgs);
            if (fp !== null && currentRunMeta?.seenOutputHashes) {
              const prior = currentRunMeta.seenOutputHashes.get(fp);
              if (prior) {
                messages.push({
                  role: 'system',
                  content: `DUPLICATE DATA: This response is identical to what "${prior.toolName}" returned in iteration ${prior.iteration}. You already have this information. Stop fetching and use what you have — proceed to the next concrete action.`,
                });
              } else {
                currentRunMeta.seenOutputHashes.set(fp, { toolName, iteration });
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
          verified: toolMadeConcreteProgress,
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
        if (isDeliveryTerminated(runMeta, options.deliveryState)) {
          break;
        }
      }

      // Update analysis-paralysis counter after each iteration's tool calls.
      // Resets to 0 when any progress tool was called; otherwise increments.
      if (!directAnswerEligible && response?.toolCalls?.length > 0
        && (analysis.mode === 'execute' || analysis.mode === 'plan_execute')) {
        const iterMeta = engine.getRunMeta(runId);
        if (iterMeta) {
          iterMeta.consecutiveReadOnlyIterations = iterationConcreteProgress
            ? 0
            : (iterMeta.consecutiveReadOnlyIterations || 0) + 1;
        }
      }

      if (engine.isRunStopped(runId)) break;
      if (engine.getRunMeta(runId)?.terminalInterim) break;
      if (isDeliveryTerminated(engine.getRunMeta(runId), options.deliveryState)) break;
      if (engine.getRunMeta(runId)?.widgetSnapshotSaved) break;
      if (!engine.activeRuns.has(runId)) break;
    }

    const finalizingRunMeta = engine.getRunMeta(runId);
    if (finalizingRunMeta) finalizingRunMeta.pauseAvailable = false;

    if (engine.isRunStopped(runId)) {
      const stoppedRunMeta = engine.getRunMeta(runId);
      const persistedTerminal = db.prepare(
        'SELECT status, error FROM agent_runs WHERE id = ?',
      ).get(runId);
      const terminalStatus = persistedTerminal?.status === 'interrupted'
        || stoppedRunMeta?.status === 'interrupted'
        ? 'interrupted'
        : 'stopped';
      const stopReason = stoppedRunMeta?.stopReason || null;
      console.warn(
        `[Run ${shortenRunId(runId)}] ${terminalStatus} trigger=${triggerSource} steps=${stepIndex} tokens=${totalTokens}`
      );
      await engine.cleanupSubagentsForRun(runId, { cancelRunning: true });
      engine.stopMessagingProgressSupervisor(runId);
      engine.activeRuns.delete(runId);
      engine.emit(userId, terminalStatus === 'interrupted' ? 'run:interrupted' : 'run:stopped', {
        runId,
        triggerSource,
        reason: stopReason,
      });
      engine.recordRunEvent(
        userId,
        runId,
        terminalStatus === 'interrupted' ? 'run_interrupted' : 'run_stopped',
        {
          triggerSource,
          totalTokens,
          iterations: iteration,
          reason: stopReason,
        },
        { agentId },
      );
      return { runId, content: '', totalTokens, iterations: iteration, status: terminalStatus };
    }

    const runMeta = engine.activeRuns.get(runId);
    if (runMeta?.terminalInterim) {
      lastContent = '';
    }
    if (runMeta?.widgetSnapshotSaved && !lastContent) {
      lastContent = 'Widget snapshot updated.';
    }
    const messagingSent = runMeta?.messagingSent || false;
    const stagedProactiveReply = normalizeOutgoingMessage(
      runMeta?.stagedProactiveMessage?.content
      || options?.deliveryState?.stagedProactiveMessage?.content
      || '',
      options?.source || null,
    );
    const lastToolWasMessaging = runMeta?.lastToolName === 'send_message' || runMeta?.lastToolName === 'make_call';

    // Hermes _handle_max_iterations: if the run exhausted its step budget without a
    // judged completion, the model's last text is usually a mid-thought fragment
    // ("let me inline everything:"). Do one tool-less wrap-up call so the user gets a
    // real final answer instead of that fragment.
    const budgetExhaustedWithoutCompletion = triggerSource === 'messaging'
      && !directAnswerEligible
      && !messagingSent
      && !runMeta?.terminalInterim
      && iteration >= maxIterations;
    if (budgetExhaustedWithoutCompletion) {
      console.warn(`[Run ${shortenRunId(runId)}] max_iteration_wrapup model=${model} iteration=${iteration}/${maxIterations}`);
      try {
        const wrapResponse = await runAbortableModelCall(
          (signal) => provider.chat(
            sanitizeConversationMessages([
              ...messages,
              { role: 'system', content: buildMaxIterationWrapupPrompt(options?.source || null) },
            ]),
            [],
            {
              model,
              reasoningEffort: engine.getReasoningEffort(providerName, options),
              signal,
            },
          ),
          { ...options, signal: engine.getRunMeta(runId)?.abortController?.signal },
          'Max-iteration wrap-up',
        );
        totalTokens += wrapResponse.usage?.totalTokens || 0;
        const wrapText = sanitizeModelOutput(wrapResponse.content || '', { model });
        // On budget exhaustion the model's last text is an untrustworthy mid-thought
        // fragment. Replace it with the wrap-up answer, or a clean deterministic
        // fallback if the wrap-up came back empty — never deliver the fragment.
        const usableWrap = normalizeOutgoingMessage(wrapText, options?.source || null)
          && !isDeferredWorkReply(wrapText);
        lastContent = usableWrap
          ? wrapText
          : buildDeterministicMessagingFallback({ failedStepCount, stepIndex, toolExecutions });
        messages.push({ role: 'assistant', content: lastContent });
        if (conversationId) {
          db.prepare('INSERT INTO conversation_messages (conversation_id, role, content, tokens) VALUES (?, ?, ?, ?)')
            .run(conversationId, 'assistant', lastContent, usableWrap ? (wrapResponse.usage?.totalTokens || 0) : 0);
        }
        engine.recordRunEvent(userId, runId, 'max_iteration_wrapup_delivered', {
          iteration, maxIterations, stepIndex, source: usableWrap ? 'model' : 'deterministic',
        }, { agentId });
      } catch (wrapErr) {
        console.warn(`[Run ${shortenRunId(runId)}] max_iteration_wrapup failed: ${summarizeForLog(wrapErr?.message || wrapErr, 180)}`);
        lastContent = buildDeterministicMessagingFallback({ failedStepCount, stepIndex, toolExecutions });
        messages.push({ role: 'assistant', content: lastContent });
      }
    }

    if (triggerSource === 'messaging' && !normalizeOutgoingMessage(lastContent, options?.source || null) && !messagingSent) {
      // Simplified blank reply recovery: one model call with direct instruction,
      // then fall back to a deterministic message. No multi-attempt LLM loop.
      console.warn(`[Run ${shortenRunId(runId)}] blank_reply_recovery model=${model}`);
      let recoveredTokens = 0;
      try {
        const recoveryResponse = await runAbortableModelCall(
          (signal) => provider.chat(
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
              reasoningEffort: engine.getReasoningEffort(providerName, options),
              signal,
            }
          ),
          { ...options, signal: engine.getRunMeta(runId)?.abortController?.signal },
          'Blank messaging reply recovery',
        );
        recoveredTokens = recoveryResponse.usage?.totalTokens || 0;
        lastContent = sanitizeModelOutput(recoveryResponse.content || '', { model });
      } catch (recoverErr) {
        console.warn(`[Run ${shortenRunId(runId)}] blank_reply_recovery failed: ${summarizeForLog(recoverErr?.message || recoverErr, 180)}`);
      }
      totalTokens += recoveredTokens;
      // The loop has already exited, so we cannot keep working: deliver the model's
      // own wrap-up (it summarizes what it tried / where it got blocked from the run
      // evidence) instead of second-guessing it into a generic blob. Only fall back to
      // a deterministic message when the model returned nothing usable.
      const recoveredVisible = Boolean(
        normalizeOutgoingMessage(lastContent, options?.source || null)
        && !isDeferredWorkReply(lastContent),
      );
      if (!recoveredVisible) {
        lastContent = buildDeterministicMessagingFallback({ failedStepCount, stepIndex, toolExecutions });
      }
      if (normalizeOutgoingMessage(lastContent, options?.source || null)) {
        engine.recordRunEvent(userId, runId, 'blank_reply_recovery_delivered', {
          source: recoveredVisible ? 'model' : 'deterministic',
          stepIndex,
          failedStepCount,
        }, { agentId });
        messages.push({ role: 'assistant', content: lastContent });
        if (conversationId) {
          db.prepare('INSERT INTO conversation_messages (conversation_id, role, content, tokens) VALUES (?, ?, ?, ?)')
            .run(conversationId, 'assistant', lastContent, recoveredVisible ? recoveredTokens : 0);
        }
      }
    }

    const lifecycleBeforeFinalize = await engine.checkpointLifecycle(runId, 'finalization_boundary', {
      iteration,
      stepIndex,
    });
    if (
      engine.isRunStopped(runId)
      || lifecycleBeforeFinalize?.action === 'stop'
      || lifecycleBeforeFinalize?.action === 'interrupt'
    ) {
      const terminal = db.prepare('SELECT status FROM agent_runs WHERE id = ?').get(runId)?.status || 'stopped';
      await engine.cleanupSubagentsForRun(runId, { cancelRunning: true });
      engine.stopMessagingProgressSupervisor(runId);
      engine.activeRuns.delete(runId);
      return { runId, content: '', totalTokens, iterations: iteration, status: terminal };
    }

    if (
      !normalizeOutgoingMessage(lastContent, options?.source || null)
      && !messagingSent
      && !stagedProactiveReply
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
        if (triggerSource === 'messaging') {
          lastContent = buildDeterministicMessagingFallback({ failedStepCount, stepIndex, toolExecutions });
          messages.push({ role: 'assistant', content: lastContent });
          if (conversationId) {
            db.prepare('INSERT INTO conversation_messages (conversation_id, role, content, tokens) VALUES (?, ?, ?, ?)')
              .run(conversationId, 'assistant', lastContent, 0);
          }
        } else {
          throw new Error(`Iteration budget exhausted before judged completion after ${maxIterations} iterations.`);
        }
      }
      if (stepIndex > 0 && !lastToolWasMessaging && iteration < maxIterations) {
        if (triggerSource === 'messaging') {
          lastContent = buildDeterministicMessagingFallback({ failedStepCount, stepIndex, toolExecutions });
          messages.push({ role: 'assistant', content: lastContent });
          if (conversationId) {
            db.prepare('INSERT INTO conversation_messages (conversation_id, role, content, tokens) VALUES (?, ?, ?, ?)')
              .run(conversationId, 'assistant', lastContent, 0);
          }
        } else {
          throw new Error('Run ended without an explicit completion or blocker reply.');
        }
      }
    }

    const sentMessageText = joinSentMessages(runMeta?.sentMessages);
    const normalizedLastContent = normalizeOutgoingMessage(lastContent, options?.source || null);
    let finalResponseText = messagingSent
      ? (sentMessageText || (normalizedLastContent ? lastContent.trim() : ''))
      : (normalizedLastContent ? lastContent.trim() : (stagedProactiveReply || sentMessageText));
    const lastFinalDeliveryMessage = normalizeOutgoingMessage(
      runMeta?.lastSentMessage
      || (Array.isArray(runMeta?.sentMessages) ? runMeta.sentMessages[runMeta.sentMessages.length - 1] : '')
      || runMeta?.stagedProactiveMessage?.content
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

    if (!messagingSent && isDeferredWorkReply(finalResponseText)) {
      engine.recordRunEvent(userId, runId, 'non_terminal_final_reply_rejected', {
        iteration,
        contentPreview: String(finalResponseText || '').slice(0, 240),
      }, { agentId });
      finalResponseText = buildDeterministicMessagingFallback({
        failedStepCount,
        stepIndex,
        toolExecutions,
      });
      lastContent = finalResponseText;
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
        engine.trackBackgroundTask(
          (signal) => refreshConversationSummary(
            conversationId,
            provider,
            model,
            historyWindow,
            false,
            { signal },
          ),
          {
            key: `conversation-summary:${conversationId}`,
            signal: runMeta?.abortController?.signal || null,
          },
        ).catch((err) => {
          if (!isAbortError(err, runMeta?.abortController?.signal) && !engine.shuttingDown) {
            console.error('[AI] Conversation summary refresh failed:', err.message);
          }
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
    await engine.stopMessagingProgressSupervisor(runId);
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

    const completionWon = engine.completeRun(runId, {
      totalTokens,
      finalResponse: finalResponseText || null,
    });
    if (!completionWon) {
      const terminal = db.prepare('SELECT status FROM agent_runs WHERE id = ?').get(runId)?.status || 'stopped';
      await engine.cleanupSubagentsForRun(runId, { cancelRunning: true });
      engine.stopMessagingProgressSupervisor(runId);
      engine.activeRuns.delete(runId);
      return { runId, content: '', totalTokens, iterations: iteration, status: terminal };
    }

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
        options: {
          ...options,
          userId,
          agentId,
          signal: engine.getRunMeta(runId)?.abortController?.signal || null,
        },
      }).catch((err) => {
        console.error('[AI] Conversation working state refresh failed:', err.message);
      });
    }

    console.info(
      `[Run ${shortenRunId(runId)}] completed trigger=${triggerSource} steps=${stepIndex} tokens=${totalTokens} durationMs=${runMeta?.startedAt ? Date.now() - runMeta.startedAt : 0} finalResponse=${finalResponseText ? 'yes' : 'no'} sentMessages=${runMeta?.sentMessages?.length || 0}`
    );
    await engine.cleanupSubagentsForRun(runId, { cancelRunning: true });
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
    timelineService?.recordRunLifecycle?.({
      userId,
      agentId,
      runId,
      title: runTitle,
      eventKind: 'run_completed',
      status: 'completed',
      triggerSource,
    });
    // ── on_loop_end hook ──
    // Fire-and-forget: plugins can use this for self-improvement, memory
    // consolidation, analytics, or other post-run housekeeping.
    if (globalHooks.has('on_loop_end')) {
      engine.trackBackgroundTask(
        (signal) => globalHooks.run('on_loop_end', {
          userId, runId, agentId, status: 'completed',
          iterations: iteration, totalTokens,
          taskAnalysis: analysis,
          finalContent: finalResponseText,
          signal,
        }),
        { signal: runMeta?.abortController?.signal || null },
      ).catch(() => {});
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
    if (!runRecordCreated) throw err;
    if (engine.isRunStopped(runId)) {
      const stoppedRunMeta = engine.getRunMeta(runId);
      const persistedTerminal = db.prepare(
        'SELECT status, error FROM agent_runs WHERE id = ?',
      ).get(runId);
      const terminalStatus = persistedTerminal?.status === 'interrupted'
        || stoppedRunMeta?.status === 'interrupted'
        ? 'interrupted'
        : 'stopped';
      console.warn(
        `[Run ${shortenRunId(runId)}] ${terminalStatus} trigger=${triggerSource} steps=${stepIndex} tokens=${totalTokens}`
      );
      await engine.cleanupSubagentsForRun(runId, { cancelRunning: true });
      engine.stopMessagingProgressSupervisor(runId);
      engine.activeRuns.delete(runId);
      engine.emit(userId, terminalStatus === 'interrupted' ? 'run:interrupted' : 'run:stopped', {
        runId,
        triggerSource,
        reason: stoppedRunMeta?.stopReason || persistedTerminal?.error || null,
      });
      engine.recordRunEvent(userId, terminalStatus === 'interrupted' ? 'run_interrupted' : 'run_stopped', {
        triggerSource,
        totalTokens,
        iterations: iteration,
      }, { agentId });
      return { runId, content: '', totalTokens, iterations: iteration, status: terminalStatus };
    }

    const runMeta = engine.activeRuns.get(runId);
    await engine.stopMessagingProgressSupervisor(runId);

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
          const modelReply = await runAbortableModelCall(
            (signal) => provider.chat(failedMessage, [], {
              model,
              reasoningEffort: engine.getReasoningEffort(providerName, options),
              signal,
            }),
            { ...options, signal: runMeta?.abortController?.signal },
            'Messaging failure reply',
          );
          const drafted = sanitizeModelOutput(modelReply.content || '', { model });
          if (
            normalizeOutgoingMessage(drafted, options?.source || null)
            && !isDeferredWorkReply(drafted)
          ) {
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
            {
              runId,
              agentId,
              signal: runMeta?.abortController?.signal || null,
            },
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

    const failureWon = engine.failRun(runId, {
      error: err.message,
      finalResponse: sendSucceeded
        ? (messagingFailureContent || null)
        : (deliverableFailureResponse || null),
      totalTokens,
    });
    if (!failureWon) {
      await engine.cleanupSubagentsForRun(runId, { cancelRunning: true });
      engine.stopMessagingProgressSupervisor(runId);
      engine.activeRuns.delete(runId);
      const terminal = db.prepare('SELECT status FROM agent_runs WHERE id = ?').get(runId)?.status || 'stopped';
      return { runId, content: '', totalTokens, iterations: iteration, status: terminal };
    }
    console.error(
      `[Run ${shortenRunId(runId)}] failed trigger=${triggerSource} steps=${stepIndex} tokens=${totalTokens} error=${summarizeForLog(err.message, 180)}`
    );

    await engine.cleanupSubagentsForRun(runId, { cancelRunning: true });
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
  } finally {
    detachExternalAbort?.();
    releaseReservation();
  }
}

module.exports = {
  getFailureFallbackModelId,
  runConversation,
};
