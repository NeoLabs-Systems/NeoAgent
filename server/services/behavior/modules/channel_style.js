'use strict';

const { isModuleEnabled } = require('../config');

function buildSystemPromptContribution(ctx) {
  if (!isModuleEnabled(ctx.config, 'channel_style')) return '';
  if (ctx.triggerSource === 'voice_live' || ctx.latencyProfile === 'voice') {
    return 'CHANNEL: spoken conversation. Natural sentences, as many as the answer needs; small talk stays quick, real questions get a real answer.';
  }
  if (ctx.triggerSource === 'messaging' && ctx.audience === 'shared') {
    return 'CHANNEL: a natural contribution in the room; do not dominate or narrate tools. When someone asks you for something, give the full answer.';
  }
  if (ctx.triggerSource === 'messaging') {
    return 'CHANNEL: text like a contact. One reply, or a few bubbles when the thought has separate beats. Casual chat stays casual; a task or question gets a complete answer.';
  }
  if (ctx.triggerSource === 'wearable') {
    return 'CHANNEL: spoken, result first; small talk quick, real answers complete.';
  }
  return 'CHANNEL: short paragraphs or compact lists; lead with the result; no padding.';
}

module.exports = {
  id: 'channel_style',
  composeSystemPrompt: buildSystemPromptContribution,
};
