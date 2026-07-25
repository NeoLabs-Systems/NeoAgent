'use strict';

const { requestStructuredJson } = require('../model_client');
const { isModuleEnabled } = require('../config');
const { truncate } = require('../signals');

const SYSTEM_PROMPT = `You refine an AI draft for a multi-party chat using lightweight theory of mind.
Return JSON with keys:
action ("send"|"revise"|"suppress"),
revisedContent (string, required if action is revise, else empty),
risk ("low"|"medium"|"high"),
reasonCodes (array of short strings),
rationale (one short sentence).
Preserve the agent's voice and safety limits. Prefer minimal edits. Suppress only if the draft is likely harmful, invasive, or clearly socially damaging.`;

async function refineDraft(ctx) {
  const {
    userId,
    agentId,
    msg,
    config,
    draft,
    signal = null,
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
    const result = await requestStructuredJson({
      userId,
      agentId,
      preference: 'cheap',
      system: SYSTEM_PROMPT,
      prompt: JSON.stringify({
        room: {
          platform: msg.platform,
          chatId: msg.chatId,
          isGroup: true,
          sender: msg.senderName || msg.sender,
          inbound: truncate(msg.content, 500),
        },
        draft: truncate(content, 1800),
      }),
      signal,
      maxTokens: 350,
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
      error: error?.message || String(error),
    };
  }
}

module.exports = {
  id: 'theory_of_mind',
  refineDraft,
};
