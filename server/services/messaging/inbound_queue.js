'use strict';

const { getErrorMessage } = require('../bootstrap_helpers');

function completionResult(outcome, cancelled = false) {
  return {
    runId: outcome?.runId || null,
    result: outcome?.result || null,
    error: outcome?.error || null,
    cancelled,
  };
}

function settleWaiters(item, result) {
  for (const resolve of item?.waiters || []) resolve(result);
  if (item?.waiters) item.waiters = [];
}

function cancelPending(queue) {
  const result = completionResult(null, true);
  for (const item of queue.pending.splice(0)) settleWaiters(item, result);
}

function queueKeyForMessage(userId, msg) {
  return [
    String(userId),
    String(msg.agentId || 'main'),
    String(msg.platform || ''),
    String(msg.chatId || ''),
  ].join(':');
}

function batchEntry(msg) {
  return {
    sender: msg.sender || null,
    senderName: msg.senderDisplayName || msg.senderName || msg.senderUsername || null,
    content: String(msg.content || ''),
    messageId: msg.messageId || null,
    timestamp: msg.timestamp || null,
    wasMentioned: msg.wasMentioned === true,
    repliedToAgent: msg.repliedToAgent === true,
  };
}

function mergeMessage(target, msg) {
  const existingBatch = Array.isArray(target.message.messageBatch)
    ? target.message.messageBatch
    : [batchEntry(target.message)];
  const nextBatch = [...existingBatch, batchEntry(msg)];
  target.message.messageBatch = nextBatch;
  target.message.content = target.message.isGroup
    ? nextBatch.map((entry) => (
      `[${entry.senderName || entry.sender || 'participant'}]: ${entry.content}`
    )).join('\n')
    : nextBatch.map((entry) => entry.content).join('\n');
  target.message.messageId = msg.messageId || target.message.messageId;
  target.message.timestamp = msg.timestamp || target.message.timestamp;
  target.message.wasMentioned = target.message.wasMentioned === true || msg.wasMentioned === true;
  target.message.repliedToAgent = target.message.repliedToAgent === true || msg.repliedToAgent === true;
  target.message.behaviorTurnEpoch = Math.max(
    Number(target.message.behaviorTurnEpoch || 0),
    Number(msg.behaviorTurnEpoch || 0),
  );
  target.message.inboundJobIds = Array.from(new Set([
    ...(target.message.inboundJobIds || []),
    target.message.inboundJobId,
    ...(msg.inboundJobIds || []),
    msg.inboundJobId,
  ].filter(Boolean)));
}

function queuedResult(queue, msg) {
  let resolveCompletion;
  const completion = new Promise((resolve) => {
    resolveCompletion = resolve;
  });
  const last = queue.collecting && queue.activeItem
    ? queue.activeItem
    : queue.pending[queue.pending.length - 1];
  if (
    last
    && last.message.platform === msg.platform
    && last.message.chatId === msg.chatId
    && (
      last.message.isGroup === true
      || String(last.message.sender || '') === String(msg.sender || '')
    )
  ) {
    mergeMessage(last, msg);
    last.waiters.push(resolveCompletion);
  } else {
    queue.pending.push({
      message: { ...msg },
      waiters: [resolveCompletion],
    });
  }
  const result = { queued: true };
  Object.defineProperty(result, 'completion', { value: completion });
  return result;
}

async function processInboundQueue({
  userQueues,
  userId,
  msg,
  executeMessage,
  onProcessingError = null,
  batchWindowMs = 0,
}) {
  const queueKey = queueKeyForMessage(userId, msg);
  if (!userQueues[queueKey]) {
    userQueues[queueKey] = {
      running: false,
      pending: [],
      activeItem: null,
      collecting: false,
      cancelRequested: false,
      cancelPending() {
        cancelPending(this);
      },
    };
  }
  const queue = userQueues[queueKey];

  if (queue.cancelRequested && !queue.running) {
    cancelPending(queue);
    queue.cancelRequested = false;
  }

  if (queue.running) {
    return queuedResult(queue, msg);
  }

  queue.running = true;
  let currentItem = { message: msg, waiters: [] };
  let processedCount = 0;
  let failedCount = 0;
  let cancelled = false;
  let initialOutcome = null;

  try {
    while (currentItem) {
      queue.activeItem = currentItem;
      const delayMs = currentItem.message.isGroup
        ? Math.max(0, Math.min(5000, Number(batchWindowMs) || 0))
        : 0;
      if (delayMs > 0) {
        queue.collecting = true;
        await new Promise((resolve) => setTimeout(resolve, delayMs));
        queue.collecting = false;
      }
      let outcome;
      try {
        outcome = await executeMessage(currentItem.message);
      } catch (error) {
        outcome = { runId: null, result: null, error };
      }
      processedCount += 1;
      const itemCancelled = queue.cancelRequested;
      const itemResult = completionResult(outcome, itemCancelled);
      if (!initialOutcome) initialOutcome = itemResult;
      settleWaiters(currentItem, itemResult);

      if (outcome?.error && !queue.cancelRequested) {
        failedCount += 1;
        await notifyProcessingError(onProcessingError, {
          error: outcome.error,
          runId: outcome.runId,
          userId,
          failedMessage: currentItem.message
        });
      }

      if (queue.cancelRequested) {
        cancelPending(queue);
        cancelled = true;
        break;
      }

      currentItem = queue.pending.shift() || null;
    }
  } finally {
    queue.running = false;
    queue.collecting = false;
    queue.activeItem = null;
    cancelPending(queue);
    queue.cancelRequested = false;
    if (userQueues[queueKey] === queue) {
      delete userQueues[queueKey];
    }
  }

  const result = {
    processedCount,
    failedCount,
    cancelled
  };
  Object.defineProperty(result, 'outcome', {
    value: initialOutcome || completionResult(null, cancelled),
  });
  return result;
}

async function notifyProcessingError(handler, details) {
  if (typeof handler !== 'function') {
    console.error(
      `[MessagingAutomation] Agent run failed platform=${details.failedMessage.platform} user=${details.userId}:`,
      getErrorMessage(details.error)
    );
    return;
  }

  try {
    await handler(details);
  } catch (error) {
    console.error(
      '[MessagingAutomation] Failed to report an agent run error:',
      getErrorMessage(error)
    );
  }
}

module.exports = {
  processInboundQueue,
  queueKeyForMessage,
};
