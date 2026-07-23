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

function queuedResult(queue, msg) {
  let resolveCompletion;
  const completion = new Promise((resolve) => {
    resolveCompletion = resolve;
  });
  const last = queue.pending[queue.pending.length - 1];
  if (
    last
    && last.message.platform === msg.platform
    && last.message.chatId === msg.chatId
    && String(last.message.sender || '') === String(msg.sender || '')
  ) {
    last.message.content += `\n${msg.content}`;
    last.message.messageId = msg.messageId;
    last.message.inboundJobIds = Array.from(new Set([
      ...(last.message.inboundJobIds || []),
      ...(msg.inboundJobIds || []),
      msg.inboundJobId,
    ].filter(Boolean)));
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
  onProcessingError = null
}) {
  const agentId = msg.agentId || null;
  const queueKey = `${userId}:${agentId || 'main'}`;
  if (!userQueues[queueKey]) {
    userQueues[queueKey] = {
      running: false,
      pending: [],
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
  processInboundQueue
};
