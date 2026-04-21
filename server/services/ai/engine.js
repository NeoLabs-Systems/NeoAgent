const { v4: uuidv4 } = require('uuid');
const fs = require('fs');
const db = require('../../db/database');
const { compact } = require('./compaction');
const {
  getConversationContext,
  buildSummaryCarrier,
  refreshConversationSummary,
  sanitizeConversationMessages
} = require('./history');
const { ensureDefaultAiSettings, getAiSettings } = require('./settings');
const { selectToolsForTask } = require('./toolSelector');
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
  normalizeOutgoingMessageForPlatform,
  splitOutgoingMessageForPlatform,
} = require('../messaging/formatting_guides');
const {
  buildInterimMetadata,
  buildInterimSignature,
  normalizeInterimKind,
} = require('./interim');

const MAX_CONSECUTIVE_TOOL_FAILURES = 3;

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
  };
}

function buildAnalyzeTaskFallback(forceMode) {
  return {
    mode: forceMode || 'execute',
    verification_need: 'light',
    planning_depth: planningDepthForForceMode(forceMode),
  };
}

function applyForcedAnalysisMode(analysis, forceMode) {
  if (!analysis || typeof analysis !== 'object') return analysis;
  if (forceMode !== 'plan_execute') return analysis;
  return {
    ...analysis,
    mode: 'plan_execute',
    planning_depth: 'deep',
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
    const taskStr = String(task || '').toLowerCase();

    // Basic detection
    let isPlanning = /\b(plan|think|analy[sz]e|complex|step by step)\b/.test(taskStr);
    let isCoding = false;

    // Enhanced detection if enabled
    if (smarterSelection) {
      isPlanning = isPlanning || /\b(reason|strategy|logical|math|complex)\b/.test(taskStr);
      isCoding = /\b(code|program|script|debug|refactor|function|implementation|logic)\b/.test(taskStr);
    }

    if (isPlanning) {
      selectedModelDef = availableModels.find((m) => m.purpose === 'planning') || fallbackModel;
    } else if (isCoding) {
      selectedModelDef = availableModels.find((m) => m.purpose === 'coding') || availableModels.find((m) => m.purpose === 'planning') || fallbackModel;
    } else if (isSubagent) {
      selectedModelDef = availableModels.find((m) => m.purpose === 'fast') || fallbackModel;
    } else {
      selectedModelDef = availableModels.find((m) => m.purpose === 'general') || fallbackModel;
    }
  }

  return {
    provider: createProviderInstance(selectedModelDef.provider, userId, providerConfig),
    model: selectedModelDef.id,
    providerName: selectedModelDef.provider
  };
}

