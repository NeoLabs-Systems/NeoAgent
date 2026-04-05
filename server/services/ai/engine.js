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
  normalizeExecutionPlan,
  normalizeTaskAnalysis,
  normalizeVerificationResult,
  parseJsonObject,
  shouldRunVerifier,
} = require('./taskAnalysis');
const { getCapabilityHealth, summarizeCapabilityHealth } = require('./capabilityHealth');

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

async function getProviderForUser(userId, task = '', isSubagent = false, modelOverride = null, providerConfig = {}) {
  const { getSupportedModels, createProviderInstance } = require('./models');
  const models = await getSupportedModels(userId);

  let enabledIds = [];
  let defaultChatModel = 'auto';
  let defaultSubagentModel = 'auto';

  let smarterSelection = true;

  try {
    const rows = db.prepare('SELECT key, value FROM user_settings WHERE user_id = ? AND key IN (?, ?, ?, ?)')
      .all(userId, 'enabled_models', 'default_chat_model', 'default_subagent_model', 'smarter_model_selector');

    for (const row of rows) {
      if (!row.value) continue;

      let parsedVal = row.value;
      try {
        parsedVal = JSON.parse(row.value);
      } catch { }

      if (row.key === 'enabled_models') enabledIds = parsedVal;
      if (row.key === 'default_chat_model') defaultChatModel = parsedVal;
      if (row.key === 'default_subagent_model') defaultSubagentModel = parsedVal;
      if (row.key === 'smarter_model_selector') smarterSelection = parsedVal !== false && parsedVal !== 'false';
    }
  } catch (e) {
    console.error('Failed to fetch model settings:', e.message);
  }

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

function estimateTokenValue(value) {
  if (!value) return 0;
  if (typeof value === 'string') return Math.ceil(value.length / 4);
  return Math.ceil(JSON.stringify(value).length / 4);
}

function normalizeOutgoingMessage(content) {
  return String(content || '')
    .replace(/\[NO RESPONSE\]/gi, '')
    .replace(/\s+/g, ' ')
    .trim();
}

function joinSentMessages(messages = []) {
  if (!Array.isArray(messages)) return '';
  return messages
    .map((message) => String(message || '').trim())
    .filter(Boolean)
    .join('\n\n');
}

function isProactiveTrigger(triggerSource) {
  return triggerSource === 'scheduler';
}

function buildForcedFinalReplyPrompt(triggerSource) {
  if (triggerSource === 'messaging') {
    return 'Tool work is finished. Write the user-visible reply that should be sent back now. Do not call tools. Do not use [NO RESPONSE] unless the user explicitly asked for silence or no confirmation.';
  }

  return 'Tool work is finished. Write the final user-facing reply now. Do not call tools.';
}

function buildBlankMessagingReplyPrompt(attempt) {
  if (attempt <= 1) {
    return 'You must send one non-empty plain-text reply for the external messaging user right now. Do not call tools. Do not use markdown. Give either: (a) the concrete outcome, or (b) a clear blocker and the next action.';
  }

  return 'Your previous reply was empty. Return one non-empty plain-text message now. Do not call tools. Do not use markdown. If needed, apologize briefly, explain the blocker in one sentence, and tell the user what to do next.';
}

function buildDeterministicMessagingFallback({ failedStepCount, stepIndex }) {
  if (failedStepCount > 0) {
    return 'I ran into an internal tool issue while working on your request, so I could not verify a reliable final result yet. Please try again in a moment.';
  }
  if (stepIndex > 0) {
    return 'I completed part of the work, but the final reply did not render correctly. Please send the request again and I will continue from there.';
  }
  return 'I could not generate a clean final reply just now. Please send the request again and I will retry immediately.';
}

function buildModelFailureLoopPrompt({ failedModel, nextModel, errorMessage }) {
  return [
    `The previous model call on "${failedModel}" failed with: ${summarizeForLog(errorMessage, 220)}.`,
    `Continue on "${nextModel}" and recover autonomously.`,
    'If a previous plan depended on that failed call, adjust your approach and proceed end-to-end.',
    'Only ask the user for help if no safe path remains.'
  ].join(' ');
}

function buildMessagingErrorReply(err) {
  const message = String(err?.message || '').trim();
  if (!message) {
    return 'I ran into an internal error while processing your request. Please try again in a moment.';
  }

  if (/no ai providers? are currently available/i.test(message)) {
    return 'I cannot answer right now because no AI provider is available for this account. Please check provider settings and try again.';
  }

  if (/(timeout|timed out)/i.test(message)) {
    return 'I hit a timeout while processing your request. Please try again in a moment.';
  }

  return 'I ran into an internal error while processing your request. Please try again in a moment.';
}

const MAX_MESSAGING_AUTONOMOUS_RETRIES = 1;

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

function classifyToolExecution(toolName, result, errorMessage = '') {
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

  return {
    toolName: name,
    ok: !errorMessage && !result?.error,
    error: errorMessage || result?.error || '',
    evidenceSource,
    evidenceRelevant,
    stateChanged,
    dependsOnOutput: true,
    summary: compactToolResult(name, {}, result || { error: errorMessage || 'Tool failed' }, {
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

class AgentEngine {
  constructor(io, services = {}) {
    this.io = io;
    this.maxIterations = 12;
    this.activeRuns = new Map();
    this.subagents = new Map();
    this.cliExecutor = services.cliExecutor || null;
    this.browserController = services.browserController || null;
    this.androidController = services.androidController || null;
    this.messagingManager = services.messagingManager || null;
    this.mcpManager = services.mcpManager || services.mcpClient || null;
    this.skillRunner = services.skillRunner || null;
    this.scheduler = services.scheduler || null;
    this.memoryManager = services.memoryManager || null;
  }

  async buildSystemPrompt(userId, context = {}) {
    const { buildSystemPrompt } = require('./systemPrompt');
    const { MemoryManager } = require('../memory/manager');
    const memoryManager = this.memoryManager || new MemoryManager();
    return buildSystemPrompt(userId, context, memoryManager);
  }

  persistRunMetadata(runId, patch = {}) {
    if (!runId || !patch || typeof patch !== 'object') return;
    const existing = db.prepare('SELECT metadata_json FROM agent_runs WHERE id = ?').get(runId);
    const current = parseMaybeJson(existing?.metadata_json, {}) || {};
    const next = { ...current, ...patch };
    db.prepare('UPDATE agent_runs SET metadata_json = ? WHERE id = ?')
      .run(JSON.stringify(next), runId);
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
        triggerSource: options.triggerSource || 'web',
        capabilityHealth: summary,
        tools,
        forceMode,
      }),
      maxTokens: 1100,
      normalize: normalizeTaskAnalysis,
      fallback: {
        mode: forceMode || 'execute',
        verification_need: 'light',
        planning_depth: forceMode === 'plan_execute' ? 'deep' : 'light',
      },
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
              content: buildBlankMessagingReplyPrompt(attempt)
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

    const fallback = buildDeterministicMessagingFallback({ failedStepCount, stepIndex });
    console.warn(
      `[Run ${shortenRunId(runId)}] blank_reply_recovery fallback=natural_language`
    );
    return { content: fallback, tokens: totalTokens, recovered: true };
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
    const cleanedOutput = clampRunContext(lastContent, 1200);
    const cleanedInput = clampRunContext(userMessage, 700);
    const meaningfulTrigger = ['messaging'].includes(triggerSource);

    if ((!meaningfulTrigger && stepIndex < 2) || !cleanedOutput) {
      return;
    }

    const parts = [
      `Recent ${triggerSource || 'agent'} run`,
      runTitle ? `Title: ${clampRunContext(runTitle, 140)}` : '',
      cleanedInput ? `Request: ${cleanedInput}` : '',
      `Outcome: ${cleanedOutput}`
    ].filter(Boolean);
    const summary = parts.join('\n');
    const { getMemoryStorageDecision } = require('../memory/policy');
    if (!getMemoryStorageDecision(summary).allow) {
      return;
    }

    try {
      const { MemoryManager } = require('../memory/manager');
      const memoryManager = this.memoryManager || new MemoryManager();
      await memoryManager.saveMemory(
        userId,
        summary,
        'episodic',
        meaningfulTrigger ? 7 : 5
      );
    } catch (err) {
      console.error('[AI] Failed to persist run context:', err.message);
    }
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
    return options.reasoningEffort || process.env.REASONING_EFFORT || 'low';
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
        } catch { }
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
    ensureDefaultAiSettings(userId);
    const aiSettings = getAiSettings(userId);

    const runId = options.runId || uuidv4();
    const conversationId = options.conversationId;
    const app = options.app;
    const triggerSource = options.triggerSource || 'web';
    const historyWindow = aiSettings.chat_history_window;
    const toolReplayBudget = aiSettings.tool_replay_budget_chars;
    const maxIterations = this.getIterationLimit(triggerType, aiSettings);
    const providerStatusConfig = {
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
    db.prepare(`INSERT OR REPLACE INTO agent_runs(id, user_id, title, status, trigger_type, trigger_source, model)
      VALUES(?, ?, ?, 'running', ?, ?, ?)`).run(runId, userId, runTitle, triggerType, triggerSource, model);

    this.activeRuns.set(runId, {
      userId,
      status: 'running',
      aborted: false,
      messagingSent: false,
      lastSentMessage: '',
      sentMessages: [],
      triggerType,
      triggerSource,
      startedAt: Date.now(),
      lastToolName: null,
      lastToolTarget: null,
      proactiveDeliveryCompleted: false,
      steeringQueue: [],
      toolPids: new Set()
    });
    this.emit(userId, 'run:start', { runId, title: runTitle, model, triggerType, triggerSource });
    console.info(
      `[Run ${shortenRunId(runId)}] started trigger=${triggerSource} type=${triggerType} model=${model} title=${summarizeForLog(runTitle, 120)}`
    );

    const systemPrompt = await this.buildSystemPrompt(userId, { ...(options.context || {}), userMessage });
    // Pass short descriptions so the model always knows every available tool.
    // compactToolDefinition caps tool desc at 120 chars, param desc at 70 chars.
    const builtInTools = this.getAvailableTools(app, {
      includeDescriptions: true,
      userId,
    });
    const mcpManager = app?.locals?.mcpManager || app?.locals?.mcpClient || this.mcpManager;
    const integrationManager = app?.locals?.integrationManager || null;
    const mcpTools = mcpManager ? mcpManager.getAllTools(userId) : [];
    const tools = selectToolsForTask(userMessage, builtInTools, mcpTools, options);
    const capabilityHealth = await getCapabilityHealth({ userId, app, engine: this });
    const capabilitySummary = summarizeCapabilityHealth(capabilityHealth);
    const integrationSummary = integrationManager?.summarizeConnectedProviders?.(userId) || '';

    const { MemoryManager } = require('../memory/manager');
    const memoryManager = this.memoryManager || new MemoryManager();
    const recallQuery = options.context?.rawUserMessage || userMessage;
    const recallMsg = options.skipGlobalRecall === true
      ? null
      : await memoryManager.buildRecallMessage(userId, recallQuery);

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

    try {
      if (options.skipTaskAnalysis === true) {
        analysis = {
          mode: options.forceMode === 'plan_execute' ? 'plan_execute' : 'execute',
          reply_mode: 'task',
          freshness_risk: 'none',
          verification_need: 'none',
          planning_depth: options.forceMode === 'plan_execute' ? 'deep' : 'light',
          confidence: 0.5,
          suggested_tools: [],
          needs_subagents: false,
          draft_reply: '',
          goal: 'Complete the user request accurately.',
          success_criteria: [],
        };
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
        totalTokens += analysisResult.usage || 0;
        analysis = { ...analysisResult.analysis };
        if (options.forceMode === 'plan_execute') {
          analysis.mode = 'plan_execute';
          analysis.planning_depth = 'deep';
        }
        if (analysis.mode === 'direct_answer' && (analysis.verification_need !== 'none' || analysis.freshness_risk !== 'none')) {
          analysis.mode = analysis.planning_depth === 'deep' ? 'plan_execute' : 'execute';
        }

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

      directAnswerEligible = (
        analysis.mode === 'direct_answer'
        && analysis.verification_need === 'none'
        && analysis.freshness_risk === 'none'
        && !analysis.needs_subagents
        && normalizeOutgoingMessage(analysis.draft_reply)
      );

      if (directAnswerEligible) {
        iteration = 1;
        lastContent = analysis.draft_reply.trim();
        messages.push({ role: 'assistant', content: lastContent });
        if (conversationId) {
          db.prepare('INSERT INTO conversation_messages (conversation_id, role, content, tokens) VALUES (?, ?, ?, ?)')
            .run(conversationId, 'assistant', lastContent, analysisResult.usage || 0);
        }
      }

      while (!directAnswerEligible && iteration < maxIterations) {
        if (this.isRunStopped(runId)) break;
        iteration++;

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
        const callOptions = { model, reasoningEffort: this.getReasoningEffort(providerName, options) };

        const tryModelCall = async (retryForFallback = true) => {
          const requestMessages = sanitizeConversationMessages(messages);
          try {
            if (options.stream !== false) {
              const gen = provider.stream(requestMessages, tools, callOptions);
              for await (const chunk of gen) {
                if (chunk.type === 'content') {
                  streamContent += chunk.content;
                  this.emit(userId, 'run:stream', {
                    runId,
                    content: sanitizeModelOutput(streamContent, { model }),
                    iteration
                  });
                }
                if (chunk.type === 'done') {
                  response = chunk;
                  responseModel = model;
                }
                if (chunk.type === 'tool_calls') {
                  response = {
                    content: chunk.content || streamContent,
                    toolCalls: chunk.toolCalls,
                    providerContentBlocks: chunk.providerContentBlocks || null,
                    finishReason: 'tool_calls',
                    usage: chunk.usage || null
                  };
                  responseModel = model;
                }
              }
            } else {
              response = await provider.chat(requestMessages, tools, callOptions);
              responseModel = model;
            }
          } catch (err) {
            console.error(`[Engine] Model call failed (${model}):`, err.message);
            if (retryForFallback && aiSettings.fallback_model_id && aiSettings.fallback_model_id !== model) {
              const failedModel = model;
              console.log(`[Engine] Attempting fallback to: ${aiSettings.fallback_model_id}`);
              const fallback = await getProviderForUser(
                userId,
                userMessage,
                triggerType === 'subagent',
                aiSettings.fallback_model_id,
                providerStatusConfig
              );
              provider = fallback.provider;
              model = fallback.model;
              providerName = fallback.providerName;

              // Recursive call once
              const retryOptions = { ...callOptions, model, reasoningEffort: this.getReasoningEffort(providerName, options) };
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

              if (options.stream !== false) {
                const gen = provider.stream(retryMessages, tools, retryOptions);
                for await (const chunk of gen) {
                  if (chunk.type === 'content') {
                    streamContent += chunk.content;
                    this.emit(userId, 'run:stream', {
                      runId,
                      content: sanitizeModelOutput(streamContent, { model }),
                      iteration
                    });
                  }
                  if (chunk.type === 'done') {
                    response = chunk;
                    responseModel = model;
                  }
                  if (chunk.type === 'tool_calls') {
                    response = {
                      content: chunk.content || streamContent,
                      toolCalls: chunk.toolCalls,
                      providerContentBlocks: chunk.providerContentBlocks || null,
                      finishReason: 'tool_calls',
                      usage: chunk.usage || null
                    };
                    responseModel = model;
                  }
                }
              } else {
                response = await provider.chat(retryMessages, tools, retryOptions);
                responseModel = model;
              }
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
            messages.push({
              role: 'system',
              content: buildModelFailureLoopPrompt({
                failedModel: model,
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
              app,
              triggerSource,
              taskId: options.taskId || null,
              deliveryState: options.deliveryState || null,
              allowMultipleProactiveMessages: options.allowMultipleProactiveMessages === true,
            });
            this.detachProcessFromRun(runId, toolResult?.pid);
            const screenshotPath = toolResult?.screenshotPath || null;
            const stepStatus = this.isRunStopped(runId) ? 'stopped' : 'completed';
            db.prepare('UPDATE agent_steps SET status = ?, result = ?, screenshot_path = ?, completed_at = datetime(\'now\') WHERE id = ?')
              .run(stepStatus, JSON.stringify(toolResult).slice(0, 20000), screenshotPath, stepId);
            this.emit(userId, 'run:tool_end', { runId, stepId, toolName, result: toolResult, screenshotPath, status: stepStatus });
            console.info(
              `[Run ${shortenRunId(runId)}] step=${stepIndex} done tool=${toolName} status=${stepStatus} durationMs=${Date.now() - stepStartedAt} result=${summarizeForLog(toolResult)}`
            );
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

          toolExecutions.push(classifyToolExecution(toolName, toolResult, toolErrorMessage));
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
            messages.push({
              role: 'system',
              content: `Tool "${toolName}" failed with error: ${summarizeForLog(toolErrorMessage, 240)}. Continue autonomously: retry with corrected arguments, try an alternative tool/path, or verify the outcome using other available tools. Contact the user only if no safe path remains.`
            });
          }

          if (toolName === 'execute_command' && (toolResult?.timedOut || toolResult?.killed)) {
            messages.push({
              role: 'system',
              content: 'The previous shell command did not finish cleanly. Keep working until you rerun it with enough time or verify the requested outcome with follow-up commands.'
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
            if (
              isProactiveTrigger(triggerSource)
              && options.allowMultipleProactiveMessages !== true
              && runMeta.messagingSent
              && (toolName === 'send_message' || toolName === 'notify_user' || toolName === 'make_call')
            ) {
              runMeta.proactiveDeliveryCompleted = true;
            }
            if (
              runMeta.proactiveDeliveryCompleted
              && isProactiveTrigger(triggerSource)
              && options.allowMultipleProactiveMessages !== true
            ) {
              lastContent = joinSentMessages(runMeta.sentMessages);
              break;
            }
          }
        }

        if (this.isRunStopped(runId)) break;
        if (!this.activeRuns.has(runId)) break;
        const runMeta = this.activeRuns.get(runId);
        if (
          runMeta?.proactiveDeliveryCompleted
          && isProactiveTrigger(triggerSource)
          && options.allowMultipleProactiveMessages !== true
        ) {
          lastContent = joinSentMessages(runMeta.sentMessages);
          break;
        }
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
      const messagingSent = runMeta?.messagingSent || false;
      const lastToolWasMessaging = runMeta?.lastToolName === 'send_message' || runMeta?.lastToolName === 'make_call';
      const proactiveDeliveryCompleted = runMeta?.proactiveDeliveryCompleted === true;

      const shouldForceFinalReply = !(
        isProactiveTrigger(triggerSource)
        && proactiveDeliveryCompleted
        && options.allowMultipleProactiveMessages !== true
      ) && (
        (iteration >= maxIterations && messages[messages.length - 1]?.role === 'tool')
        || (iteration < maxIterations && stepIndex > 0 && !lastContent.trim() && messages[messages.length - 1]?.role !== 'tool' && !lastToolWasMessaging)
      );

      if (shouldForceFinalReply) {
        const finalResponse = await provider.chat(sanitizeConversationMessages([
          ...messages,
          {
            role: 'system',
            content: buildForcedFinalReplyPrompt(triggerSource)
          }
        ]), tools, {
          model,
          reasoningEffort: this.getReasoningEffort(providerName, options)
        });
        lastContent = sanitizeModelOutput(finalResponse.content || '', { model });

        const finalAssistantMessage = { role: 'assistant', content: lastContent };
        if (finalResponse.providerContentBlocks?.length) {
          finalAssistantMessage.providerContentBlocks = finalResponse.providerContentBlocks;
        }
        messages.push(finalAssistantMessage);
        if (conversationId) {
          db.prepare('INSERT INTO conversation_messages (conversation_id, role, content, tokens) VALUES (?, ?, ?, ?)')
            .run(conversationId, 'assistant', lastContent, finalResponse.usage?.totalTokens || 0);
        }
        totalTokens += finalResponse.usage?.totalTokens || 0;
      }

      // runMeta and messagingSent are now defined above the forced reply block.

      if (triggerSource === 'messaging' && !normalizeOutgoingMessage(lastContent) && !messagingSent) {
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
          tools
        });
        lastContent = recovered.content;
        totalTokens += recovered.tokens || 0;
        if (normalizeOutgoingMessage(lastContent)) {
          messages.push({ role: 'assistant', content: lastContent });
          if (conversationId) {
            db.prepare('INSERT INTO conversation_messages (conversation_id, role, content, tokens) VALUES (?, ?, ?, ?)')
              .run(conversationId, 'assistant', lastContent, recovered.tokens || 0);
          }
        }
      }

      const sentMessageText = joinSentMessages(runMeta?.sentMessages);
      const normalizedLastContent = normalizeOutgoingMessage(lastContent);
      let finalResponseText = messagingSent
        ? (sentMessageText || (normalizedLastContent ? lastContent.trim() : ''))
        : (normalizedLastContent ? lastContent.trim() : sentMessageText);
      const lastSentMessage = normalizeOutgoingMessage(
        runMeta?.lastSentMessage
        || (Array.isArray(runMeta?.sentMessages) ? runMeta.sentMessages[runMeta.sentMessages.length - 1] : '')
        || ''
      );

      const shouldShortCircuitAfterProactiveDelivery = (
        isProactiveTrigger(triggerSource)
        && proactiveDeliveryCompleted
        && options.allowMultipleProactiveMessages !== true
      );

      if (
        !shouldShortCircuitAfterProactiveDelivery
        && options.skipVerifier !== true
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

      // Fallback: if this was a messaging-triggered run and the AI never called
      // send_message itself, auto-send its final text as a reply.
      // If a message was already sent earlier in this run, treat those send_message
      // calls as authoritative and do not auto-send additional model text.
      if (triggerSource === 'messaging' && options.source && options.chatId) {
        // Strip [NO RESPONSE] markers the AI may have embedded anywhere in the text,
        // then only send if real content remains.
        const cleanedContent = normalizeOutgoingMessage(lastContent || '');
        const shouldSendFallback = (
          cleanedContent
          && !messagingSent
          && cleanedContent !== lastSentMessage
        );
        if (shouldSendFallback) {
          const manager = this.messagingManager;
          if (manager) {
            const chunks = cleanedContent.split(/\n\s*\n/).filter((c) => c.trim().length > 0);
            console.info(
              `[Run ${shortenRunId(runId)}] messaging_fallback chunks=${chunks.length} to=${summarizeForLog(options.chatId, 80)}`
            );
            for (let i = 0; i < chunks.length; i++) {
              if (i > 0) {
                const delay = Math.max(1000, Math.min(chunks[i].length * 30, 4000));
                await manager.sendTyping(userId, options.source, options.chatId, true).catch(() => { });
                await new Promise((resolve) => setTimeout(resolve, delay));
              }
              await manager.sendMessage(userId, options.source, options.chatId, chunks[i], { runId }).catch((err) =>
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
        && !runMeta?.messagingSent
        && retryCount < MAX_MESSAGING_AUTONOMOUS_RETRIES
      );

      if (canRetryMessagingRun) {
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
          messagingAutonomousRetryCount: retryCount + 1
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
            try {
              const failedMessage = sanitizeConversationMessages([
                ...messages,
                {
                  role: 'system',
                  content: `The run encountered a runtime error and cannot continue reliably: ${summarizeForLog(err.message, 260)}. Do not call tools. Write exactly one short plain-text user message that explains the issue naturally and includes what the user should do next.`
                }
              ]);
              const modelReply = await provider.chat(failedMessage, [], {
                model,
                reasoningEffort: this.getReasoningEffort(providerName, options)
              });
              const drafted = sanitizeModelOutput(modelReply.content || '', { model });
              if (normalizeOutgoingMessage(drafted)) {
                messagingFailureContent = drafted.trim();
              }
            } catch {
              // Fall back to deterministic text below.
            }

            if (!messagingFailureContent) {
              messagingFailureContent = buildMessagingErrorReply(err);
            }

            try {
              await manager.sendMessage(userId, options.source, options.chatId, messagingFailureContent, { runId });
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
      cliExecutor: this.cliExecutor,
      browserController: this.browserController,
      androidController: this.androidController,
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
            app: options.app,
            triggerType: 'subagent',
            triggerSource: 'agent',
            runId: childRunId,
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
        } catch {}
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
    if (runMeta) {
      runMeta.status = 'stopped';
      runMeta.aborted = true;
      this.emit(runMeta.userId, 'run:stopping', { runId });
      for (const pid of runMeta.toolPids) {
        this.cliExecutor?.kill(pid, 'aborted');
      }
      runMeta.toolPids.clear();
    }
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
