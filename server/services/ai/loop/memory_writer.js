'use strict';

const db = require('../../../db/database');
const { getConversationContext } = require('../history');
const { extractJsonObject } = require('../../../utils/text');
const { getProviderForUser } = require('../provider_selector');
const { runAbortableModelCall } = require('./model_io');
const {
  buildMemoryConsolidationInstructions,
  normalizeMemoryCandidates,
} = require('../../memory/consolidation');
const {
  batchUnits,
  buildDocumentFactsPrompt,
  buildExtractionUnits,
  normalizeDocumentFacts,
} = require('../../memory/document_facts');
const { isAbortError, throwIfAborted } = require('../../../utils/abort');
const { recordModelUsage } = require('../usage');
const { EVENT_TYPES } = require('../runtime/events/event_types');
const { recordEventSafe } = require('../runtime/events/run_event_store');
const { resolveToolMeta } = require('../tools/metadata');
const { groundMemoryCandidates, keepSupportedStatements } = require('../../memory/provenance');
const { createRunTrust, isTainted } = require('../../security/run_trust');

// The background writers of long-term memory: what a run leaves behind after it
// answered, and what ingested documents add. Run receipts stay in agent_runs;
// memory only gets durable facts.

// Turns ingested documents (mail threads, notes) into a few durable facts
// about the user, checked against what memory already holds. Source text
// never becomes memory itself.
function extractDocumentFacts(engine, userId, agentId, {
    documents,
    owner = {},
    metadata = {},
    signal = null,
    onProgress = () => {},
  }) {
  const memoryManager = engine.memoryManager;
  return engine.trackBackgroundTask(async (backgroundSignal) => {
    const units = buildExtractionUnits(documents);
    const batches = batchUnits(units);
    const memoryIds = new Set();
    let done = 0;
    onProgress(done, units.length);
    if (!batches.length) return { memoryIds: [] };

    const selected = await getProviderForUser(
      userId,
      'Extract durable memory facts from documents.',
      false,
      null,
      { agentId, signal: backgroundSignal },
    );
    // Facts from earlier batches count as known, so a later mail about the
    // same thing does not add it again.
    const learned = [];
    let failedBatches = 0;
    let lastError = null;
    for (const batch of batches) {
      throwIfAborted(backgroundSignal, 'Memory extraction aborted.');
      try {
        const known = await memoryManager.listKnownMemories(userId, {
          agentId,
          query: batch.map((unit) => unit.document.title).join('\n'),
          signal: backgroundSignal,
        });
        const result = await engine.requestStructuredJson({
          provider: selected.provider,
          providerName: selected.providerName,
          model: selected.model,
          messages: [],
          prompt: buildDocumentFactsPrompt({
            owner,
            units: batch,
            knownMemories: [...learned, ...known],
          }),
          // Thinking models spend most of engine on reasoning; the facts
          // themselves are short.
          maxTokens: 8000,
          normalize: (raw) => normalizeDocumentFacts(raw, batch),
          fallback: [],
          telemetry: { userId, agentId, signal: backgroundSignal },
          phase: 'document_extraction',
        });
        for (const { candidate, document } of result.value || []) {
          const ids = await memoryManager.consolidateMemoryCandidates(userId, [candidate], {
            agentId,
            sourceRef: {
              sourceType: document.sourceType,
              sourceId: document.externalObjectId,
              sourceLabel: document.title,
            },
            metadata: { ...metadata, trustLevel: 'external_source' },
            signal: backgroundSignal,
          });
          for (const id of ids) memoryIds.add(id);
          learned.push(candidate.memory);
        }
      } catch (err) {
        if (isAbortError(err, backgroundSignal)) throw err;
        failedBatches += 1;
        lastError = err;
        console.warn('[Memory] Document fact extraction failed:', err.message);
      }
      done += batch.length;
      onProgress(done, units.length);
    }
    if (failedBatches === batches.length) throw lastError;
    return { memoryIds: [...memoryIds] };
  }, {
    key: `memory-extraction:${userId}:${agentId || 'main'}`,
    signal,
  });
}

// What this run's tools returned, to check claims against. Memory tools are left
// out: finding a fact in memory proves nothing new. The run's live trust record may
// already be gone here, so taint is read back from the steps it was built from.
function readRunToolEvidence(runId) {
  const steps = db.prepare(
    `SELECT tool_name, result FROM agent_steps
     WHERE run_id = ? AND status = 'completed' AND result IS NOT NULL
     ORDER BY step_index DESC
     LIMIT 40`
  ).all(runId).filter((step) => resolveToolMeta(step.tool_name).group !== 'memory');
  return {
    results: steps.map((step) => step.result),
    tainted: steps.some((step) => resolveToolMeta(step.tool_name).untrusted),
  };
}

// An event-triggered run opens on someone else's words, so its "user" message
// proves nothing about the owner. The same goes for a run that is not the owner's.
function openedOnOutsideContent(runId, options) {
  const run = db.prepare('SELECT trigger_source FROM agent_runs WHERE id = ?').get(runId);
  return isTainted(createRunTrust({
    audience: options.audience || 'owner',
    triggerSource: run?.trigger_source || options.triggerSource,
  }));
}

function trustLevelFor(trustLevel, { sharedRoom, outsideOpening, toolsTainted }) {
  if (trustLevel === 'model_inference') return trustLevel;
  if (sharedRoom) return 'shared_room_conversation';
  if (outsideOpening) return 'external_source';
  if (trustLevel === 'tool_observed' && toolsTainted) return 'external_source';
  return trustLevel;
}

