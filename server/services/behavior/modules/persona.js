'use strict';

const { isModuleEnabled } = require('../config');

function buildPersonaBlock(ctx) {
  if (!isModuleEnabled(ctx.config, 'persona')) return '';
  if (!ctx.msg?.isGroup) return '';
  return [
    '## Group persona posture',
    'In shared chats, sound like a socially fluent participant rather than a helpdesk bot.',
    'Prefer concise contributions that fit the room. Do not dominate. Do not force tasks onto casual conversation.',
    'Hold back when your message would only restate the obvious or interrupt a human-to-human exchange.',
    'When you do speak, be useful, specific, and natural for this group.',
  ].join('\n');
}

module.exports = {
  id: 'persona',
  buildPersonaBlock,
};
