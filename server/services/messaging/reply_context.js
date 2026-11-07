'use strict';

const { fenceUntrusted } = require('../../utils/untrusted_text');

const REPLY_CONTEXT_CHARS = 1500;

// A quote-reply answers one earlier message, which may be far back in the
// chat. Without it, "try again" or "photo please" reads as being about
// whatever was said last.
function buildReplyContextBlock(msg = {}) {
  const reply = msg.replyTo;
  const content = String(reply?.content || '').trim();
  if (!content) return '';
  const clipped = content.length > REPLY_CONTEXT_CHARS
    ? `${content.slice(0, REPLY_CONTEXT_CHARS)}…`
    : content;
  if (reply.fromAgent) {
    return `This message is a reply to one of your earlier messages:\n${fenceUntrusted('external_replied_message', clipped)}`;
  }
  return `This message is a reply to an earlier message:\n${fenceUntrusted(
    'external_replied_message',
    `[${reply.sender || 'another participant'}]: ${clipped}`,
  )}`;
}

module.exports = { buildReplyContextBlock };
