'use strict';

const db = require('../../../db/database');
const {
  getConversationContext,
  buildSummaryCarrier,
  sanitizeConversationMessages,
} = require('../history');
const { estimateTokenCount } = require('../compaction');
const { buildToolDiscoverySummary, selectToolCandidates, MAX_TOOLS } = require('../toolSelector');
const { retrieveTools } = require('../tool_retrieval');
const { summarizeCapabilityHealth } = require('../capabilityHealth');
const { getPublicRunScope } = require('../../messaging/public_audience');
const { createRunTrust } = require('../../security/run_trust');
const { buildBackgroundRunsNote, listBackgroundRuns } = require('../loop/background_runs');
const { buildOpenTasksNote } = require('../loop/agent_tasks');
const { renderFragment } = require('../prompts/registry');
const { isReadOnlyCall, resolveToolMeta, staticToolNames } = require('../tools/metadata');
const { contextBudgetFor } = require('./context/context_pressure');
const { EVENT_TYPES } = require('./events/event_types');
const { exceedsMemoryBudget } = require('./memory_policy');
const { estimatePromptMetrics } = require('./prompt_metrics');

// The share of a model's input budget that conversation history may start with.
// The rest is for the prompt and for the work this run is about to do.
const HISTORY_BUDGET_SHARE = 0.5;
const CONVERSATION_TOOL_LOOKBACK_RUNS = 3;
const CONVERSATION_TOOL_LIMIT = 8;

// Long history on a small model is cut here rather than paying for a summarizing
// model call before the run has done anything. Whole turns go, oldest first.
function fitHistoryToBudget(history, budgetTokens) {
  if (estimateTokenCount(history) <= budgetTokens) return { history, dropped: 0 };
  let start = history.length;
  let used = 0;
  while (start > 0) {
    const next = estimateTokenCount([history[start - 1]]);
    if (used + next > budgetTokens) break;
    used += next;
    start -= 1;
  }
  while (start < history.length && history[start]?.role !== 'user') start += 1;
  return { history: history.slice(start), dropped: start };
}

function recentConversationTools(conversationId, currentRunId) {
  if (!conversationId) return [];
  return db.prepare(
    `SELECT DISTINCT s.tool_name AS name
     FROM agent_steps s
     WHERE s.tool_name IS NOT NULL
       AND s.run_id IN (
         SELECT id FROM agent_runs
         WHERE conversation_id = ? AND id != ?
         ORDER BY created_at DESC LIMIT ?
       )
     LIMIT ?`,
  ).all(conversationId, currentRunId, CONVERSATION_TOOL_LOOKBACK_RUNS, CONVERSATION_TOOL_LIMIT)
    .map((row) => row.name);
}

function systemPromptLength(systemPrompt) {
  if (systemPrompt && typeof systemPrompt === 'object') {
    return (systemPrompt.stable ? 1 : 0) + (systemPrompt.dynamic ? 1 : 0);
  }
  return 1;
}

function selectRunTools(session, { engine, allTools, backgroundRuns, retrieved, retrievalMs }) {
  const { options, conversationId, runId, userId, agentId, triggerSource, triggerType } = session;
  // When NeoRecall is connected, keep day/search tools active so personal
  // recall questions do not wait on an activation turn.
  const preferredNeoRecallTools = [
    'neorecall_list_daily_summaries',
    'neorecall_search',
    'neorecall_list_conversations',
  ].filter((name) => allTools.some((tool) => tool?.name === name));
  const toolSelectionOptions = { triggerSource, triggerType };
  const started = Date.now();
  const { tools, candidates } = selectToolCandidates(allTools, {
    request: options.context?.rawUserMessage || session.userMessage,
    conversationTools: recentConversationTools(conversationId, runId),
    preferredNames: [
      ...preferredNeoRecallTools,
      ...(backgroundRuns.length > 0 ? ['background_task'] : []),
    ],
    retrieved,
    options: toolSelectionOptions,
  });
  session.tools = tools;
  session.selection = new Map(candidates.map((candidate, index) => [
    candidate.name,
    { ...candidate, rank: index + 1 },
  ]));
  engine.initializeToolRuntime?.(runId, allTools, tools, toolSelectionOptions);
  session.eventBus.publish({
    runId,
    userId,
    agentId,
    eventType: EVENT_TYPES.TOOLS_SELECTED,
    payload: {
      kind: 'initial',
      duration_ms: Date.now() - started,
      retrieval_ms: retrievalMs,
      selection: {
        // Everything the harness knows, against what this run's surface, audience,
        // and settings allow it to use.
        catalog_size: staticToolNames().length + allTools.filter((tool) => !resolveToolMeta(tool?.name, tool).known).length,
        eligible_count: allTools.length,
        candidate_count: candidates.length,
        active_count: tools.length,
        schema_limit: MAX_TOOLS,
      },
      candidates: candidates.map((candidate, index) => ({
        name: candidate.name,
        rank: index + 1,
        source: candidate.source,
        score: candidate.score,
        ...(candidate.similarity != null ? { similarity: candidate.similarity } : {}),
      })),
    },
  });
}