async function refreshConversationState(engine, {
    conversationId,
    runId,
    provider,
    providerName,
    model,
    finalReply,
    historyWindow,
    options,
  }) {
  if (!conversationId) return null;
  const { MemoryManager } = require('../../memory/manager');
  const memoryManager = engine.memoryManager || new MemoryManager();
  const context = getConversationContext(conversationId, Math.max(historyWindow, 8));
  const existingState = memoryManager.getConversationState(conversationId);
  const threadMessages = context.recentMessages.slice(-8);
  const toolEvidence = readRunToolEvidence(runId);
  const thread = { messages: threadMessages, finalReply, toolResults: toolEvidence.results };
  const knownFacts = memoryManager.listKnownFacts?.(options.userId, {
    agentId: options.agentId || null,
    query: threadMessages
      .filter((message) => message.role === 'user')
      .map((message) => message.content)
      .join('\n'),
  }) || [];
  const promptMessages = [
    {
      role: 'system',
      content: [
        'Return JSON only. Distill the current thread working state. Keep it concise and concrete.',
        'Track summary, open_commitments, unresolved_questions, referenced_entities, and last_verified_facts. Do not invent facts.',
        options.memoryScope?.scopeType === 'channel'
          ? [
              'This is a shared room. Extract only durable room or participant facts that are safe and useful in engine room.',
              'Do not infer or store facts about the authenticated owner from another participant’s message.',
              options.context?.socialIntelligence?.message?.sender
                ? `For facts about the current speaker, use the canonical subject "${options.source}:${options.context.socialIntelligence.message.sender}".`
                : '',
            ].filter(Boolean).join(' ')
          : '',
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
            evidence: 'The exact words from the thread that state it.',
          }],
        }, null, 2),
      ].join('\n\n')
    },
    {
      role: 'user',
      content: [
        existingState?.summary ? `Existing state:\n${JSON.stringify(existingState, null, 2)}` : 'Existing state: none',
        context.summary ? `Conversation summary:\n${context.summary}` : 'Conversation summary: none',
        knownFacts.length ? `Known facts:\n${knownFacts.map((fact) => `- ${fact.subject} | ${fact.predicate} | ${fact.object}`).join('\n')}` : 'Known facts: none found',
        `Recent thread messages:\n${JSON.stringify(threadMessages, null, 2)}`,
        `Latest final reply:\n${finalReply || '(empty)'}`,
      ].join('\n\n')
    }
  ];

  const startedAt = Date.now();
  const response = await runAbortableModelCall(
    (signal) => provider.chat(promptMessages, [], {
      model,
      maxTokens: 800,
      reasoningEffort: engine.getReasoningEffort(providerName, options),
      signal,
    }),
    options,
    'Conversation state refresh',
  );
  recordModelUsage({
    runId,
    userId: options.userId,
    agentId: options.agentId || null,
    provider: providerName,
    model,
    phase: 'memory_extraction',
    usage: response.usage,
    latencyMs: Date.now() - startedAt,
  });
  const parsed = extractJsonObject(response.content || '') || {};
  const nextState = {
    summary: String(parsed.summary || existingState?.summary || '').trim(),
    open_commitments: Array.isArray(parsed.open_commitments) ? parsed.open_commitments.slice(0, 8).map((item) => String(item || '').trim()).filter(Boolean) : [],
    unresolved_questions: Array.isArray(parsed.unresolved_questions) ? parsed.unresolved_questions.slice(0, 8).map((item) => String(item || '').trim()).filter(Boolean) : [],
    referenced_entities: Array.isArray(parsed.referenced_entities) ? parsed.referenced_entities.slice(0, 12).map((item) => String(item || '').trim()).filter(Boolean) : [],
    last_verified_facts: Array.isArray(parsed.last_verified_facts)
      ? keepSupportedStatements(parsed.last_verified_facts.slice(0, 10).map((item) => String(item || '').trim()).filter(Boolean), thread)
      : [],
  };

  memoryManager.updateConversationState(conversationId, nextState);
  const { grounded, dropped } = groundMemoryCandidates(normalizeMemoryCandidates(parsed.memory_candidates), thread);
  const trustContext = {
    sharedRoom: Boolean(options.memoryScope),
    outsideOpening: openedOnOutsideContent(runId, options),
    toolsTainted: toolEvidence.tainted,
  };
  for (const { candidate, trustLevel } of grounded) {
    await memoryManager.consolidateMemoryCandidates(
      options.userId,
      [candidate],
      {
        agentId: options.agentId || null,
        conversationId,
        runId,
        scope: options.memoryScope || undefined,
        metadata: {
          trustLevel: trustLevelFor(trustLevel, trustContext),
          ...(options.memoryScope ? { platform: options.source || null, chatId: options.chatId || null } : {}),
        },
        signal: options.signal,
      },
    );
  }
  if (grounded.length || dropped) {
    recordEventSafe({
      runId,
      userId: options.userId,
      agentId: options.agentId || null,
      eventType: EVENT_TYPES.MEMORY_WRITE,
      payload: { count: grounded.length, dropped, source: 'conversation_state' },
    });
  }
  if (grounded.length) {
    const { invalidateSystemPromptCache } = require('../systemPrompt');
    invalidateSystemPromptCache(options.userId, options.agentId || null);
  }
  return nextState;
}

module.exports = {
  extractDocumentFacts,
  refreshConversationState,
};
