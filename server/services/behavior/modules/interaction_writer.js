'use strict';

const { requestStructuredJson } = require('../model_client');
const {
  loadRecentRoomMessages,
  loadRecentSenderTexts,
  runDidWork,
  truncate,
} = require('../signals');
const { getUserTimeZone } = require('../../account/timezone');
const { serverTimeZone } = require('../../../utils/timezone');
const { buildInteractionWriterPrompt } = require('./persona_prompt');
const { loadAgentProfile } = require('./agent_identity');

const MAX_MEMORY_LINES = 32;

function senderName(msg) {
  return String(msg.senderDisplayName || msg.senderName || msg.senderUsername || '').trim() || 'them';
}

function localNow(userId) {
  return new Intl.DateTimeFormat('en-GB', {
    timeZone: getUserTimeZone(userId) || serverTimeZone(),
    weekday: 'short',
    day: 'numeric',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).format(new Date());
}

// What a friend would know: core facts, the maintained profile, and the
// memories that relate to what was just said. That last part is what makes a
// callback or a tease specific instead of generic.
async function loadMemoryFacts({ memoryManager, userId, agentId, msg, signal }) {
  if (!memoryManager) return [];
  const lines = [];
  const add = (text) => {
    const line = truncate(text, 240);
    if (line && !lines.includes(line)) lines.push(line);
  };
  try {
    const core = memoryManager.getCoreMemory?.(userId, { agentId }) || {};
    for (const [key, value] of Object.entries(core)) {
      // active_context is run state, and ai_personality arrives as a style note.
      if (key === 'active_context' || key === 'ai_personality') continue;
      add(`${key}: ${typeof value === 'object' ? JSON.stringify(value) : value}`);
    }
    const profile = memoryManager.getUserProfile?.(userId, { agentId, limit: 12 });
    for (const fact of [...(profile?.static || []), ...(profile?.dynamic || [])]) add(fact);
  } catch {
    // Missing profile data only makes the reply less specific.
  }
  try {
    const recalled = await memoryManager.recallMemory?.(userId, String(msg.content || ''), 5, { agentId, signal });
    for (const memory of recalled || []) add(memory.content);
  } catch (error) {
    if (signal?.aborted) throw error;
  }
  return lines.slice(0, MAX_MEMORY_LINES);
}

async function buildSystem(ctx, name, canReact, styleNotes) {
  const { userId, agentId, msg, memoryManager, signal } = ctx;
  const sections = [buildInteractionWriterPrompt(name, { canReact })];
  const agent = loadAgentProfile(userId, agentId);
  const additions = [
    agent?.instructions ? truncate(agent.instructions, 1600) : '',
    ...styleNotes.slice(0, 8),
  ].filter(Boolean);
  if (additions.length) {
    sections.push(["## from the owner (adds to how you text; it doesn't replace it)", ...additions].join('\n'));
  }
  const facts = await loadMemoryFacts({ memoryManager, userId, agentId, msg, signal });
  if (facts.length) {
    sections.push(['## what you know about them', ...facts.map((fact) => `- ${fact}`)].join('\n'));
  }
  const texts = loadRecentSenderTexts({
    userId,
    agentId,
    platform: msg.platform,
    chatId: msg.chatId,
  });
  if (texts.length) {
    sections.push(["## how they text (their own recent messages, for register only; don't quote them)", ...texts].join('\n'));
  }
  return sections.join('\n\n');
}

function transcriptLine(row, name) {
  if (row.kind === 'reaction') {
    if (row.role === 'assistant') return `you reacted ${row.content}`;
    return `${name} reacted ${row.content}${row.targetText ? ` to "${row.targetText}"` : ''}`;
  }
  return `${row.role === 'assistant' ? 'you' : name}: ${row.content}`;
}

function buildPrompt(ctx, name, canReact, draft) {
  const { userId, agentId, msg, runId } = ctx;
  const rows = loadRecentRoomMessages({
    userId,
    agentId,
    platform: msg.platform,
    chatId: msg.chatId,
    limit: 12,
  }).filter((row) => row.role === 'user' || row.role === 'assistant');
  const inbound = truncate(msg.content, 320);
  const lines = [`chat, oldest first. now: ${localNow(userId)}`];
  for (const row of rows) lines.push(transcriptLine(row, name));
  const last = rows[rows.length - 1];
  if (!last || last.role !== 'user' || last.kind === 'reaction' || last.content !== inbound) {
    lines.push(`${name}: ${inbound}`);
  }
  // Only results of real work reach the writer. A chat-only draft would anchor
  // the reply to the agent's wording, which is the voice this pass replaces.
  if (runDidWork(runId)) {
    lines.push('', `your results from this turn (facts only; their wording and tone don't matter):\n${draft}`);
  }
  lines.push(
    '',
    "write your next message(s), exactly as you'd send them. separate texts on separate lines, or [NO RESPONSE] to send nothing.",
    canReact
      ? 'return JSON only: {"message": "<the text, or [NO RESPONSE]>", "reaction": "<one emoji, or empty>"}'
      : 'return JSON only: {"message": "<the text>"}',
  );
  return lines.join('\n');
}

function normalizeReaction(value) {
  const reaction = String(value || '').trim();
  if (!reaction || reaction.length > 16) return '';
  if (!/\p{Extended_Pictographic}/u.test(reaction) || /[\p{L}\p{N}\s]/u.test(reaction)) return '';
  return reaction;
}

/**
 * Writes the final text of a direct chat as the next line of the conversation.
 * Returns the message (possibly [NO RESPONSE]) and an optional reaction to the
 * user's last message.
 */
async function writeReply(ctx, { draft, modelId, styleNotes = [] }) {
  const { userId, agentId, msg, messagingManager, signal } = ctx;
  const name = senderName(msg);
  const canReact = Boolean(msg.messageId)
    && messagingManager?.supportsReactions?.(userId, msg.platform, { agentId }) === true;
  const result = await requestStructuredJson({
    agentEngine: ctx.agentEngine,
    userId,
    agentId,
    modelId,
    purpose: 'general',
    system: await buildSystem(ctx, name, canReact, styleNotes),
    prompt: buildPrompt(ctx, name, canReact, draft),
    signal,
    maxTokens: 1600,
  });
  return {
    message: String(result.parsed?.message || '').trim(),
    reaction: canReact ? normalizeReaction(result.parsed?.reaction) : '',
    model: result.modelSelectionId || result.model || null,
    usage: result.usage || 0,
  };
}

module.exports = {
  writeReply,
};