/**
 * Builds what the model sees on its first turn, in the order that keeps the most
 * of it cacheable: stable policy, per-run state, the tool catalog, history, the
 * memory relevant to this request, and the request itself. Everything measured
 * goes on the ledger so a bad run can say what its context was made of.
 */
async function assembleRunContext(session, {
  engine,
  aiSettings,
  memoryManager,
  systemPromptPromise,
  capabilityHealthPromise,
  startConcurrently,
  startedAtMs,
  providerMs,
}) {
  const {
    options, runId, userId, agentId, app, conversationId, triggerSource, triggerType, userMessage,
  } = session;
  session.emitPhase('context', 'Gathering context');
  const historyWindow = Math.max(
    1,
    Number(options.historyWindow || aiSettings.chat_history_window) || aiSettings.chat_history_window,
  );
  const recallPromise = options.skipGlobalRecall === true
    ? null
    : startConcurrently(engine.buildMemoryRecall({
      memoryManager,
      userId,
      agentId,
      query: options.context?.rawUserMessage || userMessage,
      runId,
      options,
    }));
  session.systemPrompt = await systemPromptPromise;

  const publicScope = getPublicRunScope(runId);
  const builtInTools = engine.getAvailableTools(app, {
    includeDescriptions: true,
    userId,
    agentId,
    triggerType,
    triggerSource,
    publicScope,
  });
  const mcpManager = app?.locals?.mcpManager || app?.locals?.mcpClient || engine.mcpManager;
  const mcpTools = mcpManager && !publicScope ? mcpManager.getAllTools(userId, { agentId }) : [];
  const disallowedToolNames = new Set(
    (Array.isArray(options.disallowedToolNames) ? options.disallowedToolNames : [])
      .map((name) => String(name || '').trim())
      .filter(Boolean),
  );
  // A run limited to named tools keeps the ones that only manage the run itself.
  const allowedToolNames = Array.isArray(options.allowedToolNames) ? new Set(options.allowedToolNames) : null;
  const allTools = [...builtInTools, ...mcpTools]
    .filter((tool) => !disallowedToolNames.has(tool?.name))
    .filter((tool) => !allowedToolNames || allowedToolNames.has(tool?.name) || tool?.name === 'task_ledger')
    // A read-only run is refused the rest at dispatch; offering them only wastes its turns.
    .filter((tool) => !options.readOnly || tool?.name === 'task_ledger' || isReadOnlyCall(resolveToolMeta(tool?.name, tool)));

  let recallMsg = recallPromise ? await recallPromise : null;

  let summaryMessage = null;
  let storedHistory = [];
  if (conversationId && options.skipConversationHistory !== true) {
    const conversationContext = getConversationContext(conversationId, historyWindow);
    summaryMessage = buildSummaryCarrier(conversationContext.summary || options.priorSummary || '');
    storedHistory = conversationContext.recentMessages.length > 0
      ? conversationContext.recentMessages
      : (options.priorMessages || []).slice(-historyWindow).filter((pm) => pm.role && pm.content);
  } else {
    summaryMessage = buildSummaryCarrier(options.priorSummary || '');
    storedHistory = (options.priorMessages || []).slice(-historyWindow).filter((pm) => pm.role && pm.content);
  }

  const budget = contextBudgetFor(session.model.provider, session.model.model, options.maxTokens);
  const { history: historyMessages, dropped: historyDropped } = fitHistoryToBudget(
    storedHistory,
    Math.floor(budget.inputBudget * HISTORY_BUDGET_SHARE),
  );
  const memoryOverBudget = exceedsMemoryBudget(recallMsg, budget.inputBudget);
  if (memoryOverBudget) recallMsg = null;

  const capabilityHealth = await capabilityHealthPromise;
  // A public run must not learn what the owner has connected.
  const capabilitySummary = publicScope ? '' : summarizeCapabilityHealth(capabilityHealth);
  const connectedIntegrations = publicScope
    ? null
    : app?.locals?.integrationManager?.listConnectedProviderLabels?.(userId, agentId);
  const runtimeStatus = capabilitySummary || connectedIntegrations
    ? {
      role: 'system',
      content: [
        '[Runtime status]',
        connectedIntegrations
          ? `Connected integrations: ${connectedIntegrations}. search_tools returns their tools with usage notes.`
          : '',
        capabilitySummary ? `Needs attention:\n${capabilitySummary}` : '',
      ].filter(Boolean).join('\n'),
    }
    : null;
  const backgroundRuns = engine.getRunMeta(runId)?.backgroundEligible
    ? listBackgroundRuns(engine, { userId, agentId, excludeRunId: runId })
    : [];
  const backgroundNote = backgroundRuns.length > 0
    ? { role: 'system', content: buildBackgroundRunsNote(backgroundRuns) }
    : null;

  const retrievalStarted = Date.now();
  const retrieved = await retrieveTools(allTools, session.options.context?.rawUserMessage || session.userMessage, {
    provider: session.model?.providerName || null,
    userId,
    agentId,
    signal: session.options.signal || null,
  });
  selectRunTools(session, {
    engine,
    allTools,
    backgroundRuns,
    retrieved,
    retrievalMs: Date.now() - retrievalStarted,
  });

  // The tool catalog carries third-party descriptions (MCP, skills), so it is
  // not part of what the owner wrote and stays out of the trust record.
  const discoveryNote = {
    role: 'system',
    content: [
      '[Tool discovery]',
      buildToolDiscoverySummary(allTools, session.tools),
      renderFragment('runtime/tool_discovery.md'),
      engine.describeIntegrationsForRun?.(runId, session.tools) || '',
    ].filter(Boolean).join('\n'),
  };

  const messages = engine.buildContextMessages(
    session.systemPrompt,
    summaryMessage,
    historyMessages,
    recallMsg,
  );
  // Right behind the system prompt, ahead of anything that grows from run to run.
  let notesAt = 0;
  while (notesAt < messages.length && notesAt < systemPromptLength(session.systemPrompt)) notesAt += 1;
  const agentTasksText = buildOpenTasksNote(userId, agentId, runId);
  const agentTasksNote = agentTasksText ? { role: 'system', content: agentTasksText } : null;
  messages.splice(notesAt, 0, ...[discoveryNote, runtimeStatus, backgroundNote, agentTasksNote].filter(Boolean));
  const userTurn = engine.buildUserMessage(userMessage, options);
  messages.push(userTurn);
  session.requestTurn = userTurn;
  session.messages = sanitizeConversationMessages(messages);

  engine.getRunMeta(runId).trust = options.parentTrust || createRunTrust({
    audience: publicScope ? 'public' : (options.audience || 'owner'),
    approvedSpeaker: !publicScope && options.approvedSpeaker === true,
    triggerSource,
    // Notes the harness wrote from other agents' words are not the owner speaking.
    messages: messages.filter((message) => message !== discoveryNote && message !== agentTasksNote),
    origin: triggerSource === 'messaging'
      ? {
        platform: options.source,
        chatId: options.chatId,
        senderId: options.context?.socialIntelligence?.message?.sender,
        isGroup: options.context?.socialIntelligence?.isGroup === true,
      }
      : null,
    mediaPaths: (options.mediaAttachments || []).map((attachment) => attachment?.path),
  });

  const promptMetrics = estimatePromptMetrics(session.messages, session.tools);
  const version = session.systemPrompt?.promptVersion || null;
  if (version) engine.persistRunMetadata?.(runId, { promptVersion: version });
  session.eventBus.publish({
    runId,
    userId,
    agentId,
    eventType: EVENT_TYPES.CONTEXT_BUILT,
    payload: {
      startup_ms: Date.now() - startedAtMs,
      provider_ms: providerMs,
      prompt_version: version?.digest || null,
      sections: {
        system_tokens: promptMetrics.systemPromptTokens,
        tool_schema_tokens: promptMetrics.toolSchemaTokens,
        tool_catalog_tokens: promptMetrics.toolCatalogTokens,
        history_tokens: promptMetrics.historyTokens,
        memory_tokens: promptMetrics.recalledMemoryTokens,
        runtime_note_tokens: promptMetrics.runtimeNoteTokens,
        total_tokens: promptMetrics.totalEstimatedTokens,
      },
      budget: {
        input_tokens: budget.inputBudget,
        history_messages: historyMessages.length,
        history_dropped: historyDropped,
        memory_over_budget: memoryOverBudget,
      },
    },
  });
  return { historyWindow };
}

module.exports = {
  assembleRunContext,
  fitHistoryToBudget,
};
