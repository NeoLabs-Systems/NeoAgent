'use strict';

// What one run knows about what it has shown the user. The outbox is the
// authority on whether a message went out; this is the per-run view the loop,
// the send tools, and the task runtime read.
function createRunDelivery(seed = {}) {
  return {
    // A background task's resolved target: results go here, whatever the model named.
    notifyTarget: seed.notifyTarget || null,
    // The run's final answer has reached the user, and what it said.
    finalDelivered: false,
    finalContent: '',
    // The model chose silence.
    noResponse: false,
    // A reply in the run's own chat is still its last word; once it works on,
    // the final answer is new.
    lastWordSent: false,
    // The run asked the user something and is waiting.
    awaitingReply: null,
    // A task's message, held until the run ends.
    staged: null,
    // A guard ended the run, so its answer never had the chance to use send_message.
    wrappedUp: false,
    // Messages that answered the request, oldest first. An interim update says
    // work is under way; it never stands in for a task's result.
    sent: [],
  };
}

function markSent(delivery, content) {
  const text = String(content || '').trim();
  if (delivery && text) delivery.sent.push(text);
}

function lastSent(delivery) {
  return delivery?.sent?.length ? delivery.sent[delivery.sent.length - 1] : '';
}

module.exports = {
  createRunDelivery,
  lastSent,
  markSent,
};
