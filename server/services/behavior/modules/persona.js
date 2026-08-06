'use strict';

const { isModuleEnabled } = require('../config');
const { requestStructuredJson } = require('../model_client');
const { truncate } = require('../signals');
const { BASELINE_PERSONA_PROMPT } = require('./persona_prompt');
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

const INTERACTION_EDITOR_PROMPT = `You are a light voice editor for a personal messaging agent.
Return JSON with keys:
action ("send" or "revise"),
revisedContent (string; empty when action is send),
reasonCodes (array of short strings),
rationale (one short sentence).

Make the smallest edit that removes botty habits. Do not rewrite a good draft into your own voice. Do not invent facts.

${INTERACTION_VOICE_RULES}

If the draft is already fine, action "send".`;

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
  const bundle = resolveStyleBundle(ctx);

  try {
    const result = await requestStructuredJson({
      agentEngine: ctx.agentEngine,
      userId,
      agentId,
      modelId: config.decisionModelId || runModelId,
      purpose: runModelId ? 'general' : config.decisionModelPurpose,
      system: INTERACTION_EDITOR_PROMPT,
      prompt: JSON.stringify({
        channel: {
          platform: msg.platform,
          audience: msg.isGroup ? 'shared' : 'direct',
        },
        inbound: truncate(msg.content, 900),
        draft: content,
        styleNotes: bundle.notes.slice(0, 8),
      }),
      signal,
      maxTokens: 1200,
    });
    const parsed = result.parsed || {};
    if (
      parsed.action === 'revise'
      && String(parsed.revisedContent || '').trim()
    ) {
      return {
        action: 'revise',
        content: String(parsed.revisedContent).trim(),
        reasonCodes: Array.isArray(parsed.reasonCodes)
          ? parsed.reasonCodes
          : ['persona_revise'],
        rationale: String(parsed.rationale || '').trim(),
        model: result.modelSelectionId || result.model || null,
        usage: result.usage || 0,
      };
    }
    return {
      action: 'send',
      content,
      reasonCodes: Array.isArray(parsed.reasonCodes)
        ? parsed.reasonCodes
        : ['persona_send'],
      rationale: String(parsed.rationale || '').trim(),
      model: result.modelSelectionId || result.model || null,
      usage: result.usage || 0,
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
