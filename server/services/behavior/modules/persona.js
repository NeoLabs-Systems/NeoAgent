'use strict';

const { isModuleEnabled } = require('../config');
const { requestStructuredJson } = require('../model_client');
const {
  loadRecentRoomMessages,
  loadRecentSenderTexts,
  runDidWork,
  truncate,
} = require('../signals');
const { getPublicProfile } = require('../../messaging/public_audience');
const { getUserTimeZone } = require('../../account/timezone');
const { serverTimeZone } = require('../../../utils/timezone');
const {
  BASELINE_PERSONA_PROMPT,
  buildInteractionWriterPrompt,
} = require('./persona_prompt');
const { loadAgentProfile } = require('./agent_identity');
const {
  collectStyleNotes,
  formatStyleNotesForPrompt,
} = require('./voice_profile');

const INTERACTION_VOICE_RULES = `Mandatory interaction-voice editing rules:
- Keep every fact, number, name, URL, warning, and blocker intact. Never add a fact.
- Keep long deliverables intact when detail was requested.
- Sound like a real text, not a support bot: shorter if bloated, no corporate filler, no fake empathy menus, no automatic follow-up questions.
- Match the user's register when obvious; honor living style notes when present.
- Casual lowercase is fine when it fits; never force it.
- At most a light touch of wit; never on serious topics.
- In groups: one brief contribution.`;

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
    behaviorNotes: shared ? behaviorNotes : behaviorNotes,
  });

  return {
    notes,
    behaviorNotes: String(behaviorNotes || ''),
    identity: selfState.identity || {},
    focus: shared ? {} : (selfState.focus || {}),
  };
}

function buildSystemPromptContribution(ctx) {
  if (!isModuleEnabled(ctx.config, 'persona')) {
    return null;
  }
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

  const styleBlock = formatStyleNotesForPrompt(bundle.notes);
  // Avoid duplicating the same prose if behavior notes were the only source.
  if (styleBlock && !bundle.behaviorNotes) {
    dynamic.push(styleBlock);
  } else if (styleBlock && bundle.behaviorNotes) {
    // Only inject living notes that aren't already the full behavior notes blob.
    const extra = bundle.notes.filter((note) => note !== bundle.behaviorNotes.trim());
    const extraBlock = formatStyleNotesForPrompt(extra);
    if (extraBlock) dynamic.push(extraBlock);
  }

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
    stable: [BASELINE_PERSONA_PROMPT],
    dynamic,
  };
}

function coreMemoryFacts(ctx) {
  if (!ctx.memoryManager || typeof ctx.memoryManager.getCoreMemory !== 'function') return [];
  let core = {};
  try {
    core = ctx.memoryManager.getCoreMemory(ctx.userId, { agentId: ctx.agentId }) || {};
  } catch {
    return [];
  }
  return Object.entries(core)
    // active_context is run state, and ai_personality already arrives as a style note.
    .filter(([key]) => key !== 'active_context' && key !== 'ai_personality')
    .map(([key, value]) => `${key}: ${truncate(typeof value === 'object' ? JSON.stringify(value) : value, 200)}`)
    .slice(0, 20);
}

function senderName(ctx) {
  const { msg } = ctx;
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

function buildWriterSystem(ctx, name) {
  const { userId, agentId, msg } = ctx;
  const sections = [buildInteractionWriterPrompt(name)];
  const agent = loadAgentProfile(userId, agentId);
  const additions = [
    agent?.instructions ? truncate(agent.instructions, 1600) : '',
    ...resolveStyleBundle(ctx).notes.slice(0, 8),
  ].filter(Boolean);
  if (additions.length) {
    sections.push(["## from the owner (adds to how you text; it doesn't replace it)", ...additions].join('\n'));
  }
  const facts = coreMemoryFacts(ctx);
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

function buildWriterPrompt(ctx, name, draft) {
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
  for (const row of rows) {
    lines.push(`${row.role === 'assistant' ? 'you' : name}: ${row.content}`);
  }
  const last = rows[rows.length - 1];
  if (!last || last.role !== 'user' || last.content !== inbound) lines.push(`${name}: ${inbound}`);
  // Only results of real work reach the writer. A chat-only draft would anchor
  // the reply to the agent's wording, which is the voice this pass replaces.
  if (runDidWork(runId)) {
    lines.push('', `your results from this turn (facts only; their wording and tone don't matter):\n${draft}`);
  }
  lines.push(
    '',
    "write your next message(s), exactly as you'd send them. separate texts on separate lines, or [NO RESPONSE] to send nothing.",
    'return JSON only: {"message": "<the text>"}',
  );
  return lines.join('\n');
}

async function refineDraft(ctx) {
  const {
    userId,
    agentId,
    msg,
    config,
    draft,
    signal = null,
    runId = null,
  } = ctx;
  const content = String(draft || '').trim();
  if (
    !content
    || content.toUpperCase() === '[NO RESPONSE]'
    || !isModuleEnabled(config, 'persona')
  ) {
    return {
      action: 'send',
      content,
      reasonCodes: ['persona_refine_skip'],
    };
  }

  // The writer voices one-to-one chats. Groups keep the combined room review,
  // and public surfaces such as GitHub comments are documents, not chat.
  if (msg.isGroup || getPublicProfile(msg.platform)) {
    return {
      action: 'send',
      content,
      reasonCodes: ['persona_writer_direct_only'],
    };
  }

  if (content.length > 2800) {
    return {
      action: 'send',
      content,
      reasonCodes: ['persona_refine_large_passthrough'],
    };
  }

  const runModelId = runId
    ? ctx.agentEngine?.getRunMeta?.(runId)?.modelSelectionId || null
    : null;
  const name = senderName(ctx);

  try {
    const result = await requestStructuredJson({
      agentEngine: ctx.agentEngine,
      userId,
      agentId,
      modelId: config.voiceModelId || runModelId,
      purpose: 'general',
      system: buildWriterSystem(ctx, name),
      prompt: buildWriterPrompt(ctx, name, content),
      signal,
      maxTokens: 1600,
    });
    const message = String(result.parsed?.message || '').trim();
    const meta = {
      model: result.modelSelectionId || result.model || null,
      usage: result.usage || 0,
    };
    if (!message) {
      return {
        action: 'send',
        content,
        reasonCodes: ['persona_writer_empty'],
        ...meta,
      };
    }
    return {
      action: message === content ? 'send' : 'revise',
      content: message,
      reasonCodes: ['persona_writer'],
      ...meta,
    };
  } catch (error) {
    if (signal?.aborted) throw error;
    return {
      action: 'send',
      content,
      reasonCodes: ['persona_error_passthrough'],
      failureCode: 'model_unavailable',
    };
  }
}

module.exports = {
  id: 'persona',
  composeSystemPrompt: buildSystemPromptContribution,
  refineDraft,
  INTERACTION_VOICE_RULES,
};
