const { v4: uuidv4 } = require('uuid');
const fs = require('fs');
const db = require('../../db/database');
const { compact } = require('./compaction');
const { compactPayloadForModel } = require('./preModelCompaction');
const {
  getConversationContext,
  buildSummaryCarrier,
  refreshConversationSummary,
  sanitizeConversationMessages
} = require('./history');
const { ensureDefaultAiSettings, getAiSettings } = require('./settings');
const {
  activateTools,
  buildToolCatalog,
  selectInitialTools,
  selectToolsForTask,
} = require('./toolSelector');
const { compactToolResult } = require('./toolResult');
const { salvageTextToolCalls } = require('./toolCallSalvage');
const { sanitizeModelOutput } = require('./outputSanitizer');
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
} = require('./taskAnalysis');
const { getCapabilityHealth, summarizeCapabilityHealth } = require('./capabilityHealth');
const {
  buildPlatformFormattingGuide,
  splitOutgoingMessageForPlatform,
} = require('../messaging/formatting_guides');
const {
  buildInterimMetadata,
  buildInterimSignature,
  normalizeInterimKind,
} = require('./interim');
const { recordRunEvent } = require('./runEvents');
const {
  buildDeliverableWorkflowGuidance,
  DeliverableValidationError,
  extractArtifactsFromResult,
  getDeliverableWorkflow,
  selectDeliverableWorkflow,
  validateDeliverableExecution,
} = require('./deliverables');
const { buildLoopPolicy, resolveToolResultLimits } = require('./loopPolicy');
const { globalHooks } = require('./hooks');
const { withProviderRetry, isTransientError } = require('./providerRetry');
const { normalizeCompletionConfidence, shouldAcceptTaskComplete } = require('./completion');
const { normalizeUsage, recordModelUsage } = require('./usage');
const { enforceRateLimits } = require('./rate_limits');
const { ToolRepetitionGuard } = require('./repetitionGuard');
const { shortenRunId, summarizeForLog, parseMaybeJson } = require('./logFormat');
const {
  normalizeOutgoingMessage,
  clampRunContext,
  joinSentMessages,
  normalizeInterimText,
  buildBlankMessagingReplyPrompt,
  buildDeterministicMessagingFallback,
  buildMessagingFailureScenario,
  buildDeterministicMessagingErrorReply,
  buildModelFailureLoopPrompt,
} = require('./messagingFallback');
const {
  classifyToolExecution,
  summarizeToolExecutions,
  summarizeAvailableTools,
  inferToolFailureMessage,
  buildAutonomousRecoveryContext,
} = require('./toolEvidence');
const {
  buildMemoryConsolidationInstructions,
  normalizeMemoryCandidates,
} = require('../memory/consolidation');
const {
  buildPlannerPrompt,
  buildRerankerPrompt,
  mergeRetrievalResults,
  normalizeRerankResult,
  normalizeRetrievalPlan,
  shouldEnhanceRetrieval,
} = require('../memory/retrieval_reasoning');

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

const MESSAGING_PROGRESS_FIRST_UPDATE_MS = 60 * 1000;
const MESSAGING_PROGRESS_REPEAT_MS = 90 * 1000;
const MESSAGING_PROGRESS_STALL_MS = 240 * 1000;
const MESSAGING_PROGRESS_TICK_MS = 15 * 1000;
const GOAL_CONTRACT_SUCCESS_CRITERIA_LIMIT = 12;
const MODEL_CALL_TIMEOUT_MS = 5 * 60 * 1000;

function isoNow() {
  return new Date().toISOString();
}

function timestampMs(value, fallback = 0) {
  const resolved = value ? Date.parse(value) : NaN;
  return Number.isFinite(resolved) ? resolved : fallback;
}