async function getFailureFallbackModelId(userId, agentId, currentModelId, preferredFallbackId = null) {
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

  if (preferredFallbackId && preferredFallbackId !== currentModelId) {
    const preferred = pool.find((model) => model.id === preferredFallbackId)
      || availableModels.find((model) => model.id === preferredFallbackId);
    if (preferred) return preferred.id;
  }

  if (currentModel?.provider) {
    const differentProvider = pool.find((model) => model.id !== currentModelId && model.provider !== currentModel.provider)
      || availableModels.find((model) => model.id !== currentModelId && model.provider !== currentModel.provider);
    if (differentProvider) return differentProvider.id;
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

function normalizeOutgoingMessage(content, platform = null, options = {}) {
  const normalized = normalizeOutgoingMessageForPlatform(platform, content);
  if (options.collapseWhitespace === false) {
    return normalized;
  }
  return normalized.replace(/\s+/g, ' ').trim();
}

function joinSentMessages(messages = []) {
  if (!Array.isArray(messages)) return '';
  return messages
    .map((message) => String(message || '').trim())
    .filter(Boolean)
    .join('\n\n');
}

function normalizeInterimText(content, platform = null) {
  return normalizeOutgoingMessageForPlatform(platform, content, {
    stripNoResponseMarker: false,
  }).trim();
}

function buildBlankMessagingReplyPrompt(attempt, platform = null) {
  const formattingGuide = buildPlatformFormattingGuide(platform);
  if (attempt <= 1) {
    return `You must send one non-empty reply for the external messaging user right now. Do not call tools. Give either: (a) the concrete outcome, or (b) a clear blocker. If tool work already happened, summarize what you actually tried and where it got blocked. Do not ask the user to repeat the original request. Do not promise future work unless that work already happened in this run or will happen automatically before this reply is sent.\n\n${formattingGuide}`;
  }

  return `Your previous reply was empty. Return one non-empty message now. Do not call tools. If needed, apologize briefly and explain the blocker in one sentence. Use the run evidence already in the conversation instead of asking the user to restate the task. Do not promise future work unless that work already happened in this run or will happen automatically before this reply is sent.\n\n${formattingGuide}`;
}

function parseToolExecutionSummary(item) {
  if (!item?.summary) return null;
  try {
    const parsed = JSON.parse(item.summary);
    return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : null;
  } catch {
    return null;
  }
}

function toolWorkDescription(toolName) {
  const name = String(toolName || '');
  if (name === 'execute_command') return 'ran shell commands';
  if (name === 'read_file' || name === 'search_files' || name === 'list_directory') return 'checked files';
  if (name === 'web_search' || name === 'http_request') return 'looked up supporting information';
  if (name.startsWith('browser_')) return 'checked the browser state';
  if (name.startsWith('android_')) return 'checked the Android state';
  if (name === 'read_health_data' || name.startsWith('recordings_')) return 'checked stored data';
  return '';
}

function summarizeRecentWork(toolExecutions = []) {
  const descriptions = [];
  for (const item of toolExecutions.slice(-6)) {
    const description = toolWorkDescription(item?.toolName);
    if (!description || descriptions.includes(description)) continue;
    descriptions.push(description);
    if (descriptions.length >= 2) break;
  }

  if (descriptions.length === 0) return '';
  if (descriptions.length === 1) return `I ${descriptions[0]}`;
  return `I ${descriptions[0]} and ${descriptions[1]}`;
}

function hasFailureSignal(text) {
  const normalized = normalizeOutgoingMessage(text);
  if (!normalized) return false;
  return /\b(error|failed|failure|traceback|exception|timed out|timeout|not found|no such file|permission denied|unable to|cannot|could not|module not found)\b/i.test(normalized);
}

function extractToolFailureMessage(item) {
  const directError = normalizeOutgoingMessage(item?.error || '');
  if (directError) return directError;

  const summary = parseToolExecutionSummary(item);
  if (!summary) return '';

  const candidates = [
    summary.message,
    summary.note,
    summary.stderr,
    summary.stdout,
    summary.content,
    summary.excerpt,
    summary.result,
    summary.summary,
  ];

  if (summary.status === 'error') {
    for (const candidate of candidates) {
      const normalized = normalizeOutgoingMessage(candidate || '');
      if (normalized) return normalized;
    }
    if (summary.exitCode != null) {
      return `The last shell command exited with code ${summary.exitCode}`;
    }
  }

  for (const candidate of candidates) {
    const normalized = normalizeOutgoingMessage(candidate || '');
    if (hasFailureSignal(normalized)) return normalized;
  }

  return '';
}

function buildDeterministicMessagingFallback({ failedStepCount, stepIndex, toolExecutions = [] }) {
  const workSummary = summarizeRecentWork(toolExecutions);
  const blocker = [...toolExecutions].reverse()
    .map((item) => extractToolFailureMessage(item))
    .find(Boolean);

  if (workSummary && blocker) {
    return `${workSummary}, but I got blocked: ${blocker}. I do not have a confirmed finished result yet.`;
  }
  if (blocker) {
    return `I got blocked while working on this: ${blocker}. I do not have a confirmed finished result yet.`;
  }
  if (workSummary && stepIndex > 0) {
    return `${workSummary}, but I do not have a confirmed finished result yet.`;
  }
  if (failedStepCount > 0) {
    return 'I ran into a tool problem while working on your request, so I do not have a confirmed finished result yet.';
  }
  if (stepIndex > 0) {
    return 'I completed part of the work, but I do not have a confirmed finished result yet.';
  }
  return 'I could not produce a reliable final reply just now.';
}

function buildMessagingFailureScenario({ err, failedStepCount, stepIndex, toolExecutions = [] }) {
  const parts = [];
  const runtimeError = normalizeOutgoingMessage(err?.message || '');
  const workSummary = summarizeRecentWork(toolExecutions);
  const blocker = [...toolExecutions].reverse()
    .map((item) => extractToolFailureMessage(item))
    .find(Boolean);

  if (runtimeError) {
    parts.push(`Runtime error: ${summarizeForLog(runtimeError, 260)}.`);
  }
  if (workSummary) {
    parts.push(`Observed work before failure: ${workSummary}.`);
  }
  if (blocker) {
    parts.push(`Most specific blocker from run evidence: ${summarizeForLog(blocker, 260)}.`);
  }
  if (stepIndex > 0) {
    parts.push(`Completed steps before failure: ${stepIndex}.`);
  }
  if (failedStepCount > 0) {
    parts.push(`Failed tool steps: ${failedStepCount}.`);
  }

  return parts.join(' ');
}

function buildDeterministicMessagingErrorReply({ err, failedStepCount, stepIndex, toolExecutions = [] }) {
  const message = normalizeOutgoingMessage(err?.message || '');
  if (/no ai providers? are currently available/i.test(message)) {
    return 'I cannot continue right now because no AI provider is available for this account. Please check the provider settings.';
  }

  if (/(timeout|timed out)/i.test(message)) {
    return 'I hit a timeout while processing your request and could not finish it reliably.';
  }

  const blocker = [...toolExecutions].reverse()
    .map((item) => extractToolFailureMessage(item))
    .find(Boolean);
  if (blocker) {
    return `I got blocked while checking this: ${blocker}.`;
  }

  if (message) {
    return `I got blocked while working on this: ${message}.`;
  }

  return buildDeterministicMessagingFallback({ failedStepCount, stepIndex, toolExecutions });
}

function buildModelFailureLoopPrompt({ failedModel, nextModel, errorMessage }) {
  return [
    `The previous model call on "${failedModel}" failed with: ${summarizeForLog(errorMessage, 220)}.`,
    `Continue on "${nextModel}" and recover autonomously.`,
    'If a previous plan depended on that failed call, adjust your approach and proceed end-to-end.',
    'Only ask the user for help if no safe path remains.'
  ].join(' ');
}

function clampRunContext(text, maxChars) {
  const value = normalizeOutgoingMessage(text);
  if (!value) return '';
  if (value.length <= maxChars) return value;
  return `${value.slice(0, maxChars)}...`;
}

function shortenRunId(runId) {
  const value = String(runId || '').trim();
  if (!value) return 'unknown';
  return value.length <= 8 ? value : value.slice(0, 8);
}

function summarizeForLog(value, maxChars = 220) {
  if (value == null) return '';

  let text = '';
  if (typeof value === 'string') {
    text = value;
  } else {
    try {
      text = JSON.stringify(value);
    } catch {
      text = String(value);
    }
  }

  const normalized = text.replace(/\s+/g, ' ').trim();
  if (normalized.length <= maxChars) return normalized;
  return `${normalized.slice(0, maxChars)}...`;
}

function parseMaybeJson(value, fallback = null) {
  if (!value) return fallback;
  if (typeof value === 'object') return value;
  try {
    return JSON.parse(value);
  } catch {
    return fallback;
  }
}

function classifyToolExecution(toolName, toolArgs = {}, result, errorMessage = '') {
  const name = String(toolName || '');
  const evidenceRelevantPrefixes = ['browser_', 'android_'];
  const evidenceRelevantExact = new Set([
    'web_search',
    'http_request',
    'read_file',
    'search_files',
    'list_directory',
    'session_search',
    'memory_recall',
    'analyze_image',
    'read_health_data',
    'recordings_list',
    'recordings_get',
    'recordings_search',
    'wait_subagent',
  ]);
  const stateChangingExact = new Set([
    'execute_command',
    'write_file',
    'edit_file',
    'send_interim_update',
    'send_message',
    'make_call',
    'create_skill',
    'update_skill',
    'delete_skill',
    'create_scheduled_task',
    'update_scheduled_task',
    'delete_scheduled_task',
    'schedule_run',
    'mcp_add_server',
    'mcp_remove_server',
    'spawn_subagent',
    'cancel_subagent',
  ]);

  const evidenceSource = name.startsWith('browser_')
    ? 'browser'
    : name.startsWith('android_')
      ? 'android'
      : name.startsWith('mcp_')
        ? 'mcp'
        : name.startsWith('memory_') || name === 'session_search'
          ? 'memory'
          : name === 'web_search'
            ? 'search'
            : name === 'http_request'
              ? 'http'
              : ['read_file', 'search_files', 'list_directory', 'write_file', 'edit_file'].includes(name)
                ? 'files'
                : name === 'execute_command'
                  ? 'command'
                  : name.includes('skill')
                    ? 'skills'
                    : name.includes('scheduled_task') || name === 'schedule_run'
                      ? 'scheduler'
                      : name === 'send_message' || name === 'make_call'
                        ? 'messaging'
                        : name.startsWith('recordings_') || name === 'read_health_data'
                          ? 'data'
                          : name === 'analyze_image'
                            ? 'vision'
                            : name.includes('subagent')
                              ? 'subagent'
                              : 'tool';

  const evidenceRelevant = evidenceRelevantExact.has(name)
    || evidenceRelevantPrefixes.some((prefix) => name.startsWith(prefix));
  const stateChanged = stateChangingExact.has(name)
    || name.startsWith('android_')
    || ['browser_click', 'browser_type', 'browser_evaluate'].includes(name);

  let normalizedError = String(errorMessage || result?.error || '').trim();
  if (!normalizedError && name === 'execute_command' && result && typeof result === 'object') {
    if (result.timedOut) {
      normalizedError = `Command timed out after ${result.durationMs || 'unknown'} ms`;
    } else if (result.killed || result.signal) {
      normalizedError = 'Command was killed before it finished';
    } else if (typeof result.exitCode === 'number' && result.exitCode !== 0) {
      normalizedError = summarizeForLog(result.stderr || result.stdout || `Command exited with code ${result.exitCode}`, 220);
    }
  }

  if (!normalizedError && result && typeof result === 'object') {
    const nestedResult = result.result && typeof result.result === 'object' && !Array.isArray(result.result)
      ? result.result
      : null;
    const detail = normalizeOutgoingMessage(
      result.reason
      || result.message
      || nestedResult?.reason
      || nestedResult?.message
      || ''
    );

    if (result.skipped === true || nestedResult?.skipped === true) {
      normalizedError = detail || 'Tool reported skipped outcome.';
    } else if (result.success === false || nestedResult?.success === false) {
      normalizedError = detail || 'Tool reported success=false.';
    } else if (result.sent === false || nestedResult?.sent === false) {
      normalizedError = detail || 'Tool reported sent=false.';
    }
  }

  return {
    toolName: name,
    ok: !normalizedError,
    error: normalizedError,
    evidenceSource,
    evidenceRelevant,
    stateChanged,
    dependsOnOutput: true,
    summary: compactToolResult(name, toolArgs, result || { error: errorMessage || 'Tool failed' }, {
      softLimit: 500,
      hardLimit: 900,
    }),
  };
}

function summarizeToolExecutions(toolExecutions = [], maxItems = 10) {
  return toolExecutions.slice(-maxItems).map((item, index) => {
    const status = item.ok ? 'ok' : `error=${item.error}`;
    return `${index + 1}. ${item.toolName} [${item.evidenceSource}] ${status} :: ${clampRunContext(item.summary || '', 220)}`;
  }).join('\n');
}

function summarizeAvailableTools(tools = [], { exclude = [] } = {}) {
  const excluded = new Set((Array.isArray(exclude) ? exclude : [exclude]).filter(Boolean));
  return tools
    .map((tool) => String(tool?.name || '').trim())
    .filter((name) => name && !excluded.has(name))
    .slice(0, 24)
    .join(', ');
}

function inferToolFailureMessage(toolName, result) {
  const explicitError = normalizeOutgoingMessage(result?.error || '');
  if (explicitError) return explicitError;

  if (!result || typeof result !== 'object') return '';

  if (toolName === 'execute_command') {
    if (result.timedOut) {
      return `Command timed out after ${result.durationMs || 'unknown'} ms`;
    }
    if (result.killed || result.signal) {
      return 'Command was killed before it finished';
    }
    if (typeof result.exitCode === 'number' && result.exitCode !== 0) {
      return summarizeForLog(result.stderr || result.stdout || `Command exited with code ${result.exitCode}`, 220);
    }
  }

  if (toolName === 'http_request' && typeof result.status === 'number' && result.status >= 400) {
    const bodySnippet = normalizeOutgoingMessage(result.body || '');
    return summarizeForLog(
      bodySnippet
        ? `HTTP request returned status ${result.status}: ${bodySnippet}`
        : `HTTP request returned status ${result.status}`,
      240
    );
  }

  return '';
}

function buildAutonomousRecoveryContext({ err, toolExecutions = [], tools = [], userMessage, visibleMessageSent = false }) {
  const lastFailure = [...toolExecutions].reverse().find((item) => !item.ok);
  const alternativeTools = summarizeAvailableTools(tools, { exclude: lastFailure?.toolName || null });
  const parts = [
    'This is an internal recovery retry for the same user task. Continue the task instead of stopping.',
    userMessage ? `Original task: ${clampRunContext(userMessage, 260)}` : '',
    lastFailure?.toolName ? `Previous attempt failed on tool: ${lastFailure.toolName}.` : '',
    lastFailure?.error ? `Concrete failure: ${summarizeForLog(lastFailure.error, 260)}.` : '',
    err?.message ? `Run-level error after that failure: ${summarizeForLog(err.message, 220)}.` : '',
    'Do not send a blocker message just because one tool path failed.',
    'Use a different safe approach if available: alternate tool, different query, browser path, HTTP fetch, file/code inspection, or command verification.',
    visibleMessageSent ? 'A user-facing message was already sent in a previous internal attempt. Continue silently unless you have a materially new finished result or a real external blocker.' : '',
    alternativeTools ? `Other available tools in this run: ${alternativeTools}.` : '',
    'Only stop if the remaining problem truly requires an external dependency or user action outside this run.'
  ];
  return parts.filter(Boolean).join(' ');
}

class AgentEngine {
  constructor(io, services = {}) {
    this.io = io;
    this.maxIterations = 12;
    this.activeRuns = new Map();
    this.subagents = new Map();
    this.app = services.app || null;
    this.cliExecutor = services.cliExecutor || null;
    this.browserController = services.browserController || null;
    this.androidController = services.androidController || null;
    this.runtimeManager = services.runtimeManager || null;
    this.messagingManager = services.messagingManager || null;
    this.mcpManager = services.mcpManager || services.mcpClient || null;
    this.skillRunner = services.skillRunner || null;
    this.scheduler = services.scheduler || null;
    this.memoryManager = services.memoryManager || null;
    this.voiceRuntimeManager = services.voiceRuntimeManager || null;
  }

  async buildSystemPrompt(userId, context = {}) {
    const { buildSystemPrompt } = require('./systemPrompt');
    const { MemoryManager } = require('../memory/manager');
    const memoryManager = this.memoryManager || new MemoryManager();
    const basePrompt = await buildSystemPrompt(userId, context, memoryManager);
    const skillRunner = context.skillRunner || this.skillRunner || null;
    const skillsPrompt = skillRunner?.getSkillsForPrompt?.({
      maxTotalChars: 9000,
      maxDescriptionChars: 180,
      maxTriggerChars: 100,
    }) || '';
    return [basePrompt, skillsPrompt].filter(Boolean).join('\n\n');
  }

  persistRunMetadata(runId, patch = {}) {
    if (!runId || !patch || typeof patch !== 'object') return;
    const existing = db.prepare('SELECT metadata_json FROM agent_runs WHERE id = ?').get(runId);
    const current = parseMaybeJson(existing?.metadata_json, {}) || {};
    const next = { ...current, ...patch };
    db.prepare('UPDATE agent_runs SET metadata_json = ? WHERE id = ?')
      .run(JSON.stringify(next), runId);
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
    const createdAt = new Date().toISOString();

    if (triggerSource === 'messaging') {
      if (!platform || !chatId || !this.messagingManager) {
        return { sent: false, skipped: true, reason: 'Messaging context is not available.' };
      }
      await this.messagingManager.sendMessage(userId, platform, chatId, normalizedContent, {
        agentId,
        runId,
        persistConversation: true,
        metadata,
        deliveryKind: 'interim',
      });
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
      createdAt,
    });
    runMeta.lastInterimMessage = normalizedContent;

    this.emit(userId, 'run:assistant_interim', {
      runId,
      content: normalizedContent,
      kind: normalizedKind,
      expectsReply: expectsReply === true,
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
        content: normalizedContent,
        createdAt,
      },
      terminalInterim: terminalInterim
        ? { kind: normalizedKind, content: normalizedContent, createdAt }
        : null,
    });

    return {
      sent: true,
      kind: normalizedKind,
      expectsReply: expectsReply === true,
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
  }) {
    const response = await provider.chat(
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
    );

    const parsed = parseJsonObject(response.content || '');
    return {
      value: normalize(parsed || {}, fallback),
      raw: response.content || '',
      usage: response.usage?.totalTokens || 0,
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
    const requestMessages = sanitizeConversationMessages(messages);
    const callOptions = {
      model,
      reasoningEffort: this.getReasoningEffort(providerName, options),
    };
    let response = null;
    let streamContent = '';

    if (options.stream !== false) {
      const stream = provider.stream(requestMessages, tools, callOptions);
      for await (const chunk of stream) {
        if (chunk.type === 'content') {
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
    } else {
      response = await provider.chat(requestMessages, tools, callOptions);
    }

    return {
      response: response || {
        content: streamContent,
        toolCalls: [],
        finishReason: 'stop',
        usage: null,
      },
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
      fallback: buildAnalyzeTaskFallback(forceMode),
      reasoningEffort: this.getReasoningEffort(providerName, options),
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
    });

    return {
      plan: response.value,
      raw: response.raw,
      usage: response.usage,
    };
  }

  async decideLoopState({
    provider,
    providerName,
    model,
    messages,
    tools,
    analysis,
    plan,
    toolExecutions,
    lastReply,
    triggerSource,
    iteration,
    maxIterations,
    options,
    fallbackStatus,
  }) {
    const successCriteria = Array.isArray(plan?.success_criteria)
      ? plan.success_criteria
        .map((item) => String(item || '').trim())
        .filter(Boolean)
        .slice(0, 6)
      : [];

    const response = await this.requestStructuredJson({
      provider,
      providerName,
      model,
      messages,
      prompt: [
        'Return JSON only.',
        'Decide whether this run should continue autonomously or stop now.',
        'Schema: {"status":"continue|complete|blocked","reason":"short concrete reason"}',
        'Rules:',
        '- Use "continue" whenever any safe next step remains in this same run.',
        '- Use "complete" only when the requested outcome is actually achieved or a truthful final user reply is already ready now.',
        '- Use "blocked" only when a specific external dependency outside this run is required.',
        '- If the latest draft asks the user for a missing required value, confirmation, or choice needed to proceed, use "blocked" so the run waits instead of repeating the same ask.',
        '- A progress update is not complete.',
        '- A single failed tool attempt is not blocked if another safe retry, verification step, or alternative path remains.',
        '- A tool-specific API error, timeout, rate limit, or missing result inside this run is usually "continue", not "blocked", if any other available tool could still make progress.',
        triggerSource === 'messaging'
          ? '- For messaging, do not stop on a partial status message. Continue unless the task is actually complete or externally blocked. If you already asked for missing user input, choose "blocked" and wait.'
          : '- Do not stop just because you wrote a status update. Continue unless the task is actually complete or externally blocked.',
        analysis?.goal ? `Goal: ${analysis.goal}` : '',
        successCriteria.length > 0 ? `Success criteria:\n${successCriteria.map((item, index) => `${index + 1}. ${item}`).join('\n')}` : '',
        `Current iteration: ${iteration} of ${maxIterations}.`,
        `Available tools in this run: ${summarizeAvailableTools(tools) || 'none'}`,
        `Recent tool evidence:\n${summarizeToolExecutions(toolExecutions, 8) || 'none'}`,
        `Latest draft reply:\n${normalizeOutgoingMessage(lastReply) || '(empty)'}`,
      ].filter(Boolean).join('\n'),
      maxTokens: 320,
      normalize: (raw) => {
        const allowed = new Set(['continue', 'complete', 'blocked']);
        const requestedStatus = String(raw.status || '').trim().toLowerCase();
        return {
          status: allowed.has(requestedStatus) ? requestedStatus : fallbackStatus,
          reason: String(raw.reason || '').trim().slice(0, 400),
        };
      },
      fallback: { status: fallbackStatus },
      reasoningEffort: this.getReasoningEffort(providerName, options),
    });

    return {
      decision: response.value,
      usage: response.usage,
    };
  }

  async verifyFinalResponse({
    provider,
    providerName,
    model,
    messages,
    analysis,
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
        content: 'Return JSON only. Distill the current thread working state. Keep it concise and concrete. Track summary, open_commitments, unresolved_questions, referenced_entities, and last_verified_facts. Do not invent facts.'
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

    const response = await provider.chat(promptMessages, [], {
      model,
      maxTokens: 800,
      reasoningEffort: this.getReasoningEffort(providerName, options),
    });
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
    return nextState;
  }

  async recoverBlankMessagingReply({
    userId,
    runId,
    messages,
    provider,
    model,
    providerName,
    options,
    stepIndex,
    failedStepCount,
    toolExecutions = [],
    tools = []
  }) {
    const attempts = 3;
    let recoveredContent = '';
    let totalTokens = 0;

    for (let attempt = 1; attempt <= attempts; attempt++) {
      console.warn(
        `[Run ${shortenRunId(runId)}] blank_reply_recovery attempt=${attempt} model=${model}`
      );
      try {
        const response = await provider.chat(
          sanitizeConversationMessages([
            ...messages,
            {
              role: 'system',
              content: buildBlankMessagingReplyPrompt(attempt, options?.source || null)
            }
          ]),
          [],
          {
            model,
            reasoningEffort: this.getReasoningEffort(providerName, options)
          }
        );
        totalTokens += response.usage?.totalTokens || 0;
        recoveredContent = sanitizeModelOutput(response.content || '', { model });
        if (normalizeOutgoingMessage(recoveredContent)) {
          console.info(
            `[Run ${shortenRunId(runId)}] blank_reply_recovery succeeded attempt=${attempt}`
          );
          return { content: recoveredContent, tokens: totalTokens, recovered: true };
        }
      } catch (recoverErr) {
        console.warn(
          `[Run ${shortenRunId(runId)}] blank_reply_recovery attempt=${attempt} failed: ${summarizeForLog(recoverErr?.message || recoverErr, 180)}`
        );
      }
    }

    const error = new Error(
      buildDeterministicMessagingFallback({
        failedStepCount,
        stepIndex,
        toolExecutions,
      })
    );
    error.code = 'BLANK_MESSAGING_REPLY';
    error.recoveryTokens = totalTokens;
    throw error;
  }

  getAvailableTools(app, options = {}) {
    const { getAvailableTools } = require('./tools');
    return getAvailableTools(app, options);
  }

  async executeTool(toolName, args, context) {
    const { executeTool } = require('./tools');
    return executeTool(toolName, args, context, this);
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

  isRunStopped(runId) {
    return this.getRunMeta(runId)?.aborted === true;
  }

  attachProcessToRun(runId, pid) {
    const runMeta = this.getRunMeta(runId);
    if (!runMeta || !pid) return;
    runMeta.toolPids.add(pid);
    if (runMeta.aborted && this.cliExecutor) {
      this.cliExecutor.kill(pid, 'aborted');
    }
  }

  detachProcessFromRun(runId, pid) {
    const runMeta = this.getRunMeta(runId);
    if (!runMeta || !pid) return;
    runMeta.toolPids.delete(pid);
  }

  getIterationLimit(triggerType, aiSettings) {
    if (triggerType === 'subagent') return aiSettings.subagent_max_iterations;
    return this.maxIterations;
  }

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
    return Math.max(1, maxIterations);
  }

  buildContextMessages(systemPrompt, summaryMessage, historyMessages, recallMsg) {
    const messages = [{ role: 'system', content: systemPrompt }];
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
    return this.runWithModel(userId, userMessage, options, null);
  }

  async runWithModel(userId, userMessage, options = {}, _modelOverride = null) {
    const triggerType = options.triggerType || 'user';
    const { resolveAgentId } = require('../agents/manager');
    const agentId = resolveAgentId(userId, options.agentId || options.agent_id || null);
    ensureDefaultAiSettings(userId, agentId);
    const aiSettings = getAiSettings(userId, agentId);

    const runId = options.runId || uuidv4();
    const conversationId = options.conversationId;
    const app = options.app || this.app;
    const triggerSource = options.triggerSource || 'web';
    const historyWindow = Math.max(
      1,
      Number(options.historyWindow || aiSettings.chat_history_window) || aiSettings.chat_history_window,
    );
    const toolReplayBudget = aiSettings.tool_replay_budget_chars;
    const maxIterations = this.getIterationLimit(triggerType, aiSettings);
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

    const runTitle = generateTitle(userMessage);
    db.prepare(`INSERT OR REPLACE INTO agent_runs(id, user_id, agent_id, title, status, trigger_type, trigger_source, model)
      VALUES(?, ?, ?, ?, 'running', ?, ?, ?)`).run(runId, userId, agentId, runTitle, triggerType, triggerSource, model);

    const retryMessagingState = options.messagingRetryState || {};
    const carriedVisibleMessage = String(retryMessagingState.lastVisibleMessage || '').trim();
    const carriedExplicitMessageSent = retryMessagingState.explicitMessageSent === true;

    this.activeRuns.set(runId, {
      userId,
      agentId,
      status: 'running',
      aborted: false,
      messagingSent: false,
      explicitMessageSent: carriedExplicitMessageSent,
      lastSentMessage: carriedExplicitMessageSent ? carriedVisibleMessage : '',
      sentMessages: [],
      triggerType,
      triggerSource,
      startedAt: Date.now(),
      lastToolName: null,
      lastToolTarget: null,
      lastInterimMessage: carriedExplicitMessageSent ? '' : carriedVisibleMessage,
      interimMessages: [],
      interimSignatures: new Set(),
      terminalInterim: null,
      voiceSessionId: options.voiceSessionId || null,
      steeringQueue: [],
      toolPids: new Set(),
    });
    this.emit(userId, 'run:start', { runId, agentId, title: runTitle, model, triggerType, triggerSource });
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
    });
    const mcpManager = app?.locals?.mcpManager || app?.locals?.mcpClient || this.mcpManager;
    const integrationManager = app?.locals?.integrationManager || null;
    const mcpTools = mcpManager ? mcpManager.getAllTools(userId, { agentId }) : [];
    const tools = selectToolsForTask(userMessage, builtInTools, mcpTools, options);
    const capabilityHealth = await getCapabilityHealth({ userId, agentId, app, engine: this });
    const capabilitySummary = summarizeCapabilityHealth(capabilityHealth);
    const integrationSummary = integrationManager?.summarizeConnectedProviders?.(userId, agentId) || '';

    const { MemoryManager } = require('../memory/manager');
    const memoryManager = this.memoryManager || new MemoryManager();
    const recallQuery = options.context?.rawUserMessage || userMessage;
    const recallMsg = options.skipGlobalRecall === true
      ? null
      : await memoryManager.buildRecallMessage(userId, recallQuery, { agentId });

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
    let analysis = null;
    let plan = null;
    let verification = null;
    let directAnswerEligible = false;
    let analysisUsage = 0;

    try {
      if (options.skipTaskAnalysis === true) {
        analysis = buildSkipTaskAnalysisResult(options.forceMode);
      } else {
        const analysisResult = await this.analyzeTask({
          provider,
          providerName,
          model,
          messages,
          tools,
          capabilityHealth,
          forceMode: options.forceMode || null,
          options: { ...options, triggerSource },
        });
        analysisUsage = analysisResult.usage || 0;
        totalTokens += analysisUsage;
        analysis = applyForcedAnalysisMode({ ...analysisResult.analysis }, options.forceMode);
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
        this.emit(userId, 'run:analysis', {
          runId,
          ...analysis,
          capabilitySummary,
        });
      }

      if (analysis.mode === 'plan_execute') {
        const planResult = await this.createExecutionPlan({
          provider,
          providerName,
          model,
          messages,
          analysis,
          capabilitySummary,
          options,
        });
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
        this.emit(userId, 'run:plan', {
          runId,
          steps: plan.steps,
          successCriteria: plan.success_criteria,
          verificationFocus: plan.verification_focus,
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

      while (!directAnswerEligible && iteration < maxIterations) {
        if (this.isRunStopped(runId)) break;
        iteration++;
        let consecutiveToolFailures = 0;

        const steeringAtLoopStart = this.applyQueuedSteering(runId, messages, {
          userId,
          conversationId
        });
        messages = steeringAtLoopStart.messages;
        messages = sanitizeConversationMessages(messages);

        let metrics = this.estimatePromptMetrics(messages, tools);
        const contextWindow = provider.getContextWindow(model);
        if (metrics.totalEstimatedTokens > contextWindow * 0.85) {
          messages = await compact(messages, provider, model, contextWindow);
          messages = sanitizeConversationMessages(messages);
          this.emit(userId, 'run:compaction', { runId, iteration });
          metrics = this.estimatePromptMetrics(messages, tools);
        }

        promptMetrics = this.mergePromptMetrics(promptMetrics, metrics, iteration, tools.length);
        this.persistPromptMetrics(runId, promptMetrics).catch(() => { });
        this.emit(userId, 'run:thinking', { runId, iteration });

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
              options: { ...options, userId },
              runId,
              iteration,
            });
            response = modelCall.response;
            responseModel = modelCall.responseModel;
            streamContent = modelCall.streamContent;
          } catch (err) {
            console.error(`[Engine] Model call failed (${model}):`, err.message);
            const fallbackModelId = retryForFallback
              ? await getFailureFallbackModelId(userId, agentId, model, aiSettings.fallback_model_id)
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
          const isFatalModelError = /no ai providers? are currently available|missing an api key|disabled in settings|unauthorized|forbidden|authentication failed/i
            .test(modelError);

          if (!isFatalModelError && modelFailureRecoveries < 2) {
            modelFailureRecoveries += 1;
            failedStepCount += 1;
            const failedModel = model;
            const fallbackModelId = await getFailureFallbackModelId(userId, agentId, model, aiSettings.fallback_model_id);
            if (fallbackModelId && fallbackModelId !== model) {
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
            }
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
          const messagingSent = this.activeRuns.get(runId)?.messagingSent || false;
          if (this.shouldFastCompleteVoiceReply({
            options,
            toolExecutions,
            failedStepCount,
            messagingSent,
            lastReply: lastContent,
          })) {
            break;
          }
          if (iteration < maxIterations) {
            const fallbackStatus = (toolExecutions.length > 0 || failedStepCount > 0 || messagingSent) ? 'continue' : 'complete';
            const loopState = await this.decideLoopState({
              provider,
              providerName,
              model,
              messages,
              tools,
              analysis,
              plan,
              toolExecutions,
              lastReply: lastContent,
              triggerSource,
              iteration,
              maxIterations,
              options,
              fallbackStatus,
            });
            totalTokens += loopState.usage || 0;
            if (loopState.decision.status === 'continue') {
              messages.push({
                role: 'system',
                content: [
                  loopState.decision.reason ? `Continue working: ${loopState.decision.reason}.` : 'Continue working autonomously.',
                  messagingSent
                    ? 'You already sent a user-facing message in this run. Keep working silently unless you have a materially new finished result or a real external blocker.'
                    : 'Use send_interim_update sparingly if a short real update or question would help. Otherwise keep working until you have the result or a real blocker.',
                ].join(' ')
              });
              lastContent = '';
              continue;
            }
          }
          break;
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

          db.prepare('INSERT INTO agent_steps (id, run_id, step_index, type, description, status, tool_name, tool_input, started_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, datetime(\'now\'))')
            .run(stepId, runId, stepIndex, this.getStepType(toolName), `${toolName}: ${JSON.stringify(toolArgs).slice(0, 200)} `, 'running', toolName, JSON.stringify(toolArgs));

          this.emit(userId, 'run:tool_start', {
            runId, stepId, stepIndex, toolName, toolArgs,
            type: this.getStepType(toolName)
          });
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
              console.warn(
                `[Run ${shortenRunId(runId)}] step=${stepIndex} failed tool=${toolName} durationMs=${Date.now() - stepStartedAt} error=${summarizeForLog(toolErrorMessage, 160)}`
              );
            } else {
              this.emit(userId, 'run:tool_end', { runId, stepId, toolName, result: toolResult, screenshotPath, status: stepStatus });
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
            console.warn(
              `[Run ${shortenRunId(runId)}] step=${stepIndex} failed tool=${toolName} durationMs=${Date.now() - stepStartedAt} error=${summarizeForLog(err.message, 160)}`
            );
          }

          const execution = classifyToolExecution(toolName, toolArgs, toolResult, toolErrorMessage);
          toolExecutions.push(execution);
          this.persistRunMetadata(runId, {
            evidenceSources: [...new Set(toolExecutions.map((item) => item.evidenceSource).filter(Boolean))],
            subagentState: this.listSubagents(runId),
          });

          const toolMessage = {
            role: 'tool',
            name: toolName,
            tool_call_id: toolCall.id,
            content: compactToolResult(toolName, toolArgs, toolResult, {
              softLimit: toolReplayBudget,
              hardLimit: 3200
            })
          };
          messages.push(toolMessage);

          if (toolErrorMessage) {
            consecutiveToolFailures += 1;
            const alternativeTools = summarizeAvailableTools(tools, { exclude: toolName });
            messages.push({
              role: 'system',
              content: [
                `Tool "${toolName}" failed with error: ${summarizeForLog(toolErrorMessage, 240)}.`,
                'This tool failure is not, by itself, a user-facing blocker.',
                'Continue autonomously: retry with corrected arguments, try an alternative tool/path, or verify the outcome using other available tools.',
                alternativeTools ? `Other available tools in this run: ${alternativeTools}.` : '',
                'Only stop and tell the user you are blocked if the remaining issue truly requires an external dependency or user action outside this run.'
              ].filter(Boolean).join(' ')
            });

            if (consecutiveToolFailures >= MAX_CONSECUTIVE_TOOL_FAILURES) {
              messages.push({
                role: 'system',
                content: `There were ${consecutiveToolFailures} consecutive tool failures. Stop calling tools now and return a clear blocker response that summarizes attempted actions and concrete errors.`
              });
              break;
            }
          } else {
            consecutiveToolFailures = 0;
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

          const runMeta = this.activeRuns.get(runId);
          if (runMeta) {
            runMeta.lastToolName = toolName;
            runMeta.lastToolTarget = toolName === 'send_message' ? toolArgs.to : null;
          }

          if (runMeta?.terminalInterim) {
            break;
          }
        }

        if (this.isRunStopped(runId)) break;
        if (this.getRunMeta(runId)?.terminalInterim) break;
        if (!this.activeRuns.has(runId)) break;
      }

      if (this.isRunStopped(runId)) {
        db.prepare('UPDATE agent_runs SET status = ?, updated_at = datetime(\'now\'), completed_at = datetime(\'now\') WHERE id = ?')
          .run('stopped', runId);
        console.warn(
          `[Run ${shortenRunId(runId)}] stopped trigger=${triggerSource} steps=${stepIndex} tokens=${totalTokens}`
        );
        this.activeRuns.delete(runId);
        this.emit(userId, 'run:stopped', { runId, triggerSource });
        return { runId, content: '', totalTokens, iterations: iteration, status: 'stopped' };
      }

      const runMeta = this.activeRuns.get(runId);
      if (runMeta?.terminalInterim) {
        lastContent = '';
      }
      const messagingSent = runMeta?.messagingSent || false;
      const lastToolWasMessaging = runMeta?.lastToolName === 'send_message' || runMeta?.lastToolName === 'make_call';

      if (triggerSource === 'messaging' && !normalizeOutgoingMessage(lastContent, options?.source || null) && !messagingSent) {
        const recovered = await this.recoverBlankMessagingReply({
          userId,
          runId,
          messages,
          provider,
          model,
          providerName,
          options,
          stepIndex,
          failedStepCount,
          toolExecutions,
          tools
        });
        lastContent = recovered.content;
        totalTokens += recovered.tokens || 0;
        if (normalizeOutgoingMessage(lastContent, options?.source || null)) {
          messages.push({ role: 'assistant', content: lastContent });
          if (conversationId) {
            db.prepare('INSERT INTO conversation_messages (conversation_id, role, content, tokens) VALUES (?, ?, ?, ?)')
              .run(conversationId, 'assistant', lastContent, recovered.tokens || 0);
          }
        }
      }

      if (!normalizeOutgoingMessage(lastContent, options?.source || null) && !messagingSent) {
        if (iteration >= maxIterations) {
          throw new Error(`Iteration limit reached before explicit completion after ${maxIterations} iterations.`);
        }
        if (stepIndex > 0 && !lastToolWasMessaging) {
          throw new Error('Run ended without an explicit completion or blocker reply.');
        }
      }

      const sentMessageText = joinSentMessages(runMeta?.sentMessages);
      const normalizedLastContent = normalizeOutgoingMessage(lastContent, options?.source || null);
      let finalResponseText = messagingSent
        ? (sentMessageText || (normalizedLastContent ? lastContent.trim() : ''))
        : (normalizedLastContent ? lastContent.trim() : sentMessageText);
      const lastVisibleMessage = normalizeOutgoingMessage(
        runMeta?.lastSentMessage
        || runMeta?.lastInterimMessage
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
        const verificationResult = await this.verifyFinalResponse({
          provider,
          providerName,
          model,
          messages,
          analysis,
          toolExecutions,
          finalReply: finalResponseText,
          options,
        });
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

      db.prepare('UPDATE agent_runs SET status = ?, total_tokens = ?, final_response = ?, updated_at = datetime(\'now\'), completed_at = datetime(\'now\') WHERE id = ?')
        .run('completed', totalTokens, finalResponseText || null, runId);

      if (conversationId) {
        db.prepare('UPDATE conversations SET total_tokens = total_tokens + ?, updated_at = datetime(\'now\') WHERE id = ?')
          .run(totalTokens, conversationId);
        if (options.skipConversationMaintenance !== true) {
          refreshConversationSummary(conversationId, provider, model, historyWindow).catch((err) => {
            console.error('[AI] Conversation summary refresh failed:', err.message);
          });
          this.refreshConversationState({
            conversationId,
            provider,
            providerName,
            model,
            finalReply: finalResponseText,
            analysis,
            verification,
            historyWindow,
            options,
          }).catch((err) => {
            console.error('[AI] Conversation working state refresh failed:', err.message);
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

      // Fallback: if this was a messaging-triggered run and no user-visible
      // message was already sent in this run, auto-send the final assistant text.
      // After any visible reply already went out, later user-facing messages
      // must be sent explicitly via send_message.
      if (triggerSource === 'messaging' && options.source && options.chatId) {
        // Strip [NO RESPONSE] markers the AI may have embedded anywhere in the text,
        // then only send if real content remains.
        const cleanedContent = normalizeOutgoingMessage(lastContent || '', options.source, {
          collapseWhitespace: false
        });
        const shouldSendFallback = (
          cleanedContent
          && runMeta?.explicitMessageSent !== true
          && !lastVisibleMessage
        );
        if (shouldSendFallback) {
          const manager = this.messagingManager;
          if (manager) {
            const chunks = splitOutgoingMessageForPlatform(options.source, cleanedContent);
            console.info(
              `[Run ${shortenRunId(runId)}] messaging_fallback chunks=${chunks.length} to=${summarizeForLog(options.chatId, 80)}`
            );
            for (let i = 0; i < chunks.length; i++) {
              if (i > 0) {
                const delay = Math.max(1000, Math.min(chunks[i].length * 30, 4000));
                await manager.sendTyping(userId, options.source, options.chatId, true, { agentId }).catch(() => { });
                await new Promise((resolve) => setTimeout(resolve, delay));
              }
              await manager.sendMessage(userId, options.source, options.chatId, chunks[i], { runId, agentId }).catch((err) =>
                console.error('[Engine] Auto-reply fallback failed:', err.message)
              );
            }
          }
        }
      }

      console.info(
        `[Run ${shortenRunId(runId)}] completed trigger=${triggerSource} steps=${stepIndex} tokens=${totalTokens} durationMs=${runMeta?.startedAt ? Date.now() - runMeta.startedAt : 0} finalResponse=${finalResponseText ? 'yes' : 'no'} sentMessages=${runMeta?.sentMessages?.length || 0}`
      );
      this.cleanupSubagentsForRun(runId, { cancelRunning: true });
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

      return { runId, content: lastContent, totalTokens, iterations: iteration, status: 'completed' };
    } catch (err) {
      if (this.isRunStopped(runId)) {
        db.prepare('UPDATE agent_runs SET status = ?, updated_at = datetime(\'now\'), completed_at = datetime(\'now\') WHERE id = ?')
          .run('stopped', runId);
        console.warn(
          `[Run ${shortenRunId(runId)}] stopped trigger=${triggerSource} steps=${stepIndex} tokens=${totalTokens}`
        );
        this.cleanupSubagentsForRun(runId, { cancelRunning: true });
        this.activeRuns.delete(runId);
        this.emit(userId, 'run:stopped', { runId, triggerSource });
        return { runId, content: '', totalTokens, iterations: iteration, status: 'stopped' };
      }

      const runMeta = this.activeRuns.get(runId);
      const retryCount = Number(options.messagingAutonomousRetryCount || 0);
      const canRetryMessagingRun = (
        triggerSource === 'messaging'
        && options.source
        && options.chatId
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
        const lastVisibleMessage = normalizeOutgoingMessage(
          runMeta?.lastSentMessage
          || runMeta?.lastInterimMessage
          || '',
          options?.source || null
        );
        db.prepare('UPDATE agent_runs SET status = ?, error = ?, updated_at = datetime(\'now\') WHERE id = ?')
          .run('retrying', err.message, runId);
        console.warn(
          `[Run ${shortenRunId(runId)}] retrying_messaging_attempt=${retryCount + 1} reason=${summarizeForLog(err.message, 140)}`
        );
        this.cleanupSubagentsForRun(runId, { cancelRunning: true });
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
            lastVisibleMessage: lastVisibleMessage || String(options?.messagingRetryState?.lastVisibleMessage || '').trim(),
            explicitMessageSent: runMeta?.explicitMessageSent === true || options?.messagingRetryState?.explicitMessageSent === true,
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

      let messagingFailureContent = '';
      let sendSucceeded = false;
      if (triggerSource === 'messaging' && options.source && options.chatId) {
        if (!runMeta?.messagingSent) {
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
              const modelReply = await provider.chat(failedMessage, [], {
                model,
                reasoningEffort: this.getReasoningEffort(providerName, options)
              });
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
              await manager.sendMessage(userId, options.source, options.chatId, messagingFailureContent, { runId, agentId });
              sendSucceeded = true;
              if (runMeta) {
                runMeta.lastSentMessage = messagingFailureContent;
                if (!Array.isArray(runMeta.sentMessages)) runMeta.sentMessages = [];
                runMeta.sentMessages.push(messagingFailureContent);
              }
            } catch (sendErr) {
              console.error('[Engine] Messaging error fallback failed:', sendErr.message);
              messagingFailureContent = '';
            }
          }
        }
      }

      db.prepare('UPDATE agent_runs SET status = ?, error = ?, final_response = ?, updated_at = datetime(\'now\') WHERE id = ?')
        .run('failed', err.message, sendSucceeded ? (messagingFailureContent || null) : null, runId);
      console.error(
        `[Run ${shortenRunId(runId)}] failed trigger=${triggerSource} steps=${stepIndex} tokens=${totalTokens} error=${summarizeForLog(err.message, 180)}`
      );

      this.cleanupSubagentsForRun(runId, { cancelRunning: true });
      this.activeRuns.delete(runId);
      this.emit(userId, 'run:error', { runId, error: err.message });

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
    const subEngine = new AgentEngine(this.io, {
      app: options.app || this.app,
      cliExecutor: this.cliExecutor,
      browserController: this.browserController,
      androidController: this.androidController,
      runtimeManager: this.runtimeManager,
      messagingManager: this.messagingManager,
      mcpManager: this.mcpManager,
      skillRunner: this.skillRunner,
      scheduler: this.scheduler,
      memoryManager: this.memoryManager,
    });

    const record = {
      handle,
      parentRunId,
      childRunId,
      userId,
      agentId: options.agentId || null,
      task,
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
          task,
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
        record.result = {
          runId: result.runId,
          content: result.content,
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
        this.cliExecutor?.kill(pid, 'aborted');
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

  abort(runId) {
    if (runId) this.stopRun(runId);
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
    if (toolName.includes('scheduled_task') || toolName === 'schedule_run') return 'scheduler';
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

module.exports = { AgentEngine, getProviderForUser };
