'use strict';

const { requestStructuredJson } = require('../model_client');
const { isModuleEnabled } = require('../config');
const { truncate } = require('../signals');
const { INTERACTION_VOICE_RULES } = require('./persona');

const BASE_SYSTEM_PROMPT = `You are the final reviewer for an AI draft in a multi-party chat.
Return JSON with keys:
action ("send"|"revise"|"suppress"),
revisedContent (string, required if action is revise, else empty),
risk ("low"|"medium"|"high"),
reasonCodes (array of short strings),
rationale (one short sentence).
Prefer minimal edits. Suppress only if the draft is likely harmful, invasive, clearly socially damaging, redundant after the conversation moved on, or no longer worth adding.`;

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
      risk: 'low',
      reasonCodes: ['tom_disabled_or_direct'],
    };
  }

  const content = String(draft || '').trim();
  if (!content || content.toUpperCase() === '[NO RESPONSE]') {
    return {
      action: 'send',
      content,
      risk: 'low',
      reasonCodes: ['empty_or_silent'],
    };
  }

  try {
    const runModelId = runId
      ? ctx.agentEngine?.getRunMeta?.(runId)?.modelSelectionId || null
      : null;
    const system = isModuleEnabled(config, 'persona')
      ? `${BASE_SYSTEM_PROMPT}\n\n${INTERACTION_VOICE_RULES}`
      : BASE_SYSTEM_PROMPT;
    const result = await requestStructuredJson({
      agentEngine: ctx.agentEngine,
      userId,
      agentId,
      modelId: config.decisionModelId || runModelId,
      purpose: runModelId ? 'general' : config.decisionModelPurpose,
      system,
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
        risk: parsed.risk || 'high',
        reasonCodes: parsed.reasonCodes || ['tom_suppress'],
        rationale: parsed.rationale || '',
      };
    }
    if (action === 'revise' && String(parsed.revisedContent || '').trim()) {
      return {
        action,
        content: String(parsed.revisedContent).trim(),
        risk: parsed.risk || 'medium',
        reasonCodes: parsed.reasonCodes || ['tom_revise'],
        rationale: parsed.rationale || '',
      };
    }
    return {
      action: 'send',
      content,
      risk: parsed.risk || 'low',
      reasonCodes: parsed.reasonCodes || ['tom_send'],
      rationale: parsed.rationale || '',
    };
  } catch (error) {
    if (signal?.aborted) throw error;
    return {
      action: 'send',
      content,
      risk: 'low',
      reasonCodes: ['tom_error_passthrough'],
      failureCode: 'model_unavailable',
    };
  }
}

module.exports = {
  id: 'theory_of_mind',
  refineDraft,
};
