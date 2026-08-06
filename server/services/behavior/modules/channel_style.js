'use strict';

const { isModuleEnabled } = require('../config');

function buildSystemPromptContribution(ctx) {
  if (!isModuleEnabled(ctx.config, 'channel_style')) return '';
  if (ctx.widgetId) {
    return 'CHANNEL: widget output should be structured snapshot data, not chat filler.';
  }
  if (ctx.triggerSource === 'voice_live' || ctx.latencyProfile === 'voice') {
    return 'CHANNEL: speak in one or two short sentences unless detail is necessary.';
  }
  if (ctx.triggerSource === 'messaging' && ctx.audience === 'shared') {
    return 'CHANNEL: one brief natural contribution in the room; do not dominate or narrate tools.';
  }
  if (ctx.triggerSource === 'messaging') {
    return 'CHANNEL: text like a contact. Prefer one concise reply, or a few short bubbles only when the thought needs separate beats.';
  }
  if (ctx.triggerSource === 'wearable') {
    return 'CHANNEL: one or two short sentences, result first.';
  }
  return 'CHANNEL: short paragraphs or compact lists; lead with the result; no padding.';
}

module.exports = {
  id: 'channel_style',
  composeSystemPrompt: buildSystemPromptContribution,
};