function formatElapsedDuration(durationMs) {
  const totalSeconds = Math.max(1, Math.floor(Number(durationMs || 0) / 1000));
  if (totalSeconds < 60) return `${totalSeconds}s`;
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  if (seconds === 0) return `${minutes}m`;
  return `${minutes}m ${seconds}s`;
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

function buildInitialProgressLedger({ startedAt, retryState = {} } = {}) {
  const startedAtIso = startedAt || isoNow();
  const interimHistory = cloneInterimHistory(retryState.interimHistory);
  const lastInterimMessage = interimHistory[interimHistory.length - 1]?.content || '';
  const lastVisibleAt = retryState.lastUserVisibleUpdateAt || (lastInterimMessage ? startedAtIso : null);
  return {
    currentStep: retryState.currentStep || null,
    currentTool: retryState.currentTool || null,
    currentStepStartedAt: retryState.currentStepStartedAt || null,
    lastVerifiedProgressAt: retryState.lastVerifiedProgressAt || startedAtIso,
    lastUserVisibleUpdateAt: lastVisibleAt,
    lastFinalDeliveryAt: retryState.lastFinalDeliveryAt || null,
    heartbeatCount: Number(retryState.heartbeatCount || 0),
    stallNotifiedAt: retryState.stallNotifiedAt || null,
    progressState: retryState.progressState || 'active',
    currentPhase: retryState.currentPhase || 'idle',
  };
}

function hasVisibleInterimActivity(runMeta) {
  return Boolean(
    runMeta?.lastInterimMessage
    || (Array.isArray(runMeta?.interimMessages) && runMeta.interimMessages.length > 0)
    || Number(runMeta?.progressLedger?.heartbeatCount || 0) > 0
  );
}

function requireSuccessfulMessagingDelivery(result, label = 'Messaging delivery') {
  if (result?.success === true && result?.suppressed !== true) {
    return result;
  }
  const reason = String(
    result?.error
    || result?.reason
    || result?.result?.error
    || result?.result?.reason
    || 'the platform did not confirm delivery',
  ).trim();
  const error = new Error(`${label} failed: ${reason}`);
  error.code = 'MESSAGING_DELIVERY_FAILED';
  error.deliveryResult = result || null;
  throw error;
}

function normalizeGoalCriteria(value) {
  if (!Array.isArray(value)) return [];
  const seen = new Set();
  const items = [];
  for (const entry of value) {
    const text = String(entry || '').trim();
    if (!text) continue;
    const signature = text.toLowerCase();
    if (seen.has(signature)) continue;
    seen.add(signature);
    items.push(text);
    if (items.length >= GOAL_CONTRACT_SUCCESS_CRITERIA_LIMIT) break;
  }
  return items;
}

function normalizeGoalContract(raw = null) {
  if (!raw || typeof raw !== 'object') return null;
  const goal = String(raw.goal || '').trim();
  const successCriteria = normalizeGoalCriteria(
    raw.successCriteria || raw.success_criteria || [],
  );
  const rawCompletionConfidence = String(
    raw.completionConfidenceRequired || raw.completion_confidence_required || '',
  ).trim();
  const completionConfidenceRequired = rawCompletionConfidence
    ? normalizeCompletionConfidence(rawCompletionConfidence)
    : '';
  const progressUpdatePolicy = ['none', 'optional', 'required'].includes(String(
    raw.progressUpdatePolicy || raw.progress_update_policy || '',
  ).trim().toLowerCase())
    ? String(raw.progressUpdatePolicy || raw.progress_update_policy || '').trim().toLowerCase()
    : '';
  const autonomyLevel = ['minimal', 'normal', 'high'].includes(String(
    raw.autonomyLevel || raw.autonomy_level || '',
  ).trim().toLowerCase())
    ? String(raw.autonomyLevel || raw.autonomy_level || '').trim().toLowerCase()
    : '';
  const complexity = ['simple', 'standard', 'complex'].includes(String(
    raw.complexity || '',
  ).trim().toLowerCase())
    ? String(raw.complexity || '').trim().toLowerCase()
    : '';

  if (
    !goal
    && successCriteria.length === 0
    && !completionConfidenceRequired
    && !progressUpdatePolicy
    && !autonomyLevel
    && !complexity
  ) {
    return null;
  }

  return {
    goal,
    successCriteria,
    completionConfidenceRequired,
    progressUpdatePolicy: progressUpdatePolicy || '',
    autonomyLevel: autonomyLevel || '',
    complexity: complexity || '',
  };
}

function mergeGoalContracts(existing = null, patch = null) {
  const current = normalizeGoalContract(existing) || null;
  const nextPatch = normalizeGoalContract(patch) || null;
  if (!current && !nextPatch) return null;

  const goal = String(current?.goal || nextPatch?.goal || '').trim();
  const successCriteria = normalizeGoalCriteria([
    ...(current?.successCriteria || []),
    ...(nextPatch?.successCriteria || []),
  ]);
  const completionConfidenceRequired = nextPatch?.completionConfidenceRequired
    || current?.completionConfidenceRequired
    || 'medium';
  const progressUpdatePolicy = nextPatch?.progressUpdatePolicy
    || current?.progressUpdatePolicy
    || '';
  const autonomyLevel = nextPatch?.autonomyLevel
    || current?.autonomyLevel
    || '';
  const complexity = nextPatch?.complexity
    || current?.complexity
    || '';

  return normalizeGoalContract({
    goal,
    successCriteria,
    completionConfidenceRequired,
    progressUpdatePolicy,
    autonomyLevel,
    complexity,
  });
}

function goalContractFromAnalysis(analysis = null) {
  if (!analysis || typeof analysis !== 'object') return null;
  return normalizeGoalContract({
    goal: analysis.goal,
    successCriteria: analysis.success_criteria,
    completionConfidenceRequired: analysis.completion_confidence_required,
    progressUpdatePolicy: analysis.progress_update_policy,
    autonomyLevel: analysis.autonomy_level,
    complexity: analysis.complexity,
  });
}

function goalContractFromPlan(plan = null) {
  if (!plan || typeof plan !== 'object') return null;
  return normalizeGoalContract({
    successCriteria: plan.success_criteria,
  });
}

function buildResolvedGoalContract(runMeta, analysis = null, plan = null) {
  let contract = mergeGoalContracts(runMeta?.goalContract || null, goalContractFromAnalysis(analysis));
  contract = mergeGoalContracts(contract, goalContractFromPlan(plan));
  return contract;
}

function buildGoalContractPrompt(contract, label = 'Persistent run goal') {
  const normalized = normalizeGoalContract(contract);
  if (!normalized) return '';
  const lines = [];
  if (normalized.goal) {
    lines.push(`${label}: ${normalized.goal}`);
  }
  if (normalized.successCriteria.length > 0) {
    lines.push(`Persistent success criteria:\n- ${normalized.successCriteria.join('\n- ')}`);
  }
  const contractLine = [
    normalized.complexity ? `complexity=${normalized.complexity}` : '',
    normalized.autonomyLevel ? `autonomy_level=${normalized.autonomyLevel}` : '',
    normalized.progressUpdatePolicy ? `progress_update_policy=${normalized.progressUpdatePolicy}` : '',
    normalized.completionConfidenceRequired ? `completion_confidence_required=${normalized.completionConfidenceRequired}` : '',
  ].filter(Boolean).join('; ');
  if (contractLine) {
    lines.push(`Persistent autonomy contract: ${contractLine}`);
  }
  return lines.join('\n');
}

function resolveRunGoalContext(runMeta, analysis = null, plan = null) {
  const goalContract = buildResolvedGoalContract(runMeta, analysis, plan);
  const successCriteria = goalContract?.successCriteria?.length
    ? goalContract.successCriteria.slice(0, 6)
    : (Array.isArray(plan?.success_criteria)
      ? plan.success_criteria
        .map((item) => String(item || '').trim())
        .filter(Boolean)
        .slice(0, 6)
      : []);
  const effectiveGoal = goalContract?.goal || analysis?.goal || '';
  const effectiveComplexity = goalContract?.complexity || analysis?.complexity || 'standard';
  const effectiveAutonomyLevel = goalContract?.autonomyLevel || analysis?.autonomy_level || 'normal';
  const effectiveProgressPolicy = goalContract?.progressUpdatePolicy || analysis?.progress_update_policy || 'optional';
  const effectiveCompletionConfidence = goalContract?.completionConfidenceRequired
    || analysis?.completion_confidence_required
    || 'medium';
  const persistedGoalPrompt = buildGoalContractPrompt(goalContract);
  return {
    goalContract,
    successCriteria,
    effectiveGoal,
    effectiveComplexity,
    effectiveAutonomyLevel,
    effectiveProgressPolicy,
    effectiveCompletionConfidence,
    persistedGoalPrompt,
  };
}

function buildCompletionDecisionPrompt({
  triggerSource,
  messagingSent = false,
  goalContext,
  parallelWork = false,
  tools,
  toolExecutions,
  lastReply,
  iteration,
  maxIterations,
}) {
  const draftReply = normalizeOutgoingMessage(lastReply) || '';
  const lines = [
    'Return JSON only.',
    'Decide whether this run should continue autonomously or stop now.',
    'Schema: {"status":"continue|complete|blocked","reason":"short concrete reason"}',
    'Rules:',
    '- Use "continue" whenever any safe next step remains in this same run.',
    '- Use "complete" only when the requested outcome is actually achieved and the latest draft is the finished user-facing answer.',
    '- Use "blocked" only when a specific external dependency, missing user input, or permission outside this run is required and the latest draft is the blocker reply.',
    '- If the latest draft asks the user for a missing required value, confirmation, or choice needed to proceed, use "blocked" so the run waits instead of repeating the same ask.',
    '- A progress note, next-step note, apology, plan, or promise to investigate is "continue", not "complete".',
    '- A single failed tool attempt is not blocked if another safe retry, verification step, or alternative path remains.',
    '- A tool-specific API error, timeout, rate limit, or missing result inside this run is usually "continue", not "blocked", if any other available tool could still make progress.',
    `- If completion_confidence_required is ${goalContext.effectiveCompletionConfidence} and the latest draft depends on unverified assumptions, use "continue" so the run can gather evidence, inspect state, or narrow the reply.`,
    triggerSource === 'messaging' && messagingSent
      ? '- A final reply was already delivered via send_message. Use "complete" unless concrete task work remains.'
      : triggerSource === 'messaging'
        ? '- For messaging, do not stop on a partial status message. Continue unless the task is actually complete or externally blocked.'
        : '- Do not stop just because you wrote a status update. Continue unless the task is actually complete or externally blocked.',
  ];

  lines.push(
    goalContext.effectiveGoal ? `Goal: ${goalContext.effectiveGoal}` : '',
    goalContext.persistedGoalPrompt,
    `Autonomy contract: complexity=${goalContext.effectiveComplexity}; autonomy_level=${goalContext.effectiveAutonomyLevel}; progress_update_policy=${goalContext.effectiveProgressPolicy}; parallel_work=${parallelWork === true}; completion_confidence_required=${goalContext.effectiveCompletionConfidence}.`,
    goalContext.successCriteria.length > 0
      ? `Success criteria:\n${goalContext.successCriteria.map((item, index) => `${index + 1}. ${item}`).join('\n')}`
      : '',
    `Current iteration: ${iteration} of ${maxIterations}.`,
    `Available tools in this run: ${summarizeAvailableTools(tools) || 'none'}`,
    `Recent tool evidence:\n${summarizeToolExecutions(toolExecutions, 8) || 'none'}`,
    `Latest draft reply:\n${draftReply || '(empty)'}`,
  );
  return lines.filter(Boolean).join('\n');
}

function normalizeCompletionDecision(raw, fallbackStatus = 'continue') {
  const allowed = new Set(['continue', 'complete', 'blocked']);
  const requestedStatus = String(raw.status || '').trim().toLowerCase();
  return {
    status: allowed.has(requestedStatus) ? requestedStatus : fallbackStatus,
    reason: String(raw.reason || '').trim().slice(0, 400),
  };
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
  const { getSupportedModels, createProviderInstance } = require('./models');
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
  const { getSupportedModels } = require('./models');
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

class AgentEngine {
  constructor(io, services = {}) {
    this.io = io;
    this.activeRuns = new Map();
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

  async buildSystemPrompt(userId, context = {}) {
    const { buildSystemPromptSections } = require('./systemPrompt');
    const { MemoryManager } = require('../memory/manager');
    const memoryManager = this.memoryManager || new MemoryManager();
    const promptSections = await buildSystemPromptSections(userId, context, memoryManager);
    const skillRunner = context.skillRunner || this.skillRunner || null;
    const skillsPrompt = skillRunner?.getSkillsForPrompt?.({
      maxTotalChars: 9000,
      maxDescriptionChars: 180,
      maxTriggerChars: 100,
    }) || '';
    return {
      stable: [promptSections.stable, skillsPrompt].filter(Boolean).join('\n\n'),
      dynamic: promptSections.dynamic,
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
    const initial = await memoryManager.recallMemory(userId, query, 12, { agentId });

    const pendingChunks = memoryManager.getPendingExtractionChunks?.(userId, agentId, 5) || [];
    if (pendingChunks.length) {
      this.extractPendingChunks(pendingChunks, {
        userId,
        agentId,
        provider,
        providerName,
        model,
        memoryManager,
      }).catch((err) => console.warn('[Memory] Background chunk extraction failed:', err.message));
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
        telemetry: { runId, stepId, userId, agentId },
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
          telemetry: { runId, stepId, userId, agentId },
          phase: 'memory_retrieval_rerank',
        });
        reranked = rerankResponse.value;
      } else {
        reranked = merged;
      }
    } catch (error) {
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
  }) {
    const ids = chunks.map((c) => c.id);
    memoryManager.markChunksExtracted?.(ids, { success: true });

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
          });
        }
      } catch (err) {
        memoryManager.markChunksExtracted?.([chunk.id], { success: false });
        console.warn('[Memory] Document chunk extraction failed:', err.message);
      }
    }
  }

  persistRunMetadata(runId, patch = {}) {
    if (!runId || !patch || typeof patch !== 'object') return;
    const existing = db.prepare('SELECT metadata_json FROM agent_runs WHERE id = ?').get(runId);
    const current = parseMaybeJson(existing?.metadata_json, {}) || {};
    const next = { ...current, ...patch };
    db.prepare('UPDATE agent_runs SET metadata_json = ? WHERE id = ?')
      .run(JSON.stringify(next), runId);
  }

  updateRunGoalContract(runId, patch = {}, options = {}) {
    const runMeta = this.getRunMeta(runId);
    if (!runMeta) return null;
    runMeta.goalContract = mergeGoalContracts(runMeta.goalContract, patch);
    if (options.persist !== false) {
      this.persistRunMetadata(runId, {
        goalContract: runMeta.goalContract,
      });
    }
    return runMeta.goalContract;
  }

  buildProgressLedgerSnapshot(runMeta) {
    if (!runMeta?.progressLedger) return null;
    return {
      currentStep: runMeta.progressLedger.currentStep || null,
      currentTool: runMeta.progressLedger.currentTool || null,
      currentStepStartedAt: runMeta.progressLedger.currentStepStartedAt || null,
      lastVerifiedProgressAt: runMeta.progressLedger.lastVerifiedProgressAt || null,
      lastUserVisibleUpdateAt: runMeta.progressLedger.lastUserVisibleUpdateAt || null,
      lastFinalDeliveryAt: runMeta.progressLedger.lastFinalDeliveryAt || null,
      heartbeatCount: Number(runMeta.progressLedger.heartbeatCount || 0),
      stallNotifiedAt: runMeta.progressLedger.stallNotifiedAt || null,
      progressState: runMeta.progressLedger.progressState || 'active',
      currentPhase: runMeta.progressLedger.currentPhase || 'idle',
    };
  }

  persistProgressLedger(runId) {
    const runMeta = this.getRunMeta(runId);
    if (!runMeta?.progressLedger) return;
    this.persistRunMetadata(runId, {
      progressLedger: this.buildProgressLedgerSnapshot(runMeta),
    });
  }

  updateRunProgress(runId, patch = {}, options = {}) {
    const runMeta = this.getRunMeta(runId);
    if (!runMeta) return null;
    if (!runMeta.progressLedger) {
      runMeta.progressLedger = buildInitialProgressLedger({
        startedAt: runMeta.startedAtIso || isoNow(),
      });
    }

    const previousState = runMeta.progressLedger.progressState || 'active';
    runMeta.progressLedger = {
      ...runMeta.progressLedger,
      ...patch,
    };

    if (options.verified === true) {
      runMeta.progressLedger.lastVerifiedProgressAt = options.timestamp || isoNow();
      runMeta.progressLedger.progressState = 'active';
      runMeta.progressLedger.stallNotifiedAt = null;
      this.recordRunEvent(runMeta.userId, runId, 'progress_verified', {
        phase: runMeta.progressLedger.currentPhase || 'idle',
        currentStep: runMeta.progressLedger.currentStep || null,
        currentTool: runMeta.progressLedger.currentTool || null,
      }, { agentId: runMeta.agentId, stepId: options.stepId || null });
      if (previousState === 'stalled') {
        this.recordRunEvent(runMeta.userId, runId, 'progress_resumed', {
          phase: runMeta.progressLedger.currentPhase || 'idle',
          currentStep: runMeta.progressLedger.currentStep || null,
          currentTool: runMeta.progressLedger.currentTool || null,
        }, { agentId: runMeta.agentId, stepId: options.stepId || null });
      }
    }

    if (options.persist !== false) {
      this.persistProgressLedger(runId);
    }
    return runMeta.progressLedger;
  }

  markRunVisibleProgress(runId, timestamp = isoNow()) {
    const runMeta = this.getRunMeta(runId);
    if (!runMeta) return null;
    const ledger = this.updateRunProgress(runId, {
      lastUserVisibleUpdateAt: timestamp,
    }, {
      persist: false,
    });
    this.persistProgressLedger(runId);
    return ledger;
  }

  markRunFinalDelivery(runId, content = '', timestamp = isoNow()) {
    const runMeta = this.getRunMeta(runId);
    if (!runMeta) return null;
    runMeta.messagingSent = true;
    runMeta.finalDeliverySent = true;
    runMeta.lastSentMessage = String(content || '').trim() || runMeta.lastSentMessage || '';
    const ledger = this.updateRunProgress(runId, {
      lastUserVisibleUpdateAt: timestamp,
      lastFinalDeliveryAt: timestamp,
      progressState: 'complete',
    }, {
      persist: false,
    });
    this.persistProgressLedger(runId);
    return ledger;
  }

  recordRunEvent(userId, runId, eventType, payload = {}, options = {}) {
    try {
      return recordRunEvent({
        runId,
        userId,
        agentId: options.agentId || null,
        eventType,
        requestId: options.requestId || null,
        stepId: options.stepId || null,
        payload,
      });
    } catch {
      return null;
    }
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
    const runMeta = this.getRunMeta(runId);
    if (!runMeta || runMeta.aborted) {
      return { sent: false, skipped: true, reason: 'Run is no longer active.' };
    }

    const normalizedKind = normalizeInterimKind(kind);
    const normalizedContent = normalizeInterimText(
      content,
      triggerSource === 'messaging' ? platform : null
    );
    if (!normalizedContent || normalizedContent.toUpperCase() === '[NO RESPONSE]') {
      return { sent: false, skipped: true, reason: 'Interim content must be non-empty.' };
    }

    const signature = buildInterimSignature({
      content: normalizedContent,
      kind: normalizedKind,
      expectsReply,
      platform: triggerSource === 'messaging' ? platform : 'web',
    });
    if (runMeta.interimSignatures?.has(signature)) {
      return { sent: false, skipped: true, duplicate: true };
    }

    const metadata = buildInterimMetadata({
      kind: normalizedKind,
      expectsReply,
    });
    if (deferFollowUp === true) {
      metadata.defer_follow_up = true;
    }
    const createdAt = new Date().toISOString();

    if (triggerSource === 'messaging') {
      if (!platform || !chatId || !this.messagingManager) {
        return { sent: false, skipped: true, reason: 'Messaging context is not available.' };
      }
      const deliveryResult = await this.messagingManager.sendMessage(userId, platform, chatId, normalizedContent, {
        agentId,
        runId,
        persistConversation: true,
        metadata,
        deliveryKind: 'interim',
      });
      requireSuccessfulMessagingDelivery(deliveryResult, 'Interim messaging delivery');
    } else if (triggerSource === 'voice_live') {
      const voiceSessionId = runMeta.voiceSessionId || null;
      const manager = this.voiceRuntimeManager || this.app?.locals?.voiceRuntimeManager || null;
      if (!voiceSessionId || !manager || typeof manager.publishInterimUpdate !== 'function') {
        return { sent: false, skipped: true, reason: 'Voice session context is not available.' };
      }
      await manager.publishInterimUpdate({
        sessionId: voiceSessionId,
        content: normalizedContent,
        kind: normalizedKind,
        expectsReply,
        deferFollowUp,
      });
    } else {
      db.prepare(
        'INSERT INTO conversation_history (user_id, agent_id, agent_run_id, role, content, metadata) VALUES (?, ?, ?, ?, ?, ?)'
      ).run(userId, agentId, runId, 'assistant', normalizedContent, JSON.stringify(metadata));

      if (conversationId) {
        db.prepare('INSERT INTO conversation_messages (conversation_id, role, content) VALUES (?, ?, ?)')
          .run(conversationId, 'assistant', normalizedContent);
      }
    }

    if (!runMeta.interimSignatures) runMeta.interimSignatures = new Set();
    if (!Array.isArray(runMeta.interimMessages)) runMeta.interimMessages = [];
    runMeta.interimSignatures.add(signature);
    runMeta.interimMessages.push({
      content: normalizedContent,
      kind: normalizedKind,
      expectsReply: expectsReply === true,
      deferFollowUp: deferFollowUp === true,
      createdAt,
    });
    runMeta.lastInterimMessage = normalizedContent;
    this.markRunVisibleProgress(runId, createdAt);

    this.emit(userId, 'run:assistant_interim', {
      runId,
      content: normalizedContent,
      kind: normalizedKind,
      expectsReply: expectsReply === true,
      deferFollowUp: deferFollowUp === true,
      triggerSource,
      platform: triggerSource === 'messaging' ? platform : 'web',
    });

    const terminalInterim = expectsReply === true;
    if (terminalInterim) {
      runMeta.terminalInterim = {
        kind: normalizedKind,
        content: normalizedContent,
        createdAt,
      };
    }
    this.persistRunMetadata(runId, {
      latestInterim: {
        kind: normalizedKind,
        expectsReply: expectsReply === true,
        deferFollowUp: deferFollowUp === true,
        content: normalizedContent,
        createdAt,
      },
      progressLedger: this.buildProgressLedgerSnapshot(runMeta),
      terminalInterim: terminalInterim
        ? { kind: normalizedKind, content: normalizedContent, createdAt }
        : null,
    });

    return {
      sent: true,
      kind: normalizedKind,
      expectsReply: expectsReply === true,
      deferFollowUp: deferFollowUp === true,
      content: normalizedContent,
      terminal: terminalInterim,
    };
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
    const startedAt = Date.now();
    const structuredStep = `model:${phase}`;
    if (telemetry?.runId) {
      this.updateRunProgress(telemetry.runId, {
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
              reasoningEffort: reasoningEffort || this.getReasoningEffort(providerName, {}),
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
      const runMeta = telemetry?.runId ? this.getRunMeta(telemetry.runId) : null;
      if (runMeta?.progressLedger?.currentStep === structuredStep) {
        this.updateRunProgress(telemetry.runId, {
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
    const startedAt = Date.now();
    const requestMessages = sanitizeConversationMessages(messages);
    const callOptions = {
      model,
      reasoningEffort: this.getReasoningEffort(providerName, options),
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
              this.emit(options.userId, 'run:stream', {
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
        this.emit(options.userId, 'run:interim', {
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

  async analyzeTask({
    provider,
    providerName,
    model,
    messages,
    tools,
    capabilityHealth,
    forceMode,
    userMessage,
    options,
  }) {
    const summary = summarizeCapabilityHealth(capabilityHealth);
    const response = await this.requestStructuredJson({
      provider,
      providerName,
      model,
      messages,
      prompt: buildAnalysisPrompt({
        capabilityHealth: summary,
        tools,
        forceMode,
      }),
      maxTokens: 1100,
      normalize: normalizeTaskAnalysis,
      fallback: buildAnalyzeTaskFallback(forceMode, userMessage),
      reasoningEffort: this.getReasoningEffort(providerName, options),
      telemetry: options,
      phase: 'task_analysis',
    });

    return {
      analysis: response.value,
      raw: response.raw,
      usage: response.usage,
      capabilitySummary: summary,
    };
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
    const { MemoryManager } = require('../memory/manager');
    const memoryManager = this.memoryManager || new MemoryManager();
    const context = getConversationContext(conversationId, Math.max(historyWindow, 8));
    const existingState = memoryManager.getConversationState(conversationId);
    const promptMessages = [
      {
        role: 'system',
        content: [
          'Return JSON only. Distill the current thread working state. Keep it concise and concrete.',
          'Track summary, open_commitments, unresolved_questions, referenced_entities, and last_verified_facts. Do not invent facts.',
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

    const response = await withModelCallTimeout(
      provider.chat(promptMessages, [], {
        model,
        maxTokens: 800,
        reasoningEffort: this.getReasoningEffort(providerName, options),
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
        },
      );
      const { invalidateSystemPromptCache } = require('./systemPrompt');
      invalidateSystemPromptCache(options.userId, options.agentId || null);
    }
    return nextState;
  }

  getAvailableTools(app, options = {}) {
    const { getAvailableTools } = require('./tools');
    return getAvailableTools(app, options);
  }

  async executeTool(toolName, args, context) {
    const { executeTool } = require('./tools');
    return executeTool(toolName, args, context, this);
  }

  isReadOnlyToolCall(toolCall) {
    const name = String(toolCall?.function?.name || '');
    const readOnly = new Set([
      'read_file',
      'list_directory',
      'search_files',
      'code_navigate',
      'query_structured_data',
      'memory_recall',
      'memory_read',
      'session_search',
      'web_search',
      'list_tasks',
      'list_skills',
      'list_subagents',
      'recordings_list',
      'recordings_get',
      'recordings_search',
      'read_health_data',
    ]);
    if (name === 'http_request') {
      try {
        const args = JSON.parse(toolCall.function.arguments || '{}');
        return String(args.method || 'GET').toUpperCase() === 'GET';
      } catch {
        return false;
      }
    }
    return readOnly.has(name);
  }

  async executeReadOnlyBatch(toolCalls, context = {}) {
    const {
      userId,
      runId,
      agentId,
      app,
      triggerType,
      triggerSource,
      conversationId,
      startingStepIndex,
      options = {},
    } = context;
    const prepared = [];
    let nextStepIndex = startingStepIndex;
    for (const toolCall of toolCalls) {
      nextStepIndex += 1;
      let toolArgs = {};
      try { toolArgs = JSON.parse(toolCall.function.arguments || '{}'); } catch {}
      const toolName = toolCall.function.name;
      const repetitionGuard = this.getRunMeta(runId)?.repetitionGuard;
      if (repetitionGuard?.shouldBlock(toolName, toolArgs)) {
        const result = {
          status: 'blocked',
          reason: 'The same read-only call already returned an unchanged result twice.',
        };
        prepared.push({
          toolCall,
          toolName,
          toolArgs,
          stepIndex: nextStepIndex,
          blocked: true,
          result,
          error: result.reason,
        });
        this.recordRunEvent(userId, runId, 'repetition_blocked', {
          toolName,
          toolArgs,
          parallel: true,
        }, { agentId });
        continue;
      }
      if (globalHooks.has('before_tool_call')) {
        const hookResult = await globalHooks.run('before_tool_call', {
          toolName,
          toolArgs,
          runId,
          userId,
          agentId,
          iteration: context.iteration,
        });
        if (hookResult.block) {
          prepared.push({
            toolCall,
            toolName,
            toolArgs,
            stepIndex: nextStepIndex,
            blocked: true,
            result: { status: 'blocked', reason: hookResult.reason || 'Blocked by policy.', blocked_by: hookResult.blocked_by || 'policy' },
          });
          continue;
        }
        if (hookResult.toolArgs) toolArgs = hookResult.toolArgs;
      }
      const stepId = uuidv4();
      db.prepare(
        `INSERT INTO agent_steps (
          id, run_id, step_index, type, description, status, tool_name, tool_input, started_at
        ) VALUES (?, ?, ?, ?, ?, 'running', ?, ?, datetime('now'))`
      ).run(
        stepId,
        runId,
        nextStepIndex,
        this.getStepType(toolName),
        `${toolName}: ${JSON.stringify(toolArgs).slice(0, 200)}`,
        toolName,
        JSON.stringify(toolArgs),
      );
      this.emit(userId, 'run:tool_start', {
        runId,
        stepId,
        stepIndex: nextStepIndex,
        toolName,
        toolArgs,
        type: this.getStepType(toolName),
      });
      this.recordRunEvent(userId, runId, 'tool_started', {
        stepIndex: nextStepIndex,
        toolName,
        toolArgs,
        type: this.getStepType(toolName),
        parallel: true,
      }, { agentId, stepId });
      prepared.push({ toolCall, toolName, toolArgs, stepId, stepIndex: nextStepIndex });
    }
    this.recordRunEvent(userId, runId, 'parallel_batch_started', {
      toolNames: prepared.map((item) => item.toolName),
      count: prepared.length,
    }, { agentId });
    const results = await Promise.all(prepared.map(async (item) => {
      if (item.blocked) return item;
      const startedAt = Date.now();
      try {
        const result = await this.executeTool(item.toolName, item.toolArgs, {
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
          allowExternalSideEffects: false,
        });
        const error = inferToolFailureMessage(item.toolName, result);
        const status = error ? 'failed' : 'completed';
        db.prepare(
          `UPDATE agent_steps
           SET status = ?, result = ?, error = ?, screenshot_path = ?, completed_at = datetime('now')
           WHERE id = ?`
        ).run(
          status,
          JSON.stringify(result).slice(0, 20000),
          error || null,
          result?.screenshotPath || null,
          item.stepId,
        );
        this.emit(userId, 'run:tool_end', {
          runId,
          stepId: item.stepId,
          toolName: item.toolName,
          result,
          error: error || undefined,
          status,
        });
        this.recordRunEvent(userId, runId, error ? 'tool_failed' : 'tool_completed', {
          toolName: item.toolName,
          status,
          durationMs: Date.now() - startedAt,
          resultPreview: summarizeForLog(result),
          parallel: true,
        }, { agentId, stepId: item.stepId });
        return { ...item, result, error };
      } catch (err) {
        db.prepare(
          `UPDATE agent_steps SET status = 'failed', error = ?, completed_at = datetime('now') WHERE id = ?`
        ).run(err.message, item.stepId);
        this.emit(userId, 'run:tool_end', {
          runId,
          stepId: item.stepId,
          toolName: item.toolName,
          error: err.message,
          status: 'failed',
        });
        this.recordRunEvent(userId, runId, 'tool_failed', {
          toolName: item.toolName,
          status: 'failed',
          error: err.message,
          durationMs: Date.now() - startedAt,
          parallel: true,
        }, { agentId, stepId: item.stepId });
        return { ...item, result: { error: err.message }, error: err.message };
      }
    }));
    this.recordRunEvent(userId, runId, 'parallel_batch_completed', {
      toolNames: results.map((item) => item.toolName),
      failedCount: results.filter((item) => item.error).length,
    }, { agentId });
    return { results, endingStepIndex: nextStepIndex };
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
    const runMeta = this.getRunMeta(runId);
    if (!runMeta) return;
    runMeta.toolCatalog = Array.isArray(allTools) ? allTools : [];
    runMeta.activeTools = Array.isArray(initialTools) ? initialTools : [];
    runMeta.toolSelectionOptions = {
      widgetId: options.widgetId || null,
    };
  }

  getActiveTools(runId) {
    return this.getRunMeta(runId)?.activeTools || [];
  }

  activateToolsForRun(runId, names = []) {
    const runMeta = this.getRunMeta(runId);
    if (!runMeta) throw new Error('Run is not active.');
    const result = activateTools(
      runMeta.activeTools,
      runMeta.toolCatalog,
      names,
      runMeta.toolSelectionOptions,
    );
    runMeta.activeTools = result.tools;
    this.recordRunEvent(runMeta.userId, runId, 'tools_activated', {
      activated: result.activated,
      evicted: result.evicted,
      unknown: result.unknown,
      notActivated: result.notActivated,
      activeToolNames: result.tools.map((tool) => tool.name),
    }, { agentId: runMeta.agentId });
    return {
      success: result.unknown.length === 0 && result.notActivated.length === 0,
      activated: result.activated,
      evicted: result.evicted,
      unknown: result.unknown,
      not_activated: result.notActivated,
      active_tools: result.tools.map((tool) => tool.name),
    };
  }

  findActiveRunForUser(userId, predicate = null) {
    let candidate = null;
    for (const [runId, runMeta] of this.activeRuns.entries()) {
      if (runMeta.userId !== userId || runMeta.aborted) continue;
      if (typeof predicate === 'function' && !predicate(runMeta, runId)) continue;
      if (!candidate || (runMeta.startedAt || 0) >= (candidate.startedAt || 0)) {
        candidate = { runId, ...runMeta };
      }
    }
    return candidate;
  }

  findSteerableRunForUser(userId, triggerSource = 'web') {
    return this.findActiveRunForUser(
      userId,
      (runMeta) => runMeta.triggerSource === triggerSource && runMeta.triggerType === 'user'
    );
  }

  enqueueSteering(runId, content, metadata = {}) {
    const runMeta = this.getRunMeta(runId);
    const trimmed = typeof content === 'string' ? content.trim() : '';
    if (!runMeta || runMeta.aborted || !trimmed) return null;

    const item = {
      id: uuidv4(),
      content: trimmed,
      metadata,
      createdAt: new Date().toISOString()
    };

    runMeta.steeringQueue.push(item);
    this.emit(runMeta.userId, 'run:steer_queued', {
      runId,
      content: item.content,
      pendingCount: runMeta.steeringQueue.length
    });

    return {
      runId,
      pendingCount: runMeta.steeringQueue.length,
      item
    };
  }

  enqueueSystemSteering(runId, content, metadata = {}) {
    const runMeta = this.getRunMeta(runId);
    const trimmed = typeof content === 'string' ? content.trim() : '';
    if (!runMeta || runMeta.aborted || !trimmed) return null;
    if (!Array.isArray(runMeta.systemSteeringQueue)) {
      runMeta.systemSteeringQueue = [];
    }
    const signature = JSON.stringify({
      content: trimmed,
      reason: metadata.reason || '',
    });
    if (runMeta.systemSteeringQueue.some((item) => item.signature === signature)) {
      return null;
    }
    const item = {
      id: uuidv4(),
      content: trimmed,
      metadata,
      signature,
      createdAt: isoNow(),
    };
    runMeta.systemSteeringQueue.push(item);
    return item;
  }

  applyQueuedSystemSteering(runId, messages) {
    const runMeta = this.getRunMeta(runId);
    if (!runMeta?.systemSteeringQueue?.length) {
      return { messages, appliedCount: 0 };
    }

    const queued = runMeta.systemSteeringQueue.splice(0, runMeta.systemSteeringQueue.length);
    for (const entry of queued) {
      messages.push({ role: 'system', content: entry.content });
    }

    return { messages, appliedCount: queued.length };
  }

  applyQueuedSteering(runId, messages, { userId, conversationId }) {
    const runMeta = this.getRunMeta(runId);
    if (!runMeta?.steeringQueue?.length) {
      return { messages, appliedCount: 0 };
    }

    const queued = runMeta.steeringQueue.splice(0, runMeta.steeringQueue.length);
    messages.push({
      role: 'system',
      content: [
        'The user sent follow-up messages while you were already working.',
        'Treat them as steering or next-up context for the same conversation.',
        'If a message materially changes the active task, incorporate it now.',
        'If it is unrelated or better handled after the current task, finish the current work first and then address it.'
      ].join(' ')
    });

    for (const entry of queued) {
      messages.push({ role: 'user', content: entry.content });
      if (conversationId) {
        db.prepare('INSERT INTO conversation_messages (conversation_id, role, content) VALUES (?, ?, ?)')
          .run(conversationId, 'user', entry.content);
      }
    }

    this.emit(userId, 'run:steer_applied', {
      runId,
      count: queued.length,
      pendingCount: runMeta.steeringQueue.length,
      latestContent: queued[queued.length - 1]?.content || ''
    });

    return { messages, appliedCount: queued.length };
  }

  buildMessagingHeartbeatText(runMeta, options = {}) {
    const stalled = options.stalled === true;
    const now = Date.now();
    const runStartedAtMs = Number.isFinite(runMeta?.startedAt) ? runMeta.startedAt : now;
    const stepStartedAtMs = timestampMs(
      runMeta?.progressLedger?.currentStepStartedAt,
      0,
    );
    const runElapsed = formatElapsedDuration(now - runStartedAtMs);
    const stepElapsed = formatElapsedDuration(now - (stepStartedAtMs || runStartedAtMs));
    const unverifiedElapsed = formatElapsedDuration(now - timestampMs(
      runMeta?.progressLedger?.lastVerifiedProgressAt,
      runStartedAtMs,
    ));
    const currentTool = String(runMeta?.progressLedger?.currentTool || '').trim();
    const runTitle = String(runMeta?.title || '').trim().slice(0, 60);
    const titlePrefix = runTitle ? `[${runTitle}] ` : '';
    if (currentTool) {
      return stalled
        ? `${titlePrefix}Still working on ${currentTool}. Run active ${runElapsed}; no verified progress for ${unverifiedElapsed}.`
        : `${titlePrefix}Still working on ${currentTool}. Run active ${runElapsed}; current step ${stepElapsed} so far.`;
    }
    return stalled
      ? `${titlePrefix}Still working on this. Run active ${runElapsed}; no verified progress for ${unverifiedElapsed}.`
      : `${titlePrefix}Still working on this. Run active ${runElapsed}.`;
  }

  async sendRuntimeMessagingHeartbeat(runId, options = {}) {
    const runMeta = this.getRunMeta(runId);
    if (!runMeta || runMeta.aborted) return { sent: false, skipped: true };
    if (runMeta.triggerSource !== 'messaging' || !runMeta.messagingContext?.platform || !runMeta.messagingContext?.chatId) {
      return { sent: false, skipped: true };
    }
    if (!this.messagingManager) {
      return { sent: false, skipped: true };
    }

    const createdAt = isoNow();
    const content = this.buildMessagingHeartbeatText(runMeta, options);
    const deliveryResult = await this.messagingManager.sendMessage(
      runMeta.userId,
      runMeta.messagingContext.platform,
      runMeta.messagingContext.chatId,
      content,
      {
        agentId: runMeta.agentId,
        runId,
        persistConversation: true,
        metadata: {
          interim: true,
          interim_kind: options.stalled === true ? 'blocker' : 'progress',
          runtime_heartbeat: true,
          expects_reply: false,
        },
        deliveryKind: 'interim',
      },
    );
    requireSuccessfulMessagingDelivery(deliveryResult, 'Messaging heartbeat delivery');

    runMeta.lastInterimMessage = content;
    if (!Array.isArray(runMeta.interimMessages)) {
      runMeta.interimMessages = [];
    }
    runMeta.interimMessages.push({
      content,
      kind: options.stalled === true ? 'blocker' : 'progress',
      expectsReply: false,
      deferFollowUp: false,
      createdAt,
    });
    const heartbeatCount = Number(runMeta.progressLedger?.heartbeatCount || 0) + 1;
    this.updateRunProgress(runId, {
      heartbeatCount,
      lastUserVisibleUpdateAt: createdAt,
    });
    this.recordRunEvent(runMeta.userId, runId, 'progress_heartbeat_sent', {
      stalled: options.stalled === true,
      currentTool: runMeta.progressLedger?.currentTool || null,
      currentStep: runMeta.progressLedger?.currentStep || null,
    }, { agentId: runMeta.agentId });
    this.enqueueSystemSteering(
      runId,
      'A runtime progress update was just sent on your behalf because you were blocked in a tool. On your NEXT free turn: use send_interim_update to write 1-2 sentences in your own words describing what you are doing and why. Keep it short and concrete. Then continue toward the final answer.',
      { reason: 'heartbeat_ai_followup' },
    );
    return { sent: true, content };
  }

  shouldSendMessagingFinalFallback(runMeta, content, platform = null) {
    const cleanedContent = normalizeOutgoingMessage(content || '', platform, {
      collapseWhitespace: false,
    });
    const lastFinalDeliveryMessage = normalizeOutgoingMessage(
      runMeta?.lastSentMessage
      || (Array.isArray(runMeta?.sentMessages) ? runMeta.sentMessages[runMeta.sentMessages.length - 1] : '')
      || '',
      platform,
    );
    return Boolean(
      cleanedContent
      && !runMeta?.terminalInterim
      && runMeta?.explicitMessageSent !== true
      && runMeta?.finalDeliverySent !== true
      && !lastFinalDeliveryMessage
    );
  }

  async deliverMessagingFinalFallback({
    runId,
    userId,
    agentId,
    platform,
    chatId,
    content,
  }) {
    const runMeta = this.getRunMeta(runId);
    if (!runMeta || !this.messagingManager) return { sent: false, skipped: true };
    const cleanedContent = normalizeOutgoingMessage(content || '', platform, {
      collapseWhitespace: false,
    });
    if (!this.shouldSendMessagingFinalFallback(runMeta, cleanedContent, platform)) {
      return { sent: false, skipped: true };
    }

    const chunks = splitOutgoingMessageForPlatform(platform, cleanedContent);
    console.info(
      `[Run ${shortenRunId(runId)}] messaging_fallback chunks=${chunks.length} to=${summarizeForLog(chatId, 80)}`
    );
    for (let i = 0; i < chunks.length; i++) {
      if (i > 0) {
        const delay = Math.max(1000, Math.min(chunks[i].length * 30, 4000));
        await this.messagingManager.sendTyping(userId, platform, chatId, true, { agentId }).catch(() => {});
        await new Promise((resolve) => setTimeout(resolve, delay));
      }
      try {
        await withProviderRetry(async () => {
          const deliveryResult = await this.messagingManager.sendMessage(
            userId,
            platform,
            chatId,
            chunks[i],
            { runId, agentId },
          );
          return requireSuccessfulMessagingDelivery(deliveryResult, 'Final messaging delivery');
        }, {
          ...this.messagingDeliveryRetry,
          label: `MessagingDelivery ${platform}`,
          isRetryable: (error) => (
            error?.retryable !== false
            && (
              error?.code === 'MESSAGING_DELIVERY_FAILED'
              || isTransientError(error)
            )
          ),
        });
      } catch (error) {
        error.disableAutonomousRetry = true;
        throw error;
      }
    }

    runMeta.lastSentMessage = chunks[chunks.length - 1] || cleanedContent;
    runMeta.sentMessages = Array.isArray(runMeta.sentMessages)
      ? [...runMeta.sentMessages, ...chunks]
      : chunks.slice();
    this.markRunFinalDelivery(runId, runMeta.lastSentMessage);
    return { sent: true, chunks };
  }

  async tickMessagingProgressSupervisor(runId) {
    const runMeta = this.getRunMeta(runId);
    if (!runMeta || runMeta.aborted || runMeta.triggerSource !== 'messaging') {
      return { sent: false, skipped: true };
    }
    if (runMeta.terminalInterim) {
      return { sent: false, skipped: true };
    }

    const now = Date.now();
    const ledger = runMeta.progressLedger || buildInitialProgressLedger({
      startedAt: runMeta.startedAtIso || isoNow(),
    });
    runMeta.progressLedger = ledger;
    const startedAtMs = Number.isFinite(runMeta.startedAt) ? runMeta.startedAt : now;

    const lastVerifiedAtMs = timestampMs(ledger.lastVerifiedProgressAt, startedAtMs);
    const lastVisibleAtMs = timestampMs(ledger.lastUserVisibleUpdateAt, 0);
    const heartbeatThresholdMs = lastVisibleAtMs > 0
      ? MESSAGING_PROGRESS_REPEAT_MS
      : MESSAGING_PROGRESS_FIRST_UPDATE_MS;
    const comparisonVisibleAtMs = lastVisibleAtMs > 0 ? lastVisibleAtMs : startedAtMs;
    const stalled = (now - lastVerifiedAtMs) >= MESSAGING_PROGRESS_STALL_MS;

    if (stalled && !ledger.stallNotifiedAt) {
      this.updateRunProgress(runId, {
        stallNotifiedAt: isoNow(),
        progressState: 'stalled',
      });
      this.recordRunEvent(runMeta.userId, runId, 'progress_stalled', {
        currentTool: ledger.currentTool || null,
        currentStep: ledger.currentStep || null,
        phase: ledger.currentPhase || 'idle',
      }, { agentId: runMeta.agentId });
    }

    if ((now - comparisonVisibleAtMs) < heartbeatThresholdMs) {
      return { sent: false, skipped: true };
    }

    if (
      (ledger.currentPhase === 'tool' || ledger.currentPhase === 'model')
      && ledger.currentStepStartedAt
    ) {
      return this.sendRuntimeMessagingHeartbeat(runId, { stalled });
    }

    if (ledger.currentPhase !== 'idle') {
      return { sent: false, skipped: true };
    }

    const lastSupervisorNudgeAtMs = timestampMs(runMeta.lastSupervisorNudgeAt, 0);
    if (lastSupervisorNudgeAtMs > 0 && (now - lastSupervisorNudgeAtMs) < heartbeatThresholdMs) {
      return { sent: false, skipped: true };
    }

    const elapsed = formatElapsedDuration(now - startedAtMs);
    const nudge = stalled
      ? `You have been running for ${elapsed} and appear stalled. Use send_interim_update RIGHT NOW to write 1-2 sentences explaining the blocker in your own words, then either resolve it or call task_complete with what you have. Do not leave the user without an answer.`
      : `You have been running for ${elapsed} without sending an update to the user. Use send_interim_update RIGHT NOW to write 1-2 sentences explaining what you are currently doing. Keep it short and concrete. Then continue working toward the final answer.`;
    const queued = this.enqueueSystemSteering(runId, nudge, {
      reason: stalled ? 'stalled_progress_check' : 'progress_check',
    });
    if (!queued) {
      return { sent: false, skipped: true };
    }
    runMeta.lastSupervisorNudgeAt = isoNow();
    this.updateRunProgress(runId, {
      lastUserVisibleUpdateAt: ledger.lastUserVisibleUpdateAt || null,
    });
    return { sent: false, queued: true };
  }

  startMessagingProgressSupervisor(runId) {
    const runMeta = this.getRunMeta(runId);
    if (!runMeta || runMeta.triggerSource !== 'messaging' || !runMeta.messagingContext?.platform || !runMeta.messagingContext?.chatId) {
      return false;
    }
    if (runMeta.messagingProgressSupervisor?.timer) {
      return true;
    }
    const timer = setInterval(() => {
      this.tickMessagingProgressSupervisor(runId).catch((error) => {
        console.warn('[Engine] Messaging progress supervisor failed:', error?.message || error);
      });
    }, MESSAGING_PROGRESS_TICK_MS);
    timer.unref?.();
    runMeta.messagingProgressSupervisor = { timer };
    return true;
  }

  stopMessagingProgressSupervisor(runId) {
    const runMeta = this.getRunMeta(runId);
    const timer = runMeta?.messagingProgressSupervisor?.timer || null;
    if (timer) {
      clearInterval(timer);
    }
    if (runMeta?.messagingProgressSupervisor) {
      runMeta.messagingProgressSupervisor = null;
    }
  }

  isRunStopped(runId) {
    return this.getRunMeta(runId)?.aborted === true;
  }

  attachProcessToRun(runId, pid) {
    const runMeta = this.getRunMeta(runId);
    if (!runMeta || !pid) return;
    runMeta.toolPids.add(pid);
    if (runMeta.aborted) {
      if (this.runtimeManager && typeof this.runtimeManager.killCommand === 'function') {
        void this.runtimeManager.killCommand(runMeta.userId, pid, 'aborted');
      }
    }
  }

  detachProcessFromRun(runId, pid) {
    const runMeta = this.getRunMeta(runId);
    if (!runMeta || !pid) return;
    runMeta.toolPids.delete(pid);
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

  shouldFastCompleteVoiceReply({
    options = {},
    toolExecutions = [],
    failedStepCount = 0,
    messagingSent = false,
    lastReply = '',
  }) {
    return options.latencyProfile === 'voice'
      && toolExecutions.length === 0
      && failedStepCount === 0
      && !messagingSent
      && Boolean(String(lastReply || '').trim());
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
    const triggerType = options.triggerType || 'user';
    const { resolveAgentId } = require('../agents/manager');
    const agentId = resolveAgentId(userId, options.agentId || options.agent_id || null);
    ensureDefaultAiSettings(userId, agentId);
    const aiSettings = getAiSettings(userId, agentId);

    enforceRateLimits(userId);

    const runId = options.runId || uuidv4();
    const conversationId = options.conversationId;
    const app = options.app || this.app;
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
        this.emit(userId, 'run:interim', {
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
      this.emit(userId, 'run:interim', {
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
    db.prepare(`INSERT OR REPLACE INTO agent_runs(
      id, user_id, agent_id, title, status, trigger_type, trigger_source, model, metadata_json
    ) VALUES(?, ?, ?, ?, 'running', ?, ?, ?, ?)`).run(
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

    this.activeRuns.set(runId, {
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
      messagingContext: triggerSource === 'messaging'
        ? {
          platform: options.source || null,
          chatId: options.chatId || null,
        }
        : null,
      goalContract: carriedGoalContract,
      progressLedger,
    });
    this.persistRunMetadata(runId, {
      progressLedger,
      goalContract: carriedGoalContract,
    });
    this.startMessagingProgressSupervisor(runId);
    this.emit(userId, 'run:start', { runId, agentId, title: runTitle, model, triggerType, triggerSource });
    this.recordRunEvent(userId, runId, 'run_started', {
      title: runTitle,
      model,
      triggerType,
      triggerSource,
    }, { agentId });
    console.info(
      `[Run ${shortenRunId(runId)}] started trigger=${triggerSource} type=${triggerType} model=${model} title=${summarizeForLog(runTitle, 120)}`
    );

    const systemPrompt = await this.buildSystemPrompt(userId, {
      ...(options.context || {}),
      userMessage,
      agentId,
      triggerSource,
    });
    // Pass short descriptions so the model always knows every available tool.
    // compactToolDefinition caps tool desc at 120 chars, param desc at 70 chars.
    const builtInTools = this.getAvailableTools(app, {
      includeDescriptions: true,
      userId,
      agentId,
      triggerType,
      triggerSource,
      widgetId: options.widgetId || null,
    });
    const mcpManager = app?.locals?.mcpManager || app?.locals?.mcpClient || this.mcpManager;
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
    this.recordRunEvent(userId, runId, 'tool_inventory', {
      total: toolNames.length,
      builtInTotal: builtInTools.length,
      mcpTotal: mcpTools.length,
      core: coreToolStatus,
    }, { agentId });
    console.info(
      `[Run ${shortenRunId(runId)}] tools total=${toolNames.length} builtIns=${builtInTools.length} mcp=${mcpTools.length} core=${JSON.stringify(coreToolStatus)}`
    );
    const capabilityHealth = await getCapabilityHealth({ userId, agentId, app, engine: this });
    const capabilitySummary = summarizeCapabilityHealth(capabilityHealth);
    const integrationSummary = integrationManager?.summarizeConnectedProviders?.(userId, agentId) || '';

    const { MemoryManager } = require('../memory/manager');
    const memoryManager = this.memoryManager || new MemoryManager();
    const recallQuery = options.context?.rawUserMessage || userMessage;
    const recallMsg = options.skipGlobalRecall === true
      ? null
      : await this.buildMemoryRecall({
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

    let messages = this.buildContextMessages(systemPrompt, summaryMessage, historyMessages, recallMsg);
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
    this.recordRunEvent(userId, runId, 'memory_injected', {
      hasRecallContext: Boolean(recallMsg),
      hasThreadState: Boolean(threadStateMessage),
      recallPreview: recallMsg ? String(recallMsg).slice(0, 240) : '',
    }, { agentId });
    messages.push(this.buildUserMessage(userMessage, options));
    messages = sanitizeConversationMessages(messages);

    if (conversationId) {
      db.prepare('INSERT INTO conversation_messages (conversation_id, role, content) VALUES (?, ?, ?)')
        .run(conversationId, 'user', userMessage);
    }

    let iteration = 0;
    let totalTokens = 0;
    let lastContent = '';
    let stepIndex = 0;
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
        const analysisResult = await runWithModelFallback('task analysis', () => this.analyzeTask({
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
        this.persistRunMetadata(runId, {
          taskAnalysis: analysis,
          capabilityHealth,
        });
        this.updateRunGoalContract(runId, goalContractFromAnalysis(analysis));
        this.emit(userId, 'run:analysis', {
          runId,
          ...analysis,
          capabilitySummary,
        });

      }

      tools = selectInitialTools(allTools, analysis.suggested_tools, {
        widgetId: options.widgetId || null,
      });
      this.initializeToolRuntime(runId, allTools, tools, options);
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
      this.recordRunEvent(userId, runId, 'tool_selection_applied', {
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
            this.emit(userId, 'run:interim', {
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
        const deliverableSelectionResult = await selectDeliverableWorkflow({
          engine: this,
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
            engine: this,
            userId,
            agentId,
            runId,
            agentId,
            app,
          });
          this.persistRunMetadata(runId, {
            deliverableWorkflow: {
              ...deliverableWorkflow.selection,
              plan: deliverablePlan,
            },
          });
          this.updateRunGoalContract(runId, {
            goal: deliverableWorkflow.selection.goal,
          });
          this.recordRunEvent(userId, runId, 'deliverable_workflow_selected', {
            type: deliverableWorkflow.selection.type,
            confidence: deliverableWorkflow.selection.confidence,
            goal: deliverableWorkflow.selection.goal,
            requestedOutputs: deliverableWorkflow.selection.requestedOutputs,
          }, { agentId });
        }
      }

      if (analysis.mode === 'plan_execute') {
        const planResult = await runWithModelFallback('execution planning', () => this.createExecutionPlan({
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
        this.persistRunMetadata(runId, { executionPlan: plan });
        this.updateRunGoalContract(runId, goalContractFromPlan(plan));
        this.emit(userId, 'run:plan', {
          runId,
          steps: plan.steps,
          successCriteria: plan.success_criteria,
          verificationFocus: plan.verification_focus,
        });
      }

      const runGoalContract = this.getRunMeta(runId)?.goalContract || null;
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
        this.recordRunEvent(userId, runId, 'deliverable_execution_started', {
          type: deliverableWorkflow?.selection?.type,
          preferredTools: deliverablePlan.preferredTools || [],
          expectedOutputs: deliverablePlan.expectedOutputs || [],
        }, { agentId });
      }
      messages = sanitizeConversationMessages(messages);

      if (analysis.mode === 'execute' || analysis.mode === 'plan_execute') {
        messages.push({
          role: 'system',
          content: 'Research budget: after 3 read/list/search tool calls, you must take a concrete action (write, create, send, update) or explain clearly why you cannot. Work on one item at a time — do not queue up more reads.',
        });
      }

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

      while (!directAnswerEligible && iteration < maxIterations) {
        if (this.isRunStopped(runId)) break;
        iteration++;

        const systemSteeringAtLoopStart = this.applyQueuedSystemSteering(runId, messages);
        messages = systemSteeringAtLoopStart.messages;
        const steeringAtLoopStart = this.applyQueuedSteering(runId, messages, {
          userId,
          conversationId
        });
        messages = steeringAtLoopStart.messages;
        messages = sanitizeConversationMessages(messages);
        this.updateRunProgress(runId, {
          currentPhase: 'model',
          currentStep: `model:${iteration}`,
          currentTool: null,
          currentStepStartedAt: isoNow(),
        });

        let metrics = this.estimatePromptMetrics(messages, tools);
        const contextWindow = provider.getContextWindow(model);
        if (metrics.totalEstimatedTokens > contextWindow * loopPolicy.compactionThreshold) {
          messages = await withModelCallTimeout(
            compact(messages, provider, model, contextWindow),
            options,
            `Context compaction before iteration ${iteration}`,
          );
          messages = sanitizeConversationMessages(messages);
          this.emit(userId, 'run:compaction', { runId, iteration });
          metrics = this.estimatePromptMetrics(messages, tools);
        }

        promptMetrics = this.mergePromptMetrics(promptMetrics, metrics, iteration, tools.length);
        this.persistPromptMetrics(runId, promptMetrics).catch(() => { });
        this.emit(userId, 'run:thinking', { runId, iteration });
        this.recordRunEvent(userId, runId, 'model_turn_started', {
          iteration,
          toolCount: tools.length,
        }, { agentId });

        let response;
        let responseModel = model;
        let streamContent = '';

        const tryModelCall = async (retryForFallback = true) => {
          try {
            const modelCall = await this.requestModelResponse({
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

              const fallbackCall = await this.requestModelResponse({
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
            this.emit(userId, 'run:interim', {
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

        this.recordRunEvent(userId, runId, 'model_turn_completed', {
          iteration,
          toolCallCount: response.toolCalls?.length || 0,
          contentPreview: String(lastContent || streamContent || '').slice(0, 240),
        }, { agentId });
        this.updateRunProgress(runId, {}, {
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
          this.updateRunProgress(runId, {
            currentPhase: 'idle',
            currentStep: null,
            currentTool: null,
            currentStepStartedAt: null,
          });
          // Check for queued steering first — if something was injected while the
          // model was responding (e.g. a heartbeat nudge), give the model a chance
          // to act on it before we treat this as a final answer.
          const systemSteeringAfterResponse = this.applyQueuedSystemSteering(runId, messages);
          messages = systemSteeringAfterResponse.messages;
          if (systemSteeringAfterResponse.appliedCount > 0) {
            iteration = Math.max(0, iteration - 1);
            lastContent = '';
            continue;
          }
          const steeringAfterResponse = this.applyQueuedSteering(runId, messages, {
            userId,
            conversationId
          });
          messages = steeringAfterResponse.messages;
          if (steeringAfterResponse.appliedCount > 0) {
            iteration = Math.max(0, iteration - 1);
            lastContent = '';
            continue;
          }
          if (this.shouldFastCompleteVoiceReply({
            options,
            toolExecutions,
            failedStepCount,
            messagingSent: this.activeRuns.get(runId)?.messagingSent || false,
            lastReply: lastContent,
          })) {
            break;
          }
          // AI returned text with no tool calls → trust it as the final answer.
          directAnswerEligible = true;
          break;
        }

        const canRunParallelBatch = (
          response.toolCalls.length > 1
          && response.toolCalls.every((toolCall) => this.isReadOnlyToolCall(toolCall))
        );
        if (canRunParallelBatch) {
          const parallelToolNames = response.toolCalls
            .map((toolCall) => toolCall.function?.name)
            .filter(Boolean);
          this.updateRunProgress(runId, {
            currentPhase: 'tool',
            currentStep: `parallel:${iteration}`,
            currentTool: parallelToolNames.join(', ') || 'parallel tools',
            currentStepStartedAt: isoNow(),
          });
          const batch = await this.executeReadOnlyBatch(response.toolCalls, {
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
            this.getRunMeta(runId)?.repetitionGuard?.observe(item.toolName, item.toolArgs, item.result);
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
          this.persistRunMetadata(runId, {
            evidenceSources: [...new Set(toolExecutions.map((item) => item.evidenceSource).filter(Boolean))],
            subagentState: this.listSubagents(runId),
            deliverableArtifacts,
            compactionMetrics: compactionMetrics.slice(-20),
          });
          this.updateRunProgress(runId, {
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
          if (this.isRunStopped(runId)) break;
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
          // Trust the model — no separate judge LLM call needed.
          if (toolName === 'task_complete') {
            const finalMessage = String(toolArgs.message || '').trim();
            this.recordRunEvent(userId, runId, 'task_complete_signaled', {
              accepted: true,
              iteration,
              messageLength: finalMessage.length,
            }, { agentId });
            console.info(
              `[Run ${shortenRunId(runId)}] task_complete accepted at iteration=${iteration}`
            );
            lastContent = finalMessage;
            directAnswerEligible = true;
            break;
          }

          const repetitionGuard = this.getRunMeta(runId)?.repetitionGuard;
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
            this.recordRunEvent(userId, runId, 'repetition_blocked', {
              toolName,
              toolArgs,
            }, { agentId });
            this.emit(userId, 'run:tool_end', {
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
            .run(stepId, runId, stepIndex, this.getStepType(toolName), `${toolName}: ${JSON.stringify(toolArgs).slice(0, 200)} `, 'running', toolName, JSON.stringify(toolArgs));
          this.updateRunProgress(runId, {
            currentPhase: 'tool',
            currentStep: stepId,
            currentTool: toolName,
            currentStepStartedAt: isoNow(),
          }, {
            stepId,
          });

          this.emit(userId, 'run:tool_start', {
            runId, stepId, stepIndex, toolName, toolArgs,
            type: this.getStepType(toolName)
          });
          this.recordRunEvent(userId, runId, 'tool_started', {
            stepIndex,
            toolName,
            toolArgs,
            type: this.getStepType(toolName),
          }, { agentId, stepId });
          console.info(
            `[Run ${shortenRunId(runId)}] step=${stepIndex} start tool=${toolName} args=${summarizeForLog(toolArgs)}`
          );

          let toolResult;
          let toolErrorMessage = '';
          try {
            toolResult = await this.executeTool(toolName, toolArgs, {
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
            this.detachProcessFromRun(runId, toolResult?.pid);
            toolErrorMessage = inferToolFailureMessage(toolName, toolResult);
            if (toolErrorMessage) {
              failedStepCount++;
            }
            const screenshotPath = toolResult?.screenshotPath || null;
            const stepStatus = this.isRunStopped(runId) ? 'stopped' : (toolErrorMessage ? 'failed' : 'completed');
            db.prepare('UPDATE agent_steps SET status = ?, result = ?, error = ?, screenshot_path = ?, completed_at = datetime(\'now\') WHERE id = ?')
              .run(stepStatus, JSON.stringify(toolResult).slice(0, 20000), toolErrorMessage || null, screenshotPath, stepId);
            if (toolErrorMessage) {
              this.emit(userId, 'run:tool_end', { runId, stepId, toolName, error: toolErrorMessage, result: toolResult, screenshotPath, status: stepStatus });
              this.recordRunEvent(userId, runId, 'tool_failed', {
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
              this.emit(userId, 'run:tool_end', { runId, stepId, toolName, result: toolResult, screenshotPath, status: stepStatus });
              this.recordRunEvent(userId, runId, 'tool_completed', {
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
            this.detachProcessFromRun(runId, toolResult?.pid);
            db.prepare('UPDATE agent_steps SET status = ?, error = ?, completed_at = datetime(\'now\') WHERE id = ?')
              .run('failed', err.message, stepId);
            this.emit(userId, 'run:tool_end', { runId, stepId, toolName, error: err.message, status: 'failed' });
            this.recordRunEvent(userId, runId, 'tool_failed', {
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
                this.recordRunEvent(userId, runId, 'deliverable_artifact_produced', {
                  type: deliverableWorkflow.selection.type,
                  toolName,
                  artifact,
                }, { agentId, stepId });
              }
            }
          }
          this.persistRunMetadata(runId, {
            evidenceSources: [...new Set(toolExecutions.map((item) => item.evidenceSource).filter(Boolean))],
            subagentState: this.listSubagents(runId),
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
            this.persistRunMetadata(runId, {
              compactionMetrics: compactionMetrics.slice(-20),
            });
            this.recordRunEvent(userId, runId, 'pre_model_compaction_applied', {
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
            tools = this.getActiveTools(runId);
          }

          if (toolErrorMessage) {
            consecutiveToolFailures += 1;
            const currentRunMeta = this.getRunMeta(runId);
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
              const currentRunMeta = this.getRunMeta(runId);
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

          this.updateRunProgress(runId, {
            currentPhase: 'idle',
            currentStep: null,
            currentTool: null,
            currentStepStartedAt: null,
          }, {
            verified: true,
            stepId,
          });

          const runMeta = this.activeRuns.get(runId);
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

        if (this.isRunStopped(runId)) break;
        if (this.getRunMeta(runId)?.terminalInterim) break;
        if (this.getRunMeta(runId)?.widgetSnapshotSaved) break;
        if (!this.activeRuns.has(runId)) break;
      }

      if (this.isRunStopped(runId)) {
        db.prepare('UPDATE agent_runs SET status = ?, updated_at = datetime(\'now\'), completed_at = datetime(\'now\') WHERE id = ?')
          .run('stopped', runId);
        console.warn(
          `[Run ${shortenRunId(runId)}] stopped trigger=${triggerSource} steps=${stepIndex} tokens=${totalTokens}`
        );
        this.stopMessagingProgressSupervisor(runId);
        this.activeRuns.delete(runId);
        this.emit(userId, 'run:stopped', { runId, triggerSource });
        this.recordRunEvent(userId, runId, 'run_stopped', {
          triggerSource,
          totalTokens,
          iterations: iteration,
        }, { agentId });
        return { runId, content: '', totalTokens, iterations: iteration, status: 'stopped' };
      }

      const runMeta = this.activeRuns.get(runId);
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
                reasoningEffort: this.getReasoningEffort(providerName, options)
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
          // Grace call: budget exhausted but no content yet.
          // Strip tools and ask the model to summarise what it accomplished.
          // Mirrors the Hermes handle_max_iterations() pattern.
          console.warn(`[Run ${shortenRunId(runId)}] iteration_limit runId=${shortenRunId(runId)} — making grace call`);
          try {
            const graceMessages = sanitizeConversationMessages([
              ...messages,
              {
                role: 'user',
                content: 'You have reached the maximum number of tool-calling iterations allowed. Please provide a final response summarising what you found and accomplished so far, without calling any more tools.',
              },
            ]);
            const graceResponse = await withModelCallTimeout(
              provider.chat(graceMessages, [], {
                model,
                reasoningEffort: this.getReasoningEffort(providerName, options),
              }),
              options,
              `Grace call after ${maxIterations} iterations`,
            );
            totalTokens += graceResponse.usage?.totalTokens || 0;
            lastContent = sanitizeModelOutput(graceResponse.content || '', { model });
            if (lastContent) {
              messages.push({ role: 'assistant', content: lastContent });
              if (conversationId) {
                db.prepare('INSERT INTO conversation_messages (conversation_id, role, content, tokens) VALUES (?, ?, ?, ?)')
                  .run(conversationId, 'assistant', lastContent, graceResponse.usage?.totalTokens || 0);
              }
            }
          } catch (graceErr) {
            console.warn(`[Run ${shortenRunId(runId)}] grace call failed: ${graceErr?.message}`);
          }
          if (!normalizeOutgoingMessage(lastContent, options?.source || null)) {
            throw new Error(`Iteration limit reached before explicit completion after ${maxIterations} iterations.`);
          }
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
        const verificationResult = await runWithModelFallback('final verification', () => this.verifyFinalResponse({
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
        this.persistRunMetadata(runId, {
          verification,
          evidenceSources: verificationResult.evidenceSources,
        });
        this.emit(userId, 'run:verification', {
          runId,
          ...verification,
          evidenceSources: verificationResult.evidenceSources,
        });
      }

      if (deliverableWorkflow && deliverablePlan) {
        this.recordRunEvent(userId, runId, 'deliverable_validation_started', {
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
        this.persistRunMetadata(runId, {
          deliverable: validationResult.result,
        });
        if (deliverableValidation.status !== 'passed') {
          this.recordRunEvent(userId, runId, 'deliverable_validation_failed', {
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
        await this.persistDeliverableMemory(userId, runId, agentId, validationResult.result);
        this.recordRunEvent(userId, runId, 'deliverable_completed', {
          type: deliverableWorkflow.selection.type,
          artifactCount: validationResult.result.artifacts.length,
          summary: validationResult.result.summary,
        }, { agentId });
      }

      db.prepare('UPDATE agent_runs SET status = ?, total_tokens = ?, final_response = ?, updated_at = datetime(\'now\'), completed_at = datetime(\'now\') WHERE id = ?')
        .run('completed', totalTokens, finalResponseText || null, runId);

      if (conversationId) {
        db.prepare('UPDATE conversations SET total_tokens = total_tokens + ?, updated_at = datetime(\'now\') WHERE id = ?')
          .run(totalTokens, conversationId);
        if (options.skipConversationMaintenance !== true) {
          refreshConversationSummary(conversationId, provider, model, historyWindow).catch((err) => {
            console.error('[AI] Conversation summary refresh failed:', err.message);
          });
        }
      }

      await this.persistPromptMetrics(runId, {
        ...promptMetrics,
        finalTotalTokens: totalTokens
      });

      await this.persistRunContext(userId, {
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
        if (this.shouldSendMessagingFinalFallback(runMeta, lastContent || '', options.source) && !lastFinalDeliveryMessage) {
          await this.deliverMessagingFinalFallback({
            runId,
            userId,
            agentId,
            platform: options.source,
            chatId: options.chatId,
            content: lastContent || '',
          });
        }
      }

      if (conversationId && options.skipConversationMaintenance !== true) {
        await this.refreshConversationState({
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
      this.cleanupSubagentsForRun(runId, { cancelRunning: true });
      this.stopMessagingProgressSupervisor(runId);
      this.activeRuns.delete(runId);
      this.emit(userId, 'run:complete', {
        runId,
        content: lastContent,
        totalTokens,
        iterations: iteration,
        triggerSource,
        executionMode: analysis?.mode || 'execute',
        verificationStatus: verification?.status || 'skipped',
      });
      this.recordRunEvent(userId, runId, 'run_completed', {
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
      if (this.learningManager) {
        try {
          const learningSteps = db.prepare(
            `SELECT tool_name, tool_input, result, status
             FROM agent_steps WHERE run_id = ? ORDER BY step_index ASC`
          ).all(runId);
          this.learningManager.maybeCaptureDraft({
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
      if (this.isRunStopped(runId)) {
        db.prepare('UPDATE agent_runs SET status = ?, updated_at = datetime(\'now\'), completed_at = datetime(\'now\') WHERE id = ?')
          .run('stopped', runId);
        console.warn(
          `[Run ${shortenRunId(runId)}] stopped trigger=${triggerSource} steps=${stepIndex} tokens=${totalTokens}`
        );
        this.cleanupSubagentsForRun(runId, { cancelRunning: true });
        this.stopMessagingProgressSupervisor(runId);
        this.activeRuns.delete(runId);
        this.emit(userId, 'run:stopped', { runId, triggerSource });
        this.recordRunEvent(userId, runId, 'run_stopped', {
          triggerSource,
          totalTokens,
          iterations: iteration,
        }, { agentId });
        return { runId, content: '', totalTokens, iterations: iteration, status: 'stopped' };
      }

      const runMeta = this.activeRuns.get(runId);
      const retryCount = Number(options.messagingAutonomousRetryCount || 0);
      // Rate-limit errors (429) must not trigger messaging retries: the model
      // won't be available in the milliseconds between retries, so spawning new
      // runs just compounds the rate-limit pressure with no benefit.
      const isRateLimitError = /429|rate.?limit|free-models-per/i.test(String(err?.message || ''));
      const canRetryMessagingRun = (
        triggerSource === 'messaging'
        && options.source
        && options.chatId
        && runMeta?.finalDeliverySent !== true
        && runMeta?.messagingSent !== true
        && err?.disableAutonomousRetry !== true
        && !isRateLimitError
        && retryCount < this.getMessagingRetryLimit(maxIterations)
      );

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
        this.cleanupSubagentsForRun(runId, { cancelRunning: true });
        this.stopMessagingProgressSupervisor(runId);
        this.activeRuns.delete(runId);
        this.emit(userId, 'run:interim', {
          runId,
          message: 'Retrying internally after a transient failure.',
          phase: 'retrying'
        });

        const retryOptions = {
          ...options,
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
        delete retryOptions.runId;

        return this.runWithModel(userId, userMessage, retryOptions, _modelOverride);
      }

      const deliverableFailureResponse = err?.deliverableResult?.summary
        || err?.deliverableValidation?.summary
        || '';
      let messagingFailureContent = '';
      let sendSucceeded = false;
      if (triggerSource === 'messaging' && options.source && options.chatId) {
        if (!runMeta?.finalDeliverySent && !runMeta?.messagingSent) {
          const manager = this.messagingManager;
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
                  reasoningEffort: this.getReasoningEffort(providerName, options)
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
              this.markRunFinalDelivery(runId, messagingFailureContent);
            } catch (sendErr) {
              console.error('[Engine] Messaging error fallback failed:', sendErr.message);
              messagingFailureContent = '';
            }
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

      this.cleanupSubagentsForRun(runId, { cancelRunning: true });
      this.stopMessagingProgressSupervisor(runId);
      this.activeRuns.delete(runId);
      this.emit(userId, 'run:error', { runId, error: err.message });
      this.recordRunEvent(userId, runId, 'run_failed', {
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

  async spawnSubagent(userId, parentRunId, task, options = {}) {
    const handle = uuidv4();
    const childRunId = uuidv4();
    let relevantMemories = [];
    try {
      relevantMemories = this.memoryManager
        ? await this.memoryManager.recallMemory(userId, task, 4, {
          agentId: options.agentId || null,
        })
        : [];
    } catch {}
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
          },
          options.model || null
        );
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
        record.status = 'failed';
        record.error = err.message;
        this.emit(userId, 'run:subagent', {
          runId: parentRunId,
          handle,
          childRunId,
          status: 'failed',
          error: err.message,
        });
        throw err;
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
    const { agentCanDelegateTo, getAgentById, getAgentBySlug, resolveAgentId } = require('../agents/manager');
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

  cleanupSubagentsForRun(parentRunId, options = {}) {
    if (!parentRunId) return;
    const cancelRunning = options.cancelRunning !== false;
    for (const [handle, record] of this.subagents.entries()) {
      if (record.parentRunId !== parentRunId) continue;
      if (cancelRunning && record.status === 'running') {
        try {
          record.engine?.abort(record.childRunId);
          record.status = 'cancelled';
        } catch (err) {
          console.warn(`[AgentEngine] Failed to abort subagent ${handle}:`, err?.message);
        }
      }
      this.subagents.delete(handle);
    }
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

    record.engine?.abort(record.childRunId);
    record.status = 'cancelled';
    this.emit(record.userId, 'run:subagent', {
      runId: record.parentRunId,
      handle,
      childRunId: record.childRunId,
      status: 'cancelled',
    });

    return { handle, status: 'cancelled' };
  }

  stopRun(runId) {
    const runMeta = this.activeRuns.get(runId);
    const delegatedChildren = db.prepare(
      "SELECT child_run_id FROM agent_delegations WHERE parent_run_id = ? AND status = 'running'"
    ).all(runId);
    if (runMeta) {
      runMeta.status = 'stopped';
      runMeta.aborted = true;
      this.emit(runMeta.userId, 'run:stopping', { runId });
      for (const pid of runMeta.toolPids) {
        if (this.runtimeManager && typeof this.runtimeManager.killCommand === 'function') {
          void this.runtimeManager.killCommand(runMeta.userId, pid, 'aborted');
        }
      }
      runMeta.toolPids.clear();
    }
    for (const child of delegatedChildren) {
      if (child.child_run_id && child.child_run_id !== runId) {
        this.stopRun(child.child_run_id);
      }
    }
    db.prepare(
      "UPDATE agent_delegations SET status = 'stopped', updated_at = datetime('now'), completed_at = datetime('now') WHERE parent_run_id = ? AND status = 'running'"
    ).run(runId);
    db.prepare("UPDATE agent_runs SET status = 'stopped', updated_at = datetime('now') WHERE id = ?").run(runId);
  }

  abort(runId, { userId } = {}) {
    if (!runId) return false;
    if (userId != null) {
      // Ownership gate: never let one user abort another user's active run.
      const runMeta = this.activeRuns.get(runId);
      if (runMeta && Number(runMeta.userId) !== Number(userId)) return false;
    }
    this.stopRun(runId);
    return true;
  }

  abortAll(userId) {
    for (const [runId, run] of this.activeRuns) {
      if (run.userId === userId) this.stopRun(runId);
    }
  }

  getStepType(toolName) {
    if (toolName.startsWith('browser_')) return 'browser';
    if (toolName.startsWith('android_')) return 'android';
    if (toolName === 'execute_command') return 'cli';
    if (toolName.startsWith('memory_')) return 'memory';
    if (toolName === 'send_interim_update') return 'note';
    if (toolName === 'send_message') return 'messaging';
    if (toolName === 'make_call') return 'messaging';
    if (toolName.startsWith('mcp_') || toolName.includes('mcp')) return 'mcp';
    if (toolName === 'create_task' || toolName === 'update_task' || toolName === 'delete_task' || toolName === 'list_tasks' || toolName.includes('widget')) return 'tasks';
    if (toolName.includes('subagent')) return 'subagent';
    if (toolName === 'think') return 'thinking';
    return 'tool';
  }

  emit(userId, event, data) {
    if (this.io) {
      this.io.to(`user:${userId}`).emit(event, data);
    }
  }
}

module.exports = { AgentEngine, buildInitialRunMetadata, getProviderForUser };
