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

function buildForcedFinalReplyPrompt(triggerSource) {
  if (triggerSource === 'messaging') {
    return 'Tool work is finished. Write the user-visible reply that should be sent back now. Do not call tools. Do not use [NO RESPONSE] unless the user explicitly asked for silence or no confirmation.';
  }

  return 'Tool work is finished. Write the final user-facing reply now. Do not call tools.';
}

function buildBlankMessagingReplyPrompt(attempt) {
  if (attempt <= 1) {
    return 'You must produce one non-empty plain-text reply for the external messaging user right now. Do not call tools. Do not use markdown. Briefly summarize what you did or what blocked you.';
  }

  return 'Your previous reply was empty. Return one non-empty plain-text message now. Do not call tools. Do not use markdown. If needed, apologize briefly and explain the blocker in one or two sentences.';
}

function buildDeterministicMessagingFallback({ failedStepCount, stepIndex }) {
  if (failedStepCount > 0) {
    return 'I ran into an issue while working on that, so I do not have a clean final result yet. Ask me for a summary and I will explain what I found.';
  }
  if (stepIndex > 0) {
    return 'I worked on that, but I could not produce a clean summary before finishing. Ask me for a summary and I will condense what I found into one message.';
  }
  return 'I could not generate a proper reply just now, but I am still here. Please send the request again and I will try once more.';
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

class AgentEngine {
  constructor(io, services = {}) {
    this.io = io;
    this.maxIterations = 12;
    this.activeRuns = new Map();
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

  async recoverBlankMessagingReply({
    userId,
    runId,
    messages,
    provider,
    model,
    providerName,
    options,
    stepIndex,
    failedStepCount
  }) {
    const attempts = 2;
    let recoveredContent = '';
    let totalTokens = 0;

    for (let attempt = 1; attempt <= attempts; attempt++) {
      console.warn(
        `[Run ${shortenRunId(runId)}] blank_reply_recovery attempt=${attempt} model=${model}`
      );
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
    }

    const fallback = buildDeterministicMessagingFallback({ failedStepCount, stepIndex });
    console.warn(
      `[Run ${shortenRunId(runId)}] blank_reply_recovery fallback=deterministic`
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
    stepIndex
  }) {
    const cleanedOutput = clampRunContext(lastContent, 1200);
    const cleanedInput = clampRunContext(userMessage, 700);
    const meaningfulTrigger = ['messaging', 'scheduler', 'heartbeat'].includes(triggerSource);

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

    try {
      const { MemoryManager } = require('../memory/manager');
      const memoryManager = this.memoryManager || new MemoryManager();
      memoryManager.updateCore(userId, 'active_context', summary);
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
    const builtInTools = this.getAvailableTools(app, { includeDescriptions: true });
    const mcpManager = app?.locals?.mcpManager || app?.locals?.mcpClient || this.mcpManager;
    const mcpTools = mcpManager ? mcpManager.getAllTools(userId) : [];
    const tools = selectToolsForTask(userMessage, builtInTools, mcpTools, options);

    const { MemoryManager } = require('../memory/manager');
    const memoryManager = this.memoryManager || new MemoryManager();
    const recallQuery = options.context?.rawUserMessage || userMessage;
    const recallMsg = await memoryManager.buildRecallMessage(userId, recallQuery);

    let summaryMessage = null;
    let historyMessages = [];

    if (conversationId) {
      const conversationContext = getConversationContext(conversationId, historyWindow);
      summaryMessage = buildSummaryCarrier(conversationContext.summary);
      historyMessages = conversationContext.recentMessages;
    } else {
      summaryMessage = buildSummaryCarrier(options.priorSummary || '');
      historyMessages = (options.priorMessages || []).slice(-historyWindow).filter((pm) => pm.role && pm.content);
    }

    let messages = this.buildContextMessages(systemPrompt, summaryMessage, historyMessages, recallMsg);
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
    let promptMetrics = {};

    try {
      while (iteration < maxIterations) {
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
        if (metrics.totalEstimatedTokens > contextWindow * 0.7) {
          messages = await compact(messages, provider, model);
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
              const retryMessages = sanitizeConversationMessages(messages);

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

        await tryModelCall();

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
          try {
            toolResult = await this.executeTool(toolName, toolArgs, {
              userId,
              runId,
              app,
              triggerSource,
              taskId: options.taskId || null
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
            failedStepCount++;
            this.detachProcessFromRun(runId, toolResult?.pid);
            db.prepare('UPDATE agent_steps SET status = ?, error = ?, completed_at = datetime(\'now\') WHERE id = ?')
              .run('failed', err.message, stepId);
            this.emit(userId, 'run:tool_end', { runId, stepId, toolName, error: err.message, status: 'failed' });
            console.warn(
              `[Run ${shortenRunId(runId)}] step=${stepIndex} failed tool=${toolName} durationMs=${Date.now() - stepStartedAt} error=${summarizeForLog(err.message, 160)}`
            );
          }

          const toolMessage = {
            role: 'tool',
            name: toolName,
            tool_call_id: toolCall.id,
            content: compactToolResult(toolName, toolArgs, toolResult, {
              softLimit: toolReplayBudget,
              hardLimit: 2000
            })
          };
          messages.push(toolMessage);

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
          }
        }

        if (this.isRunStopped(runId)) break;
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

      if ((iteration >= maxIterations && messages[messages.length - 1]?.role === 'tool')
        || (iteration < maxIterations && stepIndex > 0 && !lastContent.trim() && messages[messages.length - 1]?.role !== 'tool')) {
        const finalResponse = await provider.chat(sanitizeConversationMessages([
          ...messages,
          {
            role: 'system',
            content: buildForcedFinalReplyPrompt(triggerSource)
          }
        ]), [], {
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

      const runMeta = this.activeRuns.get(runId);
      const messagingSent = runMeta?.messagingSent || false;

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
          failedStepCount
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
      const finalResponseText = lastContent.trim() ? lastContent : sentMessageText;
      const lastSentMessage = normalizeOutgoingMessage(
        runMeta?.lastSentMessage
        || (Array.isArray(runMeta?.sentMessages) ? runMeta.sentMessages[runMeta.sentMessages.length - 1] : '')
        || ''
      );

      db.prepare('UPDATE agent_runs SET status = ?, total_tokens = ?, final_response = ?, updated_at = datetime(\'now\'), completed_at = datetime(\'now\') WHERE id = ?')
        .run('completed', totalTokens, finalResponseText || null, runId);

      if (conversationId) {
        db.prepare('UPDATE conversations SET total_tokens = total_tokens + ?, updated_at = datetime(\'now\') WHERE id = ?')
          .run(totalTokens, conversationId);
        refreshConversationSummary(conversationId, provider, model, historyWindow).catch((err) => {
          console.error('[AI] Conversation summary refresh failed:', err.message);
        });
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
        stepIndex
      });

      // Fallback: if this was a messaging-triggered run and the AI never called
      // send_message itself, auto-send its final text as a reply.
      // If a message was already sent earlier in the run, still send the fallback
      // when the final text is materially different so long jobs don't end silently
      // after an interim update.
      if (triggerSource === 'messaging' && options.source && options.chatId) {
        // Strip [NO RESPONSE] markers the AI may have embedded anywhere in the text,
        // then only send if real content remains.
        const cleanedContent = normalizeOutgoingMessage(lastContent || '');
        const shouldSendFallback = cleanedContent && (!messagingSent || cleanedContent !== lastSentMessage);
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
      this.activeRuns.delete(runId);
      this.emit(userId, 'run:complete', { runId, content: lastContent, totalTokens, iterations: iteration, triggerSource });

      return { runId, content: lastContent, totalTokens, iterations: iteration, status: 'completed' };
    } catch (err) {
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

      db.prepare('UPDATE agent_runs SET status = ?, error = ?, updated_at = datetime(\'now\') WHERE id = ?')
        .run('failed', err.message, runId);
      console.error(
        `[Run ${shortenRunId(runId)}] failed trigger=${triggerSource} steps=${stepIndex} tokens=${totalTokens} error=${summarizeForLog(err.message, 180)}`
      );

      this.activeRuns.delete(runId);
      this.emit(userId, 'run:error', { runId, error: err.message });
      throw err;
    }
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
