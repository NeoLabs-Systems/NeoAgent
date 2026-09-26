'use strict';

const { requestDecision, requestStructuredJson } = require('../model_client');
const { isModuleEnabled } = require('../config');
const { truncate } = require('../signals');
const { INTERACTION_VOICE_RULES } = require('./persona');

const BASE_SYSTEM_PROMPT = `You are the final reviewer for an AI draft in a multi-party chat.
Return JSON with keys:
action ("send"|"revise"|"suppress"),
revisedContent (string, required if action is revise, else empty),
reasonCodes (array of short strings).
Prefer minimal edits. Suppress only if the draft is likely harmful, invasive, clearly socially damaging, redundant after the conversation moved on, or no longer worth adding.`;

// Jev clears a draft that can go out untouched, so the reviewer model only
// runs when something may need changing. The bar is high: in evaluation every
// draft the model revised or suppressed scored 0.3 or lower.
const JEV_READY_THRESHOLD = 0.8;

function readyQuestion(voiceRules) {
  return {
    ready_as_is: {
      type: 'noul',
      instructions: voiceRules
        ? '`draft` can be posted in the group chat exactly as written, with no edits: it fits `inbound`, follows every rule in `voice_rules`, and is not harmful, invasive, insensitive, or redundant.'
        : '`draft` can be posted in the group chat exactly as written, with no edits: it fits `inbound` and is not harmful, invasive, insensitive, or redundant.',
    },
  };
}

async function jevClearsDraft(ctx, content, voiceRules) {
  const { msg } = ctx;
  const answers = await requestDecision({
    agentEngine: ctx.agentEngine,
    userId: ctx.userId,
    agentId: ctx.agentId,
    runId: ctx.runId || null,
    phase: 'jev_draft_review',
    signal: ctx.signal || null,
    state: {
      ...(voiceRules ? { voice_rules: voiceRules } : {}),
      chat: { platform: msg.platform, group: true },
      inbound: { sender: msg.senderName || msg.sender, content: truncate(msg.content, 500) },
      draft: truncate(content, 2800),
    },
    questions: readyQuestion(voiceRules),
  });
  return Number(answers?.ready_as_is?.noul) >= JEV_READY_THRESHOLD;
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

  if (!msg?.isGroup || !isModuleEnabled(config, 'theory_of_mind')) {
    return {
      action: 'send',
      content: draft,
      reasonCodes: ['tom_disabled_or_direct'],
    };
  }

  const content = String(draft || '').trim();
  if (!content || content.toUpperCase() === '[NO RESPONSE]') {
    return {
      action: 'send',
      content,
      reasonCodes: ['empty_or_silent'],
    };
  }

  const voiceRules = isModuleEnabled(config, 'persona') ? INTERACTION_VOICE_RULES : '';
  if (await jevClearsDraft(ctx, content, voiceRules)) {
    return {
      action: 'send',
      content,
      reasonCodes: ['jev_ready_as_is'],
    };
  }

  try {
    const runModelId = runId
      ? ctx.agentEngine?.getRunMeta?.(runId)?.modelSelectionId || null
      : null;
    const result = await requestStructuredJson({
      agentEngine: ctx.agentEngine,
      userId,
      agentId,
      modelId: config.decisionModelId || runModelId,
      purpose: runModelId ? 'general' : config.decisionModelPurpose,
      system: voiceRules ? `${BASE_SYSTEM_PROMPT}\n\n${voiceRules}` : BASE_SYSTEM_PROMPT,
      prompt: JSON.stringify({
        room: {
          platform: msg.platform,
          chatId: msg.chatId,
          isGroup: true,
          sender: msg.senderName || msg.sender,
          inbound: truncate(msg.content, 500),
        },
        draft: truncate(content, 2800),
      }),
      signal,
      maxTokens: 900,
    });
    const parsed = result.parsed || {};
    const action = ['send', 'revise', 'suppress'].includes(String(parsed.action || ''))
      ? String(parsed.action)
      : 'send';
    if (action === 'suppress') {
      return {
        action,
        content: '[NO RESPONSE]',
        reasonCodes: parsed.reasonCodes || ['tom_suppress'],
      };
    }
    if (action === 'revise' && String(parsed.revisedContent || '').trim()) {
      return {
        action,
        content: String(parsed.revisedContent).trim(),
        reasonCodes: parsed.reasonCodes || ['tom_revise'],
      };
    }
    return {
      action: 'send',
      content,
      reasonCodes: parsed.reasonCodes || ['tom_send'],
    };
  } catch (error) {
    if (signal?.aborted) throw error;
    return {
      action: 'send',
      content,
      reasonCodes: ['tom_error_passthrough'],
      failureCode: 'model_unavailable',
    };
  }
}

module.exports = {
  id: 'theory_of_mind',
  refineDraft,
};
