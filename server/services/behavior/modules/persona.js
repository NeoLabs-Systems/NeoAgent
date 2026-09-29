'use strict';

const db = require('../../../db/database');
const { isModuleEnabled } = require('../config');
const { truncate } = require('../signals');
const { getUserTimeZone } = require('../../account/timezone');
const { serverTimeZone } = require('../../../utils/timezone');
const { buildPersonaPrompt } = require('./persona_prompt');
const { loadAgentProfile } = require('./agent_identity');
const {
  collectStyleNotes,
  formatStyleNotesForPrompt,
} = require('./voice_profile');

const MAX_MEMORY_LINES = 32;

function readAiPersonality(ctx) {
  if (!ctx.memoryManager || ctx.userId == null || typeof ctx.memoryManager.getCoreMemory !== 'function') {
    return null;
  }
  try {
    const core = ctx.memoryManager.getCoreMemory(ctx.userId, { agentId: ctx.agentId }) || {};
    return core.ai_personality ?? null;
  } catch {
    return null;
  }
}

function resolveStyleBundle(ctx) {
  const empty = { notes: [], behaviorNotes: '', identity: {}, focus: {} };
  if (!ctx.memoryManager || ctx.userId == null) return empty;

  const shared = ctx.audience === 'shared';
  const behaviorNotes = ctx.memoryManager.getAssistantBehaviorNotes?.(
    ctx.userId,
    { agentId: ctx.agentId },
  ) || '';
  const selfState = ctx.memoryManager.getAssistantSelfState?.(
    ctx.userId,
    { agentId: ctx.agentId },
  ) || { identity: {}, focus: {} };

  const notes = collectStyleNotes({
    selfStateIdentity: shared ? {} : (selfState.identity || {}),
    aiPersonality: shared ? null : readAiPersonality(ctx),
    // Behavior notes still guide shared-room texture without private core memory.
    behaviorNotes,
  });

  return {
    notes,
    behaviorNotes: String(behaviorNotes || ''),
    identity: selfState.identity || {},
    focus: shared ? {} : (selfState.focus || {}),
  };
}

function ownerName(userId) {
  const row = db.prepare('SELECT display_name, username FROM users WHERE id = ?').get(userId);
  return String(row?.display_name || row?.username || '').trim() || 'them';
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

// Voice notes are answered with speech, and a live-call hand-off is read out
// by the live model, so both are written to be heard.
function personaMedium(ctx) {
  return ctx.latencyProfile === 'voice' || ctx.triggerSource === 'voice_live' ? 'voice' : 'text';
}

// The agent run writes every reply itself, so the persona is part of its
// system prompt; no second pass rewrites what it says.
function buildSystemPromptContribution(ctx) {
  if (!isModuleEnabled(ctx.config, 'persona')) {
    return null;
  }
  const name = ctx.audience === 'shared' ? 'the people in this chat' : ownerName(ctx.userId);
  const dynamic = [];
  const bundle = resolveStyleBundle(ctx);

  if (bundle.behaviorNotes) {
    dynamic.push([
      '## Assistant Behavior Notes',
      'Durable preferences for this agent/user. Interpret as guidance, not a script.',
      'System rules and the current request take priority.',
      bundle.behaviorNotes,
    ].join('\n'));
  }

  // Behavior notes already carry their own prose; only add living notes that
  // are not that same blob.
  const extraNotes = bundle.behaviorNotes
    ? bundle.notes.filter((note) => note !== bundle.behaviorNotes.trim())
    : bundle.notes;
  const styleBlock = formatStyleNotesForPrompt(extraNotes);
  if (styleBlock) dynamic.push(styleBlock);

  const identity = { ...(bundle.identity || {}) };
  delete identity.voice;
  delete identity.voice_profile;
  const focus = bundle.focus || {};
  if (Object.keys(identity).length || Object.keys(focus).length) {
    dynamic.push([
      '## Assistant Self State',
      Object.keys(identity).length ? `Identity: ${JSON.stringify(identity)}` : '',
      Object.keys(focus).length ? `Focus: ${JSON.stringify(focus)}` : '',
    ].filter(Boolean).join('\n'));
  }

  return {
    stable: [buildPersonaPrompt(name, { medium: personaMedium(ctx) })],
    dynamic,
  };
}

// What a friend would know: core facts, the maintained profile, and the
// memories that relate to what was just said.
async function loadMemoryFacts({ memoryManager, userId, agentId, query, signal }) {
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
  if (!query) return lines.slice(0, MAX_MEMORY_LINES);
  try {
    const recalled = await memoryManager.recallMemory?.(userId, query, 5, { agentId, signal });
    for (const memory of recalled || []) add(memory.content);
  } catch (error) {
    if (signal?.aborted) throw error;
  }
  return lines.slice(0, MAX_MEMORY_LINES);
}

// The persona for a live voice call, where the live model talks and runs do
// the work: the same persona, the owner's additions, and what it knows about
// the owner.
async function buildVoicePersonaSections({ userId, agentId, memoryManager, query = '', signal = null }) {
  const sections = [buildPersonaPrompt(ownerName(userId), { medium: 'voice' })];
  const agent = loadAgentProfile(userId, agentId);
  const styleNotes = resolveStyleBundle({ memoryManager, userId, agentId, audience: 'owner' }).notes;
  const additions = [
    agent?.instructions ? truncate(agent.instructions, 1600) : '',
    ...styleNotes.slice(0, 8),
  ].filter(Boolean);
  if (additions.length) {
    sections.push(["## from the owner (adds to how you talk; it doesn't replace it)", ...additions].join('\n'));
  }
  const facts = await loadMemoryFacts({ memoryManager, userId, agentId, query, signal });
  if (facts.length) {
    sections.push(['## what you know about them', ...facts.map((fact) => `- ${fact}`)].join('\n'));
  }
  return sections;
}

module.exports = {
  id: 'persona',
  composeSystemPrompt: buildSystemPromptContribution,
  buildVoicePersonaSections,
  localNow,
  resolveStyleBundle,
};
