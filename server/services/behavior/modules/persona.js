'use strict';

const { isModuleEnabled } = require('../config');
const { requestStructuredJson } = require('../model_client');
const { truncate } = require('../signals');
const { BASELINE_PERSONA_PROMPT } = require('./persona_prompt');

const INTERACTION_VOICE_RULES = `Mandatory interaction-voice editing rules:
- Preserve every fact, number, name, date, URL, citation, command, result, uncertainty, warning, and user-relevant blocker. Never add a fact.
- Preserve requested formatting and substantive detail. A detailed or multi-part deliverable may remain long.
- Match the actual user's casing, punctuation, vocabulary, directness, and established emoji register.
- Short social messages should usually become one original line.
- Everyday advice should be direct and at most three short sentences unless nuance or safety requires more.
- Straightforward factual answers should usually be one compact paragraph, not a headed article or exhaustive list.
- Keep sensitive replies restrained. If a serious draft is already one or two attentive sentences with no advice menu, send it unchanged. Never add an offer to talk, vent, get support, or use distraction. Remove therapy language, support-option menus, unsolicited coping advice, and "I'm here if you want to talk" closers unless the user explicitly requested that support.
- Remove canned praise, question-grading, repeated acknowledgements, preambles, postambles, automatic follow-up questions, generic offers, and service sign-offs.
- If the user did not ask a question and the draft's question is only there to prolong the exchange, remove it.
- Keep at most one contextual joke. Never make serious material witty.
- A requested short draft should contain only the draft.
- In a group, make one brief contribution and never dominate the room.`;

const INTERACTION_EDITOR_PROMPT = `You are the final Interaction Voice editor for a personal AI messaging thread.
Return JSON with exactly these keys:
action ("send" or "revise"),
revisedContent (string; empty when action is send),
reasonCodes (array of short strings),
rationale (one short sentence).

The draft may be factually correct but sound like a generic assistant. You are an editor, not a second conversational partner: make the smallest necessary edit and do not replace a good draft merely to write your own response.

${INTERACTION_VOICE_RULES}

If the draft already satisfies these rules, return action "send". Otherwise return action "revise" with the complete replacement. Do not explain the edit inside revisedContent.`;

function buildSystemPromptContribution(ctx) {
  if (!isModuleEnabled(ctx.config, 'persona')) {
    return null;
  }
  const dynamic = [];
  const behaviorNotes = ctx.memoryManager && ctx.userId != null
    ? ctx.memoryManager.getAssistantBehaviorNotes(
      ctx.userId,
      { agentId: ctx.agentId },
    )
    : '';
  if (behaviorNotes) {
    dynamic.push([
      '## Assistant Behavior Notes',
      'These are durable preferences for how the agent should usually behave. System rules and the current request take priority.',
      behaviorNotes,
    ].join('\n'));
  }
  const selfState = ctx.memoryManager && ctx.userId != null
    ? ctx.memoryManager.getAssistantSelfState(
      ctx.userId,
      { agentId: ctx.agentId },
    )
    : null;
  const identity = selfState?.identity || {};
  const focus = ctx.audience === 'shared' ? {} : (selfState?.focus || {});
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

  // Large deliverables need their full information and structure preserved. The
  // main prompt owns their voice; the lightweight interaction pass owns messages.
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
