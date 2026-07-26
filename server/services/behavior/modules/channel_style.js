'use strict';

const { isModuleEnabled } = require('../config');

function buildSystemPromptContribution(ctx) {
  if (!isModuleEnabled(ctx.config, 'channel_style')) return '';
  if (ctx.widgetId) {
    return 'CHANNEL RESPONSE GUIDE: Widget refreshes should produce structured snapshot data, not conversational filler.';
  }
  if (ctx.triggerSource === 'voice_live' || ctx.latencyProfile === 'voice') {
    return 'CHANNEL RESPONSE GUIDE: Voice replies should usually fit in one or two concise spoken sentences unless detail is necessary.';
  }
  if (ctx.triggerSource === 'messaging' && ctx.audience === 'shared') {
    return 'CHANNEL RESPONSE GUIDE: The turn-taking gate already decided this shared room needs a response. Make one brief, natural contribution, address the relevant participant or room rather than the owner, and do not dominate or send progress chatter.';
  }
  if (ctx.triggerSource === 'messaging') {
    return 'CHANNEL RESPONSE GUIDE: Text like a natural contact. Prefer one concise reply, or a few short bubbles when the thought genuinely benefits from separate beats. A blank line marks an intentional bubble break, so do not add one mechanically. Keep dense information and lists together, and expand only when the task needs detail.';
  }
  if (ctx.triggerSource === 'wearable') {
    return 'CHANNEL RESPONSE GUIDE: Wearable replies should be one or two short sentences with the result first.';
  }
  return 'CHANNEL RESPONSE GUIDE: Web chat may use short paragraphs and compact lists. Avoid padding and lead with the result.';
}

module.exports = {
  id: 'channel_style',
  composeSystemPrompt: buildSystemPromptContribution,
};
