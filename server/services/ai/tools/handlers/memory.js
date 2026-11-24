'use strict';

const { isTainted } = require('../../../security/run_trust');
const { statementInText, ownerVerification } = require('../../../memory/provenance');

// What the model declares about a fact it saves. It can only claim the user said
// something the run's own record of the user's words backs up.
function saveProvenance(source, content, trust) {
  if (isTainted(trust)) return { metadata: { trustLevel: 'external_source' } };
  if (source === 'inference' || source === 'tool_observed') {
    return {
      metadata: { trustLevel: 'model_inference', relation: 'derives' },
      confidence: 0.45,
      staleAfterDays: 30,
    };
  }
  if (source === 'user_stated' && trust?.ownerStatements?.some((text) => statementInText(text, content))) {
    return { metadata: { trustLevel: 'user_stated', verification: ownerVerification(content) } };
  }
  return { metadata: { trustLevel: 'agent_statement', relation: 'derives' }, confidence: 0.45 };
}

const handlers = {
  async memory_save(args, ctx) {
    const { agentId, engine, runId, signal, userId } = ctx;
    const { MemoryManager } = require('../../../memory/manager');
    const { MAX_MEMORY_CHARS } = require('../../../memory/policy');
    const mm = new MemoryManager();
    const content = typeof args.content === 'string' ? args.content : args.value;
    const length = String(content || '').trim().length;
    if (length > MAX_MEMORY_CHARS) {
    return {
      error: `Memory is ${length} characters; the limit is ${MAX_MEMORY_CHARS}. Rewrite it as one shorter fact, or split it into several facts.`,
    };
    }
    // A memory written after the run read outside content may carry
    // an injected claim; it must not silently override known facts.
    const trust = engine?.getRunMeta?.(runId)?.trust;
    const replaces = isTainted(trust) || saveProvenance(args.source, content, trust).metadata.trustLevel !== 'user_stated' || !Array.isArray(args.replaces)
    ? []
    : mm.ownedMemoryIds(userId, agentId, args.replaces);
    const id = await mm.saveMemory(
    userId,
    content,
    args.category || 'episodic',
    args.importance || 5,
    { agentId, signal, replaces, ...saveProvenance(args.source, content, trust) },
    );
    if (!id) {
    return {
      success: true,
      skipped: true,
      message: 'Skipped saving transient operational detail or empty content to memory'
    };
    }
    // Plain wording cannot always show that one fact replaces another, so the
    // model gets to look at what reads alike.
    const similar = mm.findSimilarMemories(userId, content, { agentId, excludeId: id });
    if (similar.length) {
    return {
      success: true,
      id,
      message: 'Saved to memory. These read alike; if the new fact replaces one, save it again with its id in replaces.',
      similar,
    };
    }
    return { success: true, id, message: 'Saved to memory' };
  },

  async memory_recall(args, ctx) {
    const { agentId, signal, userId } = ctx;
    const { MemoryManager } = require('../../../memory/manager');
    const mm = new MemoryManager();
    const asOf = Date.parse(args.as_of || '');
    const results = await mm.recallMemory(
    userId,
    args.query,
    args.limit || 6,
    {
      agentId,
      signal,
      validAt: Number.isNaN(asOf) ? undefined : new Date(asOf).toISOString(),
      includeHistory: args.include_history === true,
    },
    );
    if (!results.length) return { results: [], message: 'Nothing found' };
    return { results };
  },

  async memory_list(args, ctx) {
    const { agentId, userId } = ctx;
    const { MemoryManager } = require('../../../memory/manager');
    const mm = new MemoryManager();
    const offset = Math.max(0, Math.floor(Number(args.offset) || 0));
    // A page must fit one tool result; a cut page hides the ids to act on.
    const limit = Math.max(1, Math.min(40, Math.floor(Number(args.limit) || 30)));
    const page = mm.listMemories(userId, { agentId, offset, limit: limit + 1 });
    const results = page.slice(0, limit).map((memory) => ({
    id: memory.id,
    content: memory.content,
    category: memory.category,
    importance: memory.importance,
    updated_at: memory.updated_at,
    }));
    return {
    results,
    next_offset: page.length > limit ? offset + limit : null,
    };
  },

  async memory_forget(args, ctx) {
    const { agentId, userId } = ctx;
    const { MemoryManager } = require('../../../memory/manager');
    const mm = new MemoryManager();
    const ids = mm.ownedMemoryIds(userId, agentId, args.ids);
    if (!ids.length) return { error: 'None of these ids is a memory of this agent.' };
    const archived = mm.archiveMemories(ids, true, userId);
    return { success: true, archived, message: `Archived ${archived} memories` };
  },

  async session_search(args, ctx) {
    const { agentId, userId } = ctx;
    const { MemoryManager } = require('../../../memory/manager');
    const mm = new MemoryManager();
    const results = mm.searchConversations(userId, args.query, {
    sessions: args.limit || 6,
    agentId
    });
    if (!results.length) return { results: [], message: 'No matching sessions found' };
    return { results };
  },

  async memory_update_core(args, ctx) {
    const { agentId, userId } = ctx;
    const { MemoryManager, CORE_KEYS } = require('../../../memory/manager');
    const mm = new MemoryManager();
    if (!CORE_KEYS.includes(args.key)) {
    return { error: `Core memory key must be one of: ${CORE_KEYS.join(', ')}.` };
    }
    if (typeof args.value !== 'string' || !args.value.trim()) {
    return { error: 'Core memory value must be a non-empty string.' };
    }
    mm.updateCore(userId, args.key, args.value, { agentId });
    return { success: true, key: args.key, message: 'Core memory updated' };
  },

  async memory_write(args, ctx) {
    const { userId } = ctx;
    const { MemoryManager } = require('../../../memory/manager');
    const mm = new MemoryManager();
    return mm.write(args.target, args.content, args.mode || 'append', userId);
  },

  async memory_read(args, ctx) {
    const { userId } = ctx;
    const { MemoryManager } = require('../../../memory/manager');
    const mm = new MemoryManager();
    return mm.read(args.target, { date: args.date, userId });
  },
};

module.exports = { handlers };
